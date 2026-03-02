import httpx, asyncio, time
async def test():
    one_month_ago = int(time.time() - 30 * 24 * 3600)
    resp = await httpx.AsyncClient().get('https://hn.algolia.com/api/v1/search', params={'query': 'arxiv.org OR paper OR preprint OR doi.org', 'tags': 'story', 'hitsPerPage': '5', 'numericFilters': f'points>50,created_at_i>{one_month_ago}'})
    print(len(resp.json().get('hits', [])))
asyncio.run(test())
