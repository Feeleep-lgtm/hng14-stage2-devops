import os
import time

import redis

REDIS_HOST = os.getenv("REDIS_HOST") or os.getenv("REDIS_SERVICE_NAME") or "localhost"
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD") or None
QUEUE_NAME = os.getenv("REDIS_QUEUE_NAME", "job")

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, password=REDIS_PASSWORD, decode_responses=True)


def process_job(job_id: str):
    print(f"Processing job {job_id}")
    r.hset(f"job:{job_id}", "status", "processing")
    time.sleep(2)  # simulate work
    r.hset(f"job:{job_id}", "status", "completed")
    print(f"Done: {job_id}")


while True:
    try:
        job = r.brpop(QUEUE_NAME, timeout=5)
    except redis.RedisError as exc:
        print(f"Redis unavailable: {exc}")
        time.sleep(1)
        continue

    if job:
        _, job_id = job
        process_job(job_id)
