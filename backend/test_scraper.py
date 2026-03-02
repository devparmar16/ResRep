import httpx, asyncio
async def test():
    resp = await httpx.AsyncClient().get('https://www.reddit.com/r/science/search.json', params={'q': 'paper OR study OR arxiv OR doi.org', 'sort': 'hot', 't': 'month', 'limit': '50', 'restrict_sr': 'on'}, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'})
    print('Reddit:', resp.status_code); print(len(resp.json().get('data', {}).get('children', [])))
asyncio.run(test())
