import httpx

r = httpx.get("https://api.openalex.org/works?filter=host_venue.id:s4306400194&per_page=1")
if r.status_code == 200:
    for w in r.json().get('results', []):
        print(w['ids'])
    
r2 = httpx.get("https://api.openalex.org/works/10.48550/arXiv.2206.02285")
print("DOI test:", r2.status_code)
        
r3 = httpx.get("https://api.openalex.org/works?filter=arxiv:2206.02285")
print("Filter test:", r3.status_code)

r4 = httpx.get("https://api.openalex.org/works?filter=ids.arxiv:https://arxiv.org/abs/2206.02285")
print("Filter abstract test:", r4.status_code)
if r4.status_code == 200:
    print(r4.json().get('meta', {}).get('count'))
    
