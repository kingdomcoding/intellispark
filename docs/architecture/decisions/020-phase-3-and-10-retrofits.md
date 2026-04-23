# ADR 020: Phase 3 + Phase 10 retrofits — demographics, lifecycle stubs, hover popovers, ExternalPerson

**Status:** Accepted
**Date:** 2026-04-23
**Builds on:** ADR 005 (Student Hub), ADR 014 (Teams + Connections + Strengths), ADR 015 (Hub Tab Framework).

## Context

Two screenshot-driven retrofits remained outstanding after Phases 6 retrofit + 18.5 shipped:

- **Phase 3 retrofits** — demographic profile fields (`gender`, `ethnicity_race`, `phone`), a Status `⋯` overflow + `Actions` header button, and hover popovers on roster column badges.
- **Phase 10 retrofit** — sectioned Team Member modal that splits Family/community drill-in (backed by `ExternalPerson`) from a searchable School-staff multi-select.

Sequencing (`next-phases-sequencing.md`) had spread Phase 3 retrofits across Phase 11 (profile fields), Phase 11.5 (lifecycle), and Phase 19 (popovers polish), and reserved `ExternalPerson` for Phase 11. We chose to land both retrofits as a focused pass before Phase 11.

## Decisions

### 1. Demographics ship as a Phase 3 polish pass, not as part of Phase 11 SIS

`gender :atom`, `ethnicity_race :atom`, `phone :string` land directly on `Student` with `one_of` constraints. SIS ingestion (Phase 11) will populate them via the same `:create` / `:update` actions; no resource shape change required at that point.

### 2. Status overflow + Actions menu render stub items, not real lifecycle transitions

Archive / Transfer / Mark withdrawn / Generate report all dispatch a single `student_action_attempt` event that flashes "Coming in Phase 11.5 (student lifecycle)". Real state-machine work (and the AshOban-driven roster cleanup) remains scoped to Phase 11.5. The UI scaffolding ships now so the screenshots are honored and the future work has a known click target.

### 3. Hover popovers are pure CSS group-hover, not a JS hook

`count_badge_with_popover` wraps the existing `count_badge` in a `group` span and renders a `hidden group-hover:block group-focus-within:block` panel. No `phx-hook`, no JavaScript surface. Popover content is computed server-side from already-loaded data; toggling is browser-native, so there is no LiveView round-trip on hover.

### 4. Top-3 lists piggy-back on full preloads, not a separate top-N query

The roster query already loads `open_flags_count` + `open_supports_count` aggregates. Adding `{:flags, open_flags_query}` + `{:supports, open_supports_query}` to the same `Ash.Query.load/2` call preloads the full filtered list per student and the view slices to 3 in HEEx. For a school-sized roster (10–500 students, most with 0–2 open items), per-student SQL fanout via Ash's relationship preloader is acceptable; "true top-N per group" via `LATERAL` would be premature.

### 5. `ExternalPerson` lifts forward from Phase 11/14 into a new Phase 10 retrofit slot

`ExternalPerson` is a school-tenant Ash resource (`paper_trail`, `pub_sub`, `multitenancy`) with `first_name`, `last_name`, `relationship_kind` (`:parent | :guardian | :sibling | :coach | :community_partner | :other`), `email`, `phone`. Lifting forward unblocks the sectioned Team Member modal without waiting for Phase 11 (SIS) — the resource is SIS-adjacent but does not depend on SIS to exist.

### 6. `KeyConnection.connected_*` is two nullable belongs_to + a validation, not `Ash.Union`

The build-plan called for `Ash.Union`. In practice, `Ash.Union` is an attribute-level type that does not compose cleanly with `belongs_to` foreign-key handling. Two nullable `belongs_to` (`connected_user`, `connected_external_person`) with a `ValidateConnectedTarget` change asserting exactly one is set is simpler, gives PostgreSQL real foreign keys for both targets, and lets each side own its own paper-trail attribute. Two partial unique indexes — `unique_per_student_user WHERE connected_user_id IS NOT NULL` and `unique_per_student_external_person WHERE connected_external_person_id IS NOT NULL` — replace the single full unique index.

### 7. KeyConnection gets a separate `:create_for_external_person` action, not an overloaded `:create`

The primary `:create` action keeps its old `[:student_id, :connected_user_id, :note, :source]` accept list — backward compat for existing callers and seeds. The new `:create_for_external_person` action accepts `[:student_id, :connected_external_person_id, :note, :source]`. Both actions share the `ValidateConnectedTarget` change. Keeps each call site explicit about which target it's connecting.

### 8. NewTeamMemberModal uses inline `:if`-dispatched view components, not a dispatcher function

A `defp view(%{view: :menu})` dispatcher pattern broke component rendering — the dispatcher's redefinitions shadowed the per-function `attr` declarations and `@myself` was lost in the assigns map. The current shape calls each sub-view as a real Phoenix function component (`<.menu_view :if={...}>`, `<.family_view :if={...}>`) with explicit `attr` declarations and explicit `myself` propagation. More verbose, but type-safe and HEEx-tooled.

### 9. Family/community + School staff create flows live entirely inside the modal component

The component itself calls `Teams.create_external_person/4`, `Teams.create_key_connection_for_external_person/3`, and `Teams.create_team_membership/4`. The parent LiveView still receives a single `{__MODULE__, :team_member_added}` message and reloads the team panel — same contract as before. Bulk staff add is sequential, not `Ash.bulk_create` — the staff list is small (school-scoped, typically <50) and the per-row error reporting is clearer with serial calls.

### 10. `staff_label/1` accepts `Ash.CiString` from Accounts

`User.email` is `Ash.CiString`-typed by AshAuthentication. `String.downcase/1` blows up on `CiString`. The fix is `s |> staff_label() |> to_string() |> String.downcase()` in the search filter — explicit normalization at the boundary, no protocol implementation hacks.

## Consequences

- **Phase 11 (SIS)** no longer needs to ship `ExternalPerson` or the demographic columns — they exist. SIS still fills them via `:upsert_from_sis`-style actions.
- **Phase 14 (About-the-Student)** still uses `ExternalPerson` for the Family/community section; nothing changes except the resource is already there.
- **Phase 11.5 (student lifecycle)** picks up the stubbed `student_action_attempt` event and replaces the flash with real `:archive`, `:transfer`, `:mark_withdrawn` state-machine actions. The UI surface stays.
- **Phase 19 (polish)** no longer owns popovers; that retrofit is shipped.
- **`KeyConnection` callers** that hand-built `%{connected_user_id: nil}` payloads now get a validation error instead of a phantom row. The new `:create_for_external_person` action is the supported path for non-staff connections.
