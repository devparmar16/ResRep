import httpx
try:
    r = httpx.get("http://localhost:8000/social-trending/", follow_redirects=True)
    data = r.json()
    print("Global Trending Total:", data.get('total'))
    for p in data.get('papers', [])[:10]:
        print("-", p.get('domain'), p.get('title'), p.get('trending_sources'))
except Exception as e:
    print("Error:", e)
