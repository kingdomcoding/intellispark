# ADR 002: Authentication with AshAuthentication + attribute-based multi-tenancy

**Status:** Accepted
**Date:** 2026-04-17

## Context

Phase 1 has to deliver three things at once:

1. Real authentication that AshAuthentication's password strategy can drive end-to-end (register, confirm email, sign in, reset password, sign out).
2. The organisational hierarchy that every later phase will scope against: District → School → SchoolTerm, with users joined to schools via UserSchoolMembership.
3. The boundary that the multi-tenancy enforcement in Phase 2+ will hang off of — we have to commit to which entity is "the tenant" before we start writing tenant-scoped resources.

The wrong choice on any of these locks in churn for the rest of the project.

## Decisions

### 1. Use AshAuthentication for everything auth-related

Use `AshAuthentication` 4.13 with `AshAuthentication.Phoenix` for the LiveView surface. Password strategy with confirmation required. `session_identifier :jti` and `require_token_presence_for_authentication? true` so revocation works on logout (the modern AshAuthentication defaults).

Confirmation strategy named `:confirm_new_user` with `require_interaction? true`, per the AshAuthentication security advisory — confirmation links use POST (via an intermediate landing page), so email previewers and antivirus scanners can't auto-confirm an account.

`Intellispark.Accounts.Secrets` reads `TOKEN_SIGNING_SECRET` from env. Returns `:error` (the atom, not a tuple) when missing — that's what the `AshAuthentication.Secret` protocol expects.

### 2. The tenant boundary is `School`, not `District`

99% of authorisation in this product is school-scoped: "which students can this counselor see?", "who's on this support team?", "raise a flag for this student". District is the organisational parent — a small number of users (super-admins) need cross-school visibility, but the read path is overwhelmingly "everyone in my school".

Concretely:

- Phase 1 Accounts-domain resources (User, Token, District, School, SchoolTerm, UserSchoolMembership) **do not** declare a `multitenancy` block — they span schools.
- Phase 2+ resources (Student, Flag, HighFive, Support, …) will declare `multitenancy do strategy :attribute; attribute :school_id end`.
- Callers always derive the tenant via `Intellispark.Tenancy.to_tenant/1`, which accepts a `%School{}`, a `%UserSchoolMembership{}`, a map containing `:current_school`, or a `school_id` binary, and **raises** on `nil` — forgetting to pass tenant is a bug, not a silent fallback.

### 3. User is cross-tenant, joined to schools via UserSchoolMembership

A user can belong to multiple schools (a counselor covering two buildings, a district administrator). Membership carries the role enum (`:admin | :counselor | :teacher | :social_worker | :clinician | :support_staff`) and a source enum (`:manual | :roster_auto`) so Phase 11's roster sync can mark which memberships it owns.

The session stores `current_school_id`. The `IntellisparkWeb.LiveUserAuth` `on_mount` hook resolves it on every authenticated LiveView mount, falling back to the first membership if the session value is missing or stale.

### 4. Policies use Ash.Policy.FilterCheck, not SimpleCheck, for cross-resource gates

`DistrictAdminOfUser`, `DistrictAdminOfSchool`, `DistrictAdminOfSchoolTerm`, and `DistrictAdminOfMembership` are `FilterCheck` modules that return an `Ash.Expr` filter (e.g. `expr(district_id == ^actor_district_id)` or `expr(school.district_id == ^actor_district_id)`). This means a read by a district admin returns the rows in their district *filtered*, rather than gating the action wholesale — so a teacher trying to read a sibling-district admin gets `NotFound` (no existence leak), while a district admin gets back the full filtered list in one query.

### 5. Paper-trail Version resources get policies via mixin

AshPaperTrail auto-generates `.Version` resources alongside each audited resource. The `Intellispark.PaperTrail.VersionPolicies` mixin (declared once on `Intellispark.Resource` and once on `User`) injects a deny-all policy block into every Version resource. Audit access happens through admin tooling using `authorize?: false`. This keeps the Phase 0 policy-audit test honest — every Accounts resource (including `_versions` tables holding student-data snapshots) has explicit policies.

## Consequences

**Gains:**

- Auth flow ships in ~1 day instead of 2-3; the password+confirmation+reset machinery is configured, not coded.
- The `Tenancy.to_tenant/1` helper plus the no-multitenancy-on-Accounts decision means Phase 2 starts from a clean baseline: declare `multitenancy ...` on the resource, pass the tenant on every query, and scoping is enforced at the data layer.
- FilterCheck-shaped policies double as filters and gates — one source of truth per "who can see what" rule.
- `hashed_password` is in `paper_trail.ignore_attributes`, so version snapshots never carry it.
- Paper trail covers User, District, School, SchoolTerm, UserSchoolMembership — every change to org structure or auth metadata lands in audit storage.

**Costs:**

- AshAuthentication's security defaults (require_interaction?, jti session identifier, require_token_presence) are non-negotiable in this version. Anyone reading the User resource has to recognise those incantations.
- The `.Version` mixin pattern is non-obvious — readers will see "policies do" appearing on a resource they didn't write.
- We've shipped District/School/SchoolTerm without a real "super admin" concept yet. Their write actions are deny-all (`authorize_if never()`), so all org bootstrapping goes through `authorize?: false` in seeds. A real super-admin role lands in Phase 2 or later.
- The User resource can't use the `Intellispark.Resource` base macro because that macro forces a fixed `extensions:` list — `AshAuthentication` has to be added as an extension at `use Ash.Resource` time. So User redeclares its `paper_trail` block by hand.
- `Intellispark.Accounts.Secrets.secret_for/4` returns `:error` (atom) on missing env, not a tuple — easy to get wrong, with confusing runtime error if you do.

## Verification

- `mix test`: 29 tests, 0 failures (8 Phase 0 + 21 Phase 1).
- `mix compile --warnings-as-errors`: clean.
- `test/policy_audit_test.exs`: every Accounts resource has policies.
- `auth_flow_test.exs`: register → confirm → sign in works end-to-end via AshAuthentication actions; password reset rotates the credential; GET /sign-in renders the branded form.
- `paper_trail_test.exs`: User update produces version rows AND `hashed_password` is absent from snapshot changes.
- Manual QA: `admin@sandboxhigh.edu / phase1-demo-pass` signs in successfully against the running endpoint.
