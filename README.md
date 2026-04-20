# Intellispark

A faithful Phoenix/LiveView/Ash recreation of the Intellispark K-12 student-support platform.

This repository now ships **Phase 2** — the Student domain, per-school Tags, Status ledger, and saved CustomLists with a branded `/students` + `/lists` UI — on top of **Phase 1.5** (admin invitations), **Phase 1** (auth + multi-tenancy), and the Phase 0 design-system + tooling baseline. See `../phase-2-students-tags-lists.md`, `../phase-1-implementation.md`, and `../phase-1.5-school-invitations.md` for the plans, and ADRs under `docs/architecture/decisions/`.

## What Phase 2 delivers

- `Intellispark.Students` domain with six resources — Student, Tag, StudentTag, Status, StudentStatus, CustomList — each tenant-scoped on `school_id` with `global?: false` so forgetting tenant raises rather than silently leaking cross-school data
- `Student` with `:display_name` + `:initials` calculations, a `:set_status` update action that maintains a paper-trailed StudentStatus ledger (append-only; denormalized pointer on Student), and partial unique identity on `(school_id, external_id) WHERE external_id IS NOT NULL` for SIS round-trip
- `Tag.apply_to_students` bulk action — `Ash.bulk_create` with `upsert?: true, stop_on_error?: false, return_errors?: true` so 30-student bulk-apply survives partial failure and surfaces a count via the LiveView flash (see ADR-004)
- `CustomList.filters` as an embedded `FilterSpec` Ash resource (tag_ids, status_ids, grade_levels, enrollment_statuses, name_contains) + a generic `:run` action that composes `Ash.Query.filter` clauses — new filter dimensions need no migration
- Per-action policy split between `StaffReadsStudentsInSchool` / `StaffEditsStudentsInSchool` (FilterCheck for read/update/destroy) and `ActorBelongsToTenantSchool` (SimpleCheck for create + generic actions), because FilterCheck can't authorize a create
- `/students` LiveView — brand-blue title, filter bar, 7-column table (Student(N) | High-5s | Flags | Status | Supports | Tags), inline status chips + tag chips with "+ N more" overflow, per-row and select-all checkboxes, white-bg bulk toolbar with 6 icons + charcoal tooltips, apply-tag modal wired through `Tag.apply_to_students`
- `/lists` LiveView — card grid of the user's own lists + shared lists in the school + a built-in "All Students" card linking to `/students`; `/lists/:id` renders the same 6-column table filtered through the saved FilterSpec
- `/students/:id` stub that 302s to a placeholder hub page (real hub lands in Phase 3) so row clicks don't 404
- School-scoped PubSub: Student create/update/destroy broadcasts to `students:school:<school_id>` and `/students` subscribes; bulk-tag applies surface in other tabs immediately
- `SetAdminActorCookies` auto-seeds the AshAdmin `tenant` session cookie from `current_school` so admins land in the right tenant on `/admin` without picking manually
- Seeds include 5 demo students (Ava/Marcus/Ling/Elena/Noah), 3 tags (IEP, 1st Gen, Academic Focus), 3 statuses (Active, Watch, Withdrawn), and 2 CustomLists (shared "At-risk (IEP)" + private "Seniors graduating") — all idempotent
- 88 tests, 0 failures — unit coverage for resources + policies + bulk, plus LiveView acceptance for signed-out redirect, tenant isolation, search, bulk-tag, and private-list visibility
- ADR-004 captures the tenant-scope / policy-split / bulk-apply / FilterSpec decisions

## What Phase 1 delivers

- AshAuthentication password strategy with email confirmation + password reset (`require_interaction? true` for the security advisory; `session_identifier :jti`)
- Branded sign-in / reset / confirm / sign-out LiveViews via `IntellisparkWeb.AuthOverrides`
- District → School → SchoolTerm hierarchy + UserSchoolMembership join with role + source enums
- `Intellispark.Tenancy.to_tenant/1` helper — Phase 2+ resources will be tenant-scoped on `school_id` and forgetting tenant raises
- FilterCheck policies (`DistrictAdminOfUser`, `…OfSchool`, `…OfSchoolTerm`, `…OfMembership`) so reads filter rows rather than gating actions
- AshPaperTrail on every Accounts resource, `hashed_password` excluded from snapshots, deny-all policies on auto-generated `.Version` resources via `Intellispark.PaperTrail.VersionPolicies` mixin
- School switcher dropdown in the app header (only renders when the user has more than one membership)

## What Phase 1.5 delivers

- `Intellispark.Accounts.SchoolInvitation` resource — email + role + status + expires_at, paper-trailed, with a partial unique index blocking duplicate pending invites per (email, school) pair
- `:invite` create action with a `DistrictAdminCanInvite` SimpleCheck policy; `:accept_by_token` update action with a transactional `AcceptInvitation` change that upserts User + UserSchoolMembership (`source: :invitation`); `:revoke` update action
- Branded invitation email via `EmailLayout.wrap/1` linking to `/invitations/:id` (the invitation's UUID primary key *is* the token — see ADR-003)
- Public `IntellisparkWeb.InvitationLive.Accept` LiveView with four states: pending/ready, accepted, revoked, invalid; on success redirects into AshAuthentication's `sign_in_with_token` flow so the invitee lands signed-in
- AshAdmin wired at `/admin` gated to district admins via a new `:require_district_admin` on_mount hook — provides the MVP invite-creation UI
- Self-service `/register` removed and the "Need an account?" toggler suppressed — account creation is strictly invite-only now
- Idempotent dev seed includes one pending invitation (`newcoach@sandboxhigh.edu` → `:counselor`) so `/admin` has data on a fresh boot and `/dev/mailbox` has a click-through URL
- 49 tests, 0 failures across all suites

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

Phase 0 (foundations), Phase 1 (auth + multi-tenancy), Phase 1.5 (school invitations), and Phase 2 (Students + Tags + Custom Lists) are complete. Next up: **Phase 3** — the Student Hub, where the row-click target grows real content. See `../build-plan-ash.md` for the full 20-phase roadmap.
