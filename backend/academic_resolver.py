"""
Phase 2 — Academic Resolution Cascade.

Resolves social candidates to real academic papers via a 3-tier fallback:
  1. OpenAlex  (by ID, then by title search)
  2. arXiv API (title search)
  3. Semantic Scholar (final fallback, high-engagement only)

Each resolution is confidence-gated. Results are cached in Redis.
"""
import logging
import math
import time
from difflib import SequenceMatcher

import redis_client
import openalex_service
from social_trending_service import SocialCandidate
from config import (
    CONFIDENCE_THRESHOLD,
    TITLE_SIMILARITY_THRESHOLD,
    RESOLVE_CACHE_TTL,
    SEMANTIC_SCHOLAR_API_KEY,
)

logger = logging.getLogger("academic_resolver")


# ── Public API ───────────────────────────────────────────────────────────

async def resolve_candidate(candidate: SocialCandidate) -> dict | None:
    """
    Resolve a SocialCandidate to an academic paper dict.
    Returns None if all tiers fail or confidence is too low.
    """

    # ── Check Redis cache first ──────────────────────────────────────
    cache_key = _cache_key(candidate)
    cached = await redis_client.get_resolve_cache(cache_key)
    if cached is not None:
        if cached == "__MISS__":
            return None  # Previously failed, don't retry within TTL
        # cached is a paper_id — fetch metadata
        meta = await redis_client.get_paper_metadata(cached)
        if meta:
            logger.debug(f"Cache hit: {cache_key} → {cached}")
            return meta

    # ── Tier 1: OpenAlex ─────────────────────────────────────────────
    paper = await _resolve_openalex(candidate)
    if paper:
        await _cache_result(cache_key, paper)
        return paper

    # ── Tier 2: arXiv API ────────────────────────────────────────────
    paper = await _resolve_arxiv(candidate)
    if paper:
        await _cache_result(cache_key, paper)
        return paper

    # ── Tier 3: Semantic Scholar (high-engagement only) ──────────────
    if candidate.total_engagement >= 50:
        paper = await _resolve_semantic_scholar(candidate)
        if paper:
            await _cache_result(cache_key, paper)
            return paper

    # ── All tiers failed ─────────────────────────────────────────────
    await redis_client.set_resolve_cache(cache_key, "__MISS__", RESOLVE_CACHE_TTL)
    logger.info(f"Resolution failed for: {cache_key}")
    return None


# ── Tier 1: OpenAlex ─────────────────────────────────────────────────────

async def _resolve_openalex(candidate: SocialCandidate) -> dict | None:
    """Try OpenAlex: exact ID lookup, then title search."""

    # 1a. Direct ID lookup (confidence = 1.0)
    if candidate.has_direct_id:
        paper = await openalex_service.resolve_paper_id(
            candidate.identifier, candidate.identifier_type
        )
        if paper:
            paper["_confidence"] = 1.0
            logger.info(f"OpenAlex ID match: {candidate.identifier_type}:{candidate.identifier}")
            return paper

    # 1b. Title search (fuzzy match)
    title = candidate.title or candidate.title_phrase
    if title and len(title) >= 10:
        paper = await openalex_service.resolve_by_title(title)
        if paper:
            similarity = _title_similarity(title, paper.get("title", ""))
            domain_match = 1.0 if paper.get("domain", "other") != "other" else 0.5
            recency = _recency_weight(paper.get("publication_date"))
            confidence = (
                0.6 * similarity + 0.2 * domain_match + 0.2 * recency
            )
            if confidence >= CONFIDENCE_THRESHOLD:
                paper["_confidence"] = confidence
                logger.info(f"OpenAlex title match (conf={confidence:.2f}): {title[:60]}")
                return paper
            else:
                logger.debug(f"OpenAlex title match rejected (conf={confidence:.2f}): {title[:60]}")

    return None


# ── Tier 2: arXiv API ────────────────────────────────────────────────────

async def _resolve_arxiv(candidate: SocialCandidate) -> dict | None:
    """Search arXiv by title. Creates a temporary paper entry."""
    import httpx

    # Prefer the extracted phrase (cleaner), fall back to post title
    title = candidate.title_phrase or candidate.title
    if not title or len(title) < 10:
        return None
    # Truncate to avoid sending huge queries
    title = title[:120].strip()

    try:
        client = await _get_shared_client()
        url = "https://export.arxiv.org/api/query"
        params = {
            "search_query": f'ti:"{title}"',
            "max_results": "3",
            "sortBy": "relevance",
        }
        resp = await client.get(url, params=params)
        if resp.status_code == 429:
            logger.warning("arXiv API: 429 rate limited, skipping")
            return None
        resp.raise_for_status()

        import xml.etree.ElementTree as ET
        root = ET.fromstring(resp.text)
        ns = {"atom": "http://www.w3.org/2005/Atom"}

        for entry in root.findall("atom:entry", ns):
            entry_title = entry.find("atom:title", ns)
            if entry_title is None:
                continue
            found_title = entry_title.text.strip().replace("\n", " ")
            similarity = _title_similarity(title, found_title)

            if similarity >= TITLE_SIMILARITY_THRESHOLD:
                # Extract arXiv ID
                id_elem = entry.find("atom:id", ns)
                if id_elem is None:
                    continue
                raw_id = id_elem.text.strip()
                import re
                match = re.search(r'(\d{4}\.\d{4,5})', raw_id)
                if not match:
                    continue
                arxiv_id = match.group(1)

                # Extract metadata
                summary_elem = entry.find("atom:summary", ns)
                authors = []
                for au in entry.findall("atom:author", ns):
                    name = au.find("atom:name", ns)
                    if name is not None:
                        authors.append(name.text.strip())

                paper = {
                    "paper_id": f"arxiv:{arxiv_id}",
                    "title": found_title,
                    "abstract": summary_elem.text.strip() if summary_elem is not None else None,
                    "summary": None,
                    "authors": authors,
                    "domain": "other",
                    "subdomain": "unknown",
                    "publication_date": None,
                    "year": None,
                    "citation_count": 0,
                    "is_open_access": True,
                    "landing_page_url": f"https://arxiv.org/abs/{arxiv_id}",
                    "_confidence": 0.6 * similarity + 0.2 * 1.0 + 0.2 * 1.0,
                    "_source": "arxiv",
                }
                logger.info(f"arXiv title match (sim={similarity:.2f}): {found_title[:60]}")
                return paper

    except Exception as e:
        logger.error(f"arXiv resolver error: {e}")

    return None


# ── Tier 3: Semantic Scholar ─────────────────────────────────────────────

async def _resolve_semantic_scholar(candidate: SocialCandidate) -> dict | None:
    """Final fallback: search Semantic Scholar by title."""
    title = candidate.title_phrase or candidate.title
    if not title or len(title) < 10:
        return None
    title = title[:120].strip()

    try:
        client = await _get_shared_client()
        url = "https://api.semanticscholar.org/graph/v1/paper/search"
        params = {
            "query": title,
            "limit": "3",
            "fields": "title,abstract,externalIds,year,citationCount,authors",
        }
        headers = {}
        if SEMANTIC_SCHOLAR_API_KEY:
            headers["x-api-key"] = SEMANTIC_SCHOLAR_API_KEY

        resp = await client.get(url, params=params, headers=headers)
        if resp.status_code == 429:
            logger.warning("Semantic Scholar: 429 rate limited")
            return None
        resp.raise_for_status()

        for paper_data in resp.json().get("data", []):
            found_title = paper_data.get("title", "")
            similarity = _title_similarity(title, found_title)

            if similarity >= TITLE_SIMILARITY_THRESHOLD:
                ext_ids = paper_data.get("externalIds", {}) or {}
                authors = [a.get("name", "") for a in paper_data.get("authors", []) if a.get("name")]

                paper_id = ext_ids.get("DOI") or ext_ids.get("ArXiv") or paper_data.get("paperId", "")
                paper = {
                    "paper_id": f"s2:{paper_id}",
                    "title": found_title,
                    "abstract": paper_data.get("abstract"),
                    "summary": None,
                    "authors": authors,
                    "domain": "other",
                    "subdomain": "unknown",
                    "publication_date": None,
                    "year": paper_data.get("year"),
                    "citation_count": paper_data.get("citationCount", 0),
                    "is_open_access": bool(ext_ids.get("ArXiv")),
                    "doi": ext_ids.get("DOI"),
                    "_confidence": 0.6 * similarity + 0.2 * 0.5 + 0.2 * 1.0,
                    "_source": "semantic_scholar",
                }
                logger.info(f"S2 title match (sim={similarity:.2f}): {found_title[:60]}")
                return paper

    except Exception as e:
        logger.error(f"Semantic Scholar resolver error: {e}")

    return None


# ── Helpers ──────────────────────────────────────────────────────────────

def _title_similarity(a: str, b: str) -> float:
    """Compute title similarity using SequenceMatcher."""
    return SequenceMatcher(None, a.lower().strip(), b.lower().strip()).ratio()


def _recency_weight(pub_date: str | None) -> float:
    """1.0 for papers within 2 years, decaying to 0.3 for older."""
    if not pub_date:
        return 0.8  # Unknown = assume reasonably recent
    try:
        from datetime import datetime
        dt = datetime.fromisoformat(pub_date.replace("Z", "+00:00"))
        age_days = (datetime.now(dt.tzinfo) - dt).days
        if age_days <= 365 * 2:
            return 1.0
        elif age_days <= 365 * 5:
            return 0.6
        else:
            return 0.3
    except Exception:
        return 0.8


def _cache_key(candidate: SocialCandidate) -> str:
    """Generate a cache key from candidate identifier or title phrase."""
    if candidate.has_direct_id:
        return f"{candidate.identifier_type}:{candidate.identifier}"
    elif candidate.title_phrase:
        # Normalise for cache key
        return f"title:{candidate.title_phrase.lower().strip()[:80]}"
    return f"unknown:{id(candidate)}"


async def _cache_result(cache_key: str, paper: dict) -> None:
    """Cache a successful resolution."""
    pid = paper.get("paper_id", "")
    await redis_client.set_resolve_cache(cache_key, pid, RESOLVE_CACHE_TTL)
    from config import SOCIAL_METADATA_TTL
    await redis_client.store_paper_metadata(pid, paper, SOCIAL_METADATA_TTL)


# Shared httpx client
_shared_client = None

async def _get_shared_client():
    global _shared_client
    if _shared_client is None:
        import httpx
        _shared_client = httpx.AsyncClient(timeout=20.0, follow_redirects=True)
    return _shared_client
