"""
Social Trending background job — orchestrates the 2-phase pipeline:
  Phase 1: Social Discovery → deduplicated top-N candidates
  Phase 2: Academic Resolution → confidence-gated, scored papers in Redis
"""
import asyncio
import math
import time
import logging

import redis_client
from social_trending_service import fetch_all_social_candidates, SocialCandidate
from academic_resolver import resolve_candidate
from config import (
    CORE_DOMAINS_CONCEPTS,
    SOCIAL_TRENDING_TTL,
    SOCIAL_SOURCES_TTL,
    SOCIAL_METADATA_TTL,
    MAX_SOCIAL_TRENDING_GLOBAL,
    MAX_SOCIAL_TRENDING_DOMAIN,
    PLATFORM_WEIGHT,
    MENTION_WEIGHT,
    ENGAGEMENT_LOG_WEIGHT,
    DECAY_HALF_LIFE_DAYS,
)

logger = logging.getLogger("social_trending_jobs")


async def social_trending_fetch_job() -> None:
    """
    Scheduled job (every 3 hours):
    1. Phase 1: Fetch + filter + deduplicate + rank top candidates
    2. Phase 2: Resolve each via 3-tier cascade
    3. Score with recency decay
    4. Store in Redis trending ZSETs
    """
    logger.info("═══ Social Trending Job START ═══")

    # ── Phase 1: Social Discovery ────────────────────────────────────
    candidates = await fetch_all_social_candidates()
    if not candidates:
        logger.info("No candidates found, skipping.")
        return

    # ── Phase 2: Academic Resolution ─────────────────────────────────
    r = await redis_client.get_redis()
    resolved = 0
    failed = 0
    batch_size = 5  # Small batches to respect API rate limits

    for batch_start in range(0, len(candidates), batch_size):
        batch = candidates[batch_start:batch_start + batch_size]
        tasks = [_resolve_score_store(r, c) for c in batch]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        for result in results:
            if isinstance(result, Exception):
                logger.error(f"Resolution error: {result}")
                failed += 1
            elif result:
                resolved += 1
            else:
                failed += 1

        # Brief pause between batches
        if batch_start + batch_size < len(candidates):
            await asyncio.sleep(1.5)

    # ── Cap ZSETs ────────────────────────────────────────────────────
    await _cap_all_sets(r)

    logger.info(
        f"═══ Social Trending Job DONE: {resolved}/{len(candidates)} resolved, "
        f"{failed} failed ═══"
    )


async def _resolve_score_store(r, candidate: SocialCandidate) -> bool:
    """Resolve a single candidate, compute score, store in Redis."""
    try:
        paper = await resolve_candidate(candidate)
        if not paper:
            return False

        pid = paper.get("paper_id", "")
        domain = paper.get("domain", "other")
        confidence = paper.get("_confidence", 0.5)

        # ── Compute trending score ───────────────────────────────────
        distinct_platforms = len(candidate.source_platforms)
        mention_count = candidate.mention_count
        total_engagement = candidate.total_engagement

        raw_score = (
            distinct_platforms * PLATFORM_WEIGHT
            + mention_count * MENTION_WEIGHT
            + math.log(total_engagement + 1) * ENGAGEMENT_LOG_WEIGHT
        )

        # Recency decay
        age_days = _age_in_days(candidate.discovered_at)
        decay = math.exp(-age_days / DECAY_HALF_LIFE_DAYS)
        final_score = raw_score * decay

        # ── Store in Redis ───────────────────────────────────────────
        # Paper metadata
        await redis_client.store_paper_metadata(pid, paper, SOCIAL_METADATA_TTL)

        # Global ZSET
        await r.zadd("trending:social:global", {pid: final_score})
        await r.expire("trending:social:global", SOCIAL_TRENDING_TTL)

        # Domain ZSET
        if domain and domain != "other":
            domain_key = f"trending:social:{domain}"
            await r.zadd(domain_key, {pid: final_score})
            await r.expire(domain_key, SOCIAL_TRENDING_TTL)

        # Source platforms for badge display
        sources_list = list(candidate.source_platforms)
        await redis_client.store_social_sources(pid, sources_list, SOCIAL_SOURCES_TTL)

        logger.info(
            f"  ✓ {pid[:40]} | score={final_score:.1f} | "
            f"platforms={sources_list} | conf={confidence:.2f}"
        )
        return True

    except Exception as e:
        logger.error(f"Error in _resolve_score_store: {e}")
        return False


def _age_in_days(timestamp: float) -> float:
    """Calculate age in days from a unix timestamp."""
    if not timestamp or timestamp <= 0:
        return 1.0  # Default to 1 day if unknown
    return max(0, (time.time() - timestamp) / 86400)


async def _cap_all_sets(r) -> None:
    """Cap all social trending sorted sets."""
    await redis_client.cap_sorted_set("trending:social:global", MAX_SOCIAL_TRENDING_GLOBAL)
    for domain_id in CORE_DOMAINS_CONCEPTS:
        key = f"trending:social:{domain_id}"
        if await r.exists(key):
            await redis_client.cap_sorted_set(key, MAX_SOCIAL_TRENDING_DOMAIN)
