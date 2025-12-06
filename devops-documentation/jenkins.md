# Jenkins Standards

## Architecture
- Controller + agents; avoid running builds on controller. Use labels for workload isolation.
- Back up `$JENKINS_HOME` (configs, jobs, credentials) regularly; test restores.
- Keep minimal plugins; track versions; pin critical ones.

## Security
- Enforce RBAC with folders; no shared admin accounts; enable 2FA/SSO if available.
- Use credential store with scoped IDs; rotate keys; prefer cloud identities/IRSA/OIDC over static keys.
- Disable CLI where possible; restrict script console to admins; audit logs enabled.

## Pipelines
- Use `Jenkinsfile` in-repo; declarative preferred. Keep steps idempotent.
- Shared libraries for common stages (build/test/publish/deploy); versioned.
- Timeouts on stages; retry only safe steps (e.g., fetch). Fail fast on secrets missing.
- Use lightweight checkout; avoid global environment leakage between stages.

## Agents and Tooling
- Agents run as non-root; mount least-privileged credentials.
- Cache dependencies carefully; clean workspaces on success/failure to avoid disk bloat.
- Monitor disk/CPU/RAM; set executor counts conservatively (controller often 0).

## Notifications and Observability
- Notify on failed/unstable builds with actionable links.
- Export build metrics/logs to centralized logging/monitoring (Prometheus plugin or JMX exporter).
- Periodic job cleanup; discard old builds/artifacts to control disk usage.
