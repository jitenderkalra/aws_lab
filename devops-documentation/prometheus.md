# Prometheus

Prometheus provides metrics scraping and alerting. Run it with proper retention, storage, and security.

## Deployment
- Use the Prometheus Operator/ kube-prometheus-stack (Helm) for CRDs (Prometheus, Alertmanager, ServiceMonitor, PodMonitor).
- Size retention and storage: set `--storage.tsdb.retention.time` and PVC sizes; use persistent volumes.
- Isolate by namespace; restrict ingress; enable TLS/auth if exposed.

## Scrape configuration
- Prefer ServiceMonitor/PodMonitor CRDs with label selectors over manual scrape configs.
- For standalone Prometheus, configure `prometheus.yml` scrape jobs per target.
```yaml
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

## Alerts
- Define alerting rules in separate files; route to Alertmanager.
- Use labels for routing (severity, team, env).
```yaml
groups:
  - name: uptime
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.instance }} down"
```

## Service discovery and relabeling
- Use K8s service discovery with relabeling to filter targets by namespace/labels.
- Drop high-cardinality labels; keep label sets stable across environments.

## Performance and Storage
- Use remote_write for long-term storage (e.g., Thanos/Cortex/Mimir).
- Tune scrape intervals/timeouts; avoid scraping high-cardinality endpoints frequently.
- Monitor Prometheus itself: CPU/mem, disk I/O, TSDB head block size, target counts.

## Security
- Restrict access (mTLS/reverse proxy); do not expose Prometheus UI unauthenticated.
- Limit remote_write exposure; use network policies.
- Do not scrape endpoints that expose secrets.

## Tooling
- Use `promtool` to lint rules and check configs: `promtool check rules rules.yml`.
- Grafana for dashboards; Alertmanager for routing; exporters (node_exporter, kube-state-metrics, cadvisor) for common metrics.
