"""
Phase 1 — Social Discovery Service.

Fetches high-signal posts from 3 social platforms (Reddit, HN, HuggingFace),
filters by engagement + research keywords, extracts identifiers and title
phrases, deduplicates, ranks by buzz, and returns the top N candidates.
"""
import re
import time
import logging
import httpx
from dataclasses import dataclass, field

from config import (
    REDDIT_USER_AGENT, REDDIT_SUBREDDITS,
    REDDIT_MIN_SCORE, HN_MIN_POINTS,
    RESEARCH_KEYWORDS, MAX_CANDIDATES_PER_CYCLE,
)

logger = logging.getLogger("social_discovery")

# ── Shared async client ──────────────────────────────────────────────────
_client: httpx.AsyncClient | None = None


async def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(timeout=20.0, follow_redirects=True)
    return _client


async def close_client() -> None:
    global _client
    if _client is not None:
        await _client.aclose()
        _client = None


# ── Extraction patterns ──────────────────────────────────────────────────
DOI_PATTERN = re.compile(r'10\.\d{4,9}/[^\s\]\)">]+')
ARXIV_PATTERN = re.compile(
    r'(?:arxiv\.org/abs/|arxiv:)(\d{4}\.\d{4,5}(?:v\d+)?)', re.IGNORECASE
)
# Title-like phrases: "paper titled X", quoted text, capitalized sequences
TITLE_AFTER_PATTERN = re.compile(
    r'(?:paper\s+titled|study\s+called|paper\s+called|titled)\s*[:\-]?\s*["\u201c](.+?)["\u201d]',
    re.IGNORECASE,
)
QUOTED_PATTERN = re.compile(r'["\u201c]([A-Z][^"\u201d]{15,120})["\u201d]')
CAP_PHRASE_PATTERN = re.compile(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){2,11})\b')

# Research keywords as a set for fast lookup
_KW_SET = set(RESEARCH_KEYWORDS)


# ── Data structures ──────────────────────────────────────────────────────
@dataclass
class SocialCandidate:
    """A candidate paper identified through social buzz."""
    identifier: str | None = None      # DOI or arXiv ID (if found)
    identifier_type: str | None = None  # "doi" or "arxiv"
    title_phrase: str | None = None     # Extracted title phrase
    source_platforms: set = field(default_factory=set)
    mention_count: int = 0
    total_engagement: int = 0
    post_urls: list = field(default_factory=list)
    title: str | None = None           # Best available title
    abstract: str | None = None        # Best available abstract
    authors: list = field(default_factory=list)
    discovered_at: float = 0.0         # Timestamp of discovery

    @property
    def has_direct_id(self) -> bool:
        return self.identifier is not None

    @property
    def buzz_score(self) -> float:
        """Pre-resolution ranking score for candidate selection."""
        return len(self.source_platforms) * 10 + self.total_engagement


# ── Keyword & quality filters ────────────────────────────────────────────
def _is_research_post(text: str) -> bool:
    """Check if the text is research-related via keyword matching."""
    lower = text.lower()
    return any(kw in lower for kw in _KW_SET)


def _has_identifier_signal(text: str) -> bool:
    """Check if the text contains arXiv/DOI patterns."""
    return bool(DOI_PATTERN.search(text)) or bool(ARXIV_PATTERN.search(text))


def _extract_identifiers(text: str) -> list[tuple[str, str]]:
    """Extract DOI and arXiv IDs from text. Returns [(id, type), ...]."""
    results = []
    for match in DOI_PATTERN.finditer(text):
        results.append((match.group(0).rstrip(".,;"), "doi"))
    for match in ARXIV_PATTERN.finditer(text):
        results.append((match.group(1), "arxiv"))
    return results


def _extract_title_phrases(text: str) -> list[str]:
    """Extract candidate paper titles from post text."""
    phrases = []
    # 1. "paper titled X" patterns
    for m in TITLE_AFTER_PATTERN.finditer(text):
        phrases.append(m.group(1).strip())
    # 2. Quoted capitalized phrases (15-120 chars)
    for m in QUOTED_PATTERN.finditer(text):
        phrases.append(m.group(1).strip())
    # 3. Capitalized multi-word phrases (3-12 words)
    for m in CAP_PHRASE_PATTERN.finditer(text):
        phrase = m.group(1).strip()
        if len(phrase.split()) >= 3:
            phrases.append(phrase)
    # Deduplicate
    seen = set()
    unique = []
    for p in phrases:
        norm = p.lower()
        if norm not in seen:
            seen.add(norm)
            unique.append(p)
    return unique[:5]  # Cap at 5 per post


# ═════════════════════════════════════════════════════════════════════════
# FETCHER 1: REDDIT
# ═════════════════════════════════════════════════════════════════════════

async def fetch_reddit_candidates(domain: str | None = None) -> list[SocialCandidate]:
    """Fetch research-related posts from Reddit, filtered by engagement."""
    client = await _get_client()
    candidates = []

    subreddits = (
        REDDIT_SUBREDDITS.get(domain, ["science"])
        if domain
        else ["science", "MachineLearning", "Physics"]
    )

    for sub in subreddits[:3]:
        try:
            url = f"https://www.reddit.com/r/{sub}/search.json"
            params = {
                "q": "paper OR study OR preprint OR arxiv OR doi.org",
                "sort": "hot",
                "t": "month",
                "limit": "50",
                "restrict_sr": "on",
            }
            headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
            resp = await client.get(url, params=params, headers=headers)
            if resp.status_code != 200:
                logger.warning(f"Reddit r/{sub}: {resp.status_code}")
                continue

            for post in resp.json().get("data", {}).get("children", []):
                pd = post.get("data", {})
                score = pd.get("score", 0)
                comments = pd.get("num_comments", 0)
                engagement = score + comments

                # ── Engagement gate ──
                if score < 10:
                    continue

                text = f"{pd.get('title', '')} {pd.get('selftext', '')} {pd.get('url', '')}"

                # ── Research filter ──
                if not (_is_research_post(text) or _has_identifier_signal(text)):
                    continue

                # ── Extract identifiers ──
                identifiers = _extract_identifiers(text)
                post_url = f"https://reddit.com{pd.get('permalink', '')}"
                post_title = pd.get("title", "")

                if identifiers:
                    for pid, ptype in identifiers:
                        candidates.append(SocialCandidate(
                            identifier=pid,
                            identifier_type=ptype,
                            source_platforms={"reddit"},
                            mention_count=1,
                            total_engagement=engagement,
                            post_urls=[post_url],
                            title=post_title,
                            abstract=pd.get("selftext", ""),
                            discovered_at=pd.get("created_utc", time.time()),
                        ))
                else:
                    # No direct ID — try title phrases
                    phrases = _extract_title_phrases(text)
                    for phrase in phrases:
                        candidates.append(SocialCandidate(
                            title_phrase=phrase,
                            source_platforms={"reddit"},
                            mention_count=1,
                            total_engagement=engagement,
                            post_urls=[post_url],
                            title=post_title,
                            discovered_at=pd.get("created_utc", time.time()),
                        ))

        except Exception as e:
            logger.error(f"Reddit r/{sub} error: {e}")

    return candidates


# ═════════════════════════════════════════════════════════════════════════
# FETCHER 2: HACKER NEWS
# ═════════════════════════════════════════════════════════════════════════

async def fetch_hn_candidates() -> list[SocialCandidate]:
    """Fetch research posts from Hacker News, filtered by points."""
    client = await _get_client()
    candidates = []

    try:
        one_month_ago = int(time.time() - 30 * 24 * 3600)
        url = "https://hn.algolia.com/api/v1/search"
        params = {
            "query": "arxiv.org OR paper OR doi.org",
            "tags": "story",
            "hitsPerPage": "50",
            "numericFilters": f"points>{10},created_at_i>{one_month_ago}",
        }
        resp = await client.get(url, params=params)
        resp.raise_for_status()

        for hit in resp.json().get("hits", []):
            points = hit.get("points", 0) or 0
            text = f"{hit.get('title', '')} {hit.get('url', '')} {hit.get('story_text', '')}"

            if not (_is_research_post(text) or _has_identifier_signal(text)):
                continue

            identifiers = _extract_identifiers(text)
            post_url = f"https://news.ycombinator.com/item?id={hit.get('objectID', '')}"
            post_title = hit.get("title", "")

            if identifiers:
                for pid, ptype in identifiers:
                    candidates.append(SocialCandidate(
                        identifier=pid,
                        identifier_type=ptype,
                        source_platforms={"hn"},
                        mention_count=1,
                        total_engagement=points,
                        post_urls=[post_url],
                        title=post_title,
                        abstract=hit.get("story_text", ""),
                        discovered_at=hit.get("created_at_i", time.time()),
                    ))
            else:
                phrases = _extract_title_phrases(text)
                for phrase in phrases:
                    candidates.append(SocialCandidate(
                        title_phrase=phrase,
                        source_platforms={"hn"},
                        mention_count=1,
                        total_engagement=points,
                        post_urls=[post_url],
                        title=post_title,
                        discovered_at=hit.get("created_at_i", time.time()),
                    ))

    except Exception as e:
        logger.error(f"HackerNews error: {e}")

    return candidates


# ═════════════════════════════════════════════════════════════════════════
# FETCHER 3: HUGGINGFACE DAILY PAPERS
# ═════════════════════════════════════════════════════════════════════════

async def fetch_huggingface_candidates() -> list[SocialCandidate]:
    """Fetch trending papers from HuggingFace Daily Papers (always high-signal)."""
    client = await _get_client()
    candidates = []

    try:
        url = "https://huggingface.co/api/daily_papers"
        resp = await client.get(url)
        resp.raise_for_status()

        for paper_obj in resp.json():
            paper = paper_obj.get("paper", {})
            arxiv_id = paper.get("id")
            if not arxiv_id:
                continue

            authors = [a.get("name", "") for a in paper.get("authors", []) if a.get("name")]
            candidates.append(SocialCandidate(
                identifier=arxiv_id,
                identifier_type="arxiv",
                source_platforms={"huggingface"},
                mention_count=1,
                total_engagement=paper.get("upvotes", 0) or 1,
                post_urls=[f"https://huggingface.co/papers/{arxiv_id}"],
                title=paper.get("title", ""),
                abstract=paper.get("summary", ""),
                authors=authors,
                discovered_at=time.time(),
            ))

    except Exception as e:
        logger.error(f"HuggingFace Daily Papers error: {e}")

    return candidates


# ═════════════════════════════════════════════════════════════════════════
# DEDUPLICATION + RANKING
# ═════════════════════════════════════════════════════════════════════════

def _deduplicate_candidates(raw: list[SocialCandidate]) -> list[SocialCandidate]:
    """Merge candidates sharing the same identifier or similar title phrase."""
    by_id: dict[str, SocialCandidate] = {}      # key: "doi:xxx" or "arxiv:xxx"
    by_title: dict[str, SocialCandidate] = {}    # key: normalised title phrase

    for c in raw:
        if c.has_direct_id:
            key = f"{c.identifier_type}:{c.identifier}"
            if key in by_id:
                _merge_into(by_id[key], c)
            else:
                by_id[key] = c
        elif c.title_phrase:
            norm = c.title_phrase.lower().strip()
            if norm in by_title:
                _merge_into(by_title[norm], c)
            else:
                by_title[norm] = c

    # Remove title-phrase candidates if we already have their ID from another platform
    result = list(by_id.values())
    id_titles = {c.title.lower().strip() for c in result if c.title}
    for tc in by_title.values():
        norm_title = (tc.title_phrase or "").lower().strip()
        if norm_title not in id_titles:
            result.append(tc)

    return result


def _merge_into(target: SocialCandidate, source: SocialCandidate) -> None:
    """Merge source candidate data into target."""
    target.source_platforms |= source.source_platforms
    target.mention_count += source.mention_count
    target.total_engagement += source.total_engagement
    target.post_urls.extend(source.post_urls)
    if source.title and (not target.title or len(source.title) > len(target.title)):
        target.title = source.title
    if source.abstract and (not target.abstract or len(source.abstract) > len(target.abstract)):
        target.abstract = source.abstract
    if source.authors and len(source.authors) > len(target.authors):
        target.authors = source.authors
    if source.discovered_at and source.discovered_at < (target.discovered_at or float("inf")):
        target.discovered_at = source.discovered_at


def _rank_and_cap(candidates: list[SocialCandidate], max_n: int) -> list[SocialCandidate]:
    """Sort by buzz score (platform count × engagement), cap at max_n."""
    candidates.sort(key=lambda c: c.buzz_score, reverse=True)
    return candidates[:max_n]


# ═════════════════════════════════════════════════════════════════════════
# MAIN ENTRY POINT
# ═════════════════════════════════════════════════════════════════════════

async def fetch_all_social_candidates(domain: str | None = None) -> list[SocialCandidate]:
    """
    Phase 1: Run all social fetchers → deduplicate → rank → return top N.
    """
    import asyncio

    tasks = [
        fetch_reddit_candidates(domain),
        fetch_hn_candidates(),
        fetch_huggingface_candidates(),
    ]

    results = await asyncio.gather(*tasks, return_exceptions=True)
    raw_candidates = []
    platform_names = ["Reddit", "HackerNews", "HuggingFace"]

    for i, result in enumerate(results):
        if isinstance(result, Exception):
            logger.error(f"{platform_names[i]} fetcher failed: {result}")
        else:
            logger.info(f"{platform_names[i]}: {len(result)} raw candidates")
            raw_candidates.extend(result)

    logger.info(f"Phase 1: {len(raw_candidates)} raw candidates from 3 platforms")

    # Deduplicate across platforms
    deduped = _deduplicate_candidates(raw_candidates)
    logger.info(f"Phase 1: {len(deduped)} after deduplication")

    # Rank by buzz and cap
    top = _rank_and_cap(deduped, MAX_CANDIDATES_PER_CYCLE)
    logger.info(f"Phase 1: top {len(top)} candidates selected for resolution")

    return top
