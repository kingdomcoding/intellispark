# ADR 010: Insightfull survey + 13 SEL dimensions + IndicatorScore pipeline

**Status:** Accepted
**Date:** 2026-04-22
**Builds on:** ADR 002 (multitenancy), ADR 004 (Student domain), ADR 006 (Flag workflow — notifier + Oban pattern), ADR 007 (FilterCheck + custom Oban digest), ADR 008 (token-based public view + `Ash.bulk_create`), ADR 009 (surveys framework).

## Context

Phase 8 ships the first **scored** survey — the Insightfull SEL assessment — and the **13 SEL dimension indicators** that render on the Student Hub's "Key SEL & Well-Being Indicators" panel. Phase 7 put the generic survey machinery in place; Phase 8 adds the scoring layer + a new resource for scored output + 13 Ash calculations that expose per-dimension levels as attributes on Student.

The panel at screenshot `10-04-19` is the product-level acceptance target: a 2-column grid of filled pill chips (red-pink Low / amber Moderate / green High) labelled by dimension name. Phase 3 stubbed this section; Phase 8 populates it from real submissions.

This is also the foundation for Phase 9's Insights modal. Everything Phase 9 reads — per-student per-dimension rows, grouped aggregates for the donut, cross-cohort breakdown — flows out of the `IndicatorScore` resource Phase 8 introduces.

## Decisions

### 1. IndicatorScore as a sibling resource (not embedded on Student)

Each `(student_id, dimension)` pair becomes one row in `indicator_scores`. Benefits:

- **History via AshPaperTrail** — Phase 12 longitudinal "Chris's Belonging over time" query works out of the box.
- **Upsert by `(student_id, dimension)` identity** — `mix indicators.recompute` is trivially idempotent.
- **Traceability** — `source_survey_assignment_id` ties each score to the submission that produced it.
- **Cross-cohort aggregates** — Phase 9's donut is a one-line grouped aggregate over IndicatorScore; embedding 13 fields on Student would force a 13-column pivot query.

### 2. Dimension as a module constant, not a table

`Intellispark.Indicators.Dimension` holds the canonical 13-atom list + humanisation map. Rationale: the taxonomy is product-level, not per-school tenant-level. Exposing it as a resource would invite admin editability that we explicitly don't want — adding a 14th dimension should require a code change + migration, not a runtime insert. This matches Phase 7's `question_type` enum precedent (no `question_types` table).

### 3. Pure scoring + deferred to an Oban worker (not synchronous on submit)

`SurveyAssignment.:submit` has three existing change steps (validate required, set submitted_at, transition state). Phase 8 adds a fourth after_action that enqueues `ComputeIndicatorScoresWorker`. Rationale:

- Submit latency stays tight — no 13-dimension SQL fan-out blocking the student's LiveView.
- Oban gives us retry semantics for free (scoring is idempotent; retries are safe).
- The scoring module itself is pure — `Scoring.score_responses/2` takes a template version + responses and returns a list of maps. Easy to property-test.

### 4. Thirteen compile-time-unrolled calculations on Student

`student.belonging` returns `:low | :moderate | :high | nil` as if it were a plain attribute. The alternative — one parameterised calculation (`student.indicator_level(:belonging)`) — would be cleaner at definition time but worse at every call site (LV templates, filter expressions, aggregate compositions).

Ash's `calculate` macro doesn't support `unquote` inside a comprehension, so the 13 entries are enumerated explicitly. 13 lines of code that each read the same shape — acceptable for the ergonomic win at call sites.

### 5. Threshold constants (2.5 / 3.75) documented + property-tested

`@low_threshold 2.5` → below is `:low`. `@high_threshold 3.75` → at or above is `:high`. Everything in between is `:moderate`. Properties:

- **Boundary behaviour** — scores of exactly 2.5 land in `:moderate`; 3.75 lands in `:high`.
- **Monotonicity** — StreamData property test asserts `bucket(lo) <= bucket(hi)` for any `lo <= hi` under the ordering `:low < :moderate < :high`.
- **Full-coverage invariant** — answering every question with value `n` (1-5) yields `bucket(n * 1.0)` for every dimension.

Phase 14 (ScholarCentric) + Phase 15 (security hardening) can revisit these thresholds per grade-band without changing the resource schema.

### 6. Explicit `:indicators` Oban queue

Separate from `:emails` and `:notifications`. Rationale: indicator jobs are CPU-ish (read responses, compute mean, upsert 13 rows), whereas emails are I/O-bound on Resend. Decoupling the queues lets us tune retry/backoff independently. Queue size 10.

### 7. FilterSpec 13-dim extension + `exists()` filter

CustomList filtering by indicator level uses Ash's `exists/2` over the `indicator_scores` relationship — pushdown to SQL via a correlated subquery. The alternative (filter by calculation directly) can't pushdown because `IndicatorLevel` is a module-based calculation that runs in Elixir.

```elixir
Ash.Query.filter(query, exists(indicator_scores, dimension == ^dim and level == ^level))
```

13 explicit attributes on FilterSpec. One `apply_dimension_filters/2` reducer over `Dimension.all()`.

### 8. 26-item Insightfull seed (2 items per dimension)

The plan cites "2–4 items per dimension for reliability." 2 is the floor for a demo — enough for scoring, cheap to answer, easy to seed. Wording draws from CASEL-adjacent public item banks (not copied verbatim from any specific instrument). Phase 12 polish can grow the bank toward 4 per dimension if reliability tuning demands it.

### 9. Chip tooltip deferred to Phase 9

The panel renders chip + label only. Tooltip with "Belonging — Low (from 2 of 2 answered) · computed Apr 22, 2026 from Insightfull" is Phase 9 scope because the Insights modal is the full-resolution provenance view. Keeping Phase 8 tight — just the chip grid — avoids scope creep and matches the real Intellispark's panel UX.

## Consequences

**Positive**
- Phase 9 (Insights modal) lands on a clean data shape — per-student per-dimension rows, grouped aggregates work as-is, CSV export is a one-liner.
- `mix indicators.recompute` rescues any future scoring-algorithm change — idempotent by construction.
- Submit-to-indicator latency is ~100ms end-to-end on dev (student's "Thanks for your response!" screen + Hub chips update via PubSub without manual refresh).
- The scoring module is pure — any future ML-style scoring (weighted items, per-grade-band norming, skip-pattern adjustments) slots into `Scoring.score_responses/2` without touching the resource layer.
- Property tests catch boundary regressions automatically.

**Negative**
- The 13 explicit `calculate` entries on Student bloat the resource module. Phase 14 adds 6 more dimensions (ScholarCentric's resiliency skills) — at some point a parameterised calculation may be warranted. Accepted for now because call-site ergonomics matter more than definition-site terseness.
- Scoring fans out one Oban job per submit. Not a concern at demo scale; at multi-district Phase 11+ scale with simultaneous roster-wide Insightfull sends, the `:indicators` queue needs a rate-limit plug.
- IndicatorScore.Version grows unbounded with every recompute. Phase 15 needs a retention policy (e.g., keep versions >= 90 days + one per quarter beyond that).
- The 26-item bank is thin for real SEL validity. Demo-only; not a production-ready instrument.

## Alternatives rejected

- **Embed 13 fields directly on Student.** Rejected — kills longitudinal history + forces a 13-column pivot whenever recompute changes.
- **AshOban trigger on `:submit` instead of explicit after_action + worker.** Rejected — the trigger scheduler is built for cron/scan patterns; one-shot-per-action is cleaner as an after_action. Explicit insertion also makes `Oban.Testing.perform_job/2` trivial in tests.
- **Parameterised single calculation on Student (`indicator_level(:belonging)`).** Rejected — `student.belonging` is worth more at call sites than 12 lines saved in the resource.
- **Run scoring synchronously in the submit change.** Rejected — submit latency would include 13 INSERT…ON CONFLICT roundtrips + all the PaperTrail version writes. Defer to Oban.
- **Filter CustomList via the calculation directly (no relationship).** Rejected — `IndicatorLevel` doesn't have an `expression/2` so it can't pushdown to SQL; `exists()` over the has_many does.
- **Storing a single JSONB blob of all 13 scores on Student.** Rejected — same problem as embedding fields, plus concurrent-update complications.
- **Re-scoring on every GET of Student.belonging.** Rejected — scoring is not free (template-version fetch + response read + upsert), and the result is deterministic given the same inputs. Cache via IndicatorScore row.

## Cross-references

- ADR-002 — multi-tenancy; IndicatorScore inherits `global?: false`.
- ADR-004 — Student domain; 13 new calculations live on Student.
- ADR-006 — Flag workflow's notifier → Oban pattern is the same shape reused here.
- ADR-007 — Phase 5 FilterCheck + custom Oban digest; reused for the 13-dim CustomList filter pattern.
- ADR-008 — `Ash.bulk_create` with `notify?: true`; not directly reused but the scoring `Ash.create!` + upsert_identity combines cleanly with it.
- ADR-009 — surveys framework; Phase 8 extends `SurveyQuestion` with `:dimension_rating` and wires `:submit`'s after_action to enqueue the scoring worker.
