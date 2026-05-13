global:
  resolve_timeout: 5m
  smtp_smarthost: '__SMTP_SMARTHOST__'
  smtp_from: '__SMTP_FROM__'
  smtp_auth_username: '__SMTP_AUTH_USERNAME__'
  smtp_auth_password: '__SMTP_AUTH_PASSWORD__'
  smtp_require_tls: true

route:
  receiver: email
  group_by:
    - alertname
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 24h

receivers:
  - name: email
    email_configs:
      - to: '__ALERT_EMAIL_TO__'
        send_resolved: true
        headers:
          subject: '{{ if and .CommonLabels.job .CommonLabels.host }}[monitoring] {{ .Status }} {{ .CommonLabels.alertname }} {{ .CommonLabels.job }} / {{ .CommonLabels.host }}{{ else if .CommonLabels.job }}[monitoring] {{ .Status }} {{ .CommonLabels.alertname }} {{ .CommonLabels.job }} ({{ len .Alerts }} alerts){{ else }}[monitoring] {{ .Status }} {{ .CommonLabels.alertname }} ({{ len .Alerts }} alerts){{ end }}'
