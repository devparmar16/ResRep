import httpx
import asyncio

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
        "offset": 0,
        "sort": "start",
        "state": "active"
    }
    async with httpx.AsyncClient() as client:
        response = await client.get(BASE_URL, headers=headers, params=params)
        print("Status", response.status_code)
        try:
            data = response.json()
            events = data.get("results", [])
            print("Count", len(events))
            if events:
                for ev in events:
                    print(ev.get("title"), ev.get("country"))
            else:
                print(data)
        except Exception as e:
            print("Error", e, response.text)

asyncio.run(test())
