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
