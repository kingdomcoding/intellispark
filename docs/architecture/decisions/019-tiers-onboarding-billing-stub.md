# ADR 019: Per-school tier model + onboarding wizard + billing stub

**Status:** Accepted
**Date:** 2026-04-22
**Builds on:** ADR 001 (auth + multi-tenancy), ADR 015 (Hub Tab Framework — nav surface), ADR 017 (flag close-flow — adjacent), ADR 018 (Phase 6 retrofit — adjacent).

## Context

The product ladder is three tiers: **Starter** (free baseline), **Plus** (mid), **Pro** (full). Phase 11's Xello bidirectional embed is PRO-only; Phase 12's automation rules have PLUS + PRO caps; Phase 10.5's custom-list count scales with tier. Without a tier model, every phase would either ship unguarded or retrofit a flag later. The sequencing doc argues Phase 18.5 should land *before* Phase 11 so new features gate cleanly from day one.

Onboarding is also absent today: a fresh district admin lands on an empty `/students` page with no cue to set up tags, invite co-admins, or pick a plan. A short wizard solves that friction and is a natural place to ask "which tier?"

## Decisions

### 1. Tier stored on `SchoolSubscription`, not directly on School

A one-per-school `SchoolSubscription` resource (attributes: `tier`, `status`, `seats`, `started_at`, `renews_at`, `stripe_subscription_id`) keeps billing state out of `School`'s identity + slug columns. Future Stripe webhooks will update Subscription rows; School's shape is unchanged. `has_one :subscription` relationship on School.

### 2. Three-tier ladder: `:starter | :plus | :pro`

Rejected `:trial` (trialing is a *status*, not a tier) and `:enterprise` (add later, additive). `tier_rank/1` private helper in both `Tiers` + `RequiresTier` compares them.

### 3. Pure-Elixir feature matrix over DB-backed flags

`lib/intellispark/tiers.ex` holds a compile-time `@features` + `@tier_caps` map. Rejected LaunchDarkly / GrowthBook for a 7-feature matrix. Features rotate in code anyway; no deploy-time toggles needed.

### 4. `RequiresTier` is a SimpleCheck, not FilterCheck

Tier gating is boolean on the actor's current school. FilterChecks produce row-scoping SQL filters; that's the wrong shape for tier deny/allow. Usage:

```elixir
policy action(:create) do
  authorize_if {IntellisparkWeb.Policies.RequiresTier, tier: :pro}
end
```

### 5. Actor carries `:current_school` for policies to read

`RequiresTier.match?(actor, _, tier: :pro)` reads `actor.current_school.subscription.tier`. The `LiveUserAuth` + `AssignCurrentSchool` loaders both `Map.put(user, :current_school, school)` after loading the school with `load: [:subscription, :onboarding_state]`. Tests that build synthetic actors for the policy mirror this shape.

### 6. `SchoolOnboardingState` is one-per-school, not per-admin

First district admin to hit the wizard owns it. Subsequent admins see the button only if still incomplete. Avoids the N-admins × N-steps state explosion. `identity :unique_school`.

### 7. `current_step :atom` enum, not ordinal integer

Named steps (`:school_profile`, `:invite_coadmins`, `:starter_tags`, `:sis_provider`, `:pick_tier`, `:done`) beat `1..6` for readability and resist reordering. Reordering orphans no rows.

### 8. Every step is skippable

`advance_step` writes the target step regardless of inputs. A district admin can walk the 5-step flow with every button as "Skip" and still land at `:done`. Friction is the enemy of adoption.

### 9. Onboarding gated to district admins

Counselors, teachers, etc. never see the Get Started button and are redirected away from `/onboarding` with a flash. District-admin is the existing computed predicate (`user.district_id != nil and Enum.any?(memberships, &(&1.role == :admin))`).

### 10. Backfill existing schools to `:starter` + `:done`

A data migration creates `SchoolSubscription{tier: :starter, status: :active}` + `SchoolOnboardingState{current_step: :done, completed_at: now()}` for every pre-existing school. The onboarding wizard is an artifact for NEW schools; existing admins shouldn't be badgered.

### 11. Seed NEW schools via `School.:create` after-action change

`Intellispark.Accounts.Changes.SeedBillingState` wraps an `after_action` that creates Subscription + OnboardingState atomically with `authorize?: false`. Guarantees every School has the two sibling rows — `RequiresTier` can assume tier is always present.

### 12. Tier badge hidden for `:starter`

Showing `(STARTER)` next to every school name in the switcher is visual noise. Plus gets a brand-tinted pill; Pro gets a solid brand-colored pill; Starter gets nothing. `defp tier_badge(%{tier: :starter} = assigns), do: ~H""`.

### 13. Dedicated `Intellispark.Billing` domain

Not folded into `Accounts`. Billing state is its own concern; Accounts stays people-focused (Users, Memberships, Invitations, Schools, Districts). Future Stripe integration will add adapters under `Intellispark.Billing.Stripe` without touching Accounts.

### 14. AshAdmin as the day-1 tier management UI

A polished `/settings/billing` LV is a stretch — AshAdmin's free-with-the-resource CRUD covers tier changes for now. District admins visit `/admin` → SchoolSubscription → edit row. Swap to a branded LV when customer-facing billing ships.

### 15. `district_id` calculation on SchoolSubscription + SchoolOnboardingState

Both resources reach their district via `school.district_id`. Exposing as `calculate :district_id, :uuid, expr(school.district_id)` lets the existing `DistrictAdminOfSchool` FilterCheck apply unchanged.

## Consequences

- Every School now has two sibling rows (Subscription + OnboardingState). `setup_world/0` loads them before returning the school; existing tests that don't count DB rows are unaffected.
- `RequiresTier` requires the actor to carry `current_school.subscription.tier`. Controllers / LVs that bypass the existing loaders (and don't attach `current_school` to the actor) will fail the check silently. No current code does this, but new code must follow the pattern.
- Seeds + fixtures upgrade demo schools to `:pro` + completed-onboarding so dev sessions don't show the Get Started pill.
- Downstream phases (11/12/14) can now declare `RequiresTier(:pro)` / `RequiresTier(:plus)` on resource actions without scaffolding.

## Tests added (+14)

- `test/intellispark/billing/school_subscription_test.exs` — 4 cases (seed on School create, set_tier by admin, set_tier denied for counselor, unique_school identity)
- `test/intellispark/billing/school_onboarding_state_test.exs` — 3 cases (seed on School create, advance stamps prior step, complete stamps :done + completed_at)
- `test/intellispark/tiers_test.exs` — 3 cases (Xello PRO-only, custom_lists cap scales, unknown feature denies)
- `test/intellispark_web/policies/requires_tier_test.exs` — 5 cases (nil denies, PRO passes all, PLUS passes plus+starter, STARTER passes only starter, missing current_school denies)
- `test/intellispark_web/live/onboarding_live_test.exs` — 2 cases (counselor redirected, admin walks wizard to :done)

Running total: **439** (was 425 after Phase 6 retrofit).

## Alternatives considered

- **Tier as a `School.tier` attribute.** Conflates billing state with school identity; Stripe webhooks would touch schools directly. Rejected.
- **LaunchDarkly / GrowthBook feature flags.** Overkill for a 7-feature static matrix; external dependency + latency hit on every check. Rejected.
- **Per-admin onboarding state.** Each admin walks the wizard independently. Too many rows; nobody owns the "this school is onboarded" state. Rejected.
- **Separate `/billing` LV for tier management.** Deferred. AshAdmin covers it.
- **Modal wizard instead of full-page `/onboarding` LV.** Rejected — walking 5 steps inside a modal is awkward and requires modal state restoration. A dedicated page handles browser back-button sanely.
