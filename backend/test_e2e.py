"""Test: Full 2-phase pipeline end-to-end."""
import asyncio
import logging
logging.basicConfig(level=logging.INFO)

async def main():
    from social_trending_jobs import social_trending_fetch_job
    await social_trending_fetch_job()

    # Check what's in the API
    import httpx
    r = httpx.get("http://localhost:8000/social-trending", follow_redirects=True)
    data = r.json()
    print(f"\n{'='*60}")
    print(f"API returned {data.get('total')} papers")
    for p in data.get('papers', [])[:10]:
        print(f"  [{p.get('domain')}] {p.get('title', '')[:60]} | sources={p.get('trending_sources')} | conf={p.get('confidence', 0):.2f}")

if __name__ == "__main__":
    asyncio.run(main())
