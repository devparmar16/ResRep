import logging
import httpx
from config import OPENALEX_BASE_URL, OPENALEX_MAILTO

logger = logging.getLogger("openalex")

_client: httpx.AsyncClient | None = None

HEADERS = {
    "User-Agent": f"ScholarShorts/1.0 (mailto:{OPENALEX_MAILTO})",
}


async def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            base_url=OPENALEX_BASE_URL,
            headers=HEADERS,
            timeout=30.0,
        )
    return _client


async def close_client() -> None:
    global _client
    if _client is not None:
        await _client.aclose()
        _client = None


# ── Papers ───────────────────────────────────────────────────────────────

async def fetch_papers_by_domain(
    domain_id: str,
    concept_id: str,
    from_date: str | None = None,
    per_page: int = 100,
    page: int = 1,
) -> list[dict]:
    """
    Fetch works from OpenAlex filtered by the broad concept.
    Tags them with their matching subdomain context.
    """
    client = await _get_client()

    filters = [f"concepts.id:{concept_id}", "type:article"]
    if from_date:
        filters.append(f"from_publication_date:{from_date}")

    params = {
        "filter": ",".join(filters),
        "sort": "cited_by_count:desc",
        "per_page": str(per_page),
        "page": str(page),
        "mailto": OPENALEX_MAILTO,
    }

    try:
        resp = await client.get("/works", params=params)
        resp.raise_for_status()
        data = resp.json()

        results = []
        for work in data.get("results", []):
            try:
                results.append(_normalise_work(work, domain_id))
            except Exception as inner_e:
                logger.error(f"Error normalising work: {inner_e}")
                continue
        return results
    except Exception as e:
        logger.error(f"Error fetching papers from OpenAlex: {e}")
        return []


def _normalise_work(work: dict, primary_domain: str = "other") -> dict:
    """Convert an OpenAlex Work object into our flat, minimal paper dict to save Redis memory."""
    from config import DOMAIN_SUBDOMAINS
    
    title = work.get("title") or "Untitled"
    abstract_text = _reconstruct_abstract(work.get("abstract_inverted_index"))

    # Fallback to text matching for subdomains
    subdomain = "unknown"
    if primary_domain in DOMAIN_SUBDOMAINS:
        search_text = f"{title} {abstract_text or ''}".lower()
        for sub in DOMAIN_SUBDOMAINS[primary_domain]:
            if sub.lower() in search_text:
                subdomain = sub
                break

    # Extract authors (limit to 5 string array)
    authors = []
    for authorship in work.get("authorships", [])[:5]:
        name = authorship.get("author", {}).get("display_name", "")
        if name:
            authors.append(name)

    # Primary location for journal name & id, plus official URLs
    source = work.get("primary_location", {}) or {}
    source_obj = source.get("source") or {}
    journal_name = source_obj.get("display_name")
    journal_id = source_obj.get("id", "").replace("https://openalex.org/", "") if source_obj.get("id") else None
    
    landing_page_url = source.get("landing_page_url")
    pdf_url = source.get("pdf_url")

    # Open access info
    oa = work.get("open_access", {}) or {}
    is_open_access = oa.get("is_oa", False)
    
    # Fallback PDF from OA object
    if not pdf_url and is_open_access:
        pdf_url = oa.get("oa_url")
        
    # DOI for fallback landing page
    doi = work.get("doi")

    # Limit summary memory
    summary = None
    if abstract_text:
        sentences = abstract_text.split(". ")
        summary = ". ".join(sentences[:2]) + ("." if len(sentences) > 0 and not sentences[0].endswith(".") else "")

    # Minimal flat schema for caching
    return {
        "paper_id": work.get("id", "").replace("https://openalex.org/", ""),
        "title": title,
        "abstract": abstract_text,
        "summary": summary,
        "authors": authors,  # Limited to top 5 string arrays
        "journal": journal_name,
        "journal_id": journal_id,
        "doi": doi,
        "landing_page_url": landing_page_url,
        "pdf_url": pdf_url,
        "is_open_access": is_open_access,
        "publication_date": work.get("publication_date"),
        "year": work.get("publication_year"),
        "citation_count": work.get("cited_by_count", 0),
        "openalex_score": work.get("relevance_score", 0.0),
        "domain": primary_domain,
        "subdomain": subdomain,
    }


def _reconstruct_abstract(inverted_index: dict | None) -> str | None:
    """Rebuild abstract text from OpenAlex inverted-index representation."""
    if not inverted_index:
        return None
    try:
        word_positions: list[tuple[int, str]] = []
        for word, positions in inverted_index.items():
            for pos in positions:
                word_positions.append((pos, word))
        word_positions.sort(key=lambda x: x[0])
        return " ".join(w for _, w in word_positions)
    except Exception:
        return None


# ── Journals (Sources) ───────────────────────────────────────────────────

async def fetch_journals_by_domain(
    concept_ids: list[str] = None,
    search_query: str = None,
) -> list[dict]:
    """Fetch academic journals (sources) with broad fallbacks."""
    client = await _get_client()
    
    async def _do_fetch(q: str | None, cids: list[str] | None):
        filters = ["type:journal|conference", "works_count:>10"] 
        if not q and cids:
            filters.append(f"concepts.id:{'|'.join(cids)}")
        
        params = {
            "filter": ",".join(filters),
            "sort": "cited_by_count:desc",
            "per_page": "50",
            "mailto": OPENALEX_MAILTO,
        }
        if q:
            params["search"] = q

        logger.info(f"OpenAlex Source Search: q='{q}', filter={filters}")
        resp = await client.get("/sources", params=params)
        resp.raise_for_status()
        return resp.json().get("results", [])

    try:
        results = await _do_fetch(search_query, concept_ids)
        
        # If no results for specific query, try a broader one
        if not results and search_query:
            logger.info("Specific search returned zero, trying broader fallback...")
            broad_q = search_query.split()[0] # e.g. "Artificial" from "Artificial Intelligence"
            results = await _do_fetch(broad_q, None)
            
        # Last resort fallback: Broad Computer Science journals
        if not results:
            logger.info("All specific searches failed, using 'Computer Science' fallback.")
            results = await _do_fetch("Computer Science", None)

    except Exception as e:
        logger.error(f"Error in source fetch: {e}")
        return []

    results_normalised = []
    for source in results:
        sid = source.get("id", "").replace("https://openalex.org/", "")
        name = source.get("display_name", "Unknown")
        results_normalised.append({
            "journal_id": sid if sid else name.lower().replace(" ", "-"),
            "name": name,
            "paper_count": source.get("works_count", 0),
        })
    return results_normalised


async def fetch_journal_papers(
    journal_id: str,
    sort: str = "top",
    per_page_count: int = 50,
    search_query: str = None,
) -> list[dict]:
    """Fetch papers from a specific journal (source)."""
    client = await _get_client()

    # Map internal sort to OpenAlex sort
    sort_map = {
        "top": "cited_by_count:desc",
        "recent": "publication_date:desc",
        "trending": "cited_by_count:desc",  # Simplification for now
    }
    oa_sort = sort_map.get(sort, "cited_by_count:desc")

    # OpenAlex source ID format
    source_id = journal_id if journal_id.startswith("S") else f"S{journal_id}"
    openalex_id = f"https://openalex.org/{source_id}"

    params = {
        "filter": f"primary_location.source.id:{openalex_id}",
        "sort": oa_sort,
        "per_page": str(per_page_count),
        "mailto": OPENALEX_MAILTO,
    }
    
    if search_query:
        params["search"] = search_query

    try:
        resp = await client.get("/works", params=params)
        resp.raise_for_status()
        data = resp.json()
        return [_normalise_work(w) for w in data.get("results", [])]
    except Exception as e:
        logger.error(f"Error fetching journal papers from OpenAlex: {e}")
        return []
