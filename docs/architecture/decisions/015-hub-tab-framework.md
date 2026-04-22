# ADR 015: Hub Tab Framework — URL-driven tab strip replacing flag/support sheets

**Status:** Accepted
**Date:** 2026-04-22
**Builds on:** ADR 005 (Student Hub layout — original), ADR 006 (Flag workflow — sheet pattern being replaced), ADR 013 (Insights modal — comparable URL-driven view), ADR 014 (Phase 10 LiveComponent patterns).

## Context

The Phase 3 Hub renders the Profile pane (3-column panel grid + activity card) as the only view of a student. Phases 4 + 5 added side-sheets (`FlagDetailSheet`, `SupportDetailSheet`) docked on the right edge of the viewport when a flag or support row is clicked — partially obscuring the panels and not bookmarkable.

The 2026-04-21 screenshot review shows a different pattern in the real product:

- A tab strip directly under the header card with `Profile` always pinned, plus dynamically opened entity tabs (e.g. `Flag: Internet access issues`, `About the Student`)
- Active tab gets a colored bottom border + tinted icon
- Clicking a non-Profile tab swaps the **entire main pane** below the strip — content swap, not overlay
- Browser back/forward navigates between tabs
- The strip will also host Phase 11/14's `About the Student` (Xello) tab

Phase 3.5 lands the framework. The Phase 4 retrofit (and future Phase 11/14 tabs) drop tabs in instead of inventing new mechanics.

## Decisions

### 1. URL is the source of truth for tab state

`?tab=` query param drives `@active_tab` + the open-tabs list. `handle_params/3` is the only place that reads the param; all event handlers `push_patch/2` to a new URL and let `handle_params` update assigns. Bookmarks, shareable links, browser back/forward all work for free.

### 2. One pinned `Profile` tab + a dynamic `@open_tabs` list

`@open_tabs` is a list ordered by open-time, never including `:profile`. Re-clicking an already-open tab just `push_patch`es to its URL; doesn't reorder. Adding a tab dedupes by `==` equality.

### 3. Whitelist atom-from-string for tab kinds

Never `String.to_atom/1` on user input. The four valid kinds (`:profile`, `:about`, `{:flag, uuid}`, `{:support, uuid}`) are constructed in `Tabs.from_param/1` via explicit pattern matches; UUID is validated through `Ecto.UUID.cast/1` before constructing the tuple. Garbage input falls back to `:profile` silently.

### 4. Mobile keeps the side-sheet (CSS-only switch)

On `<md` viewports the existing `FlagDetailSheet` + `SupportDetailSheet` LiveComponents still render (wrapped in `<div class="md:hidden">`); the tab strip is hidden and a "← Back to Profile" link is shown when not on Profile. On `md:`+, the sheets hide and the tab pane handles the same data. Same data, two render paths — acceptable for v1.

### 5. Backward-compat shims for legacy sheet event handlers

`open_flag_sheet` / `close_flag_sheet` / `open_support_sheet` / `close_support_sheet` event handlers are aliases that delegate to the new `open_tab` / `close_tab` flow. Tagged with `# DEPRECATED: remove in Phase 4 retrofit`. This keeps existing tests passing while the framework lands.

### 6. Pane components duplicate sheet content rather than share

`FlagDetailPane` is a copy of `FlagDetailSheet` minus the `<aside class="fixed">` wrapper and close button. Same `update/2`, same handlers, same helpers. Trying to abstract a shared body component would mean a third file and indirection for marginal benefit. The duplication will retire when the sheets do (Phase 16 mobile refresh).

### 7. Generic tab labels in v1 ("Flag detail", not "Flag: Internet access issues")

Resolving the flag-type name into the tab label requires a resource lookup at strip-render time — either passing the resolved entity into the strip or making the strip a `LiveComponent` with its own `update/2`. Both add weight that v1 doesn't need. Richer labels deferred to a later polish pass.

### 8. Tab close falls back to `:profile`, never to a sibling tab

When the active tab closes, the next active is `:profile`. The remaining sibling tabs stay in `@open_tabs` but none is auto-promoted. This avoids "which sibling did I just navigate to?" confusion.

### 9. `push_patch/2` (not `push_navigate/2`) for in-Hub navigation

`push_patch` keeps the LV mounted and PubSub subscriptions alive. `push_navigate` would remount the LV, re-fetch the student, and momentarily flash the table. Tabs are intra-Hub navigation, so patching is correct.

### 10. `handle_params/3` is wired with a `sync_legacy_sheet_assigns/2` shim

The Phase 4 sheet renders only when `@flag_detail_open?` and `@active_flag_id` are set. Until the sheet retires, those assigns must stay in sync with `@active_tab`: when the tab is `{:flag, id}`, both `flag_detail_open?: true` and `active_flag_id: id` are set. When the tab is `:profile` or anything else, both are cleared. One private helper handles the sync to keep the legacy mobile sheet rendering correctly.

## Consequences

**Positive**
- Bookmarkable URLs for any tab. `/students/<id>?tab=flag:<flag_id>` works for sharing or re-opening.
- Browser back/forward is free.
- Phase 11 (Xello) + Phase 14 (ScholarCentric) drop their `About the Student` tab into a working framework with no new infrastructure.
- Backward-compat shims mean no Phase 4 regressions during the framework rollout.
- Pure URL parser (`Tabs`) is unit-testable with no LV harness.

**Negative**
- Pane vs sheet duplication doubles maintenance for Flag + Support detail until the sheets retire. Mitigated by the duplication being mechanical (no logic divergence) and the sheets being scheduled for retirement.
- Tab strip renders generic labels in v1; users see "Flag detail" not "Flag: Internet access issues". UX regression vs the screenshots until richer labels land.
- `@open_tabs` could grow without bound if a user opens many flags. Acceptable for v1; Phase 14 polish can cap to 5 with overflow `…` menu.
- `handle_params/3` shim coupling the new `@active_tab` to the legacy sheet assigns is technical debt that retires when the sheets do.

## Alternatives rejected

- **State-driven tabs (no URL).** Rejected — loses bookmarking + back-button.
- **Per-resource shim handlers** (each entity type owns its own `open_xxx_tab`). Rejected — single `open_tab` event with a `kind` param scales cleaner.
- **Replace the side-sheet entirely on day one (no mobile fallback).** Rejected — narrow viewports can't host a full content swap comfortably; the bottom-sheet/drawer pattern is the right mobile UX. Defer the mobile redesign to Phase 16.
- **Make `TabStrip` a `LiveComponent` with its own state.** Rejected — strip rendering is a pure function of `@active_tab` + `@open_tabs`; LiveComponent overhead isn't justified.
- **`String.to_atom/1` on `params["tab"]`** for kind dispatch. Rejected — atom DoS vector.

## Cross-references

- ADR-005 — original Hub layout. Phase 3.5 wraps the existing Profile pane in `<.hub_pane>` without changing its content.
- ADR-006 — Flag workflow + sheet introduction. The pane lifts content from the sheet verbatim.
- ADR-013 — Insights modal. Comparable URL-driven LV state pattern (uses `?dimension=`).
- ADR-014 — Phase 10 LiveComponent + policy precedents. Same `live_component` pattern.
