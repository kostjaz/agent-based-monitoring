#!/bin/sh
set -eu

metrics_dir=/var/lib/compose-state-collector
metrics_file="$metrics_dir/metrics"
interval="${COLLECTION_INTERVAL:-15}"

escape_label() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

write_metric() {
  source="$1"
  target="$2"
  running="$3"

  printf 's2snext_container_running{source="%s",target="%s"} %s\n' \
    "$(escape_label "$source")" \
    "$(escape_label "$target")" \
    "$running"
}

collect() {
  output="$metrics_file.tmp"
  success=1

  {
    echo '# HELP s2snext_container_running Whether an expected Docker Compose service or explicitly named container is running.'
    echo '# TYPE s2snext_container_running gauge'

    if [ -n "${COMPOSE_PROJECT_DIRECTORY:-}" ]; then
      if services="$(docker compose \
        --project-directory "$COMPOSE_PROJECT_DIRECTORY" \
        -f "$COMPOSE_PROJECT_DIRECTORY/docker-compose.yml" \
        config --services 2>/dev/null)"; then
        running_services="$(docker ps \
          --filter status=running \
          --filter "label=com.docker.compose.project.working_dir=$COMPOSE_PROJECT_DIRECTORY" \
          --format '{{.Label "com.docker.compose.service"}}')"

        for service in $services; do
          if printf '%s\n' "$running_services" | grep -Fqx "$service"; then
            write_metric compose "$service" 1
          else
            write_metric compose "$service" 0
          fi
        done
      else
        success=0
      fi
    fi

    explicit_names="$(printf '%s' "${MONITORED_CONTAINER_NAMES:-}" | tr ',' ' ')"
    for container_name in $explicit_names; do
      if [ "$(docker inspect --format '{{.State.Running}}' "$container_name" 2>/dev/null || true)" = true ]; then
        write_metric explicit "$container_name" 1
      else
        write_metric explicit "$container_name" 0
      fi
    done

    echo '# HELP s2snext_container_collector_success Whether the last collector run completed successfully.'
    echo '# TYPE s2snext_container_collector_success gauge'
    printf 's2snext_container_collector_success %s\n' "$success"
    echo '# HELP s2snext_container_collector_timestamp_seconds Unix timestamp of the last collector run.'
    echo '# TYPE s2snext_container_collector_timestamp_seconds gauge'
    printf 's2snext_container_collector_timestamp_seconds %s\n' "$(date +%s)"
  } > "$output"

  mv "$output" "$metrics_file"
}

mkdir -p "$metrics_dir"
collect

busybox nc -lk -p 9418 -e /opt/compose-state-collector/serve.sh &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT INT TERM

while kill -0 "$server_pid" 2>/dev/null; do
  sleep "$interval" &
  wait $!
  collect
done
