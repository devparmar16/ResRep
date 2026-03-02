import httpx
import asyncio
import urllib.parse

PREDICTHQ_API_KEY = "jqmFYPUETzmXnJ6HKd024roJj6tOeZ9DBlW7srwj"
BASE_URL = "http://localhost:8000/conferences"

async def test():
    params = {
        "country": "US",
        "domain": "AI",
        "mode": "online",
        "limit": 6,
    }
    url = f"{BASE_URL}?{urllib.parse.urlencode(params)}"
    print("Fetching", url)
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        print("Status", response.status_code)
        try:
            data = response.json()
            events = data.get("conferences", [])
            print("Count", len(events))
            if events:
                for ev in events:
                    print(ev.get("title"), ev.get("country"), ev.get("mode"))
            else:
                print(data)
        except Exception as e:
            print("Error", e, response.text)

asyncio.run(test())
