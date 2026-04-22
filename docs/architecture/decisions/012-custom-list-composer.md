# ADR 012: CustomList composer UI — save / edit / rename / delete filtered views

**Status:** Accepted
**Date:** 2026-04-22
**Builds on:** ADR 004 (Student domain + CustomList resource), ADR 005 (Hub composer pattern), ADR 010 (Insightfull dimension constants), ADR 013 (Insights filter consumption), ADR 014 (Phase 10 LiveComponent + policy precedents).

## Context

Phase 2 shipped the CustomList resource + the `/lists` card grid. Phase 2's deferred-items list called out the missing in-app composer; Phases 3–10 each had higher-priority scope, so the composer kept getting bumped. By the end of Phase 10 the resource works fine — `Students.create_custom_list/3`, `update_custom_list`, `archive_custom_list`, FilterSpec validation, AshAdmin CRUD all in place — but staff have no way to **save a filtered view** without an admin manually editing JSONB in `/admin`.

Phase 10.5 closes the gap. Three outcomes:

1. The `/students` filter bar grows real form controls (tags, status, grade, enrollment) and a "Save view" button.
2. A shared `<.list_composer>` LiveComponent powers both the Save modal on `/students` and the Rename modal on `/lists`.
3. `/lists` cards grow a `⋯` menu with Rename / Edit filters / Delete entries; deletion uses AshArchival via the existing `archive_custom_list` code interface.

## Decisions

### 1. Single shared `<.list_composer>` LiveComponent for create + update

One file, two entry points. `mode: :create` (filter_spec known, list nil) and `mode: :update` (list known, filter_spec optional) branch in `update/2` to build either `AshPhoenix.Form.for_create/3` or `AshPhoenix.Form.for_update/3`. One form, two test surfaces, one set of helpers.

Rejected: separate `SaveModal` + `RenameModal` components. Would duplicate ~80% of the form, summary, validate/submit logic.

### 2. LV assigns are the source of truth for filter state; URL only seeds it

`/students` keeps `@filter_spec` in assigns. `handle_params/3` parses `?from_list=<id>` *once* on mount, loading the saved spec into assigns. After that, the URL is ignored — the bar's `phx-change` events update assigns, and the composer reads `@filter_spec` (never params). This eliminates "stale URL overwrites tweaked filters" bugs when a user lands via Edit filters then changes the bar.

### 3. Filter bar uses `<details>` disclosure, not pills

Tag + status + enrollment use `<.multi_select>` (a `<details><summary>` block with checkboxes). Grade uses `<.checkbox_group>` (a `<details>` with horizontal-flex labels). No JS hooks. Pills (clickable visual chips with `×` to remove) are nicer UX but ~3× the JS surface area; deferred to Phase 12 polish.

### 4. 13 SEL dimension filters stay JSONB-only

The composer's read-only "Filters in this view" summary *includes* dimension filters when set — humanized via `Intellispark.Indicators.Dimension.humanize/1` — so users understand what they're saving. But no form rows for the 13 dimensions. Phase 12 polish adds them. The composer's `@filter_keys` list explicitly enumerates all 20 supported keys (7 base + 13 dimensions) so `non_empty_filters/1` and `filters_to_params/1` cover dimensions too.

### 5. Per-card `⋯` menu uses `JS.toggle/2` + `phx-click-away`, not LV state

No `assign(menu_open?: ...)` per card. Native CSS/JS commands flip a `hidden` class. `phx-click-away` closes when clicked outside. Three menu entries: **Rename** (LV event), **Edit filters** (`<.link navigate>`), **Delete** (LV event with `data-confirm`).

### 6. `data-confirm` for Delete, not a custom modal

Native browser `confirm()` prompts before the LV event fires. Matches the existing pattern on Notes / Actions. AshArchival captures the soft-delete; admin restore is via AshAdmin's "show archived" filter.

### 7. `shared?` stays binary (school-wide); per-user sharing is Phase 15

The Phase 2 read policy is `owner_id == ^actor(:id) or shared? == true`. No per-user grants in v1. FERPA-aware sharing refinement is Phase 15.

### 8. `OwnerOrAdminForCustomList` SimpleCheck — owner OR school admin

Phase 2 limited update/destroy to `expr(owner_id == ^actor(:id))` only. Phase 10.5 widens to either the owner or any admin at the same school, so school admins can clean up lists owned by departed staff. The new policy is a `SimpleCheck` (not a FilterCheck) because the action operates on a known record (`Ash.Changeset.data`), not a list to filter.

Rejected: a third "any-staff-at-school" tier. Custom lists are personal artifacts; non-owner non-admin staff have no business editing them.

### 9. AshArchival via the base resource macro — no new wiring

`Intellispark.Resource` (the project's base macro at `lib/intellispark/resource.ex`) already includes `AshArchival.Resource` for every resource. CustomList already had `archived_at` migrated. The Phase 2 `archive_custom_list` code interface (which previously hard-deleted despite the name) now correctly soft-deletes. Manual recovery path exists through `/admin?show_archived=true`.

### 10. Test wait pattern: `assert_redirect/2` after `render_submit/1`

`send(self(), {Composer, :saved})` from inside a LiveComponent is asynchronous w.r.t. the `render_submit/1` call. `render_submit` returns the post-submit HTML before the parent LV processes the message. Tests that assert on `push_navigate` therefore use `assert_redirect(lv, timeout)` which blocks until the redirect message arrives. Tests that assert on flashes use `render(lv)` after the submit so the message-processed render is captured.

## Consequences

**Positive**
- Counselors save / rename / delete custom lists without touching iex or `/admin`.
- The shared `<.list_composer>` is reusable by Phase 11 (SIS roster auto-saves) and Phase 14 (filter-template seeding).
- AshArchival means no destroyed work — admins can restore through AshAdmin.
- `OwnerOrAdminForCustomList` covers the "departed staff cleanup" case without any tenant-policy churn.
- The filter bar's expanded controls are a foundation Phase 12 builds on (pills + dimension rows).

**Negative**
- The bar disclosure uses `<details>` — not as polished as a real popover with arrow positioning + outside-click handling. Acceptable v1.
- 13 dimension filters are saved/loaded but not editable in the composer form. A user editing filters via `/lists → /students` cannot *remove* a dimension filter through the bar — they'd need iex/admin. Mitigation: `non_empty_filters/1` shows them in the read-only summary so the user at least knows what's there.
- `assert_redirect` requires a timeout — slight test flake risk if the host is overloaded. 1000ms default leaves wide margin.

## Alternatives rejected

- **Two separate components** (Save + Rename) — rejected, ~80% duplication.
- **Pills-based filter bar** — rejected, deferred to Phase 12 polish.
- **URL as filter source of truth** — rejected, causes "tweaked-then-saved-stale-URL" bugs.
- **Dimension form rows in v1** — rejected, would 3× the form size for a feature most counselors won't touch in week 1.
- **Custom confirm modal for delete** — rejected, native `confirm()` is enough; AshArchival means destructive isn't permanent.
- **Per-user sharing in v1** — rejected, FERPA-aware sharing belongs in Phase 15.

## Cross-references

- ADR-004 — Student domain + CustomList resource (Phase 2). Phase 10.5 doesn't touch the resource shape.
- ADR-005 — Hub composer pattern (LiveComponent + parent PubSub reload). Reused by `<.list_composer>`.
- ADR-010 — Insightfull dimension constants. `humanize_filter_key/1` consults `Intellispark.Indicators.Dimension.valid?/1` + `humanize/1`.
- ADR-013 — Insights modal also reads CustomList `filters` for cohort scoping; round-trip fidelity here helps Insights stay accurate.
- ADR-014 — Phase 10 LiveComponent + policy patterns. `OwnerOrAdminForCustomList` mirrors `OwnerOrClinicalRoleInSchool`.
