#!/usr/bin/env bash
set -euo pipefail

if (( $# < 4 )); then
  echo "usage: $0 <service-name> <image> <network> <env-file> [KEY=VALUE ...]"
  exit 1
fi

SERVICE_NAME="$1"
IMAGE_NAME="$2"
NETWORK_NAME="$3"
ENV_FILE="$4"
shift 4

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

CANDIDATE_NAME="${SERVICE_NAME}-candidate-${RANDOM}"

run_args=(
  docker run -d
  --name "$CANDIDATE_NAME"
  --network "$NETWORK_NAME"
  --env-file "$ENV_FILE"
)

for env_var in "$@"; do
  run_args+=(--env "$env_var")
done

run_args+=("$IMAGE_NAME")

"${run_args[@]}"

if ! wait_for_health "$CANDIDATE_NAME" 60; then
  docker rm -f "$CANDIDATE_NAME"
  echo "Candidate for ${SERVICE_NAME} failed health checks; leaving current container untouched"
  exit 1
fi

if docker container inspect "$SERVICE_NAME" >/dev/null 2>&1; then
  docker stop "$SERVICE_NAME"
  docker rm "$SERVICE_NAME"
fi

docker rename "$CANDIDATE_NAME" "$SERVICE_NAME"
