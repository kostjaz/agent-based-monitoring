set -eu

if [ -z "${HOST_LABEL:-}" ]; then
  echo "missing required environment variable: HOST_LABEL" >&2
  exit 1
fi

REGION_LABEL="${REGION_LABEL:-default}"

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\/&|]/\\&/g'
}

escaped_host_label="$(escape_sed_replacement "$HOST_LABEL")"
escaped_region_label="$(escape_sed_replacement "$REGION_LABEL")"

sed \
  -e "s|__HOST_LABEL__|$escaped_host_label|g" \
  -e "s|__REGION_LABEL__|$escaped_region_label|g" \
  /etc/vmagent/prometheus.yml.tpl > /tmp/vmagent-prometheus.yml

exec /vmagent-prod "$@"
