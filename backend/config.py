"""
Application configuration — Redis keys, TTLs, ranking weights, API settings.
"""
import os


# ── Redis ────────────────────────────────────────────────────────────────
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

# TTLs (seconds)
DOMAIN_CACHE_TTL = 3600                # 1 hour max (memory safe)
PAPER_METADATA_TTL = 6 * 3600          # 6 hours max
USER_FEED_TTL = 7200                   # 2 hours max
JOURNAL_CACHE_TTL = 24 * 3600          # 24 hours
SEARCH_CACHE_TTL = 1800                # 30 mins max

# Max sorted-set sizes
MAX_DOMAIN_PAPERS = 100
MAX_USER_FEED = 100
MAX_JOURNAL_LIST = 100
MAX_JOURNAL_PAPERS = 100

# ── Interest Handling ────────────────────────────────────────────────────
MAX_INTERESTS = 10

def papers_per_interest(n_interests: int) -> int:
    """Dynamic per-interest paper limit."""
    if n_interests <= 5:
        return 100
    elif n_interests <= 8:
        return 60
    else:
        return 40

# ── Ranking Weights ──────────────────────────────────────────────────────
CORE_WEIGHT = 0.4
SUBDOMAIN_ENG_WEIGHT = 0.3
RECENT_INT_WEIGHT = 0.2
TREND_WEIGHT = 0.1

# ── OpenAlex ─────────────────────────────────────────────────────────────
OPENALEX_BASE_URL = "https://api.openalex.org"
OPENALEX_MAILTO = os.getenv("OPENALEX_MAILTO", "scholar-shorts@example.com")

# ── Background Job ───────────────────────────────────────────────────────
DOMAIN_FETCH_INTERVAL_MINUTES = 30

# ── Domain Configurations ──────────────────────────────────────────────────
# Mapping Core Domains to OpenAlex Broad Concept IDs
CORE_DOMAINS_CONCEPTS: dict[str, str] = {
    "cs": "C41008148",
    "engineering": "C127413603",
    "math": "C33923547",
    "physics": "C121332964",
    "chemistry": "C185592680",
    "biology": "C86803240",
    "medicine": "C71924100",
    "environmental": "C39432304",
    "economics": "C162324750",
    "psychology": "C15744967",
    "business": "C144133560",
    "ds-ai": "C119857082", # Machine Learning concept as proxy setup
    "sociology": "C144024400",
    "political": "C17744445",
    "law": "C199539241",
    "interdisciplinary": "C130828816",
}

# Subdomain Keywords for Text-Matching
DOMAIN_SUBDOMAINS: dict[str, list[str]] = {
    "cs": ["Artificial Intelligence", "Machine Learning", "Cybersecurity", "Software Engineering", "Computer Vision", "Natural Language Processing", "Distributed Systems"],
    "engineering": ["Civil Engineering", "Mechanical Engineering", "Electrical Engineering", "Robotics", "Aerospace Engineering", "Materials Engineering"],
    "math": ["Pure Mathematics", "Applied Mathematics", "Statistics", "Probability", "Mathematical Modeling"],
    "physics": ["Quantum Physics", "Astrophysics", "Particle Physics", "Condensed Matter Physics", "Optics & Photonics"],
    "chemistry": ["Organic Chemistry", "Inorganic Chemistry", "Analytical Chemistry", "Biochemistry", "Materials Chemistry"],
    "biology": ["Molecular Biology", "Genetics", "Microbiology", "Biotechnology", "Neuroscience", "Ecology"],
    "medicine": ["Cardiology", "Oncology", "Neurology", "Public Health", "Epidemiology", "Clinical Research"],
    "environmental": ["Climate Science", "Sustainability", "Renewable Energy", "Conservation", "Water Resource Management"],
    "economics": ["Microeconomics", "Macroeconomics", "Econometrics", "Development Economics", "Financial Economics"],
    "psychology": ["Cognitive Psychology", "Clinical Psychology", "Behavioral Psychology", "Social Psychology"],
    "business": ["Finance", "Marketing", "Operations Management", "Entrepreneurship", "Supply Chain Management"],
    "ds-ai": ["Deep Learning", "Big Data Analytics", "Data Engineering", "AI Ethics", "Generative AI"],
    "sociology": ["Social Theory", "Urban Studies", "Gender Studies", "Social Policy"],
    "political": ["International Relations", "Public Policy", "Comparative Politics", "Governance"],
    "law": ["Constitutional Law", "Criminal Law", "Corporate Law", "Intellectual Property Law", "Cyber Law"],
    "interdisciplinary": ["Bioinformatics", "Computational Biology", "Cognitive Science", "Environmental Economics", "Digital Humanities"],
}

# ── Domain → OpenAlex search queries ─────────────────────────────────────
# Used for fetching basic journals or when concept IDs fail
DOMAIN_SEARCH_QUERIES: dict[str, str] = {
    "cs": "Computer Science",
    "engineering": "Engineering",
    "math": "Mathematics",
    "physics": "Physics",
    "chemistry": "Chemistry",
    "biology": "Biology",
    "medicine": "Medicine Healthcare",
    "environmental": "Environmental Science",
    "economics": "Economics",
    "psychology": "Psychology",
    "business": "Business Management",
    "ds-ai": "Data Science",
    "sociology": "Sociology",
    "political": "Political Science",
    "law": "Law",
    "interdisciplinary": "Interdisciplinary Research",
}
