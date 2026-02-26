"""
Pydantic models for API responses.
"""
from pydantic import BaseModel


class PaperResponse(BaseModel):
    paper_id: str
    title: str
    abstract: str | None = None
    summary: str | None = None
    authors: list[str] = []
    journal: str | None = None
    journal_id: str | None = None
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


class FeedResponse(BaseModel):
    user_id: str
    papers: list[PaperResponse]
    total: int
    cached: bool = False


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
