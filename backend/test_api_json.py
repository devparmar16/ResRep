import httpx
r = httpx.get("http://localhost:8000/social-trending", follow_redirects=True)
print("Status:", r.status_code)
d = r.json()
print("Total count:", d.get('total'))
keys = set()
for p in d.get('papers', []):
    for src in p.get('trending_sources', []):
        keys.add(src)
print("Sources found in global:", keys)
