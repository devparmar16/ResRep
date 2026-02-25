"""
Journals router — list journals per domain, papers per journal.
"""
import json
import logging
from fastapi import APIRouter, Query

import redis_client
from config import CORE_DOMAINS_CONCEPTS, JOURNAL_CACHE_TTL, MAX_JOURNAL_PAPERS
from models import JournalResponse, PaperResponse
import background_jobs

logger = logging.getLogger("journals")
router = APIRouter(prefix="/journals", tags=["Journals"])


@router.get("/{domain}", response_model=list[JournalResponse])
async def list_journals(
    domain: str,
    query: str = Query(None, description="Search term for journals"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100)
):
    """
    List cached journals for a domain with optional search query and pagination.
    If cache is empty / expired, triggers a fetch job on-the-fly.
    """
    logger.info(f"Request: list journals for domain='{domain}'")
    r = await redis_client.get_redis()
    cache_key = f"journals:domain:{domain}"

    try:
        # Check cache
        cached = await r.zrevrange(cache_key, 0, -1)
        if not cached:
            logger.info(f"Cache miss for domain='{domain}', triggering fetch job...")
            # Trigger fetch
            if domain in CORE_DOMAINS_CONCEPTS:
                await background_jobs.journal_fetch_job(domain)
                cached = await r.zrevrange(cache_key, 0, -1)
            else:
                logger.warning(f"Domain '{domain}' not found in CORE_DOMAINS_CONCEPTS")

        journals = []
        logger.info(f"Found {len(cached)} journals in cache for domain='{domain}'")
        for item in cached:
            try:
                j = json.loads(item)
                name = j.get("name", "Unknown")
                
                # Simple text search (could be expanded to semantic if needed)
                if query and query.lower() not in name.lower():
                    continue
                    
                journals.append(JournalResponse(
                    journal_id=j.get("journal_id", ""),
                    name=name,
                    domain=domain,
                    paper_count=j.get("paper_count", 0),
                ))
            except (json.JSONDecodeError, TypeError, ValueError) as e:
                logger.error(f"Error parsing journal item: {e}")
                continue

        # Apply pagination
        return journals[skip : skip + limit]
    except Exception as e:
        logger.error(f"Internal error in list_journals: {e}")
        from fastapi import HTTPException
        raise HTTPException(status_code=500, detail="Internal error retrieving journals")


@router.get("/{journal_id}/papers", response_model=list[PaperResponse])
async def get_journal_papers(
    journal_id: str,
    sort: str = Query("top", description="Sort: top, recent, trending"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    query: str = Query(None, description="Semantic search query inside the journal"),
):
    """
    Get papers for a specific journal, sorted by top/recent/trending with pagination.
    Fetches on-the-fly if cache is empty.
    """
    r = await redis_client.get_redis()
    cache_key = f"journal:{journal_id}:{sort}"

    paper_ids = await r.zrevrange(cache_key, 0, -1)
    if not paper_ids:
        await background_jobs.journal_papers_fetch_job(journal_id, sort)
        paper_ids = await r.zrevrange(cache_key, 0, -1)

    try:
        if query:
            logger.info(f"Semantic search in journal {journal_id} for '{query}'")
            import openalex_service
            raw_papers = await openalex_service.fetch_journal_papers(
                journal_id=journal_id, 
                sort=sort, 
                per_page_count=100, 
                search_query=query
            )
            search_results = raw_papers[skip : skip + limit]
            
            papers = []
            for meta in search_results:
                try:
                    papers.append(PaperResponse(
                        paper_id=meta.get("paper_id"),
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
                except Exception as ve:
                    logger.error(f"Validation error for search paper {meta.get('paper_id')}: {ve}")
            return papers

        # Apply pagination to paper IDs
        paginated_ids = paper_ids[skip : skip + limit]

        # Hydrate
        papers = []
        for pid in paginated_ids:
            meta = await redis_client.get_paper_metadata(pid)
            if meta:
                try:
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
                except Exception as ve:
                    logger.error(f"Validation error for paper {pid}: {ve}")
        return papers
    except Exception as e:
        logger.error(f"Internal error in get_journal_papers: {e}")
        from fastapi import HTTPException
        raise HTTPException(status_code=500, detail="Internal error retrieving papers")
