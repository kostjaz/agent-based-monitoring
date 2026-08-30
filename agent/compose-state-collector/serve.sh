#!/bin/sh
set -eu

while IFS= read -r header; do
  [ "$header" = "$(printf '\r')" ] && break
done

metrics_file=/var/lib/compose-state-collector/metrics
content_length="$(wc -c < "$metrics_file" | tr -d ' ')"

printf 'HTTP/1.1 200 OK\r\n'
printf 'Content-Type: text/plain; version=0.0.4; charset=utf-8\r\n'
printf 'Content-Length: %s\r\n' "$content_length"
printf 'Connection: close\r\n'
printf '\r\n'
cat "$metrics_file"
