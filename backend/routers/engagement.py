"""
Engagement router — Tracks user interactions (clicks, reads, saves) using memory-safe ZSETs.
"""
import logging
from fastapi import APIRouter, Query, BackgroundTasks
import redis_client

logger = logging.getLogger("engagement")
router = APIRouter(prefix="/engagement", tags=["Engagement"])


@router.post("/track")
async def track_interaction(
    paper_id: str = Query(..., description="The OpenAlex ID of the paper"),
    action: str = Query(..., description="Type of engagement: 'click', 'read', 'save', 'read_duration', 'full_paper_open', 'share'"),
    value: float = Query(1.0, description="Value to increment by (e.g., seconds for read_duration)"),
    domain: str = Query(None, description="Optional core domain to increment domain-specific trending"),
    subdomain: str = Query(None, description="Optional subdomain to increment granular subdomain trending"),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    """
    Fire-and-forget endpoint for user engagement.
    Increments lightweight ZSET counters instead of creating massive payload lists.
    """
    valid_actions = {"click", "read", "save", "read_duration", "full_paper_open", "share"}
    if action not in valid_actions:
        return {"status": "ignored", "reason": "invalid_action"}

    # Offload to background task to keep API response instantaneous
    background_tasks.add_task(redis_client.track_engagement, action, paper_id, value, domain, subdomain)
    
    return {"status": "recorded"}
