# Grafana

Grafana provides dashboards, alerting, and data source integrations. Use it with proper access control and backups.

## Deployment
- Use official Helm chart or Grafana Operator; set admin password via secret.
- Persist data via PVCs (or use database backends like MySQL/Postgres).
- Restrict ingress; enable TLS/SSO if available (OAuth/SAML).

## Configuration
- Provision data sources and dashboards as code (`provisioning/`).
- Use folders and permissions to separate teams/environments.
- Configure alerting (Grafana Alerting) with contact points (Slack/Email/PagerDuty).
- Enable backups of config/dashboards if not fully provisioned-as-code.

## Common data sources
- Prometheus, Loki, Tempo, Elasticsearch, CloudWatch, PostgreSQL/MySQL.
- For Prometheus: set scrape interval/timeout in the data source; enable exemplar/OTLP if using traces.

## Dashboards as code
- Place JSON in `provisioning/dashboards/`; reference via providers.
```yaml
# provisioning/dashboards/dashboard.yml
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: 'Platform'
    type: file
    options:
      path: /var/lib/grafana/dashboards
```

## Security
- Enforce org roles; avoid shared admin accounts; prefer SSO.
- Disable anonymous access unless strictly required.
- Keep secrets in Kubernetes Secrets/HashiCorp Vault; mount via env vars.

## Operations
- Monitor Grafana itself (HTTP 200s, latency, panel errors).
- Prune unused data sources/dashboards; keep version control of provisioned assets.
- Upgrade chart regularly; pin versions; test in non-prod first.
