import httpx
try:
    r = httpx.get("http://localhost:8000/social-trending/")
    print("Status:", r.status_code)
    print("Text:", r.text[:200])
except Exception as e:
    print("Error:", e)
