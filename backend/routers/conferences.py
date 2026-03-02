"""
Conferences router — offset-based pagination with Redis caching.
Uses PredictHQ API via predicthq_service.
"""
import json
import logging
from typing import Optional
from fastapi import APIRouter, Query

from models import ConferenceResponse, Conference
from services.predicthq_service import PredictHQService
import redis_client
from config import CONFERENCES_CACHE_TTL, CONFERENCES_PAGE_SIZE

logger = logging.getLogger("conferences_router")
router = APIRouter(prefix="/conferences", tags=["Conferences"])


@router.get("", response_model=ConferenceResponse)
async def get_conferences(
    mode: Optional[str] = Query(None, description="Mode: online, offline, hybrid"),
    country: Optional[str] = Query(None, description="ISO-3166-1 alpha-2 country code"),
    city: Optional[str] = Query(None, description="City name for location filtering"),
    domain: Optional[str] = Query(None, description="Domain like AI, ML, CS"),
    limit: int = Query(CONFERENCES_PAGE_SIZE, ge=1, le=50),
    offset: int = Query(0, ge=0),
    ignore_cache: bool = Query(False, description="Skip cache and fetch fresh"),
):
    """
    Fetch conferences with offset-based pagination and Redis caching.
    Each unique filter+offset combo gets its own cache entry (TTL 30 min).
    """
    # ── 1. Build deterministic cache key ─────────────────
    cache_key = (
        f"conferences:v7:"
        f"{(mode or '').lower()}:"
        f"{(country or '').upper()}:"
        f"{(city or '').lower()}:"
        f"{(domain or '').lower()}:"
        f"{offset}"
    )

    r = await redis_client.get_redis()

    # ── 2. Check Redis cache ─────────────────────────────
    if not ignore_cache:
        cached_data = await r.get(cache_key)
        if cached_data:
            try:
                data = json.loads(cached_data)
                logger.info(f"Cache HIT for {cache_key}")
                conferences = [Conference(**c) for c in data.get("conferences", [])]
                return ConferenceResponse(
                    conferences=conferences,
                    total=len(conferences),
                    has_more=data.get("has_more", False),
                    next_offset=data.get("next_offset", offset + limit),
                    mode_filter=mode,
                    country_filter=country,
                    city_filter=city,
                    domain_filter=domain,
                )
            except Exception as e:
                logger.warning(f"Failed to parse cached conferences: {e}")

    # ── 3. Cache MISS — query PredictHQ ──────────────────
    logger.info(f"Cache MISS for {cache_key}. Querying PredictHQ.")
    conferences = await PredictHQService.fetch_conferences(
        mode=mode,
        country=country,
        city=city,
        domain=domain,
        limit=limit,
        offset=offset,
    )

    has_more = len(conferences) >= limit
    next_offset = offset + limit

    response = ConferenceResponse(
        conferences=conferences,
        total=len(conferences),
        has_more=has_more,
        next_offset=next_offset,
        mode_filter=mode,
        country_filter=country,
        city_filter=city,
        domain_filter=domain,
    )

    # ── 4. Cache the result ──────────────────────────────
    try:
        cache_payload = {
            "conferences": [c.model_dump(mode="json") for c in conferences],
            "has_more": has_more,
            "next_offset": next_offset,
        }
        await r.setex(cache_key, CONFERENCES_CACHE_TTL, json.dumps(cache_payload, default=str))
        logger.info(f"Cached {len(conferences)} conferences at {cache_key}")
    except Exception as e:
        logger.error(f"Failed to cache conferences: {e}")

    return response
