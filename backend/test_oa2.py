import httpx

urls = [
    "https://api.openalex.org/works/https://arxiv.org/abs/2206.02285",
    "https://api.openalex.org/works/arxiv:2206.02285"
]

for u in urls:
    r = httpx.get(u)
    print(u, r.status_code)
