import httpx
try:
    r = httpx.get("http://localhost:8000/social-trending/")
    data = r.json()
    print("Global Trending Total:", data.get('total'))
    for p in data.get('papers', [])[:5]:
        print("-", p.get('domain'), p.get('title'), p.get('trending_sources'))
        
    for domain in ["cs", "medicine", "engineering"]:
        rd = httpx.get(f"http://localhost:8000/social-trending/{domain}")
        dd = rd.json()
        print(f"Domain {domain} Trending Total:", dd.get('total'))
        
except Exception as e:
    print("Error:", e)
