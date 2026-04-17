# Intellispark

A faithful Phoenix/LiveView/Ash recreation of the Intellispark K-12 student-support platform.

This repository contains **Phase 0** — the technical and visual foundation that every later phase builds on. See `../phase-0-implementation.md` for the plan and the master checklist.

## What Phase 0 delivers

- Phoenix 1.8 + LiveView + Ash 3.24 ecosystem wired end-to-end
- Nine empty Ash domains (Accounts, Students, Support, Recognition, Assessments, Indicators, Teams, Integrations, Automations) — ready for Phase 1+ resources
- Full Intellispark design system in Tailwind v4 (colors, typography, spacing, components)
- Core component library: Button, Card, Chip primitives, Modal, Avatar, Empty state, Status badges, Level indicators, Count badges
- `/styleguide` LiveView rendering every component for visual QA
- Unified Docker workflow (one `Dockerfile`, one `docker-compose.yml`) usable for both dev and prod via `APP_TARGET`
- Policy audit test that fails CI if a future resource ships without policies (FERPA posture)
- Ready for NPM-proxy-based production deployment

## Quickstart (local dev)

```bash
cp .env.example .env
docker compose up -d --build --wait
docker compose exec app mix ash.setup
```

Then open:
- <http://localhost:4000> — placeholder landing page
- <http://localhost:4000/styleguide> — every design primitive
- <http://localhost:4000/dev/mailbox> — Swoosh local mailbox preview

Edit source on the host; the `.:/app` mount + `inotify-tools` in the dev image propagate changes immediately via Phoenix LiveReload.

## Running the app natively (without Docker)

If you already have Elixir 1.18+ and Postgres 16 locally:

```bash
POSTGRES_HOST=localhost mix setup
POSTGRES_HOST=localhost mix phx.server
```

## Production deployment

See Section 13 of `../phase-0-implementation.md`. TL;DR after NPM + DNS are configured:

```bash
# On the server:
docker compose up -d --build --wait
```

Migrations run automatically at container start via the runtime image's `CMD`.

## Tests and quality checks

```bash
POSTGRES_HOST=localhost mix test
POSTGRES_HOST=localhost mix compile --warnings-as-errors
mix format --check-formatted
mix credo
mix sobelow --config
```

## Tech stack

| Layer | Tool |
|---|---|
| Language | Elixir 1.18+ (OTP 27+) — this dev box runs 1.20-rc.1 / OTP 28 |
| Web | Phoenix 1.8.5 + LiveView 1.1 + Bandit |
| Domain | Ash 3.24 (+ AshPostgres, AshPhoenix, AshAuthentication, AshOban, AshPaperTrail, AshArchival, AshStateMachine, AshAdmin) |
| Database | PostgreSQL 16 |
| Background jobs | Oban 2.21 |
| Email | Swoosh — `Swoosh.Adapters.Local` in dev, `Swoosh.Adapters.Resend` in prod |
| Styling | Tailwind v4 (CSS `@theme`) + Figtree from Google Fonts |
| Container | Alpine-based multi-stage Dockerfile |
| Reverse proxy | Nginx Proxy Manager (GUI-managed) |

## Roadmap

This is Phase 0 of a 20-phase plan. Next: Phase 1 (Auth + multi-tenancy), Phase 2 (Tags + Custom Lists + Student list view), and so on. See `../build-plan-ash.md` for the full roadmap.
