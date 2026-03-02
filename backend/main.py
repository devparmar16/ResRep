"""
FastAPI entry point — Scholar Shorts Backend.
"""
import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.asyncio import AsyncIOScheduler

import redis_client
import openalex_service
from background_jobs import decay_trending_job
from social_trending_jobs import social_trending_fetch_job
from routers import feed, journals, health, engagement, search, social_trending, conferences
from config import DOMAIN_FETCH_INTERVAL_MINUTES, SOCIAL_FETCH_INTERVAL_HOURS

from fastapi import Request
from fastapi.responses import JSONResponse
import traceback

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("main")

scheduler = AsyncIOScheduler()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown lifecycle."""
    # ── Startup ──
    logger.info("Connecting to Redis ...")
    r = await redis_client.get_redis()
    await r.ping()
    
    # Attempt to set LRU eviction to prevent memory explosion
    if not redis_client.is_using_fakeredis():
        try:
            await r.config_set("maxmemory-policy", "allkeys-lru")
            logger.info("Redis maxmemory-policy set to allkeys-lru")
        except Exception as e:
            logger.warning(f"Could not set maxmemory-policy (maybe running in constrained env): {e}")
            
    logger.info("Redis connected ✓")


    
    # Run exponential decay independently twice a day
    scheduler.add_job(
        decay_trending_job,
        "interval",
        hours=12,
        id="trending_decay",
        replace_existing=True,
    )
    
    # Schedule social trending fetch
    scheduler.add_job(
        social_trending_fetch_job,
        "interval",
        hours=SOCIAL_FETCH_INTERVAL_HOURS,
        id="social_trending_fetch",
        replace_existing=True,
    )
    # Run initial social trending fetch
    asyncio.create_task(social_trending_fetch_job())
    
    scheduler.start()
    logger.info(f"Scheduler started: decay every 12 hours, social trending every {SOCIAL_FETCH_INTERVAL_HOURS} hours.")

    yield

    # ── Shutdown ──
    scheduler.shutdown(wait=False)
    await openalex_service.close_client()
    await redis_client.close_redis()
    logger.info("Shutdown complete.")


app = FastAPI(
    title="Scholar Shorts API",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — allow Flutter web, Android emulator, etc.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    err = traceback.format_exc()
    logger.error(f"Global exception: {err}")
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "traceback": err},
    )

# Routers
app.include_router(feed.router)
app.include_router(journals.router)
app.include_router(engagement.router)
app.include_router(search.router)
app.include_router(social_trending.router)
app.include_router(conferences.router)
app.include_router(health.router)
