# ADR 024: Phase 18 — Deployment, CI/CD & Infrastructure

**Status:** Accepted
**Date:** 2026-04-23
**Builds on:** ADR 001 (Authentication + multitenancy — reuses `:require_district_admin` for `/admin/dashboard`), ADR 021 (Cloak vault — `CLOAK_KEY` is now a prod secret).

## Context

Until Phase 18, Intellispark ran only in `dev` via `docker compose` on the portfolio host. To ship a live demo at `intellispark.josboxoffice.com` and make future changes routine, the project needs a production deployment, a CI pipeline, a CD pipeline, a runbook, and some baseline monitoring — without over-engineering for a single-operator host.

## Decisions

### 1. Self-host on the portfolio's existing server, not a PaaS

The same box that runs dev runs prod. It already hosts Nginx Proxy Manager, shared host Postgres, and several sibling portfolio apps. Deploying Intellispark elsewhere (Fly.io / Render / Railway) would duplicate infrastructure that already works here and hide deploy-relevant surface area (deploy keys, image registries, compose files, reverse-proxy routing) that a hiring reviewer notices.

### 2. GitHub Actions as CI/CD orchestrator

Repo lives on GitHub; Actions is free for public repos and generous for private. One YAML file per pipeline, no third-party account to manage. CircleCI / Jenkins / Buildkite would add accounts without giving anything back at this scale.

### 3. GitHub Container Registry (GHCR) for immutable tagged images

Same account as the repo, same auth as CI. Alternative — building the image on the server on every deploy — is slower, less diagnosable, and couples the build step to the deploy target. GHCR gives us immutable `:latest` and `:<commit-sha>` tags the server just pulls.

### 4. Deploy via SSH from GitHub Actions using a deploy key

Standard pattern: dedicated SSH keypair, public key in `~deploy/.ssh/authorized_keys`, private key in a `DEPLOY_SSH_KEY` repo secret, `shimataro/ssh-key-action` installs it, a small idempotent script runs on the host. Alternative considered: webhook receiver on the server. Rejected — more moving parts than an SSH action.

### 5. `docker-compose.prod.yml` committed to the repo as IaC

Prod topology is documented in-tree. Reviewing the compose file tells the reader exactly how the app is deployed — which image, which ports, which env file, which network mode. Dev `docker-compose.yml` stays unchanged.

### 6. `mix ash.codegen --check` is the drift gate in CI

Ash generates migrations from resource changes. A developer who edits a resource attribute and forgets to run codegen ships a migration-less branch. `mix ash.codegen --check` runs codegen in dry-run mode and fails CI if the generated migration differs from committed migrations. Catches the single most common Ash-specific deploy bug.

### 7. Auto-deploy on main only

`CI` fires on all pushes + PRs. Only pushes to `main` trigger `Deploy` (build-and-push → deploy). Feature branches run CI but don't deploy.

### 8. Migrations run on container start via `start.sh`, not in CI

New file at `rel/overlays/bin/start.sh` chains `Intellispark.Release.migrate/0` → `bin/intellispark start`. Migrations run inside the release, on the target machine, with the right `DATABASE_URL`. A bad migration exits the new container; `restart: unless-stopped` keeps retrying and the previous (still-healthy) container continues serving until the fix-forward commit lands. Splitting migrate and endpoint start into two log-distinguishable phases makes migration errors obvious in `docker logs`.

### 9. Secrets live in a root-owned `.env.prod` file on the host

Path: `/srv/intellispark/.env.prod`, mode `600`, owner `root`. The prod compose file loads it via `env_file:`. Secrets never enter the repo, never enter GitHub Actions config, never appear in `docker inspect` for non-root users. Runtime config (`config/runtime.exs`) validates all five required keys (`DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `CLOAK_KEY`, `TOKEN_SIGNING_SECRET`) at boot — missing keys raise with a pointer to the env file path, so failures land in the first 5 seconds of a deploy rather than at first request.

### 10. Nginx Proxy Manager (already running) terminates TLS + routes the domain

NPM at `npm-app-1` on the host already serves 80/81/443 and handles Let's Encrypt auto-cert for sibling apps. Adding Intellispark is a 2-minute GUI task: proxy host for `intellispark.josboxoffice.com` → target `127.0.0.1:4810` → toggle SSL → save. No app-side TLS config needed.

## Cross-reference: non-goals

Phase 18 deliberately skips:
- No rollback procedure or tooling. Deploys fail forward with a corrective commit (~4 minute cycle).
- No AshAdmin prod hardening. The existing `:require_district_admin` guard (Phase 14) is sufficient for this scale.
- No staging environment, no blue/green, no canary, no multi-host replication. Single host, rolling replacement.
- No hosted error tracking (Sentry / Honeybadger / Rollbar). `docker logs` + UptimeRobot cover it at demo scale.

See `markdowns/phase-18-deployment-cicd-infrastructure.md` for the full rationale + the detailed runbook at `docs/operations/deployment-runbook.md`.
