import httpx
import asyncio
import urllib.parse

PREDICTHQ_API_KEY = "jqmFYPUETzmXnJ6HKd024roJj6tOeZ9DBlW7srwj"
BASE_URL = "https://api.predicthq.com/v1/events/"

async def test():
    headers = {
        "Authorization": f"Bearer {PREDICTHQ_API_KEY}",
        "Accept": "application/json"
    }
    params = {
        "category": "conferences",
        "active.gte": "2023-01-01",
        "limit": 5,
        "country": "US",
        "q": "AI online",
        "state": "active"
    }
    print("Fetching PredictHQ directly with:", params)
    async with httpx.AsyncClient() as client:
        response = await client.get(BASE_URL, headers=headers, params=params)
        print("Status", response.status_code)
        try:
            data = response.json()
            events = data.get("results", [])
            print("Count", len(events))
            if events:
                for ev in events[:5]:
                    print(ev.get("title"), ev.get("country"), ev.get("phq_attendance_mode"))
        except Exception as e:
            print("Error", e)

asyncio.run(test())
