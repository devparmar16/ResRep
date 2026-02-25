"""
Background jobs for fetching and scoring research papers.
"""
import asyncio
import logging
from datetime import datetime, timedelta, timezone

import redis_client
import openalex_service
import ranking
from config import (
    CORE_DOMAINS_CONCEPTS,
    MAX_DOMAIN_PAPERS,
    DOMAIN_CACHE_TTL,
    PAPER_METADATA_TTL,
    MAX_JOURNAL_PAPERS,
    JOURNAL_CACHE_TTL,
)

logger = logging.getLogger("background_jobs")


async def domain_fetch_job() -> None:
    """
    Periodic job:
    For each domain, fetch new papers from OpenAlex, score them,
    insert into the domain sorted set, cap, and set TTL.
    """
    logger.info("Starting domain fetch job ...")
    r = await redis_client.get_redis()

    for domain_id, concept_id in CORE_DOMAINS_CONCEPTS.items():
        try:
            await _fetch_domain(r, domain_id, concept_id)
        except Exception as e:
            logger.error(f"Error fetching domain {domain_id}: {e}")

    logger.info("Domain fetch job complete.")


async def _fetch_domain(r, domain_id: str, concept_id: str) -> None:
    """Fetch papers for a single domain and populate Redis."""
    cache_key = f"papers:domain:{domain_id}"

    # Determine last_checked for incremental fetch
    last_checked_key = f"domain:last_checked:{domain_id}"
    last_checked = await r.get(last_checked_key)

    from_date = None
    if last_checked:
        from_date = last_checked
    else:
        # First run: fetch last 30 days
        from_date = (datetime.now(timezone.utc) - timedelta(days=30)).strftime("%Y-%m-%d")

    logger.info(f"Fetching papers for domain {domain_id} from {from_date}...")
    papers = await openalex_service.fetch_papers_by_domain(
        domain_id=domain_id,
        concept_id=concept_id,
        from_date=from_date,
        per_page=100,
    )

    if not papers:
        logger.info(f"No new papers found for {domain_id}")
        return

    # Process and store
    for paper in papers:
        pid = paper["paper_id"]
        score = ranking.compute_score(
            citation_count=paper.get("citation_count", 0),
            publication_date=paper.get("publication_date"),
        )

        # 1. Store/refresh metadata
        await redis_client.store_paper_metadata(pid, paper, PAPER_METADATA_TTL)

        # 2. Add to domain sorted set
        await r.zadd(cache_key, {pid: score})

    # 3. Cap size
    await redis_client.cap_sorted_set(cache_key, MAX_DOMAIN_PAPERS)

    # 4. Set TTL
    await r.expire(cache_key, DOMAIN_CACHE_TTL)

    # 5. Update last_checked to today
    await r.set(last_checked_key, datetime.now(timezone.utc).strftime("%Y-%m-%d"))

    logger.info(f"Updated domain {domain_id} with {len(papers)} papers.")


async def journal_fetch_job(domain_id: str) -> None:
    """Fetch and cache journals for a domain."""
    r = await redis_client.get_redis()
    cache_key = f"journals:domain:{domain_id}"

    from config import DOMAIN_SEARCH_QUERIES, CORE_DOMAINS_CONCEPTS
    
    cid = CORE_DOMAINS_CONCEPTS.get(domain_id)
    concept_ids = [cid] if cid else []
    search_query = DOMAIN_SEARCH_QUERIES.get(domain_id)
    
    if not concept_ids and not search_query:
        logger.warning(f"No concept IDs or search query for domain {domain_id}")
        return

    logger.info(f"Fetching journals (sources) for domain {domain_id}...")
    journals = await openalex_service.fetch_journals_by_domain(
        concept_ids=concept_ids,
        search_query=search_query
    )

    # Store in sorted set (score by paper_count)
    if journals:
        import json
        pipe = r.pipeline()
        for j in journals:
            # We store the whole JSON string in the sorted set for quick listing
            pipe.zadd(cache_key, {json.dumps(j): j.get("paper_count", 0)})
        await pipe.execute()
        await r.expire(cache_key, JOURNAL_CACHE_TTL)
        logger.info(f"Cached {len(journals)} journals for {domain_id}.")
    else:
        logger.warning(f"No journals found for domain {domain_id}")


async def journal_papers_fetch_job(journal_id: str, sort: str = "top") -> None:
    """Fetch and cache papers for a specific journal."""
    r = await redis_client.get_redis()
    cache_key = f"journal:{journal_id}:{sort}"

    logger.info(f"Fetching {sort} papers for journal {journal_id}...")
    papers = await openalex_service.fetch_journal_papers(
        journal_id=journal_id,
        sort=sort,
        per_page_count=MAX_JOURNAL_PAPERS,
    )

    if papers:
        pipe = r.pipeline()
        for paper in papers:
            pid = paper["paper_id"]
            score = ranking.compute_score(
                citation_count=paper.get("citation_count", 0),
                publication_date=paper.get("publication_date"),
            )
            # Store metadata
            await redis_client.store_paper_metadata(pid, paper, PAPER_METADATA_TTL)
            # Add to journal sorted set
            pipe.zadd(cache_key, {pid: score})

        await pipe.execute()
        # Cap
        await r.zremrangebyrank(cache_key, 0, -(MAX_JOURNAL_PAPERS + 1))
        await r.expire(cache_key, JOURNAL_CACHE_TTL)
        logger.info(f"Cached {len(papers)} papers for journal {journal_id} ({sort}).")


async def decay_trending_job() -> None:
    """
    Periodic job to apply exponential decay to engagement/trending metrics.
    Runs globally and per-domain to ensure fresh papers rotate in.
    """
    logger.info("Starting trending metric decay job...")
    r = await redis_client.get_redis()
    
    decay_factor = 0.8  # Reduce score by 20%
    
    keys_to_decay = await r.keys("trending:*")
    engagement_keys = await r.keys("engagement:*")
    
    pipe = r.pipeline()
    for key in (keys_to_decay + engagement_keys):
        # Fetch all members and scores
        items = await r.zrange(key, 0, -1, withscores=True)
        if items:
            for member, score in items:
                new_score = score * decay_factor
                if new_score < 0.05:
                    # Remove completely if effectively 0 to save RAM
                    pipe.zrem(key, member)
                else:
                    pipe.zadd(key, {member: new_score})
                    
    await pipe.execute()
    logger.info("Trending metric decay complete.")
