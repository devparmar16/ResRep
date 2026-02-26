import asyncio
from social_trending_service import *

async def main():
    print("Testing reddit...")
    r = await fetch_reddit_mentions()
    print("Reddit:", len(r))
    
    print("Testing hn...")
    h = await fetch_hackernews_mentions()
    print("HN:", len(h))
    
    print("Testing arxiv...")
    a = await fetch_arxiv_trending()
    print("Arxiv:", len(a))

    print("Testing pwc...")
    p = await fetch_paperswithcode_trending()
    print("PWC:", len(p))

    print("Testing ss...")
    s = await fetch_semantic_scholar_trending()
    print("SS:", len(s))

    print("Testing crossref...")
    c = await fetch_crossref_events()
    print("Crossref:", len(c))

    print("Testing pubmed...")
    pu = await fetch_pubmed_trending()
    print("Pubmed:", len(pu))

    print("Testing altmetric...")
    al = await fetch_altmetric_trending()
    print("Altmetric:", len(al))

if __name__ == "__main__":
    asyncio.run(main())
