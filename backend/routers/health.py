"""
Health check router.
"""
from fastapi import APIRouter
import redis_client
from models import HealthResponse

router = APIRouter(tags=["Health"])


@router.get("/health", response_model=HealthResponse)
async def health_check():
    try:
        r = await redis_client.get_redis()
        await r.ping()
        mode = "fakeredis (in-memory)" if redis_client.is_using_fakeredis() else "connected"
        return HealthResponse(status="ok", redis=mode)
    except Exception as e:
        return HealthResponse(status="degraded", redis=str(e))
