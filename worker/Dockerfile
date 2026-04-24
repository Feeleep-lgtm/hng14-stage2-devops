FROM python:3.13-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

RUN python -m venv "$VIRTUAL_ENV"

COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

RUN groupadd --system appgroup && useradd --system --gid appgroup --create-home --home-dir /home/appuser appuser

COPY --from=builder /opt/venv /opt/venv
COPY worker.py .

USER appuser

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD ["python", "-c", "import os, sys, redis; client=redis.Redis(host=os.getenv('REDIS_HOST') or os.getenv('REDIS_SERVICE_NAME') or 'localhost', port=int(os.getenv('REDIS_PORT', '6379')), password=os.getenv('REDIS_PASSWORD') or None, decode_responses=True);\ntry:\n    sys.exit(0 if client.ping() else 1)\nexcept Exception:\n    sys.exit(1)"]

CMD ["python", "worker.py"]
