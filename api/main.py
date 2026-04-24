import os
import uuid

import redis
from fastapi import FastAPI, HTTPException

app = FastAPI()

REDIS_HOST = os.getenv("REDIS_HOST") or os.getenv("REDIS_SERVICE_NAME") or "localhost"
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD") or None
QUEUE_NAME = os.getenv("REDIS_QUEUE_NAME", "job")

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, password=REDIS_PASSWORD, decode_responses=True)


@app.get("/health")
def healthcheck():
    try:
        r.ping()
    except redis.RedisError as exc:
        raise HTTPException(status_code=503, detail=f"redis unavailable: {exc}") from exc
    return {"status": "ok"}


@app.post("/jobs")
def create_job():
    job_id = str(uuid.uuid4())
    r.hset(f"job:{job_id}", "status", "queued")
    r.lpush(QUEUE_NAME, job_id)
    return {"job_id": job_id, "status": "queued"}


@app.get("/jobs/{job_id}")
def get_job(job_id: str):
    status = r.hget(f"job:{job_id}", "status")
    if status is None:
        raise HTTPException(status_code=404, detail="job not found")
    return {"job_id": job_id, "status": status}
