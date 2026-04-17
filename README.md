# Intellispark

A faithful Phoenix/LiveView/Ash recreation of the Intellispark K-12 student-support platform.

This repository now ships **Phase 1** — authentication and the multi-tenant foundation — on top of the Phase 0 design-system + tooling baseline. See `../phase-1-implementation.md` for the build plan and master checklist; ADRs live under `docs/architecture/decisions/`.

## What Phase 1 delivers

- AshAuthentication password strategy with email confirmation + password reset (`require_interaction? true` for the security advisory; `session_identifier :jti`)
- Branded sign-in / register / reset / confirm LiveViews via `IntellisparkWeb.AuthOverrides`
- District → School → SchoolTerm hierarchy + UserSchoolMembership join with role + source enums
- `Intellispark.Tenancy.to_tenant/1` helper — Phase 2+ resources will be tenant-scoped on `school_id` and forgetting tenant raises
- FilterCheck policies (`DistrictAdminOfUser`, `…OfSchool`, `…OfSchoolTerm`, `…OfMembership`) so reads filter rows rather than gating actions
- AshPaperTrail on every Accounts resource, `hashed_password` excluded from snapshots, deny-all policies on auto-generated `.Version` resources via `Intellispark.PaperTrail.VersionPolicies` mixin
- School switcher dropdown in the app header (only renders when the user has more than one membership)
- Idempotent dev seed: `admin@sandboxhigh.edu` (district admin) and `curtis.murphy@sandboxhigh.edu` (teacher), both `phase1-demo-pass`
- 29 tests, 0 failures across policy / paper-trail / tenancy / auth-flow suites

## What Phase 0 still delivers

- Phoenix 1.8 + LiveView + Ash 3.24 ecosystem wired end-to-end
- Nine Ash domains (Accounts is now populated; Students, Support, Recognition, Assessments, Indicators, Teams, Integrations, Automations remain ready for later phases)
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
- <http://localhost:4800> — placeholder landing page
- <http://localhost:4800/sign-in> — branded login (sign in with `admin@sandboxhigh.edu` / `phase1-demo-pass`)
- <http://localhost:4800/register> — registration with email confirmation
- <http://localhost:4800/reset> — password reset
- <http://localhost:4800/styleguide> — every design primitive
- <http://localhost:4800/dev/mailbox> — Swoosh local mailbox preview (password-reset and confirmation emails land here)

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

Phase 0 (foundations) and Phase 1 (auth + multi-tenancy) are complete. Next up: **Phase 2** — Tags, Custom Lists, and the Student list view, where multi-tenancy starts paying for itself. See `../build-plan-ash.md` for the full 20-phase roadmap.
