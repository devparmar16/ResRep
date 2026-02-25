"""
Ranking / scoring utilities.
"""
from datetime import datetime, timezone
from config import CORE_WEIGHT, SUBDOMAIN_ENG_WEIGHT, RECENT_INT_WEIGHT, TREND_WEIGHT


def recency_score(publication_date: str | None) -> float:
    """1 / (days_since_publication + 1).  Returns 0 if date is missing."""
    if not publication_date:
        return 0.0
    try:
        pub = datetime.fromisoformat(publication_date.replace("Z", "+00:00"))
        days = max((datetime.now(timezone.utc) - pub).days, 0)
        return 1.0 / (days + 1)
    except (ValueError, TypeError):
        return 0.0


def compute_score(
    citation_count: int = 0,
    publication_date: str | None = None,
    core_domain_weight: float = 1.0,
    subdomain_engagement: float = 0.0,
    recent_interaction: float = 0.0,
    trending_score: float = 0.0,
) -> float:
    """
    Memory-safe, Redis-optimized ZSET ranking score.
    Formula:
    (Core Domain Weight * CORE_WEIGHT)
    + (Subdomain Engagement * SUBDOMAIN_ENG_WEIGHT)
    + (Recent Interaction * RECENT_INT_WEIGHT)
    + (Citation/Trending Score * TREND_WEIGHT)
    """
    
    # Normalise citation/trending (log-ish scale, cap at 1.0)
    norm_citations = min(citation_count / 500.0, 1.0)
    base_trending = min(trending_score / 100.0, 1.0)
    combined_trending = min(norm_citations + base_trending, 1.0)
    
    return (
        core_domain_weight * CORE_WEIGHT
        + subdomain_engagement * SUBDOMAIN_ENG_WEIGHT
        + recent_interaction * RECENT_INT_WEIGHT
        + combined_trending * TREND_WEIGHT
    )
