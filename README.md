# Monitoring Stack

A minimal monitoring setup for environments where remote hosts cannot expose inbound ports.

## Architecture

Central monitoring host:

- Caddy: HTTPS termination and basic auth for incoming `remote_write` traffic.
- Prometheus: receives metrics through `remote_write`, stores time series data, and evaluates alert rules.
- Alertmanager: sends alerts by email.
- Grafana: reads metrics from Prometheus.

Remote host:

- node_exporter: collects local operating system metrics.
- vmagent: scrapes node_exporter locally and sends metrics to the central Prometheus over HTTPS.

This is not classic Prometheus pull over the network. If inbound ports are closed on remote hosts, a central Prometheus cannot scrape them directly. The pull model remains local on each host, and transport to the central host is outbound-only through `remote_write`.

## Quick Start

### 1. Central Host

```bash
cd central
cp .env.example .env
```

Edit `central/.env`:

- `MONITOR_DOMAIN`: public DNS name for the monitoring host, for example `monitor.example.com`.
- `ACME_EMAIL`: email address for Let's Encrypt.
- `REMOTE_WRITE_USERNAME` and `REMOTE_WRITE_PASSWORD_HASH`: username and bcrypt password hash for agents.
- SMTP settings for Alertmanager.
- `GRAFANA_ADMIN_PASSWORD`.

Generate a Caddy password hash:

```bash
docker run --rm caddy:2 caddy hash-password --plaintext 'change-me'
```

Keep the bcrypt hash in single quotes in `.env`, because bcrypt hashes contain `$` characters.

Start the stack:

```bash
docker compose up -d
```

Check the deployment:

```bash
docker compose ps
curl -u agent:password https://monitor.example.com/-/healthy
```

Interfaces:

- Grafana: `https://monitor.example.com/`
- Alertmanager: `https://monitor.example.com/alertmanager/`
- Prometheus: `https://monitor.example.com/prometheus/`

Prometheus and Alertmanager are protected by Caddy basic auth. Grafana uses its own login.

### 2. Remote Host

```bash
cd agent
cp .env.example .env
```

Edit `agent/.env`:

- `HOST_LABEL`: stable host name, for example `prod-db-01`.
- `REMOTE_WRITE_URL`: `https://monitor.example.com/api/v1/write`.
- `REMOTE_WRITE_USERNAME` and `REMOTE_WRITE_PASSWORD`: credentials matching the Caddy basic auth configuration.

Start the agent:

```bash
docker compose up -d
```

Verify metrics in Grafana Explore on the central host:

```promql
up{job="node"}
node_uname_info
```

## Included Alerts

- missing host metrics;
- high CPU usage;
- high memory usage;
- low filesystem free space;
- high load average;
- local node_exporter scrape failures from vmagent's point of view.

Email routing is configured in `central/alertmanager/alertmanager.yml.tpl`. Alert rules are configured in `central/prometheus/rules/host-alerts.yml`.

## Security

- Agent-to-central traffic is protected by HTTPS through Caddy.
- Writes to Prometheus are protected with basic auth.
- Remote hosts do not need inbound ports exposed.
- Grafana, Prometheus, and Alertmanager are routed through Caddy. Grafana uses its own login, while Prometheus and Alertmanager are protected by the same Caddy basic auth.

For production, it is still better to restrict access to the monitoring host with a VPN or firewall allowlist when possible.

## Public Repository Notes

The repository is safe to publish as long as real credentials are not committed.

- Keep only `.env.example` files in git.
- Keep real `.env` files untracked.
- Store deployment credentials in GitHub Actions Secrets or another secrets manager.
- Do not put SMTP passwords, Grafana passwords, Caddy hashes, or agent passwords directly into workflow YAML files.
