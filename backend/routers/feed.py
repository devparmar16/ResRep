"""
Feed router — assembles user feed using cursor-based pagination.
"""
import json
import logging
from fastapi import APIRouter, Query

import redis_client
from config import PAPER_METADATA_TTL
from models import PaperResponse, FeedResponse
import openalex_service

logger = logging.getLogger("feed")
router = APIRouter(prefix="/feed", tags=["Feed"])


@router.get("", response_model=FeedResponse)
async def get_feed(
    interests: str = Query("all", description="Comma-separated domain IDs, e.g. 'cs,biology', or 'all'"),
    publisher: str | None = Query(None, description="Optional publisher filter"),
    sort: str = Query("recent", description="Sort order: recent, trending, relevance"),
    cursor: str = Query("*", description="Pagination cursor"),
    user_id: str | None = Query(None, description="User identifier (optional)"),
    ignore_cache: bool = Query(False, description="Bypass cache for pull-to-refresh"),
    query: str | None = Query(None, description="Search term to filter the feed"),
):
    logger.info(f"FEED REQUEST: interests={interests} sort={sort} cursor={cursor} query={query} ignore_cache={ignore_cache}")
    r = await redis_client.get_redis()
    
    pub_key = publisher or "none"
    q_key = query or "none"
    feed_key = f"feed:{interests}:{pub_key}:{sort}:{q_key}:{cursor}"

    # Check cache (TTL 10 mins)
    cached_data = None
    if not ignore_cache:
        cached_data = await r.get(feed_key)
    if cached_data:
        try:
            data = json.loads(cached_data)
            return FeedResponse(
                user_id=user_id,
                papers=data.get("papers", []),
                total=data.get("total", 0),
                cached=True,
                next_cursor=data.get("next_cursor")
            )
        except json.JSONDecodeError:
            pass
            
    # Cache miss
    if ignore_cache and cursor == "*":
        # Fetch first page to get a next_cursor to advance from
        first_page, first_next = await openalex_service.fetch_feed_cursor(
            domain=interests,
            publisher=publisher,
            sort=sort,
            cursor="*",
            per_page=25,
            search_query=query,
        )
        
        # Now fetch a second page from the next_cursor to get truly different papers
        if first_next:
            second_page, second_next = await openalex_service.fetch_feed_cursor(
                domain=interests,
                publisher=publisher,
                sort=sort,
                cursor=first_next,
                per_page=25,
                search_query=query,
            )
        else:
            second_page, second_next = [], None
        
        # Combine both pages and shuffle entirely for a fully fresh feel
        import random
        pool = first_page + second_page
        random.shuffle(pool)
        raw_papers = pool[:25]  # Cap at 25 total
        next_cursor = second_next or first_next
    else:
        raw_papers, next_cursor = await openalex_service.fetch_feed_cursor(
            domain=interests,
            publisher=publisher,
            sort=sort,
            cursor=cursor,
            per_page=25,
            search_query=query,
        )

    papers = []
    for meta in raw_papers:
        pid = meta.get("paper_id")
        if pid:
            await redis_client.store_paper_metadata(pid, meta, PAPER_METADATA_TTL)
            
        try:
            papers.append(PaperResponse(
                paper_id=pid,
                title=meta.get("title", "Untitled"),
                abstract=meta.get("abstract"),
                summary=meta.get("summary"),
                authors=meta.get("authors", []) if isinstance(meta.get("authors"), list) else [],
                journal=meta.get("journal"),
                journal_id=meta.get("journal_id"),
                publisher=meta.get("publisher"),
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
        except Exception as ve:
            logger.error(f"Validation error for search paper {pid}: {ve}")
            
    # Build response dict for caching
    response_dict = {
        "papers": [p.dict() for p in papers],
        "total": len(papers),
        "next_cursor": next_cursor,
    }
    
    # Cache with 10 min TTL (600 seconds)
    await r.setex(feed_key, 600, json.dumps(response_dict))

    return FeedResponse(
        user_id=user_id,
        papers=papers,
        total=len(papers),
        cached=False,
        next_cursor=next_cursor,
    )


@router.post("/refresh", response_model=FeedResponse)
async def refresh_feed(
    interests: str = Query("all"),
    user_id: str | None = Query(None),
):
    """Fallback refresh clears cache and shuffles."""
    return await get_feed(
        interests=interests, 
        publisher=None,
        sort="recent",
        cursor="*", 
        user_id=user_id, 
        ignore_cache=True
    )
