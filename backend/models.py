"""
Pydantic models for API responses.
"""
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel


class PaperResponse(BaseModel):
    paper_id: str
    title: str
    abstract: str | None = None
    summary: str | None = None
    authors: list[str] = []
    journal: str | None = None
    journal_id: str | None = None
    publisher: str | None = None
    doi: str | None = None
    landing_page_url: str | None = None
    pdf_url: str | None = None
    is_open_access: bool = False
    publication_date: str | None = None
    year: int | None = None
    citation_count: int = 0
    openalex_score: float = 0.0
    domain: str = "other"
    subdomain: str = "unknown"
    score: float = 0.0


class JournalResponse(BaseModel):
    journal_id: str
    name: str
    domain: str
    paper_count: int = 0
    publisher: str | None = None


class FeedResponse(BaseModel):
    user_id: str | None = None
    papers: list[PaperResponse]
    total: int
    cached: bool = False
    next_cursor: str | None = None


class HealthResponse(BaseModel):
    status: str
    redis: str


class SocialTrendingPaper(PaperResponse):
    trending_sources: list[str] = []
    social_score: float = 0.0
    confidence: float = 0.0


class SocialTrendingResponse(BaseModel):
    papers: list[SocialTrendingPaper]
    total: int
    domain: str | None = None


class Conference(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    venue_name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    mode: str = "offline"  # online, offline, hybrid
    url: Optional[str] = None
    labels: List[str] = []
    publisher: Optional[str] = None
    domain: Optional[str] = None


class ConferenceResponse(BaseModel):
    conferences: List[Conference]
    total: int
    has_more: bool = False
    next_offset: int = 0
    mode_filter: Optional[str] = None
    country_filter: Optional[str] = None
    city_filter: Optional[str] = None
    domain_filter: Optional[str] = None