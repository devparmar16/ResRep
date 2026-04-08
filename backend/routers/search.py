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
    start_year: int = Query(None, description="Start year filter"),
    end_year: int = Query(None, description="End year filter"),
    sort: str = Query("publication_year:desc", description="Sort criteria")
):
    """
    Real-time semantic search proxy for OpenAlex.
    Enforces a strict memory-safe layer: only 50 results maximally, cached for 30 mins.
    """
    r = await redis_client.get_redis()
    cache_key = f"search:cache:{query.lower().strip()}:{start_year}:{end_year}:{sort}"
    
    # 1. Check Redis Cache
    cached_ids = await r.zrevrange(cache_key, 0, -1)
    if cached_ids:
        logger.info(f"Search cache HIT for '{query}'")
        
        # Hydrate cached paper IDs
        results = []
        for pid_bytes in cached_ids:
            pid = pid_bytes.decode() if isinstance(pid_bytes, bytes) else pid_bytes
            meta = await redis_client.get_paper_metadata(pid)
            if meta:
                try:
                    results.append(PaperResponse(
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
                        openalex_score=float(meta.get("openalex_score", 0.0)) if meta.get("openalex_score") else 0.0,
                        domain=meta.get("domain", "other"),
                        subdomain=meta.get("subdomain", "unknown"),
                    ))
                except Exception as e:
                    logger.error(f"Error hydrating cached paper {pid}: {e}")
        return results
        
    logger.info(f"Search cache MISS for '{query}', querying OpenAlex directly...")
    
    # 2. Proxy to OpenAlex
    client = await openalex_service._get_client()
    params = {
        "search": query,
        # Force strict semantic matching first to guarantee powerful relevance
        "sort": "relevance_score:desc",
        "per_page": "100", # Pull deeper pool of relevant candidates
        "mailto": openalex_service.OPENALEX_MAILTO,
    }
    
    import datetime
    current_year = datetime.datetime.now().year

    # Prevent future-dated papers (dirty OpenAlex metadata) from bubbling up
    actual_start = start_year
    actual_end = min(end_year, current_year) if end_year else current_year
    
    if actual_start:
        params["filter"] = f"publication_year:{actual_start}-{actual_end}"
    else:
        params["filter"] = f"to_publication_date:{actual_end}-12-31"
    
    try:
        resp = await client.get("/works", params=params)
        resp.raise_for_status()
        data = resp.json().get("results", [])
    except Exception as e:
        logger.error(f"Error proxying search '{query}' to OpenAlex: {e}")
        return []
        
    papers = [openalex_service._normalise_work(w) for w in data]
    
    # 2.5 Local Secondary Sort
    # We extracted the absolute top 100 most relevant hits. If the user sorting is not relevance, apply it locally.
    if sort == "publication_year:desc":
        papers.sort(key=lambda x: (x.get("year") or 0), reverse=True)
    elif sort == "cited_by_count:desc":
        papers.sort(key=lambda x: (x.get("citation_count") or 0), reverse=True)
        
    papers = papers[:50] # Slice back to strict 50 for the frontend
    
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
