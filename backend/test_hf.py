import httpx
import json

hf = httpx.get("https://huggingface.co/api/daily_papers")
print("HF API: ", hf.status_code)
if hf.status_code == 200:
    data = hf.json()
    print("HF count", len(data))
    if data:
        print("HF Sample:", data[0].get('paper', {}).get('id'))

# Let's see what happens if we query reddit with month
from social_trending_service import *
import datetime

async def main():
    import time
    now = int(time.time())
    month_ago = now - 30 * 24 * 3600
    hn = httpx.get(f"https://hn.algolia.com/api/v1/search?query=arxiv.org&tags=story&numericFilters=created_at_i>{month_ago}")
    print("HN count:", len(hn.json().get('hits', [])))
    
if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
