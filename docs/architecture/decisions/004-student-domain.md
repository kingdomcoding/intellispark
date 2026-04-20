# ADR 004: Student domain — tenant-scoped resources, FilterSpec, and bulk actions

**Status:** Accepted
**Date:** 2026-04-20
**Builds on:** ADR 002 (multi-tenancy via attribute on `school_id`), ADR 003 (invite-driven membership).

## Context

Phase 2 delivers the Student record, per-school tagging, status tracking, and saved CustomLists — the data surfaces every downstream phase (Hub, High-5s, Flags, Supports, Teams) builds on. The resource model has to land before any of that work becomes fruitful, so the decisions baked into this phase are load-bearing for the rest of the build plan.

Three requirements shaped every trade-off:

1. **Hard tenant isolation.** A staff member in School A must never see a Student from School B, full stop. Attribute-based multi-tenancy from ADR 002 already scopes reads, but Phase 2 introduces actions (bulk tag apply, status ledger writes, saved-filter runs) where the FilterCheck path doesn't help.
2. **Bulk tag apply that survives partial failure.** The UX is "check 30 kids → click the IEP tag → done." Half-failing silently is worse than not shipping it at all — the admin needs a flash telling them 27 succeeded + 3 were rejected.
3. **Saved filters without a rigid schema migration per new dimension.** CustomList.filters has to be extensible — adding "current_status_id" or "risk_score_gte" should be an attribute addition on an embedded Ash resource, not a join table.

## Decisions

### 1. Every Phase 2 resource is tenant-scoped on `school_id` with `global?: false`

Student, Tag, StudentTag, Status, StudentStatus, CustomList all declare:

```elixir
multitenancy do
  strategy :attribute
  attribute :school_id
  global? false
end
```

`global?: false` means every Ash query requires a tenant — forgetting to set one raises `Ash.Error.Invalid.TenantRequired` at the boundary instead of silently returning every school's data. This is a 100% guarantee no amount of FilterCheck discipline can provide.

`paper_trail do attributes_as_attributes [:school_id] end` is required on every tenant-scoped resource so the auto-generated `Version` mirror has its own `school_id` column — otherwise AshPaperTrail's inserted-tenant block on the Version resource references a column that doesn't exist, and every create fails.

### 2. Policies split by action type — FilterCheck for read/update, SimpleCheck for create/generic

`Ash.Policy.FilterCheck` can't authorize a `create` action — there's no row to filter yet — and can't authorize a generic action either (see the explicit "Cannot use filter checks with generic actions" guard in Ash 3.24).

To get both branches, Phase 2 ships two policy checks:

- `StaffReadsStudentsInSchool` + `StaffEditsStudentsInSchool` (`FilterCheck`) — emit `school_id in ^member_school_ids` based on the actor's `school_memberships`. Used on `:read`, `:update`, `:destroy`.
- `ActorBelongsToTenantSchool` (`SimpleCheck`) — looks at the changeset's / action input's tenant and returns true when the actor has a `UserSchoolMembership` on that school. Used on `:create` and on CustomList's generic `:run` action.

Phase 2's authorization model is deliberately permissive: any staff with a membership in the tenant school can CRUD students in that school. Teacher-scoped-to-their-classes tightening lands in Phase 10 Teams.

### 3. Bulk tag apply is a custom `change` on Tag, not a separate action on StudentTag

`Tag.apply_to_students` is an update action on Tag that takes a `student_ids: {:array, :uuid}` argument. The `BulkApplyTag` change module runs `Ash.bulk_create/4` on `StudentTag` inside an `after_action` hook and stashes the `Ash.BulkResult` back on the tag's `__metadata__` so the LiveView can surface a "Bulk tag applied; 3 record(s) could not be updated" flash.

Key flags on the bulk call:
- `upsert?: true, upsert_identity: :unique_student_tag, upsert_fields: [:applied_at]` — re-applying a tag is idempotent; we refresh `applied_at` but don't error on the identity collision.
- `stop_on_error?: false, return_errors?: true` — partial failure reports a count, doesn't abort the whole operation.
- `authorize?: false` on the inner bulk — the outer `Tag.apply_to_students` action is already gated by the tenant-scoped `StaffEditsStudentsInSchool` policy. Enabling the inner authorize path triggers a `CaseClauseError` inside Ash's bulk-create authorize code when the policy resolves to a FilterCheck, because the bulk path doesn't handle the 4-tuple return from a filter-returning check. Single gate, enforced at the resource-level action, is the cleaner boundary anyway.

Applying `applied_by_id` via a `force_change_attribute` hook driven off `context.actor` (rather than Ash's `relate_actor`) is deliberate: `relate_actor` sets a relationship that needs to be managed, which the bulk+upsert path also can't handle.

### 4. Status is a denormalized ledger, not a single `current_status` field

`StudentStatus` is an append-only ledger — every `:set_status` call on Student inserts a new row (with `set_by_id` = actor) and clears the previous active row's `cleared_at`. `Student.current_status_id` is a denormalized pointer to the active row, kept in sync by `Changes.SetStudentStatus`.

This costs one extra table + one extra write per status transition but it buys:
- Audit: "who put this student on Watch last April?" is a single query against paper-trail'd StudentStatus rows with the actor on every row.
- Ledger invariant: exactly one active row per student (enforced by `cleared_at IS NULL` filter; identity could tighten this further in Phase 3).
- No data loss on status churn — every transition is preserved.

Rejected alternative: a single `current_status_id` + paper-trail on Student. Works, but the history is embedded in Student's Version rows and harder to query for status-specific questions ("how many kids went Watch → Active last term?").

### 5. CustomList.filters is an embedded FilterSpec Ash resource

Instead of a jsonb blob with no schema, `CustomList.filters` is an Ash embedded resource (`data_layer: :embedded`) with typed attributes: `tag_ids`, `status_ids`, `grade_levels`, `enrollment_statuses`, `name_contains`. It round-trips as jsonb but validates on write — trying to stash `grade_levels: ["12"]` (strings) gets a proper Ash validation error.

`:run` is a generic action on CustomList whose implementation module `RunCustomList` (`Ash.Resource.Actions.Implementation`) loads the list, chains `Ash.Query.filter` calls for each non-empty FilterSpec field, and returns the matching students. Adding a new filter dimension = add an attribute to FilterSpec + a new `apply_<dim>` clause in `RunCustomList`. No migration, no schema ceremony.

`CustomList` also has a private/shared toggle — `shared?: true` makes it visible to every other staff member in the school, `false` makes it owner-only. The read policy is deliberately `owner OR shared?` (no StaffEditsStudentsInSchool fallback) so private means private, not "private-to-every-staff-in-the-school".

## Consequences

**Positive**
- `global?: false` multi-tenancy + policy-per-action-type gives a hard tenant boundary with no "oops we forgot to filter" failure mode.
- Bulk tag apply returns a real `Ash.BulkResult` with `success_count`, `error_count`, `errors` — the LiveView flash tells the user what happened without any custom counting code.
- CustomList.filters is extensible without migrations — every new filter is an attribute on FilterSpec.
- Every tenant-scoped resource is paper-trailed with `school_id` on the Version row — audit queries don't need to join through the source resource.

**Negative**
- Two policy checks for what looks like one concept ("staff edits students in school") means the policy block on each resource has at least two `policy action_type(...)` stanzas. Discoverable via grep, but not obvious at first read.
- Bulk tag apply's `authorize?: false` inside the inner `Ash.bulk_create` depends on the outer action's policy being the real gate. Anyone adding a new entry point that bypasses `Tag.apply_to_students` and calls `Ash.bulk_create(StudentTag, ...)` directly is working around the tenant check.
- StudentStatus is append-only — a chatty status field on a busy student will grow quickly. Phase 3 Hub can paginate history; Phase 10+ can introduce archival windowing if it matters.

## Alternatives rejected

- **Put `status_id` + `tag_ids` directly on Student.** Works for Phase 2 but destroys the audit story — no "who added the IEP tag on 2026-03-04?" answer, no soft-delete/restore story for a removed tag, no per-tag metadata (color changes, etc.).
- **Model tags as an enum instead of a per-school resource.** Fails the "per-school custom tags" requirement — different schools use different vocabularies. A shared enum forces every school to adopt the same taxonomy.
- **FilterSpec as a plain map with a Changeset validation.** Nothing to render an AshAdmin form from, nothing to validate on the API edge, no path to "all custom lists with a tag_id of X" queries. The embedded resource is the cleanest path to all three.
- **Do bulk tag apply with `Enum.map(&Ash.create/2)` + rescue for idempotency.** Functionally equivalent but no `Ash.BulkResult` — the LiveView has to roll its own partial-failure reporting, and we lose batched transactions.

## Follow-ups (future phases)

- Phase 3 Student Hub — clear-status semantics, per-tag metadata (added_by, added_at) surfacing in the UI.
- Phase 4 High-5s + Phase 5 Flags + Phase 6 Supports — those resources hang off Student with their own tenant scoping; the 0-placeholder columns on `/students` fill in as they land.
- Phase 10 Teams — tighten policies from "any staff in school" to "teacher scoped to their assigned classes".
- "Create a new CustomList from the /students filter panel" — Phase 2 ships AshAdmin + seeds for list creation; an in-app save-filter UI lands with the Hub work.
