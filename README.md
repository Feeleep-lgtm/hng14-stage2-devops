# hng14-stage2-devops

This project contains a small job-processing stack made up of:

- `frontend`: Node/Express UI and API proxy
- `api`: FastAPI job submission and status service
- `worker`: Redis-backed job processor
- `redis`: queue and job-status store

## Prerequisites

Install the following on a clean machine before starting:

- Docker Engine 24+ with the Docker Compose plugin
- Git

Optional but helpful for manual verification:

- `curl`
- A web browser

## Getting Started From Scratch

1. Clone the repository:

```bash
git clone <your-repo-url>
cd hng14-stage2-devops
```

2. Create your runtime environment file from the committed example:

```bash
cp .env.example .env
```

3. Edit `.env` and set at least these values for your machine:

- `REDIS_PASSWORD`
- `API_IMAGE`
- `WORKER_IMAGE`
- `FRONTEND_IMAGE`
- Any port, CPU, or memory values you want to override

For local development, these image values are already safe defaults:

- `API_IMAGE=hng14/api:local`
- `WORKER_IMAGE=hng14/worker:local`
- `FRONTEND_IMAGE=hng14/frontend:local`

4. Build and start the full stack:

```bash
docker compose --env-file .env up --build -d
```

5. Check that all services are healthy:

```bash
docker compose --env-file .env ps
```

## What Successful Startup Looks Like

When startup succeeds:

- `redis`, `api`, `worker`, and `frontend` all appear in `docker compose ps`
- The `STATE` or health column shows `healthy` for services with health checks
- Redis is running only on the internal Docker network and is not published to the host
- The frontend is reachable on `http://localhost:5000`
- The API is reachable on `http://localhost:8000/health`

You can verify manually with:

```bash
curl http://localhost:8000/health
curl http://localhost:5000/health
curl -X POST http://localhost:5000/submit
```

The expected API health response is:

```json
{"status":"ok"}
```

The expected frontend health response is:

```json
{"status":"ok"}
```

A successful job submission returns JSON with a generated `job_id` and queued status:

```json
{"job_id":"<uuid>","status":"queued"}
```

Polling the job through the frontend should eventually return:

```json
{"job_id":"<same-uuid>","status":"completed"}
```

Example poll command:

```bash
curl http://localhost:5000/status/<job_id>
```

## Common Commands

Start the stack:

```bash
docker compose --env-file .env up --build -d
```

View logs:

```bash
docker compose --env-file .env logs -f
```

Stop the stack:

```bash
docker compose --env-file .env down
```

Stop the stack and remove named volumes:

```bash
docker compose --env-file .env down -v
```

Rebuild a single service:

```bash
docker compose --env-file .env build api
docker compose --env-file .env up -d api
```

## CI/CD Pipeline

The GitHub Actions workflow runs these stages in strict order:

1. `lint`
2. `test`
3. `build`
4. `security scan`
5. `integration test`
6. `deploy`

Deploy runs only for pushes to `main`. Any failure blocks all later stages.

## Repository Documentation

- `README.md`: clean-machine startup and operational guide
- `FIXES.md`: every issue found, including file, original line reference, problem, and fix
- `.env.example`: placeholder values for all required runtime and pipeline variables
