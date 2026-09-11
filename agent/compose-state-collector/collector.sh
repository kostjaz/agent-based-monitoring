#!/bin/sh
set -eu

metrics_dir=/var/lib/compose-state-collector
metrics_file="$metrics_dir/metrics"
interval="${COLLECTION_INTERVAL:-15}"

escape_label() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

write_metric() {
  target="$1"
  running="$2"

  printf 's2snext_container_running{source="compose-label",target="%s"} %s\n' \
    "$(escape_label "$target")" \
    "$running"
}

collect() {
  output="$metrics_file.tmp"
  success=1

  {
    echo '# HELP s2snext_container_running Whether an expected Docker Compose service or explicitly named container is running.'
    echo '# TYPE s2snext_container_running gauge'

    if config="$(docker compose \
        --project-directory "$COMPOSE_PROJECT_DIRECTORY" \
        -f "$COMPOSE_PROJECT_DIRECTORY/docker-compose.yml" \
        config --format json 2>/dev/null)"; then
        services="$(printf '%s' "$config" | jq -r '
          .services
          | to_entries[]
          | select((.value.labels // {})["com.s2snext.monitoring.expected-running"] == "true")
          | .key
        ')"
        running_services="$(docker ps \
          --filter status=running \
          --filter "label=com.docker.compose.project.working_dir=$COMPOSE_PROJECT_DIRECTORY" \
          --format '{{.Label "com.docker.compose.service"}}')"

        for service in $services; do
          if printf '%s\n' "$running_services" | grep -Fqx "$service"; then
            write_metric "$service" 1
          else
            write_metric "$service" 0
          fi
        done
    else
      success=0
    fi

    echo '# HELP s2snext_container_collector_success Whether the last collector run completed successfully.'
    echo '# TYPE s2snext_container_collector_success gauge'
    printf 's2snext_container_collector_success{mode="compose-label"} %s\n' "$success"
    echo '# HELP s2snext_container_collector_timestamp_seconds Unix timestamp of the last collector run.'
    echo '# TYPE s2snext_container_collector_timestamp_seconds gauge'
    printf 's2snext_container_collector_timestamp_seconds{mode="compose-label"} %s\n' "$(date +%s)"
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
