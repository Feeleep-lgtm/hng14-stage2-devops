FROM python:3.13-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

RUN python -m venv "$VIRTUAL_ENV"

COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

FROM python:3.13-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

RUN groupadd --system appgroup && useradd --system --gid appgroup --create-home --home-dir /home/appuser appuser

COPY --from=builder /opt/venv /opt/venv
COPY main.py .

USER appuser

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD ["python", "-c", "import os, sys, urllib.request; port=os.getenv('API_PORT', '8000'); url=f'http://127.0.0.1:{port}/health';\ntry:\n    with urllib.request.urlopen(url, timeout=3) as response:\n        sys.exit(0 if response.status == 200 else 1)\nexcept Exception:\n    sys.exit(1)"]

CMD ["sh", "-c", "uvicorn main:app --host \"${API_HOST:-0.0.0.0}\" --port \"${API_PORT:-8000}\""]
