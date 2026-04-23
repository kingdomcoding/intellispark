# ADR 022: Phase 11.5 — Student Lifecycle Retrofit

**Status:** Accepted
**Date:** 2026-04-23
**Builds on:** ADR 019 (Tiers + Onboarding + Billing Stub), ADR 020 (Phase 3+10 retrofits — the stub this closes), ADR 021 (SIS + Xello integration).
**Supersedes part of:** ADR 020 §2 (the `student_action_attempt` stub).

## Context

Phase 3 retrofit (v0.10.5.4, ADR 020) shipped the Status `⋯` overflow + `Actions` header button with all four menu items (Archive / Transfer / Mark withdrawn / Generate report) dispatching a single `student_action_attempt` event that flashed "Coming in Phase 11.5 (student lifecycle)". The UI surface landed for screenshot parity; the state-machine actions were explicitly deferred.

This was the **only remaining identified-but-unshipped retrofit** in `build-plan-ash.md`. Every other retrofit from the 2026-04-21 screenshot review had already shipped by tag `b990e45`.

Goal: replace the four flash stubs with real persisted Ash actions on `Student`, backed by confirmation modals + AshPaperTrail capture + policies, so each click lands an auditable lifecycle event instead of a placeholder. Shipped as `v0.11.5-student-lifecycle-complete` with 508 tests green.

## Decisions

### 1. Three lifecycle actions, not one

Archive / Withdraw / Transfer have different semantics — different arguments (none / none / `destination_school_id`), different policies (clinical-role staff / clinical-role staff / district admin + PRO), and different post-conditions (hidden from lists / stays visible / cross-school clone). Merging into one `:lifecycle_transition` would hide the per-action branching behind runtime checks. Three distinct actions read cleanly in `iex`, tests, and the paper-trail log (version_action_name is `:archive` / `:mark_withdrawn` / `:transfer`).

### 2. `:archive` uses AshArchival, not AshStateMachine

`AshArchival.Resource` is already wired in globally via `Intellispark.Resource`. Every resource has an implicit `archived_at` attribute and a base_filter that hides archived rows from default reads. `:archive` sets `archived_at: now()` via `change set_attribute(:archived_at, &DateTime.utc_now/0)`. Wrapping this in a state machine adds ceremony without capability — `enrollment_status` already tracks the "active vs not" axis that the UI needs, and AshArchival provides restore semantics via `:unarchive`.

### 3. `:mark_withdrawn` is a plain update action, not AshStateMachine

`enrollment_status` is a constrained `one_of` atom (`:active | :inactive | :graduated | :withdrawn`). The Ash attribute constraint already enforces valid values. A state machine would also forbid legitimate transitions (e.g., a `:graduated` student who officially withdraws). We use a purpose-named update action — `update :mark_withdrawn` — so the paper-trail row reads `version_action_name: :mark_withdrawn` rather than the generic `:update`, and so policy separation targets the intent.

### 4. `:transfer` is a cross-tenant clone + source archive

Transfer semantics, precisely:

1. Set `archived_at` on the source student (soft delete).
2. In `after_action`, `Ash.create/3` a new Student in the destination school with matching demographics + `external_id`.
3. Downstream rows (flags, high-5s, supports, notes, team memberships, key connections, strengths, survey assignments) do NOT migrate. They stay at the source for audit integrity.

Rationale: multitenancy policies would reject cross-school writes on the downstream rows, and even if bypassed, audit integrity suffers — a flag opened by a counselor at School A shouldn't appear authored-by-that-counselor at School B. Clean cut is cleaner. Archiving the source (instead of hard-delete) means the source row stays visible in AshAdmin + paper-trail for accidental-transfer recovery.

Implementation lives in `lib/intellispark/students/changes/transfer_to_school.ex` via an `after_action` hook so the source archive + destination create run inside one changeset transaction. If the destination create fails (e.g., unique `external_id` collision), the whole thing rolls back — tested explicitly in Test 12.

### 5. `:transfer` is PRO-tier gated via AND-semantics policies

Cross-school moves are an enterprise signal: district admins of multi-school districts need it; Starter-tier single-school accounts don't. Wiring:

```elixir
policy action(:transfer) do
  authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
end

policy action(:transfer) do
  authorize_if {IntellisparkWeb.Policies.RequiresTier, tier: :pro}
end
```

Two separate policy blocks on the same action — Ash treats them with **AND** semantics (both must pass). This matches the pattern already in `integration_provider.ex:146-165` for tier-gated Xello creates. The source school's tier is what's checked; the destination's tier is not, on the assumption that a district admin authoring a transfer is admin of both schools and thus inherits district-level tier.

### 6. `:unarchive` is admin-only, no confirmation modal, no Hub surface

Un-archiving is a recovery action, not a destructive one. Single-button restore via AshAdmin (`/admin` → Student → set `archived_at: nil`) is sufficient for v1. Adding a Hub "archived students" list surface with its own pagination + modal pattern is out of scope. The `:unarchive` action + domain define + policy exist for API completeness, future-proofing, and test coverage.

### 7. Actions menu dispatches expand in place; event name + payload stay

The `student_action_attempt` event name and `%{"action" => ...}` payload shape are unchanged. What changes is the handler: from a single catch-all flash to four dispatchers. This minimizes HEEx diff — the menu-items component still builds the same `{label, action}` tuples and fires the same event. Forking into four events would double the surface for no benefit.

### 8. Three confirm modals, not one polymorphic modal

Archive / Withdraw / Transfer have different bodies (transfer needs a destination-school picker), different primary-button variants (danger / primary / primary), and different labels. One modal with runtime branching on `@confirm_modal` shape would be messier than three small `<.modal :if={@confirm_modal == :archive}>` blocks. All three reuse `IntellisparkWeb.UI.Modal`.

### 9. Transfer modal uses a plain `<select>`, not a typeahead

District admins typically admin ≤20 schools. A `<select>` scrolls; a typeahead is over-engineering for v1. The options list is populated from `sibling_schools_for/2` which walks `user.school_memberships` and excludes the current school. When the list is empty (single-school district) the form shows "No other schools are available…" and the submit button is disabled.

### 10. `"report"` stays stubbed; flash text updates

PDF / report generation is a Phase 17 (observability / exports) topic, not this retrofit. The flash text changes from "Coming in Phase 11.5 (student lifecycle)" — which is now false — to **"Reports ship in a future release."**, which is accurate and doesn't commit to a timeline. The menu item stays to preserve screenshot parity.

### 11. Transfer menu item is hidden for non-eligible actors

Rather than render the item and reject clicks with a forbidden flash, we filter the menu at render time based on `@can_transfer?` (which is `district_admin?(actor) AND current_school.subscription.tier == :pro`). Hidden-but-present menu items are a minor security anti-pattern and a UX regression. The `:transfer` policy still guards the action itself — the UI filter is defense-in-depth, not the authorization boundary.

## Consequences

- `build-plan-ash.md` line 279 flips from "remain scoped to Phase 11.5" to ✅ with a link to this ADR + `markdowns/phase-11.5-student-lifecycle.md`.
- `intellispark/README.md` line 24 replaces the "Coming in Phase 11.5" note with the shipped-state description (clinical-role archive/withdraw, PRO-tier district-admin transfer, parked report).
- The `student_action_attempt` event in `show.ex` is now a real dispatcher; ADR 020 §2 is superseded for the archive/withdraw/transfer items.
- `generate_report` remains a stub; picked up when the reporting phase lands.
- Future graveyard UI (archived-student list + bulk restore) is explicitly deferred.
- Test count: baseline 495 → 508 green (+5 archive/unarchive + 2 withdraw + 5 transfer + 1 LV integration).

## Cross-references

- ADR 019 — tier model + `RequiresTier` SimpleCheck used by policy block 2 on `:transfer`
- ADR 020 — the Phase 3 retrofit that shipped the stub this ADR closes
- ADR 021 — SIS + Xello integration; the AND-semantic tier-gating policy pattern this ADR reuses from `integration_provider.ex`
- `markdowns/phase-11.5-student-lifecycle.md` — the detailed implementation plan + todo list
