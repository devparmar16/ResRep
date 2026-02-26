"""
Social Trending router — serves socially trending papers from Redis.
Uses the new 'trending:social:' key prefix from the 2-phase architecture.
"""
import logging
from fastapi import APIRouter, Query

import redis_client
from models import SocialTrendingPaper, SocialTrendingResponse

logger = logging.getLogger("social_trending_router")
router = APIRouter(prefix="/social-trending", tags=["Social Trending"])


@router.get("", response_model=SocialTrendingResponse)
async def get_social_trending(
    limit: int = Query(30, ge=1, le=100, description="Max papers to return"),
):
    """Get globally trending papers across all platforms."""
    papers = await _get_trending_papers("trending:social:global", limit)
    return SocialTrendingResponse(papers=papers, total=len(papers), domain=None)


@router.get("/{domain}", response_model=SocialTrendingResponse)
async def get_social_trending_by_domain(
    domain: str,
    limit: int = Query(30, ge=1, le=50),
):
    """Get trending papers for a specific domain."""
    key = f"trending:social:{domain}"
    papers = await _get_trending_papers(key, limit)

    # Fallback to global if domain has no data
    if not papers:
        papers = await _get_trending_papers("trending:social:global", limit)

    return SocialTrendingResponse(papers=papers, total=len(papers), domain=domain)


async def _get_trending_papers(redis_key: str, limit: int) -> list[SocialTrendingPaper]:
    """Fetch top N papers from a trending sorted set with source badges."""
    r = await redis_client.get_redis()

    paper_ids_scores = await r.zrevrange(redis_key, 0, limit - 1, withscores=True)
    if not paper_ids_scores:
        return []

    papers = []
    for pid, score in paper_ids_scores:
        meta = await redis_client.get_paper_metadata(pid)
        if not meta:
            continue

        sources = await redis_client.get_social_sources(pid)

        papers.append(SocialTrendingPaper(
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
            social_score=score,
            trending_sources=sources,
            confidence=float(meta.get("_confidence", 0.0)),
        ))

    return papers
