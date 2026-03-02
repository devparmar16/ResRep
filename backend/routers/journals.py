"""
Journals router — list journals per domain, papers per journal.
"""
import json
import logging
from fastapi import APIRouter, Query

import redis_client
from config import CORE_DOMAINS_CONCEPTS, JOURNAL_CACHE_TTL, MAX_JOURNAL_PAPERS
from models import JournalResponse, PaperResponse, FeedResponse
import background_jobs

logger = logging.getLogger("journals")
router = APIRouter(prefix="/journals", tags=["Journals"])

async def _fetch_and_cache_journals(domain: str, cache_key: str, r) -> list[str]:
    from openalex_service import fetch_journals_by_domain
    cids = [CORE_DOMAINS_CONCEPTS[domain]] if domain in CORE_DOMAINS_CONCEPTS else []
    search_q = domain if domain != "all" else None
    
    # Actually fetch from OpenAlex
    raw_journals = await fetch_journals_by_domain(concept_ids=cids, search_query=search_q)
    
    if raw_journals:
        pipe = r.pipeline()
        for j in raw_journals:
            j["domain"] = domain
            pipe.zadd(cache_key, {json.dumps(j): int(j.get("paper_count", 0))})
        pipe.expire(cache_key, JOURNAL_CACHE_TTL)
        await pipe.execute()
        return await r.zrevrange(cache_key, 0, -1)
    return []


@router.get("/{domain}", response_model=list[JournalResponse])
async def list_journals(
    domain: str,
    query: str = Query(None, description="Search term for journals"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    ignore_cache: bool = Query(False, description="Bypass cache for pull-to-refresh")
):
    """
    List cached journals for a domain with optional search query and pagination.
    If cache is empty / expired, triggers a fetch job on-the-fly.
    """
    logger.info(f"Request: list journals for domain='{domain}'")
    r = await redis_client.get_redis()
    cache_key = f"journals:domain:{domain}"

    try:
        cached = None
        if not ignore_cache:
            cached = await r.zrevrange(cache_key, 0, -1)
            
        if not cached:
            if domain and domain != "all":
                logger.info(f"Cache miss (or refresh) for domain='{domain}', fetching directly from OpenAlex...")
                cached = await _fetch_and_cache_journals(domain, cache_key, r)
            else:
                logger.warning(f"Domain '{domain}' not found in CORE_DOMAINS_CONCEPTS (or 'all' used)")

        journals = []
        logger.info(f"Found {len(cached)} journals in cache for domain='{domain}')")
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
                    publisher=j.get("publisher"),
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


@router.get("", response_model=list[JournalResponse])
async def list_journals_multi(
    domains: str = Query("all", description="Comma-separated domain IDs, or 'all'"),
    query: str = Query(None, description="Search term for journals"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    ignore_cache: bool = Query(False, description="Bypass cache for pull-to-refresh"),
):
    """
    List journals across multiple domains. Supports 'all' to aggregate from every domain.
    """
    r = await redis_client.get_redis()

    if domains == "all":
        domain_list = list(CORE_DOMAINS_CONCEPTS.keys())
    else:
        domain_list = [d.strip() for d in domains.split(",") if d.strip()]

    all_journals: list[JournalResponse] = []
    seen_ids: set[str] = set()

    for domain in domain_list:
        cache_key = f"journals:domain:{domain}"
        
        cached = None
        if not ignore_cache:
            cached = await r.zrevrange(cache_key, 0, -1)

        if not cached and domain in CORE_DOMAINS_CONCEPTS:
            logger.info(f"Cache miss (or refresh) for domain='{domain}' in multi-fetch, fetching from OpenAlex...")
            cached = await _fetch_and_cache_journals(domain, cache_key, r)

        if not cached:
            continue
            
        for item in cached:
            try:
                j = json.loads(item)
                jid = j.get("journal_id", "")
                if jid in seen_ids:
                    continue
                name = j.get("name", "Unknown")
                if query and query.lower() not in name.lower():
                    continue
                seen_ids.add(jid)
                all_journals.append(JournalResponse(
                    journal_id=jid,
                    name=name,
                    domain=domain,
                    paper_count=j.get("paper_count", 0),
                    publisher=j.get("publisher"),
                ))
            except (json.JSONDecodeError, TypeError, ValueError):
                continue

    # Sort by paper_count descending (popular first)
    all_journals.sort(key=lambda j: j.paper_count, reverse=True)
    return all_journals[skip : skip + limit]


@router.get("/{journal_id}/papers", response_model=FeedResponse)
async def get_journal_papers(
    journal_id: str,
    sort: str = Query("top", description="Sort: top, recent, trending"),
    cursor: str = Query("*", description="Pagination cursor"),
    query: str = Query(None, description="Semantic search query inside the journal"),
    ignore_cache: bool = Query(False, description="Bypass cache for pull-to-refresh"),
):
    """
    Get papers for a specific journal using cursor pagination.
    Uses dynamic redis caching with a 10 min TTL.
    """
    r = await redis_client.get_redis()
    
    safe_query = query or "none"
    cache_key = f"journal:{journal_id}:papers:{sort}:{safe_query}:{cursor}"

    # Check cache (TTL 10 mins)
    cached_data = None
    if not ignore_cache:
        cached_data = await r.get(cache_key)
    if cached_data:
        try:
            data = json.loads(cached_data)
            return FeedResponse(
                user_id=None,
                papers=data.get("papers", []),
                total=data.get("total", 0),
                cached=True,
                next_cursor=data.get("next_cursor")
            )
        except json.JSONDecodeError:
            pass

    import openalex_service
    if ignore_cache and cursor == "*":
        # Fetch page 1
        first_page, first_next = await openalex_service.fetch_journal_papers_cursor(
            journal_id=journal_id, sort=sort, cursor="*",
            per_page_count=25, search_query=query
        )
        # Fetch page 2 for genuine variety
        if first_next:
            second_page, second_next = await openalex_service.fetch_journal_papers_cursor(
                journal_id=journal_id, sort=sort, cursor=first_next,
                per_page_count=25, search_query=query
            )
        else:
            second_page, second_next = [], None
        import random
        pool = first_page + second_page
        random.shuffle(pool)
        raw_papers = pool[:25]
        next_cursor = second_next or first_next
    else:
        raw_papers, next_cursor = await openalex_service.fetch_journal_papers_cursor(
            journal_id=journal_id, 
            sort=sort, 
            cursor=cursor,
            per_page_count=25, 
            search_query=query
        )
    
    papers = []
    from config import PAPER_METADATA_TTL
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
                
    response_dict = {
        "papers": [p.dict() for p in papers],
        "total": len(papers),
        "next_cursor": next_cursor,
    }
    
    # Cache with 10 min TTL (600 seconds)
    await r.setex(cache_key, 600, json.dumps(response_dict))

    return FeedResponse(
        user_id=None,
        papers=papers,
        total=len(papers),
        cached=False,
        next_cursor=next_cursor,
    )
