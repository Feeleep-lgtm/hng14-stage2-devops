#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
ENV_FILE="$ROOT_DIR/.env"
TIMEOUT_SECONDS="${INTEGRATION_TIMEOUT_SECONDS:-60}"

cleanup() {
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down -v --remove-orphans
}

wait_for_health() {
  local container_id="$1"
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  local status

  while (( SECONDS < deadline )); do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")"
    if [[ "$status" == "healthy" ]]; then
      return 0
    fi
    sleep 2
  done

  docker logs "$container_id"
  return 1
}

trap cleanup EXIT

docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

wait_for_health "$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q redis)"
wait_for_health "$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q api)"
wait_for_health "$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q frontend)"
wait_for_health "$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q worker)"

job_id="$(
  timeout "$TIMEOUT_SECONDS" curl --fail --silent --show-error -X POST "http://127.0.0.1:${FRONTEND_PORT}/submit" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["job_id"])'
)"

deadline=$((SECONDS + TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
  status="$(
    timeout "$TIMEOUT_SECONDS" curl --fail --silent --show-error "http://127.0.0.1:${FRONTEND_PORT}/status/${job_id}" |
      python3 -c 'import json, sys; print(json.load(sys.stdin)["status"])'
  )"

  if [[ "$status" == "completed" ]]; then
    exit 0
  fi

  sleep 2
done

echo "Job ${job_id} did not complete successfully"
exit 1
