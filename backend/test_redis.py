import redis
import json
r = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
count = r.zcard("social_trending:global")
print("Total solved globally:", count)
for p in r.zrevrange("social_trending:global", 0, 5, withscores=True):
    print(p)
