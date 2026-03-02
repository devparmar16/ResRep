"""
Social Trending router — serves socially trending papers from Redis.
Uses the new 'trending:social:' key prefix from the 2-phase architecture.
"""
import logging
from fastapi import APIRouter, Query

import redis_client
import openalex_service
from models import SocialTrendingPaper, SocialTrendingResponse

logger = logging.getLogger("social_trending_router")
router = APIRouter(prefix="/social-trending", tags=["Social Trending"])


@router.get("", response_model=SocialTrendingResponse)
async def get_social_trending(
    limit: int = Query(30, ge=1, le=100, description="Max papers to return"),
    skip: int = Query(0, ge=0, description="Number of papers to skip"),
    ignore_cache: bool = Query(False, description="Bypass cache and randomize results"),
):
    if ignore_cache:
        logger.info("Bypassing cache for social trending refresh (ignore_cache=True)")
        papers = await _openalex_trending_fallback(domain=None, limit=limit, ignore_cache=True)
    else:
        papers = await _get_trending_papers("trending:social:global", limit, skip)
        if not papers:
            logger.info("No social trending data yet — falling back to OpenAlex top cited")
            papers = await _openalex_trending_fallback(domain=None, limit=limit, ignore_cache=False)
    return SocialTrendingResponse(papers=papers, total=len(papers), domain=None)


@router.get("/{domain}", response_model=SocialTrendingResponse)
async def get_social_trending_by_domain(
    domain: str,
    limit: int = Query(30, ge=1, le=100),
    skip: int = Query(0, ge=0),
    ignore_cache: bool = Query(False),
):
    if ignore_cache:
        logger.info(f"Bypassing cache for {domain} social trending refresh (ignore_cache=True)")
        papers = await _openalex_trending_fallback(domain=domain, limit=limit, ignore_cache=True)
    else:
        key = f"trending:social:{domain}"
        papers = await _get_trending_papers(key, limit, skip)

        # Fallback to global if domain has no data
        if not papers:
            papers = await _get_trending_papers("trending:social:global", limit, skip)

        # Final fallback: use OpenAlex top cited for the domain
        if not papers:
            logger.info(f"No social trending data for {domain} — falling back to OpenAlex top cited")
            papers = await _openalex_trending_fallback(domain=domain, limit=limit, ignore_cache=False)

    return SocialTrendingResponse(papers=papers, total=len(papers), domain=domain)


async def _get_trending_papers(redis_key: str, limit: int, skip: int) -> list[SocialTrendingPaper]:
    """Fetch top N papers from a trending sorted set with source badges."""
    r = await redis_client.get_redis()

    paper_ids_scores = await r.zrevrange(redis_key, skip, skip + limit - 1, withscores=True)
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


async def _openalex_trending_fallback(domain: str | None, limit: int, ignore_cache: bool = False) -> list[SocialTrendingPaper]:
    """Fetch top-cited recent papers from OpenAlex as a trending fallback."""
    try:
        if ignore_cache:
            p1, n1 = await openalex_service.fetch_feed_cursor(
                domain=domain or "all", publisher=None, sort="trending", cursor="*", per_page=25
            )
            logger.info(f"Fallback randomization page 1: {len(p1)} papers found")
            if n1:
                p2, _ = await openalex_service.fetch_feed_cursor(
                    domain=domain or "all", publisher=None, sort="trending", cursor=n1, per_page=25
                )
                logger.info(f"Fallback randomization page 2: {len(p2)} papers found")
            else:
                p2 = []
            import random
            pool = p1 + p2
            random.shuffle(pool)
            raw_papers = pool[:limit]
        else:
            raw_papers, _ = await openalex_service.fetch_feed_cursor(
                domain=domain or "all",
                publisher=None,
                sort="trending",
                cursor="*",
                per_page=min(limit, 50), # Get more to ensure we have enough after filtering
            )
            logger.info(f"Fallback fetch (ignore_cache=False): {len(raw_papers)} papers found")
        
        papers = []
        for meta in raw_papers:
            pid = meta.get("paper_id")
            if not pid:
                continue
            try:
                papers.append(SocialTrendingPaper(
                    paper_id=pid,
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
                    openalex_score=_safe_float(meta.get("openalex_score")),
                    domain=meta.get("domain", "other"),
                    subdomain=meta.get("subdomain", "unknown"),
                    social_score=float(meta.get("citation_count", 0)),
                    trending_sources=["openalex"],
                    confidence=0.5,
                ))
            except Exception as e:
                logger.error(f"Fallback paper error: {e}")
        return papers
    except Exception as e:
        from fastapi import HTTPException
        if isinstance(e, HTTPException):
            raise e
        logger.error(f"OpenAlex trending fallback error: {e}")
        return []

def _safe_float(val) -> float:
    try:
        return float(val)
    except (TypeError, ValueError):
        return 0.0
