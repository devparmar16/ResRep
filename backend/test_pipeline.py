import asyncio
from social_trending_jobs import social_trending_fetch_job
async def run():
    print('Starting full pipeline...')
    await social_trending_fetch_job()
    print('Done.')
if __name__ == '__main__':
    asyncio.run(run())
