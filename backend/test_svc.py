import asyncio
from services.predicthq_service import PredictHQService

async def test():
    try:
        res = await PredictHQService.fetch_conferences(
            country="US",
            domain="AI",
            mode="online",
            limit=5
        )
        print("Fetched:", len(res))
        for r in res[:2]:
            print(r.title, r.mode, r.country)
    except Exception as e:
        print("TEST SCRIPT EXCEPTION:", e)

if __name__ == "__main__":
    import logging
    logging.basicConfig(level=logging.ERROR)
    asyncio.run(test())
