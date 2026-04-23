# Deployment Runbook

Day-to-day operations for the Intellispark production deployment.

**Production host:** `intellispark.josboxoffice.com` (same box that runs dev, NPM, host Postgres, and the sibling portfolio apps).
**Container:** `intellispark-prod` (project name `intellispark-prod`).
**Image:** `ghcr.io/kingdomcoding/intellispark:<sha-or-latest>` pulled from GHCR.
**Port:** `localhost:4810` (NPM fronts TLS at `443`).
**Compose file:** `/srv/intellispark/docker-compose.prod.yml`.
**Env file:** `/srv/intellispark/.env.prod` (root:root, mode 600).

---

## Deploy

Push to `main`. That's it.

1. `git push origin main`
2. GitHub Actions `CI` workflow runs (format / compile --warnings-as-errors / `mix ash.codegen --check` / `mix test`). Green = proceed.
3. GitHub Actions `Deploy` workflow runs two jobs:
   - `build-and-push` — builds the `runtime` image target, pushes `ghcr.io/kingdomcoding/intellispark:latest` + `:<commit-sha>`.
   - `deploy` — SSHes to the host, scp's the updated `docker-compose.prod.yml`, then `docker compose pull && up -d` against the commit SHA.
4. `start.sh` in the new container runs migrations, then binds the endpoint.

**Watch the deploy:**

```sh
# Actions log — from anywhere:
gh run watch --exit-status

# Container log — on the host:
docker logs -f --tail=200 intellispark-prod
```

If the deploy fails, fix forward with a new commit. The previous container keeps serving until the new one is healthy.

## Manual deploy (Actions down)

```sh
cd /srv/intellispark
IMAGE_TAG=<sha> docker compose --env-file .env.prod -f docker-compose.prod.yml pull
IMAGE_TAG=<sha> docker compose --env-file .env.prod -f docker-compose.prod.yml up -d
```

## Tail logs

```sh
docker logs -f --tail=200 intellispark-prod
```

## SSH into the running container

```sh
docker exec -it intellispark-prod sh
```

## Run a one-off release command

Always prefer `rpc` over `eval` — `rpc` executes in the already-running BEAM, so there's no second-node port clash. `eval` starts a fresh node that would try to bind the same port.

```sh
# Run inside the live node:
docker exec intellispark-prod /app/bin/intellispark rpc 'Intellispark.Release.seed()'

# Ad-hoc expression:
docker exec intellispark-prod /app/bin/intellispark rpc 'Intellispark.Repo.aggregate(Intellispark.Accounts.User, :count)'

# Create an admin (no invitation flow):
docker exec intellispark-prod /app/bin/intellispark rpc 'Intellispark.Release.create_admin("you@example.com", "change-me-before-shipping")'
```

## Rotate a secret

Example: rotate `SECRET_KEY_BASE`.

```sh
# 1. Generate new value
NEW=$(docker run --rm elixir mix phx.gen.secret)  # or any equivalent

# 2. Edit the env file
vim /srv/intellispark/.env.prod
# update SECRET_KEY_BASE=…

# 3. Bounce the container
cd /srv/intellispark
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --force-recreate app

# 4. Verify
curl -fsS https://intellispark.josboxoffice.com/healthz
```

Rotating `SECRET_KEY_BASE` invalidates all signed sessions; active users must sign in again. Rotate when that's acceptable.

## Scale

Not supported. `network_mode: host` (inherited from the dev pattern so the container reaches host Postgres directly at `127.0.0.1:5432`) means a second replica can't bind the same port. Scaling out is an architectural change:
1. Switch to a bridge network + explicit Postgres hostname in `DATABASE_URL`.
2. Run `app` on an internal port.
3. Point NPM at the compose service (needs shared network) or use a load balancer.

Out of scope for a single-operator portfolio host.

## Connect to the DB

```sh
PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres intellispark_prod
```

Or from inside the container (no Postgres client installed):

```sh
docker exec intellispark-prod /app/bin/intellispark rpc 'Intellispark.Repo.query!("SELECT 1").rows'
```

## Reseed demo data

```sh
docker exec intellispark-prod /app/bin/intellispark rpc 'Intellispark.Release.seed()'
```

The seeds are idempotent at the district + school + user level (they check for existing rows before inserting). The Phase 14 resiliency assessment is also re-idempotent (skipped if Ava already has a submitted assessment).

## Manual DB backup

```sh
# Dump
pg_dump -h 127.0.0.1 -U postgres intellispark_prod > /var/backups/intellispark-$(date +%Y-%m-%d).sql

# Restore (destructive — wipes current state)
docker stop intellispark-prod
PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres -c "DROP DATABASE intellispark_prod"
PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE intellispark_prod OWNER postgres"
PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres intellispark_prod < /var/backups/intellispark-<date>.sql
docker start intellispark-prod
```

Host Postgres is shared with sibling apps; whatever backup policy covers them (daily cron `pg_dump` or filesystem snapshot) covers Intellispark too.

## Check prod health

```sh
# Local (from the host):
curl -fsS http://127.0.0.1:4810/healthz

# Public:
curl -fsS https://intellispark.josboxoffice.com/healthz

# Detailed container state:
docker ps --filter name=intellispark-prod --format '{{.Names}} {{.Status}}'
```

The `/healthz` endpoint runs `SELECT 1` against the repo and returns `ok` on success. Docker `HEALTHCHECK` polls it every 30 s; three consecutive failures mark the container unhealthy.

## LiveDashboard (metrics)

`https://intellispark.josboxoffice.com/admin/dashboard` — requires a signed-in district admin. Shows BEAM memory, Ecto pool, Phoenix LiveView socket counts, request timings, and custom metrics from `IntellisparkWeb.Telemetry`.

## UptimeRobot

External uptime checks:

- `GET https://intellispark.josboxoffice.com/healthz` — expect 200, 5-minute interval.
- `GET https://intellispark.josboxoffice.com/` — expect 200, 5-minute interval.

Alert channel: email. Configure new monitors at https://uptimerobot.com.
