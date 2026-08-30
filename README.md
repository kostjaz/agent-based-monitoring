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

- `REGION_LABEL`: office label, for example `MIAC_Saratov`, `ENC_Moscow`, or `dc-1`. This is exposed as `job`, so the Node Exporter Full dashboard can use `Job` as the office selector.
- `HOST_LABEL`: server label inside the office, for example `voice-dc` or `medvox01`. This value is exposed as `host`, `instance`, and `node_uname_info.nodename`, so the Node Exporter Full dashboard shows the same server name in `Nodename` and `Instance`.
- `REMOTE_WRITE_URL`: `https://monitor.example.com/api/v1/write`.
- `REMOTE_WRITE_USERNAME` and `REMOTE_WRITE_PASSWORD`: credentials matching the Caddy basic auth configuration.

Start the agent:

```bash
docker compose up -d
```

For the NLU host with an NVIDIA GPU, layer the host-specific Compose file on
top of the base agent configuration:

```bash
docker compose -f docker-compose.yml -f docker-compose.nlu.yml up -d
```

This starts `nvidia_gpu_exporter` with access to all NVIDIA GPUs and switches
vmagent to the NLU scrape configuration. The exporter remains internal to the
Compose network; no GPU metrics port is published on the host. The NVIDIA
driver and NVIDIA Container Toolkit must already be installed and configured
for Docker.

Verify metrics in Grafana Explore on the central host:

```promql
up{host!="",instance!~".+-vmagent"}
node_uname_info
nvidia_smi_gpu_info
nvidia_smi_utilization_gpu_ratio
nvidia_smi_memory_used_bytes
```

Grafana provisions the upstream `Nvidia GPU Metrics` dashboard (Grafana
dashboard ID `14574`) from the local dashboard JSON. Use its `job`, `host`, and
`GPU` selectors to inspect utilization, VRAM, temperature, power, clocks, and
throttling.

### Container Monitoring

To monitor the desired running state of containers, layer the container
monitoring Compose file on top of the base agent configuration:

```bash
docker compose -f docker-compose.yml -f docker-compose.containers.yml up -d
```

Set `COMPOSE_PROJECT_DIRECTORY` to monitor every service declared by that
Compose project. A service reports as down even when its container was never
created or has been removed. The default directory is `/opt/s2snext`.

Additional containers can be monitored explicitly, including containers that
do not belong to that Compose project:

```dotenv
COMPOSE_PROJECT_DIRECTORY=/opt/s2snext
MONITORED_CONTAINER_NAMES=engine,task-loader,postgres,freeswitch
```

Both modes can be enabled at the same time. `MONITORED_CONTAINER_NAMES` accepts
comma-separated or space-separated exact Docker container names.

## Included Alerts

- missing host metrics;
- high CPU usage;
- high memory usage;
- low filesystem free space;
- high load average;
- local node_exporter scrape failures from vmagent's point of view.
- missing or stale NVIDIA GPU metrics;
- NVIDIA GPU collection failures;
- high GPU temperature and thermal throttling;
- GPU recovery actions reported by the NVIDIA driver.
- stopped, missing, or not-yet-created expected containers;
- container desired-state collector failures.

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
