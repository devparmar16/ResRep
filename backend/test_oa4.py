import httpx
r = httpx.get("https://api.openalex.org/works?filter=primary_location.source.id:s4306400194&per_page=1")
for w in r.json().get('results', []):
    print(w['ids'])
