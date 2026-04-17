# ADR 001: Build on the Ash Framework

**Status:** Accepted
**Date:** 2026-04-17

## Context

This project rebuilds the Intellispark K-12 student-support platform. The domain has several characteristics that drive the framework choice:

- **Multi-tenant** (district → school → student scoping) where a cross-tenant leak is a FERPA incident, not a bug.
- **Rich authorization** — teachers see students in their classes, counselors see all in their school, admins see all in their district, families see only their child's data.
- **Auditability** — FERPA-grade edit history on every student record.
- **Many computed fields** — the Student Hub's 13 SEL indicators, "no High 5 in 30 days" counters, flag age, etc.
- **Heavy form / CRUD surface** — the real product is dozens of modals, each creating/updating/closing a different entity.
- **Background jobs tied to domain events** — auto-close flags, send survey reminders, email deliverability, automation rules.

Plain Phoenix with hand-rolled contexts can do all of this, but each of those concerns becomes a separate layer of hand-written code: scoping macros, policy plugs, audit-log hooks, calculation helpers, form wrappers, Oban workers. The surface area compounds fast.

## Decision

Build on the **Ash Framework** (3.24) with the full first-party extension suite:

- `AshPostgres` as the data layer
- `AshPhoenix` for form integration
- `AshAuthentication` + `AshAuthentication.Phoenix` for auth (Phase 1)
- `AshOban` for trigger-based background jobs (Phase 4+)
- `AshPaperTrail` for audit trails (FERPA)
- `AshArchival` for soft deletes with retention policies
- `AshStateMachine` for flag/support/survey workflow states
- `AshAdmin` for baseline admin UI

Every resource `use`s `Intellispark.Resource`, a base macro that wires `AshPaperTrail`, `AshArchival`, `AshOban`, `Ash.Policy.Authorizer`, and `Ash.Notifier.PubSub` by default — so the safety defaults can't be forgotten.

## Consequences

**Gains:**

- **Policies are declarative** and co-located with the resource. A reviewer can verify FERPA authorization by reading the resource file, not by hunting through context modules and plugs.
- **Multi-tenancy is attribute-enforced** at the data layer (Phase 1). Forgetting to scope a query becomes architecturally impossible, not just code-review discipline.
- **Calculations and aggregates** replace one-off query helpers. The Student Hub's indicator display, the list view's counts, and custom list filters all read from the same source of truth.
- **AshPaperTrail is on from day one** — the FERPA audit log is a free query from Phase 1 onwards, not a retrofit.
- **CRUD-heavy phases accelerate** — Phase 2's Tags/Lists, Phase 3's Student Hub, Phase 5's Actions/Supports/Notes are all much shorter with Ash.
- **State machine for Flags** (Phase 4) is explicit and invalid transitions raise at the resource layer.
- **Timeline savings** — estimated ~15–20% shorter on the CRUD-heavy phases (2, 3, 5, 10), and FERPA posture is front-loaded so Phase 15 (security hardening) is mostly verification.

**Costs:**

- **Dependency weight** — ~20 additional deps across the Ash ecosystem.
- **Learning curve for reviewers** — Ash resource DSL reads cleanly once you're in the mental model, but requires the reviewer to be in that model too.
- **Escape-hatch complexity** — when the product needs behavior that doesn't fit a resource action (e.g., complex multi-step orchestration), we reach for `Ash.Reactor` rather than writing plain Elixir functions. This is fine but adds another library surface.
- **Divergence from Intellispark's likely real stack** — the real Intellispark codebase (shipped in 2020) almost certainly uses plain Ecto + Phoenix contexts since Ash was nascent then. This project is a portfolio artifact, not a drop-in replacement, so the divergence is acceptable.

## Conventions

Two Ash conventions that govern every later phase (documented in §6.0 of the Phase 0 plan):

1. **Encapsulate all logic inside actions**, never pipeline into `Ash.read`/`Ash.create`. Side effects live in `change` modules, `after_action` hooks, or `Ash.Notifier` — never on the caller side.
2. **Code interfaces live on the domain**, not on the resource. Callers invoke `Intellispark.Accounts.register_user!(...)` via the domain's `resources do resource … do define …` block — never `code_interface do ... end` on the resource itself.

These compound across 70+ days of downstream work; violating them leads to codebases that fight the framework.

## Alternatives Considered

- **Plain Phoenix + Ecto + hand-rolled contexts.** Simpler to review on first pass; heavier ongoing maintenance; FERPA/audit/scoping burden falls on reviewer discipline rather than the framework. Documented in `../../../build-plan.md` as the Plain-Phoenix alternative.
- **Event-sourcing with Commanded.** Pushed back (see earlier conversation in the plan directory). The hybrid recommendation — AshPaperTrail + Phoenix.PubSub events + AshStateMachine for Flags only — captures ~80% of event-sourcing's benefit with ~5% of its cost.
