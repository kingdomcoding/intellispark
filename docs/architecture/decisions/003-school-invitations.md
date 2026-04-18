# ADR 003: School invitations replace self-service registration

**Status:** Accepted
**Date:** 2026-04-18
**Supersedes (in part):** ADR 002 — specifically the decision to expose `/register` for self-service sign-up.

## Context

ADR 002 gave us a working AshAuthentication stack end-to-end, including a self-service `/register` page. Two things surfaced while dog-fooding the Phase 1 build:

1. **Anonymous schoolless accounts.** `/register` creates a `User` row but doesn't attach a `UserSchoolMembership`. The `current_school` plug correctly returns `nil` and the header has no school name — but the user is technically signed in and can bounce around the app in a broken state.

2. **The authorization story doesn't match the product.** K-12 districts don't let random people sign up for the district's LMS. Onboarding is one of:
   - An admin provisions an account (email invite).
   - SSO / roster sync (Clever, ClassLink, OneRoster) pulls accounts from the SIS automatically.

Keeping `/register` open looks wrong to a technical reviewer and makes Phase 1 feel more like a generic Phoenix template than a K-12 product.

## Decisions

### 1. Account creation is invite-only

Remove `register_path` from `sign_in_route` so `/register` 404s. The "Need an account?" toggler on the sign-in card is suppressed via `register_toggle_text: nil` on the `Components.Password` override (AshAuth's Password component gates the toggler on this text value).

The `:register_with_password` Ash action stays on `User`. It's not exposed as a route — it's called internally by `SchoolInvitation.Changes.AcceptInvitation` when a new invitee accepts their invite.

### 2. Invitations are a first-class Ash resource

`Intellispark.Accounts.SchoolInvitation` is a regular resource (not a short-lived auth token). Attributes: `email`, `role`, `status` (`:pending | :accepted | :revoked`), `expires_at`, `accepted_at`, plus belongs_to `school` + `inviter`. It's paper-trailed and archivable like every other Intellispark resource.

Benefits over a bare-token design:
- Admins can list/filter/revoke invites from `/admin` (AshAuth `tokens` table has no such affordance).
- Paper-trail records the `:invite` create + `:accept_by_token` update events for audit.
- Identity on `(email, school_id) WHERE status = :pending` prevents duplicate pending invites for the same pair.

### 3. The invitation's UUID primary key *is* the URL token

No separate JWT wrapper. The URL is `/invitations/<invitation.id>`. Verification is a straightforward `Ash.get(SchoolInvitation, id)` followed by status + expiry checks on the row.

UUID v4 is 128 bits of entropy — more than sufficient to resist guessing. Revocation is a status change on the row: the URL keeps resolving but the state machine in `AcceptInvitation` rejects it with a friendly "invitation cancelled" page.

Alternative considered: sign a JWT with the `jti` matching a column. Rejected because it adds a signing secret and a verification hop without meaningful security gain — a stolen email is the only real threat vector and JWT doesn't help there.

### 4. Accept is a single-transaction update with side-effects in after_action

`SchoolInvitation.Changes.AcceptInvitation` runs:

1. `before_action` — checks status is `:pending` and `expires_at` is in the future; sets `status: :accepted`, `accepted_at: now()`.
2. `after_action` — finds an existing `User` by email OR registers a new one via the `:register_with_password` action; then upserts `UserSchoolMembership` with `source: :invitation`.

The action is `require_atomic? false` and relies on AshPostgres's default wrapping transaction so the whole thing rolls back if any step fails. The side-effects are intentionally in `after_action` so that if they error, the invitation update rolls back and the row stays `:pending` (the link keeps working, no user sees a half-accepted state).

### 5. Two distinct policy checks for create vs read/update

`Ash.Policy.FilterCheck` can't cross a `belongs_to` on create because the row doesn't exist yet — so `DistrictAdminOfSchoolInvitation` (FilterCheck) handles read/revoke by filtering on `expr(school.district_id == ^actor_district_id)`, and `DistrictAdminCanInvite` (SimpleCheck) handles `:invite` by reading `school_id` off the changeset and loading the school directly.

`:accept_by_token` is `authorize_if always()` — the URL token itself is the authorization. This matches how AshAuthentication's confirm and reset flows work.

### 6. AshAdmin is the MVP UI for creating invites

`AshAdmin` is already in the dep list. Extending `Intellispark.Accounts` with `AshAdmin.Domain` and `show? true` exposes every resource (including `SchoolInvitation`) at `/admin` with a generated CRUD form. The route is gated by `on_mount: [:live_user_required, :require_district_admin]` — non-admins are redirected to `/` with a flash.

A branded `SchoolLive.Invitations` page with pending/accepted/revoked tabs, resend, and revoke buttons is deferred until a real need surfaces. The AshAdmin UI is sufficient for demo + early internal use.

### 7. After acceptance, the invitee is auto-signed-in

The accept LiveView, on success, extracts `user.__metadata__.token` (populated by `:register_with_password` when `sign_in_tokens_enabled?: true`) and redirects to `/auth/user/password/sign_in_with_token?token=<jwt>`. That endpoint calls `AuthController.success/4` which establishes the session the same way as a normal password sign-in.

Existing-user acceptance (invitee already has an account) falls back to `/sign-in` with a welcome flash — they already have a password, so the auto-sign-in token dance would require minting one manually. Deferred as a polish task.

## Consequences

**Positive**
- Closes the "anonymous schoolless account" bug from ADR 002.
- Portfolio story: the Phase 1.5 feature exercises Ash policies (two flavors), multi-resource transactions, paper-trail, branded email, LiveView, and AshAdmin — all hung off one coherent user-facing flow.
- Product story: lines up with real K-12 onboarding (admin-driven or SSO).

**Negative**
- `/register` disappearing breaks any external docs or bookmarks that pointed at it (there are none yet, so this is free).
- Seeds now need a bootstrap path to create the first admin — the existing `priv/repo/seeds.exs` handles this: admin is registered + assigned a membership directly via Ash actions, then everything downstream flows through `invite_to_school/3`.
- AshAdmin's default UI is functional but not brand-consistent. Branded admin pages are a deferred polish task.

## Alternatives rejected

- **Keep `/register` but add a "request access" review step.** Same anonymous-account problem, just with a gate. Adds complexity without changing the product semantics.
- **Magic-link passwordless invites only (no `SchoolInvitation` resource).** Works but loses list/audit UX for admins — "what invites are still outstanding?" becomes unanswerable.
- **Embed invites inside the AshAuthentication `tokens` table using a custom purpose.** Too much surface area for a resource that wants its own CRUD, paper-trail, and unique constraint.

## Follow-ups (future phases)

- SSO / roster sync (Clever, ClassLink, OneRoster) — separate, larger phase.
- Branded `/schools/:id/invitations` LiveView replacing the AshAdmin MVP.
- AshOban-backed job that auto-expires `:pending` invites past `expires_at`.
- "Resend invitation" action.
- Polished existing-user accept flow (auto-sign-in for invitees who already have a password).
