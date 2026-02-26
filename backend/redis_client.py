"""
Async Redis connection pool and helper utilities.
Falls back to fakeredis (in-memory) when real Redis is unavailable.
"""
import json
import zlib
import logging
import redis.asyncio as aioredis
import fakeredis.aioredis
from config import REDIS_URL

logger = logging.getLogger("redis_client")

_pool = None
_using_fake = False


async def get_redis():
    """Return the shared async Redis client (lazy-init)."""
    global _pool, _using_fake
    if _pool is None:
        try:
            _pool = aioredis.from_url(
                REDIS_URL,
                decode_responses=True,
                max_connections=50, # Increased for efficiency
            )
            await _pool.ping()
            logger.info("Connected to real Redis ✓")
        except Exception as e:
            logger.warning(f"Failed to connect to real Redis, falling back to fakeredis: {e}")
            _pool = fakeredis.aioredis.FakeRedis(decode_responses=True)
            _using_fake = True
    return _pool


async def close_redis() -> None:
    global _pool
    if _pool is not None:
        if hasattr(_pool, "aclose"):
            await _pool.aclose()
        elif hasattr(_pool, "close"):
            await _pool.close()
        _pool = None


def is_using_fakeredis() -> bool:
    return _using_fake


# ── Helpers ──────────────────────────────────────────────────────────────

async def cap_sorted_set(key: str, max_size: int) -> None:
    """Trim a sorted set to keep only the top `max_size` members (highest scores)."""
    r = await get_redis()
    # ZREMRANGEBYRANK removes the lowest-scored members
    await r.zremrangebyrank(key, 0, -(max_size + 1))


async def store_paper_metadata(paper_id: str, data: dict, ttl: int) -> None:
    """Store a minimal paper JSON string in Redis with TTL."""
    r = await get_redis()
    key = f"paper:{paper_id}"
    await r.setex(key, ttl, json.dumps(data))


async def get_paper_metadata(paper_id: str) -> dict | None:
    """Retrieve a minimal minimal paper JSON string from Redis."""
    r = await get_redis()
    key = f"paper:{paper_id}"
    
    try:
        val_type = await r.type(key)
        if val_type == 'hash':
            # Fallback for older format during migration
            raw_data = await r.hgetall(key)
            if not raw_data:
                return None
            
            # Very basic string cleanup
            for k, v in raw_data.items():
                if isinstance(v, str) and v.startswith('[') and v.endswith(']'):
                    try: raw_data[k] = json.loads(v)
                    except: pass
            return raw_data
            
        val = await r.get(key)
        if val:
            return json.loads(val)
        return None
    except Exception as e:
        logger.error(f"Error reading paper metadata {paper_id}: {e}")
        return None


async def paper_exists(paper_id: str) -> bool:
    r = await get_redis()
    return await r.exists(f"paper:{paper_id}") > 0


async def track_engagement(action_type: str, paper_id: str, value: float = 1.0, domain: str = None, subdomain: str = None) -> None:
    """
    Increment engagement ZSET securely without exploding memory.
    action_type expects 'click', 'read', 'save', 'read_duration', 'full_paper_open', 'share'.
    """
    r = await get_redis()
    
    # Global tracking
    await r.zincrby(f"engagement:{action_type}", value, paper_id)
    await r.zincrby("trending:global", value, paper_id)
    
    # Domain tracking
    if domain:
        await r.zincrby(f"trending:domain:{domain}", value, paper_id)
        
    # Subdomain tracking
    if subdomain:
        await r.zincrby(f"trending:subdomain:{subdomain}", value, paper_id)


async def store_social_sources(paper_id: str, sources: list[str], ttl: int) -> None:
    """Store the list of platforms where a paper is trending."""
    r = await get_redis()
    key = f"social_trending:sources:{paper_id}"
    await r.setex(key, ttl, json.dumps(sources))


async def get_social_sources(paper_id: str) -> list[str]:
    """Retrieve the trending source platforms for a paper."""
    r = await get_redis()
    key = f"social_trending:sources:{paper_id}"
    val = await r.get(key)
    if val:
        try:
            return json.loads(val)
        except Exception:
            return []
    return []


async def get_resolve_cache(key: str) -> str | None:
    """Check if a resolution result is cached. Returns paper_id or '__MISS__' or None."""
    r = await get_redis()
    return await r.get(f"resolve_cache:{key}")


async def set_resolve_cache(key: str, value: str, ttl: int) -> None:
    """Cache a resolution result (paper_id or '__MISS__')."""
    r = await get_redis()
    await r.setex(f"resolve_cache:{key}", ttl, value)
