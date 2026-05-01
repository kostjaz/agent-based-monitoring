set -eu

if [ -z "${HOST_LABEL:-}" ]; then
  echo "missing required environment variable: HOST_LABEL" >&2
  exit 1
fi

escaped_host_label="$(printf '%s' "$HOST_LABEL" | sed 's/[\/&|]/\\&/g')"
sed "s|__HOST_LABEL__|$escaped_host_label|g" \
  /etc/vmagent/prometheus.yml.tpl > /tmp/vmagent-prometheus.yml

exec /vmagent-prod "$@"
