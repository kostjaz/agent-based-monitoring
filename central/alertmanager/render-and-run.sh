set -eu

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\/&|]/\\&/g'
}

require_env() {
  name="$1"
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    echo "missing required environment variable: $name" >&2
    exit 1
  fi
}

for name in SMTP_SMARTHOST SMTP_FROM SMTP_AUTH_USERNAME SMTP_AUTH_PASSWORD ALERT_EMAIL_TO; do
  require_env "$name"
done

sed \
  -e "s|__SMTP_SMARTHOST__|$(escape_sed_replacement "$SMTP_SMARTHOST")|g" \
  -e "s|__SMTP_FROM__|$(escape_sed_replacement "$SMTP_FROM")|g" \
  -e "s|__SMTP_AUTH_USERNAME__|$(escape_sed_replacement "$SMTP_AUTH_USERNAME")|g" \
  -e "s|__SMTP_AUTH_PASSWORD__|$(escape_sed_replacement "$SMTP_AUTH_PASSWORD")|g" \
  -e "s|__ALERT_EMAIL_TO__|$(escape_sed_replacement "$ALERT_EMAIL_TO")|g" \
  /etc/alertmanager/alertmanager.yml.tpl > /tmp/alertmanager.yml

exec /bin/alertmanager "$@"

