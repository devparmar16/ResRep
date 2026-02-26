import httpx
r = httpx.get("https://huggingface.co/api/daily_papers")
arxiv_id = r.json()[0]['paper']['id']
r1 = httpx.get(f"https://api.openalex.org/works/https://arxiv.org/abs/{arxiv_id}")
r2 = httpx.get(f"https://api.openalex.org/works/arxiv:{arxiv_id}")
print(f"HF paper {arxiv_id}")
print("URI approach:", r1.status_code)
print("Arxiv: approach:", r2.status_code)
