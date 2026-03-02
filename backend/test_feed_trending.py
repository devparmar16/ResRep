import httpx
import asyncio

BASE_URL = "http://localhost:8000"

async def test():
    async with httpx.AsyncClient(timeout=100) as client:
        print("Testing /feed with real domains...")
        try:
            resp = await client.get(f"{BASE_URL}/feed?user_id=test_user&interests=cs,biology")
            print("Feed Status:", resp.status_code)
            data = resp.json()
            print("Feed Count:", len(data.get("papers", [])))
            if data.get("error"):
                print("Feed Error:", data.get("error"))
        except Exception as e:
            print("Feed Exception:", e)

asyncio.run(test())
