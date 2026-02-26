import asyncio
from social_trending_service import *
from openalex_service import resolve_paper_id

async def main():
    a = await fetch_arxiv_trending()
    print("Arxiv mentions:", len(a))
    if a:
        print("First arxiv mention:", a[0])
        res = await resolve_paper_id(a[0].paper_identifier, a[0].identifier_type)
        print("Resolved:", "Yes" if res else "No")
        if res:
            print("Domain:", res.get("domain"))

    r = await fetch_reddit_mentions()
    print("Reddit mentions:", len(r))
    if r:
        print("First reddit mention:", r[0])
        res = await resolve_paper_id(r[0].paper_identifier, r[0].identifier_type)
        print("Resolved:", "Yes" if res else "No")
        if res:
            print("Domain:", res.get("domain"))

if __name__ == "__main__":
    asyncio.run(main())
