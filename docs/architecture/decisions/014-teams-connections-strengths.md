# ADR 014: Team Members, Key Connections, Strengths + teacher-class read scoping

**Status:** Accepted
**Date:** 2026-04-22
**Builds on:** ADR 002 (multitenancy + policies), ADR 004 (Student domain), ADR 007 (FilterCheck pattern), ADR 010 (`Ash.bulk_create` + notify? pattern).

## Context

Phase 10 ships three independent relational structures that hang off a Student and one major policy change:

1. **`TeamMembership`** — staff assigned to a student's team (role-qualified: teacher / coach / counselor / social_worker / clinician / family / community_partner / other). Phase 11 rosters will feed this via the idempotent `add_members_from_roster` bulk action.
2. **`KeyConnection`** — meaningful staff-student relationships with provenance note. Sources are `:self_reported` (from a survey) or `:added_manually` (from a staff user on the Hub). Phase 14 will generalise `connected_user_id` to a polymorphic connected-person reference for family + community contacts.
3. **`Strength`** — free-text student strengths with auto-assigned `display_order` for bullet-list ordering.

And the scoping change: **teachers** now see only the students they're on the team of. Admins + clinical roles (counselor, social_worker, clinician, psychologist) bypass this filter and see every student in the school.

## Decisions

### 1. Three separate resources, not one polymorphic "relationship" table

Each concept has distinct state and motion. TeamMembership has a role enum + source + permissions_override; KeyConnection has a note + source; Strength is a description + display_order. Flattening them into one `student_relationships` table with a `kind` discriminator would force every new attribute to nullable-for-other-kinds and kill query hygiene. Three tables, three identities, three policies.

### 2. `TeamMembership.role` is an enum, not a FK to a roles table

Eight roles are product-level vocabulary (teacher / coach / counselor / social_worker / clinician / family / community_partner / other), not per-tenant editable. Same reasoning as ADR 010's Dimension constant: roles should change with code + migration, not runtime inserts.

### 3. Teacher scoping via `FilterCheck` on Student, chained with a `SimpleCheck` bypass

Student's `:read` policy is:

```elixir
policy action_type(:read) do
  authorize_if AdminOrClinicalRoleInSchool   # SimpleCheck — bypass
  authorize_if TeacherOnlySeesTeamStudents   # FilterCheck — restricts teachers
end
```

OR semantics: if either authorises, the read proceeds. Admins + clinical staff short-circuit at the SimpleCheck; teachers fall through to the FilterCheck which emits `exists(team_memberships, user_id == ^actor.id)` — a correlated subquery pushdown.

`FilterCheck` is the right tool for this because we're **filtering a list** of rows, not rejecting an action outright. A `SimpleCheck` returning `false` for teachers would block them from reading *any* students, even ones they're on the team of.

### 4. Creates use `SimpleCheck`, not `FilterCheck`

Strength's create action initially used `StaffEditsStudentsInSchool` (FilterCheck) and failed at runtime: `CannotFilterCreates` — FilterCheck can't filter nonexistent rows. Fix: split the policy — create uses `ActorBelongsToTenantSchool` (SimpleCheck); update/destroy stay on FilterCheck. Same pattern reused for TeamMembership + KeyConnection write policies via `CounselorOrAdminForStudent` (SimpleCheck).

### 5. `StampAddedBy` change as a cross-resource reusable

TeamMembership, KeyConnection, and Strength all stamp `added_by_id` from the actor. One `Ash.Resource.Change` module, three `change StampAddedBy` lines. Matches Phase 5's `SetAuthor` pattern for Notes.

### 6. `Strength.display_order` auto-assigned in Elixir (not a DB sequence)

`DefaultDisplayOrder` reads the max existing order for the student + sets `max + 1`. Ran in the change module before insert — cheap (one indexed lookup), idempotent, and lets callers override by passing `display_order` explicitly. Alternative (DB-level sequence) would require per-student partitioning logic and doesn't compose with multitenancy.

### 7. `add_members_from_roster` uses `Ash.bulk_create` with `upsert_identity`

Phase 11 will call this with a list of staff user_ids when a teacher picks up a new class. Upsert semantics on `(school_id, student_id, user_id, role)` make re-syncs idempotent — the same SIS feed can fire hourly without duplicating rows. `source: :roster_auto` distinguishes roster-driven rows from manual Hub additions.

### 8. Hub panels use role-grouped lists, not a single flat table

Team Members panel splits memberships into three visual groups: Current Teachers (role == :teacher), Family (role == :family), Other Staff (everything else). Matches screenshot `10-08-17` and gives each audience (teachers, parents, specialists) a predictable read. `group_key/1` is a one-line classifier.

### 9. Strengths + Key Connections in a 2-column grid; Team Members in the main column

The main column holds "primary" structured data (notes, high fives, indicators, team). The right column holds "secondary" context (forms & surveys, strengths, connections). The 2-col grid on the right column matches the real Intellispark's spacing at `md:` and above.

## Consequences

**Positive**
- Teacher class scoping lands with one FilterCheck (15 lines) + one SimpleCheck (20 lines) — minimal blast radius.
- `add_members_from_roster` is Phase-11-ready — a one-line call from a roster sync worker.
- Three panels + three modals follow the established Phase 5 / 7 / 8 pattern (live_component + parent PubSub reload); no new UI primitives needed.
- Timeline gains three new event kinds for free — PaperTrail's Version resources are already per-resource, so `load_timeline/2` just appends three more `Ash.Query.filter |> read!` branches.

**Negative**
- Teachers scoped out of the Student list can still hit `/students/:id` directly by URL; the FilterCheck correctly returns empty but the redirect-with-flash UX relies on the Hub's mount-time `with`. Works today; deliberate — logs + flash are enough for demo.
- `Strength.display_order` gap-fills aren't handled — deleting strength #2 of [1,2,3] leaves [1,3]. Acceptable for now; compact-on-delete can be a Phase 12 polish.
- `KeyConnection.connected_user_id` is a belongs_to to User — Phase 14 will need a migration + polymorphic lift to reach family + community contacts.
- `AdminOrClinicalRoleInSchool` duplicates the tenant-extraction boilerplate from `ActorBelongsToTenantSchool`. Tolerated; consolidating would hide tenant-check semantics behind indirection.

## Alternatives rejected

- **Single `StudentRelationship` polymorphic table.** Rejected — kills query hygiene + forces every new attribute to be nullable for unrelated kinds.
- **Teacher scoping via a SimpleCheck only (hide-list strategy).** Rejected — would need a second filter hook on `list_students` to actually remove rows, doubling the surface area.
- **Store team roles as a join to a `team_roles` resource.** Rejected — eight product-level values; a table invites per-school editability we don't want.
- **Auto-assign display_order via a DB sequence.** Rejected — sequences aren't per-student-scoped without partitioning tricks, and the Elixir-side max-plus-one is a single indexed query.
- **Synchronous notifier from `add_members_from_roster` to refresh each Hub.** Rejected — the resource's `publish_all` handles this; `notify?: true` on `Ash.bulk_create` fans it out correctly.

## Cross-references

- ADR-002 — multitenancy (all three resources are attribute-tenanted on `school_id`) + policy primitives.
- ADR-004 — Student domain; three new `has_many` relationships + updated read policy.
- ADR-007 — FilterCheck pattern reused for TeacherOnlySeesTeamStudents + StaffEditsStudentsInSchool.
- ADR-010 — `Ash.bulk_create` with `notify?: true` reused by `add_members_from_roster` + `TeamBulkModal`.
