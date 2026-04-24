#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
ROLLING_DEPLOY_SCRIPT="$ROOT_DIR/scripts/rolling-deploy.sh"

wait_for_health() {
  local container_name="$1"
  local timeout_seconds="${2:-60}"
  local deadline=$((SECONDS + timeout_seconds))
  local status

  while (( SECONDS < deadline )); do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_name")"
    if [[ "$status" == "healthy" ]]; then
      return 0
    fi
    sleep 2
  done

  docker logs "$container_name"
  return 1
}

create_network_if_missing() {
  if ! docker network inspect "$STACK_NETWORK_NAME" >/dev/null 2>&1; then
    docker network create --internal "$STACK_NETWORK_NAME"
  fi
}

ensure_redis() {
  if docker container inspect redis >/dev/null 2>&1; then
    if wait_for_health redis 60; then
      return 0
    fi
    docker rm -f redis
  fi

  docker run -d \
    --name redis \
    --network "$STACK_NETWORK_NAME" \
    --env-file "$ENV_FILE" \
    --env "REDIS_PASSWORD=$REDIS_PASSWORD" \
    --health-cmd='redis-cli -a "$REDIS_PASSWORD" ping | grep -q PONG' \
    --health-interval="${HEALTH_CHECK_INTERVAL}s" \
    --health-timeout="${HEALTH_CHECK_TIMEOUT}s" \
    --health-retries="$HEALTH_CHECK_RETRIES" \
    --health-start-period="${REDIS_HEALTH_START_PERIOD}s" \
    "$REDIS_IMAGE" \
    sh -c 'redis-server --appendonly yes --requirepass "$REDIS_PASSWORD"'

  wait_for_health redis 60
}

source "$ENV_FILE"

: "${API_IMAGE:?API_IMAGE must be set}"
: "${WORKER_IMAGE:?WORKER_IMAGE must be set}"
: "${FRONTEND_IMAGE:?FRONTEND_IMAGE must be set}"

create_network_if_missing
ensure_redis

"$ROLLING_DEPLOY_SCRIPT" api "$API_IMAGE" "$STACK_NETWORK_NAME" "$ENV_FILE" \
  "REDIS_HOST=$REDIS_SERVICE_NAME" \
  "REDIS_PORT=$REDIS_PORT" \
  "REDIS_PASSWORD=$REDIS_PASSWORD" \
  "REDIS_QUEUE_NAME=$REDIS_QUEUE_NAME" \
  "API_HOST=$API_HOST" \
  "API_PORT=$API_PORT"

"$ROLLING_DEPLOY_SCRIPT" worker "$WORKER_IMAGE" "$STACK_NETWORK_NAME" "$ENV_FILE" \
  "REDIS_HOST=$REDIS_SERVICE_NAME" \
  "REDIS_PORT=$REDIS_PORT" \
  "REDIS_PASSWORD=$REDIS_PASSWORD" \
  "REDIS_QUEUE_NAME=$REDIS_QUEUE_NAME"

"$ROLLING_DEPLOY_SCRIPT" frontend "$FRONTEND_IMAGE" "$STACK_NETWORK_NAME" "$ENV_FILE" \
  "FRONTEND_PORT=$FRONTEND_PORT" \
  "API_PORT=$API_PORT" \
  "API_SERVICE_NAME=$API_SERVICE_NAME" \
  "API_URL=http://$API_SERVICE_NAME:$API_PORT" \
  "API_TIMEOUT=$API_TIMEOUT"
