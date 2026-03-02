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


async def fetch_feed_cursor(
    domain: str,
    publisher: str | None,
    sort: str,
    cursor: str = "*",
    per_page: int = 25,
    search_query: str | None = None,
) -> tuple[list[dict], str | None]:
    """
    Fetch works from OpenAlex using cursor-based pagination.
    Supports multiple domains, publisher filter, and custom sorting.
    """
    from config import CORE_DOMAINS_CONCEPTS
    client = await _get_client()

    filters = ["type:article"]
    
    if domain and domain != "all":
        domain_list = [d.strip() for d in domain.split(",") if d.strip()]
        concept_ids = []
        for d in domain_list:
            if d in CORE_DOMAINS_CONCEPTS:
                concept_ids.append(CORE_DOMAINS_CONCEPTS[d])
        if concept_ids:
            # Use OR logic for multiple concepts
            filters.append(f"concepts.id:{'|'.join(concept_ids)}")

    if sort == "trending" or sort == "top":
        from datetime import date
        filters.append(f"from_publication_date:{date.today().year - 1}-01-01")

    if publisher:
        filters.append(f"primary_location.source.host_organization_name.search:{publisher}")

    openalex_sort = "relevance_score:desc"
    if sort == "recent" or sort == "latest":
        openalex_sort = "publication_date:desc"
    elif sort == "trending" or sort == "top" or sort == "cited_by_count:desc":
        openalex_sort = "cited_by_count:desc"
    elif sort == "relevance":
        if search_query:
            openalex_sort = "relevance_score:desc"
        else:
            # Fallback for relevance without keywords
            openalex_sort = "cited_by_count:desc"
    else:
        openalex_sort = sort

    params = {
        "filter": ",".join(filters),
        "sort": openalex_sort,
        "per_page": str(per_page),
        "cursor": cursor,
        "mailto": OPENALEX_MAILTO,
    }
    if search_query:
        params["search"] = search_query

    try:
        resp = await client.get("/works", params=params)
        if resp.status_code != 200:
            logger.error(f"OpenAlex API error (status={resp.status_code}): {resp.text}")
            from fastapi import HTTPException
            raise HTTPException(status_code=resp.status_code, detail=f"OpenAlex API error: {resp.text}")
        
        data = resp.json()

        next_cursor = data.get("meta", {}).get("next_cursor")

        results = []
        for work in data.get("results", []):
            try:
                domain_list = [d.strip() for d in domain.split(",") if d.strip()] if domain and domain != "all" else []
                results.append(_normalise_work(work, domain_list if domain_list else "other"))
            except Exception as inner_e:
                logger.error(f"Error normalising work: {inner_e}")
                continue
        return results, next_cursor
    except Exception as e:
        logger.error(f"Error fetching cursor feed from OpenAlex: {e}")
        return [], None


def _normalise_work(work: dict, primary_domain: str | list[str] = "other") -> dict:
    """Convert an OpenAlex Work object into our flat, minimal paper dict to save Redis memory."""
    from config import DOMAIN_SUBDOMAINS, CORE_DOMAINS_CONCEPTS
    
    title = work.get("title") or "Untitled"
    abstract_text = _reconstruct_abstract(work.get("abstract_inverted_index"))

    # Determine assigned domain
    assigned_domain = "other"
    if isinstance(primary_domain, list) and primary_domain:
        concept_to_domain = {v: k for k, v in CORE_DOMAINS_CONCEPTS.items() if k in primary_domain}
        for c in work.get("concepts", []):
            cid = c.get("id", "").split("/")[-1]
            if cid in concept_to_domain:
                assigned_domain = concept_to_domain[cid]
                break
        if assigned_domain == "other":
            assigned_domain = primary_domain[0]
    elif isinstance(primary_domain, str):
        assigned_domain = primary_domain

    # Fallback to text matching for subdomains
    subdomain = "unknown"
    if assigned_domain in DOMAIN_SUBDOMAINS:
        search_text = f"{title} {abstract_text or ''}".lower()
        for sub in DOMAIN_SUBDOMAINS[assigned_domain]:
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
    publisher = source_obj.get("host_organization_name")
    
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
        "domain": assigned_domain,
        "subdomain": subdomain,
        "publisher": publisher,
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


async def resolve_paper_id(identifier: str, id_type: str) -> dict | None:
    """
    Resolve a DOI or arXiv ID to an OpenAlex normalised paper dict.
    Returns None if the paper cannot be found.
    """
    client = await _get_client()
    try:
        if id_type == "doi":
            url = f"/works/doi:{identifier}"
        elif id_type == "arxiv":
            url = f"/works/https://arxiv.org/abs/{identifier}"
        else:
            return None

        params = {"mailto": OPENALEX_MAILTO}
        resp = await client.get(url, params=params)

        if resp.status_code == 404:
            return None
        resp.raise_for_status()

        work = resp.json()
        logger.info(f"Successfully resolved {id_type}:{identifier}")
        # Detect domain from concepts
        domain = _detect_domain_from_work(work)
        return _normalise_work(work, domain)

    except Exception as e:
        logger.warning(f"Could not resolve {id_type}:{identifier}: {e}")
        return None


def _detect_domain_from_work(work: dict) -> str:
    """Best-effort domain detection from OpenAlex concept IDs."""
    from config import CORE_DOMAINS_CONCEPTS
    concept_id_to_domain = {v: k for k, v in CORE_DOMAINS_CONCEPTS.items()}

    for concept in work.get("concepts", []):
        cid = concept.get("id", "").replace("https://openalex.org/", "")
        if cid in concept_id_to_domain:
            return concept_id_to_domain[cid]
    return "other"


async def resolve_by_title(title: str) -> dict | None:
    """
    Search OpenAlex by title and return the best-matching work.
    Filters to papers from last 3 years for relevance.
    """
    from difflib import SequenceMatcher
    from config import TITLE_SIMILARITY_THRESHOLD

    client = await _get_client()
    try:
        params = {
            "search": title,
            "per_page": "5",
            "filter": "from_publication_date:2023-01-01",
            "mailto": OPENALEX_MAILTO,
        }
        resp = await client.get("/works", params=params)
        resp.raise_for_status()

        results = resp.json().get("results", [])
        best_match = None
        best_sim = 0.0

        for work in results:
            work_title = work.get("title", "")
            if not work_title:
                continue
            similarity = SequenceMatcher(
                None, title.lower().strip(), work_title.lower().strip()
            ).ratio()
            if similarity > best_sim:
                best_sim = similarity
                best_match = work

        if best_match and best_sim >= TITLE_SIMILARITY_THRESHOLD:
            domain = _detect_domain_from_work(best_match)
            paper = _normalise_work(best_match, domain)
            logger.info(f"OpenAlex title search match (sim={best_sim:.2f}): {title[:50]}")
            return paper
        else:
            logger.debug(f"OpenAlex title search: no match above threshold for: {title[:50]}")
            return None

    except Exception as e:
        logger.warning(f"OpenAlex title search error: {e}")
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
            "publisher": source.get("host_organization_name", ""),
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

async def fetch_journal_papers_cursor(
    journal_id: str,
    sort: str = "top",
    cursor: str = "*",
    per_page_count: int = 50,
    search_query: str = None,
) -> tuple[list[dict], str | None]:
    """Fetch papers from a specific journal (source) with cursor pagination."""
    client = await _get_client()

    sort_map = {
        "top": "cited_by_count:desc",
        "recent": "publication_date:desc",
        "trending": "cited_by_count:desc",
    }
    oa_sort = sort_map.get(sort, "cited_by_count:desc")

    source_id = journal_id if journal_id.startswith("S") else f"S{journal_id}"
    openalex_id = f"https://openalex.org/{source_id}"

    params = {
        "filter": f"primary_location.source.id:{openalex_id}",
        "sort": oa_sort,
        "per_page": str(per_page_count),
        "cursor": cursor,
        "mailto": OPENALEX_MAILTO,
    }
    
    if search_query:
        params["search"] = search_query

    try:
        resp = await client.get("/works", params=params)
        resp.raise_for_status()
        data = resp.json()
        next_c = data.get("meta", {}).get("next_cursor")
        return [_normalise_work(w) for w in data.get("results", [])], next_c
    except Exception as e:
        logger.error(f"Error fetching journal cursor papers from OpenAlex: {e}")
        return [], None

