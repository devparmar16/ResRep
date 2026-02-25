"""
Feed router — assembles user feed from domain caches.
"""
import json
import logging
from fastapi import APIRouter, Query

import redis_client
from config import (
    MAX_USER_FEED,
    USER_FEED_TTL,
    papers_per_interest,
    PAPER_METADATA_TTL,
)
from models import PaperResponse, FeedResponse
from ranking import compute_score
import openalex_service

logger = logging.getLogger("feed")
router = APIRouter(prefix="/feed", tags=["Feed"])


@router.get("", response_model=FeedResponse)
async def get_feed(
    user_id: str = Query(..., description="User identifier"),
    interests: str = Query(..., description="Comma-separated domain IDs, e.g. 'ai-ml,cloud'"),
):
    """
    Build or return a cached feed snapshot for the user.

    1. Check for existing snapshot (feed:user:{user_id})
    2. If cached and fresh → return it
    3. Else → pull from domain caches, merge, rank, snapshot, return
    """
    r = await redis_client.get_redis()
    feed_key = f"feed:user:{user_id}"

    # Check cache
    cached_ids = await r.zrevrange(feed_key, 0, -1)
    if cached_ids:
        papers = await _hydrate_papers(cached_ids)
        return FeedResponse(
            user_id=user_id, papers=papers, total=len(papers), cached=True
        )

    # Build fresh feed
    domain_ids = [d.strip() for d in interests.split(",") if d.strip()]
    papers = await _build_feed(r, user_id, domain_ids)
    return FeedResponse(
        user_id=user_id, papers=papers, total=len(papers), cached=False
    )


@router.post("/refresh", response_model=FeedResponse)
async def refresh_feed(
    user_id: str = Query(...),
    interests: str = Query(...),
):
    """Force-refresh user feed (delete snapshot, rebuild)."""
    r = await redis_client.get_redis()
    feed_key = f"feed:user:{user_id}"
    await r.delete(feed_key)

    domain_ids = [d.strip() for d in interests.split(",") if d.strip()]
    papers = await _build_feed(r, user_id, domain_ids)
    return FeedResponse(
        user_id=user_id, papers=papers, total=len(papers), cached=False
    )


# ── Internal helpers ─────────────────────────────────────────────────────

async def _build_feed(r, user_id: str, domain_ids: list[str]) -> list[PaperResponse]:
    """Assemble feed from domain caches."""
    n = len(domain_ids)
    per_domain = papers_per_interest(n) if n > 0 else 100

    all_scored: list[tuple[str, float]] = []

    for domain_id in domain_ids:
        cache_key = f"papers:domain:{domain_id}"

        # Check if domain cache exists, if not populate on-the-fly
        exists = await r.exists(cache_key)
        if not exists:
            from config import CORE_DOMAINS_CONCEPTS
            concept_id = CORE_DOMAINS_CONCEPTS.get(domain_id)
            if concept_id:
                await _populate_domain_cache(r, domain_id, concept_id)

        # Get top N paper IDs from domain sorted set
        paper_ids_scores = await r.zrevrange(cache_key, 0, per_domain - 1, withscores=True)
        for pid, score in paper_ids_scores:
            all_scored.append((pid, score))

    # Deduplicate (same paper may appear in multiple domains)
    seen = set()
    unique = []
    for pid, score in all_scored:
        if pid not in seen:
            seen.add(pid)
            unique.append((pid, score))

    # Re-rank and take top N
    unique.sort(key=lambda x: x[1], reverse=True)
    top = unique[:MAX_USER_FEED]

    # Store snapshot
    feed_key = f"feed:user:{user_id}"
    if top:
        pipe = r.pipeline()
        for pid, score in top:
            pipe.zadd(feed_key, {pid: score})
        await pipe.execute()
        await r.expire(feed_key, USER_FEED_TTL)

    # Hydrate
    papers = await _hydrate_papers([pid for pid, _ in top])
    logger.info(f"Feed built for user {user_id}: {len(papers)} papers returned (top size: {len(top)})")
    return papers


async def _populate_domain_cache(r, domain_id: str, concept_id: str) -> None:
    """On-the-fly domain cache population when cache is empty.
    Applies the custom 4-factor ranking logic using Redis engagement ZSETs.
    """
    from config import DOMAIN_CACHE_TTL, MAX_DOMAIN_PAPERS
    logger.info(f"On-the-fly cache population for domain '{domain_id}'")

    papers = await openalex_service.fetch_papers_by_domain(
        domain_id=domain_id,
        concept_id=concept_id,
        per_page=100,
    )

    cache_key = f"papers:domain:{domain_id}"
    for paper in papers:
        pid = paper["paper_id"]
        subdomain = paper.get("subdomain", "unknown")
        
        # Pull dynamic scores from Redis
        
        # 1. Subdomain Engagement (Reads + Clicks + Saves within this subdomain context)
        subdomain_trending = 0.0
        if subdomain != "unknown":
            subdomain_trending = await r.zscore(f"trending:subdomain:{subdomain}", pid) or 0.0

        # General backup trending weight
        trending_score = await r.zscore("trending:global", pid) or 0.0
        
        # 2. Recent Interaction
        recent_interaction = await r.zscore(f"engagement:click", pid) or 0.0
        
        score = compute_score(
            citation_count=paper.get("citation_count", 0),
            publication_date=paper.get("publication_date"),
            core_domain_weight=1.0, # Baseline Core Map
            subdomain_engagement=subdomain_trending, 
            recent_interaction=recent_interaction,
            trending_score=trending_score,
        )
        await redis_client.store_paper_metadata(pid, paper, PAPER_METADATA_TTL)
        await r.zadd(cache_key, {pid: score})

    await redis_client.cap_sorted_set(cache_key, MAX_DOMAIN_PAPERS)
    await r.expire(cache_key, DOMAIN_CACHE_TTL)


async def _hydrate_papers(paper_ids: list[str]) -> list[PaperResponse]:
    """Load full paper data from Redis hashes."""
    papers = []
    for pid in paper_ids:
        meta = await redis_client.get_paper_metadata(pid)
        if meta:
            papers.append(PaperResponse(
                paper_id=meta.get("paper_id", pid),
                title=meta.get("title", "Untitled"),
                abstract=meta.get("abstract"),
                summary=meta.get("summary"),
                authors=meta.get("authors", []) if isinstance(meta.get("authors"), list) else [],
                journal=meta.get("journal"),
                journal_id=meta.get("journal_id"),
                doi=meta.get("doi"),
                landing_page_url=meta.get("landing_page_url"),
                pdf_url=meta.get("pdf_url"),
                is_open_access=bool(meta.get("is_open_access", False)),
                publication_date=meta.get("publication_date"),
                year=int(meta["year"]) if meta.get("year") and str(meta["year"]).isdigit() else None,
                citation_count=int(meta.get("citation_count", 0)),
                openalex_score=float(meta.get("openalex_score", 0.0)) if meta.get("openalex_score") else 0.0,
                domain=meta.get("domain", "other"),
                subdomain=meta.get("subdomain", "unknown"),
            ))
    return papers
