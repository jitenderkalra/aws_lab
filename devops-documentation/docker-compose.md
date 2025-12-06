# Docker Compose

Compose is for local dev and small multi-container stacks. Not a replacement for production orchestration.

## Basics
- Define services, networks, and volumes in `docker-compose.yml`.
- Use `.env` for config; avoid secrets in git.
- Keep versioned images; avoid `latest` in shared environments.

### Example compose file
```yaml
version: "3.9"
services:
  web:
    build: ./app
    ports:
      - "8080:8080"
    environment:
      - APP_ENV=local
    depends_on:
      - db
  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=app
      - POSTGRES_PASSWORD=change_me
      - POSTGRES_DB=appdb
    volumes:
      - db_data:/var/lib/postgresql/data
volumes:
  db_data:
```

## Commands
```
docker compose up -d         # start
docker compose logs -f web   # tail logs
docker compose ps            # list services
docker compose down          # stop/remove
docker compose down -v       # remove volumes too
docker compose build         # rebuild images
```

## Good practices
- Use named volumes for data; avoid bind mounts in shared envs.
- Keep env-specific overrides in `docker-compose.override.yml`.
- Resource limits for shared hosts:
```yaml
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

## When to move to K8s
- Need autoscaling, rolling deploys, secrets management, service discovery, ingress, or multi-host HA. Use Helm/K8s instead.
