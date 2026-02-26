import asyncio
import logging
from social_trending_jobs import social_trending_fetch_job

logging.basicConfig(level=logging.INFO)

async def main():
    print("Running job...")
    await social_trending_fetch_job()
    print("Done")

if __name__ == "__main__":
    asyncio.run(main())
