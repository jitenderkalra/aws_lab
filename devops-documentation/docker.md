# Docker

Build, tag, and ship images securely and reproducibly.

## Dockerfile best practices
- Use minimal base images; pin versions (e.g., `alpine:3.19`).
- Multi-stage builds to keep runtime images small.
- Non-root user in final stage.
- Set `WORKDIR`, `ENV`, `EXPOSE`, and health checks where applicable.
- Avoid copying secrets; use `.dockerignore`.

### Example Dockerfile (multi-stage Go app)
```Dockerfile
FROM golang:1.21 AS builder
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/hello .

FROM alpine:3.19
RUN adduser -D appuser
COPY --from=builder /out/hello /usr/local/bin/hello
USER appuser
EXPOSE 8081
ENTRYPOINT ["/usr/local/bin/hello"]
```
*Why:* multi-stage drops build deps; `appuser` avoids root; explicit port/entrypoint.

## Image tagging and pushing
```
docker build -t myapp:1.0.0 .
docker tag myapp:1.0.0 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:1.0.0
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:1.0.0
```

## Security and hygiene
- Scan images (Trivy/grype); fail builds on critical vulns.
- Drop capabilities; set read-only root filesystem where possible.
- Keep images small; avoid caching secrets in layers.
- Clean up local artifacts: `docker system prune -af`.

## Runtime
- Prefer compose/Kubernetes for orchestration.
- Use resource limits (`--memory`, `--cpus`) when running standalone.
- Log to stdout/err; avoid writing to container FS when possible.
