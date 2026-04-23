# ADR 023: Phase 14 — ScholarCentric + Academic Risk Index + About-the-Student Tab

**Status:** Accepted
**Date:** 2026-04-23
**Builds on:** ADR 009 (Surveys framework), ADR 010 (Insightfull + Indicators), ADR 015 (Hub Tab Framework), ADR 019 (Tiers + Onboarding + Billing Stub), ADR 020 (Phase 3+10 retrofits), ADR 021 (SIS + Xello integration), ADR 022 (Student lifecycle).

## Context

Phase 14 lands the educator-facing "About the Student" pane (the third Hub tab, shipped as a stub in Phase 3.5 + ADR 020), backed by:

- **ScholarCentric resiliency assessments** — a canon-defined survey over six skills (Confidence / Persistence / Organization / Getting Along / Resilience / Curiosity) across three grade bands.
- **Academic Risk Index** — a per-student composite banding of the six skill scores.
- **Intervention library** — per-school configurable catalog of interventions; selecting one creates a Support.
- **Risk Dashboard** (`/students/risk`) — ranked at-risk view.

All Phase 14 resources are **PRO-tier gated**. Starter/Plus schools see tier-CTA placeholders.

## Decisions

### 1. Resiliency lives in a new `Intellispark.Assessments.Resiliency.*` sub-namespace, not a new domain
Reuses `Intellispark.Assessments`. `ResiliencyAssessment` is distinct from `SurveyTemplate` — the question set is fixed + versioned in code (`QuestionBank`), not editable. Surveys (ADR 009) are user-authorable; resiliency is canon-defined. Wiring these into one resource would need an `editable?` flag + policy split — messier than two small resources side by side.

### 2. Six skills, three grade bands, code-defined assessment versions
Skills: `:confidence | :persistence | :organization | :getting_along | :resilience | :curiosity`. Grade bands: `:grades_3_5 | :grades_6_8 | :grades_9_12` — each with 18 questions (3 per skill) in `QuestionBank.@questions`. Version string = `"v1"` — bumped in code when questions are rewritten. `Assessment.version` is stamped at assign time so the scoring worker reads the correct bank even after a version change.

### 3. `AcademicRiskIndex` is a calculation, never stored
Mirrors the Phase 8 `IndicatorLevel` pattern. Reads the 6 latest `SkillScore` rows for a student, computes mean, bands to `:low | :moderate | :high | :critical`. Always consistent across the Hub, Risk Dashboard, and any future reports. No cache invalidation. If the Risk Dashboard ever grows past ~5k rows, we promote to a DB-side calculation via `Ash.Query.calculate/3`.

Thresholds (tunable):
- `mean >= 3.75` → `:low` (low risk)
- `2.5 <= mean < 3.75` → `:moderate`
- `1.25 <= mean < 2.5` → `:high`
- `mean < 1.25` → `:critical`

Same 0-5 Likert scale as IndicatorScore (ADR 010).

### 4. Contributing factors = up to 2 lowest non-high skills
Exposed as `contributing_factors :{array, :atom}` calculation on `Student`. Empty list when the index is `:low`. Readers format via `humanize_skill/1` on the web layer. Stable sort by `(score_value asc, skill atom asc)` so the pair doesn't churn when scores are tied.

### 5. Intervention library is a per-school resource, not a global lookup
Different schools have different MTSS-tier catalogs (state-mandated or district-defined). School admins seed their library via AshAdmin; no default ships. `InterventionLibraryItem` holds `title`, `description`, `mtss_tier` (`:tier_1 | :tier_2 | :tier_3`), `default_duration_days`, `active?`. Modal queries with `active? == true`.

### 6. `Support.:create_from_intervention` is a distinct action, not an argument on `:create`
Because the `PrefillFromIntervention` change module needs to read the library item (via `Ash.get` inside the change) and stamp `intervention_library_item_id` on the new Support for traceability. Keeping `Support.:create` untouched means existing callers don't regress.

### 7. Risk Dashboard lives at `/students/risk`, not as a tab on `/students`
Separate LiveView. Different query shape (sorted by risk band), different filters (skill contributor), different intended audience (clinical roles only on PRO). Mixing it into the main roster filter bar would explode the filter surface. A "View Risk Dashboard →" link on `/students` for PRO actors connects the two.

### 8. Tier gating happens at two layers: policy + render
Policies on `ResiliencyAssessment.:assign`, `InterventionLibraryItem` writes, `Support.:create_from_intervention`, all reject non-PRO actors (via `{RequiresTier, tier: :pro}` as a separate policy block — AND-semantics with the role check, matching the Phase 11 Xello pattern). Separately, the Hub LV's About tab checks `current_school.subscription.tier == :pro` at render time and skips ScholarCentric zones with a CTA placeholder. Defense in depth.

### 9. Oban worker pattern for scoring, mirroring Phase 8
`SkillScoreWorker` (queue `:indicators`) triggered by `Assessment.:submit` via an `after_action` hook that `Oban.insert!`s a job. Reads responses, groups by skill via `QuestionBank.skill_for_question/3`, upserts 6 `SkillScore` rows by `(student_id, skill)` identity. Idempotent — re-running produces no duplicates.

### 10. Suggested-cluster vocabulary is a compile-time module constant
`@personality_vocab` in `show.ex` maps Holland codes (`"helper"` → `{"Helper", "Social"}`). Unknown codes render as `{capitalized_key, "—"}`. No DB, no resource. If customers need customization, we revisit.

### 11. Hub About tab subscribes only to Xello + resiliency PubSub topics
`xello_profiles:student:<id>` + `resiliency_skill_scores:student:<id>`. `reload_about/1` re-queries the two data sources on broadcast. Other student updates don't trigger About-pane reloads.

### 12. Adding `completed_lessons :{array, :string}` to `XelloProfile`
Not in the original Phase 11 schema. Small one-column migration. Count in the Hub = `length(profile.completed_lessons)`. Max lessons per year in ScholarCentric's program = 8 (one per month Sep-Apr), mirrored by the "N of 8" Hub display.

## Consequences

- Phase 14 exit criteria in `build-plan-ash.md` flip to ✅.
- `README.md` gains a "Phase 14 — ScholarCentric & About-the-Student" section.
- Test count: 508 baseline → **552 green** (+44): 18 resiliency + 8 calculations + 6 interventions + 5 About tab LV + 3 intervention modal + 4 Risk Dashboard LV.
- Tag `v0.14.0-scholarcentric-complete` placed after 8 commits.
- Future work (deferred): historical trend charts (Phase 17), parent self-service view (Phase 15), automation hooks (Phase 12), bulk intervention assignment.

## Cross-references

- ADR 009 — why resiliency is a new resource, not a `SurveyTemplate` flavor (§1)
- ADR 010 — `IndicatorLevel` scoring pattern this mirrors (§3, §9)
- ADR 015 — `:about` tab atom pre-wired in `Tabs` module (§11)
- ADR 019 — `RequiresTier` SimpleCheck reused (§8)
- ADR 020 — `KeyConnection.source: :self_reported` (used on About tab side column)
- ADR 021 — XelloProfile webhook pipeline + Cloak vault (§12)
- ADR 022 — policy AND-semantics pattern + lifecycle ADR template (§8)
- `markdowns/phase-14-scholarcentric-about-student.md` — detailed implementation plan + todo list
