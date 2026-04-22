# ADR 013: Insights view — 13-dimension analytics with donut chart + CSV export

**Status:** Accepted
**Date:** 2026-04-22
**Builds on:** ADR 002 (multitenancy), ADR 004 (Student domain), ADR 010 (IndicatorScore resource + 13 calculations).

## Context

Phase 8 wrote scored per-student per-dimension rows. Phase 9 reads them and renders the analytics surface observed in screenshot `10-13-08` — a full-screen "Insights" view with a 13-dimension sidebar, an individual breakdown table, and a donut chart summary of how a cohort distributes across Low/Moderate/High.

Three entry patterns need to work:
- Select N students on `/students` → bar-chart icon in bulk toolbar → cohort is those N
- Open `/lists/:id` → "View insights" header link → cohort is students in that saved filter
- Direct `/insights` URL → cohort is the entire school

Plus a CSV export per dimension for district compliance reports.

## Decisions

### 1. `/insights` is a full LiveView route, not a live_component modal

The screenshot looks modal — centered card, dimmed backdrop, `×` close — but implementing it as a route avoids nested-LV state gymnastics + preserves back-button + URL-is-truth semantics. The visual modal effect comes from `<section class="fixed inset-0 z-50 bg-abbey/40 overflow-auto">` wrapped around a `max-w-6xl` card.

### 2. Three cohort sources via query params

`?student_ids=<csv>` (bulk selection), `?list_id=<uuid>` (CustomList run), no params (school-wide). One LV handles all three via a 3-clause `resolve_student_ids/3` pattern match in `handle_params/3`. Keeps the URL the authoritative source of cohort state.

### 3. Dimension selection via `push_patch` on query param

Clicking a sidebar dimension button does `push_patch(to: ~p"/insights?<params+dimension>")` rather than a private socket assign. This gives us:
- Deep-linkable URLs (`/insights?dimension=well_being&list_id=...`)
- Browser back/forward works
- Dimension state isn't lost on remount

### 4. Data layer = two pure helpers, not a custom Ash read action

`Intellispark.Indicators.summary_for/3` + `individual_for/3` are plain functions with tenant-scoped queries. Phase 8's 13 calculations on Student do the heavy lifting (`Ash.Query.load([:display_name, dim])` fetches name + level in one batch). Simpler than grouped aggregates + custom Ash actions for this shape. If Phase 12 adds trend-over-time reads, a custom action may become warranted.

### 5. Donut chart is pure SVG (no library), pre-computed paths

`IntellisparkWeb.UI.Donut` computes arc paths in Elixir using `:math.sin/cos/pi` and renders them as `<path>` elements. Zero JS dependencies, ~100 lines of component code, accessible via `role="img"` + `<title>` + `aria-label` summarising the counts. Segment colors reference the existing indicator CSS custom properties — matches the `<.level_indicator>` chips.

### 6. CSV export is a plain Phoenix controller + `send_resp`

Not a LiveView download dance. `GET /insights/export.csv` lives in `InsightsController`, uses `NimbleCSV.RFC4180.dump_to_iodata/1` to build iodata, and `send_resp(200, iodata)` with `content-disposition: attachment; filename="insights-<dim>-<date>.csv"`. Reuses the same `resolve_student_ids/3` + `resolve_dimension/1` helpers the LV uses (copy-pasted for now; both are ~10 lines — if a third consumer emerges, extract).

### 7. `authorize?: false` on the data helpers — tenant filter is the security boundary

The LV and controller both verify the actor via the `:browser` pipeline. Student_ids passed in the query param are filtered through `Ash.Query.set_tenant(school.id)`, so even a user hand-crafting a URL with another school's student UUIDs gets an empty result. This mirrors Phase 6's Hub rendering pattern.

### 8. Unscored students appear in the individual table as "— not measured"

Rather than hiding rows without scores, we render every student in the cohort with a dimmed placeholder chip. This matches the Hub panel's design (Phase 8 ADR-010 decision 11) and surfaces "who needs a survey sent" as part of the analytics surface. The `unscored` count is also rendered as "Not yet measured: N" below the legend when non-zero.

### 9. One dimension at a time (no multi-dim comparison)

Matches the real product's constraint — the screenshot shows a single dimension's breakdown. Saves us from building a pivot-table UI that doesn't exist in the reference app. Phase 12 polish can revisit.

## Consequences

**Positive**
- CSV export is a simple `GET` URL users can share or bookmark. No "download button dance."
- All three cohort modes share one LV — maintenance is proportional to the logic, not the entry points.
- Donut component is reusable for Phase 14 ScholarCentric's Resiliency score breakdowns.
- `push_patch` URL contract means Phase 12 can add "saved insight views" by just bookmarking the current URL.
- Phase 8's Student calculations are exactly the right abstraction — no new queries, no new aggregates.

**Negative**
- `?student_ids=<csv>` URLs grow with cohort size (~18KB for 500 students). Past ~2000 we'd hit URL limits; the `?list_id=<uuid>` path is the workaround at scale. Phase 10.5's CustomList composer makes this the natural entry for large cohorts.
- School-wide mode fetches every student in the tenant. For a 500-student school that's fine (~100ms); at multi-district Phase 11 scale we'll want pagination or cohort-first flows.
- No caching — two queries per dimension switch. Fast at current scale; Phase 17 observability will revisit.
- Donut arcs use CSS custom properties via `var()`, which means the SVG doesn't render correctly if opened standalone outside the app. Acceptable — it's only ever embedded in the LV.

## Alternatives rejected

- **Use a charting library (Chart.js / Recharts-style).** Rejected — 80KB of JS for a feature that renders in 100 lines of SVG. No interactivity needed beyond the sidebar switcher.
- **Render as a live_component modal on `/students`.** Rejected — URL truth, back button, and bookmarkable state all mean a route is simpler.
- **Custom `:insights_for_list` Ash read action with grouped aggregates.** Rejected — Phase 8 calculations + one frequencies_by are equally idiomatic and simpler to test.
- **LiveView-based CSV download via `push_event` + client JS.** Rejected — `send_resp` in a controller is 20 lines simpler and works without JS.
- **Per-dimension policy scoping.** Rejected — Intellispark's product model grants all-or-nothing access per student. FERPA scoping is at the Student read layer (Phase 10 Teams refines this).

## Cross-references

- **ADR-010** — IndicatorScore resource + 13 Student calculations that this view consumes.
- **ADR-012** — CustomList composer (Phase 10.5) introduces the `/lists/:id` runner that hosts the "View insights" header link.
- **Phase 11 (future)** — SIS integration might seed multi-school cohorts; this view's school-wide mode is the initial UI for district-level analytics before Phase 11 adds cross-tenant aggregates.
