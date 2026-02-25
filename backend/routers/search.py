"""
Query router — Proxies real-time searches to OpenAlex with short-TTL minimalist caching.
"""
import logging
from fastapi import APIRouter, Query

import redis_client
import openalex_service
from config import SEARCH_CACHE_TTL
from models import PaperResponse

logger = logging.getLogger("search")
router = APIRouter(prefix="/search", tags=["Search"])

@router.get("", response_model=list[PaperResponse])
async def search_papers(
    query: str = Query(..., description="Search query string"),
):
    """
    Real-time semantic search proxy for OpenAlex.
    Enforces a strict memory-safe layer: only 50 results maximally, cached for 30 mins.
    """
    r = await redis_client.get_redis()
    cache_key = f"search:cache:{query.lower().strip()}"
    
    # 1. Check Redis Cache
    cached_ids = await r.zrevrange(cache_key, 0, -1)
    if cached_ids:
        logger.info(f"Search cache HIT for '{query}'")
        from routers.feed import _hydrate_papers
        return await _hydrate_papers(cached_ids)
        
    logger.info(f"Search cache MISS for '{query}', querying OpenAlex directly...")
    
    # 2. Proxy to OpenAlex (Max 50 results)
    # Using fetch_papers_by_domain as a generic fetcher by overriding the filter in openalex_service
    # Or implement a small inline client query
    client = await openalex_service._get_client()
    params = {
        "search": query,
        "sort": "relevance_score:desc",
        "per_page": "50",
        "mailto": openalex_service.OPENALEX_MAILTO,
    }
    
    try:
        resp = await client.get("/works", params=params)
        resp.raise_for_status()
        data = resp.json().get("results", [])
    except Exception as e:
        logger.error(f"Error proxying search '{query}' to OpenAlex: {e}")
        return []
        
    papers = [openalex_service._normalise_work(w) for w in data]
    
    # 3. Cache Minimal Data Safely
    if papers:
        pipe = r.pipeline()
        for idx, paper in enumerate(papers):
            pid = paper["paper_id"]
            
            # Store metadata
            from config import PAPER_METADATA_TTL
            await redis_client.store_paper_metadata(pid, paper, PAPER_METADATA_TTL)
            
            # Save ID in sorted set representing the query order
            # The lower the index (ie top result), the higher the score
            score = 1000 - idx 
            pipe.zadd(cache_key, {pid: score})
            
        await pipe.execute()
        await r.expire(cache_key, SEARCH_CACHE_TTL)
        
    # 4. Map to exact Response Model
    results = []
    for p in papers:
        results.append(PaperResponse(
            paper_id=p["paper_id"],
            title=p.get("title", "Untitled"),
            abstract=p.get("abstract"),
            summary=p.get("summary"),
            authors=p.get("authors", []),
            journal=p.get("journal"),
            journal_id=p.get("journal_id"),
            doi=p.get("doi"),
            landing_page_url=p.get("landing_page_url"),
            pdf_url=p.get("pdf_url"),
            is_open_access=bool(p.get("is_open_access", False)),
            publication_date=p.get("publication_date"),
            year=int(p["year"]) if p.get("year") and str(p["year"]).isdigit() else None,
            citation_count=int(p.get("citation_count", 0)),
            openalex_score=float(p.get("openalex_score", 0.0)) if p.get("openalex_score") else 0.0,
            domain=p.get("domain", "other"),
            subdomain=p.get("subdomain", "unknown"),
        ))
        
    return results
