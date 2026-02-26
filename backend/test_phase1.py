"""Quick test: Phase 1 social discovery."""
import asyncio
import logging
from social_trending_service import fetch_all_social_candidates

logging.basicConfig(level=logging.INFO)

async def main():
    candidates = await fetch_all_social_candidates()
    print(f"\n{'='*60}")
    print(f"Total candidates: {len(candidates)}")
    for i, c in enumerate(candidates[:15]):
        id_str = f"{c.identifier_type}:{c.identifier}" if c.has_direct_id else f"title:'{c.title_phrase}'"
        print(f"  #{i+1} | buzz={c.buzz_score:.0f} | platforms={c.source_platforms} | {id_str[:70]}")

if __name__ == "__main__":
    asyncio.run(main())
