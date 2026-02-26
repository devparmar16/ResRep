import httpx

url1 = "https://api.openalex.org/works/https://arxiv.org/abs/2602.21204"
url2 = "https://api.openalex.org/works/arxiv:2602.16800"

print("testing:", url1, httpx.get(url1).status_code)
print("testing:", url2, httpx.get(url2).status_code)
