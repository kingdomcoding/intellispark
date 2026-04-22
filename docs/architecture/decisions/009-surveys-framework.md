# ADR 009: Surveys framework — versioned templates + token-based student access + auto-save responses

**Status:** Accepted
**Date:** 2026-04-21
**Builds on:** ADR 002 (multitenancy), ADR 004 (Student domain), ADR 006 (Flag workflow — notifier + Swoosh sender pattern), ADR 007 (Phase 5 FilterCheck + custom Oban digest), ADR 008 (token-based public view + `Ash.bulk_create` with partial-failure reporting).

## Context

Phase 7 ships the generic survey framework + the first concrete survey ("Get to Know Me", 9 free-text + choice questions). Counselors assign surveys to a student or to a roster cohort; the student receives an emailed magic-link, lands on an Insightfull-branded gradient page, answers one question per page with auto-save, and submits.

This is the foundation for Phase 8's SEL-dimension scoring (the Insightfull survey + the 13 indicators). The contract Phase 8 will rely on: a `SurveyAssignment` carries a stable pinned `SurveyTemplateVersion`, and `SurveyResponse` rows are upserted by `(assignment, question)` so partial completion survives browser-tab loss.

## Decisions

### 1. Five resources — Template + Question + TemplateVersion + Assignment + Response

`SurveyTemplate` is the mutable draft. `SurveyQuestion` belongs to the template. `SurveyTemplateVersion` is the immutable snapshot taken at `:publish`. `SurveyAssignment` pins to a `SurveyTemplateVersion` so in-flight assignments survive template edits. `SurveyResponse` is the per-question answer.

Splitting versioning into a side-car (rather than reconstructing from `SurveyTemplate.Version` paper-trail rows) lets the public LiveView fetch the entire question schema in one read of the pinned version's JSONB column — no joins, no per-question paper-trail walk.

### 2. Template versioning via JSONB schema column

`SurveyTemplateVersion.schema` is a JSONB blob containing the entire template tree (template metadata + questions in position order). `:publish` builds the snapshot inside a `Change` and writes it. The student-facing LiveView mounts by hydrating `survey_template_version`, then iterates `schema["questions"]` directly — avoiding per-render N+1 reads.

### 3. Assignment state machine — `:assigned → :in_progress → :submitted` with `:expired` as dead-letter

Same shape as Phase 4 Flags but simpler. `:save_progress` action self-transitions `:assigned → :in_progress` on first save; subsequent saves stay in `:in_progress` (the state machine accepts the same-state transition). `:submit` validates required responses then transitions to `:submitted`. `:expire` is a terminal transition only callable from `:assigned` or `:in_progress` — `:submitted` rejects expiry so a completed survey can never be later marked stale.

### 4. Token-based unauthenticated student access

Same pattern as Phase 6 HighFive. Each `SurveyAssignment` carries a 22-character URL-safe token (128 bits of entropy). The `:by_token` action uses `multitenancy :bypass`. The public LiveView at `/surveys/:token` reads the row with `authorize?: false` (mirroring the established Phase 6 path).

Students aren't `User` rows in Phase 7. The token IS the auth. Phase 11's roster portal can later promote students to authenticated users without changing this contract.

### 5. Auto-save via `:save_progress` upsert action; `:submit` as separate validating action

Every blur / `Next` click on the student-facing page calls `:save_progress(question_id, answer_text, answer_values)`. The change runs `UpsertResponse` after-action, which calls `Ash.create(SurveyResponse, ..., upsert?: true, upsert_identity: :unique_response_per_question)`. Closing the tab and re-opening the link restores every saved answer because the responses are persisted, not buffered in LV state.

`:submit` is a separate action that runs `ValidateRequiredResponses` + sets `submitted_at` + transitions state. Keeping validation concentrated on submit (rather than fanning it across every save) means partial answers never block progress.

### 6. Question `metadata` as JSONB per-type config

Single `metadata :map` attribute holds type-specific config: `%{options: [...]}` for `:single_choice` / `:multi_choice`, `%{scale_labels: [...]}` for `:likert_5`. No polymorphic question-options table. Cheap, flexible, fits Ash's first-class JSONB support.

### 7. Bulk assign with two modes matching the real product's modal

`bulk_assign_to_students` is a custom action that calls `Ash.bulk_create` with `notify?: true, stop_on_error?: false` — same pattern as Phase 6 bulk High-5. Two `mode` values match the screenshots:
- `:skip_if_previously_assigned` — pre-filters student_ids by removing those with any existing assignment for this template, regardless of state (`:assigned`, `:in_progress`, `:submitted`, or `:expired`). Matches the "Assign only if never assigned" button text.
- `:assign_regardless` — pass-through; creates one assignment per id unconditionally.

Per-row authorization runs through `ActorBelongsToTenantSchool`, so a mixed-school bulk fails cleanly.

### 8. Reminders as a custom cron-driven scanner (not AshOban per-row trigger)

`DailySurveyReminderScanner` runs at 9:00 daily, iterates schools, queries assignments matching `state in [:assigned, :in_progress] and assigned_at <= now() - 2d`, and enqueues one `DeliverSurveyReminderWorker` per due row. The scanner uses a 4-day cooldown via `last_reminded_at` to avoid re-pinging the same student.

This pattern (one scan pass enqueuing N delivery jobs) is intentionally different from AshOban's per-row trigger model. AshOban triggers fan out one Oban row per matching assignment per scheduler tick; the scanner pattern fans out only when something is actually due, and records last-sent state in the resource itself rather than the Oban table.

### 9. Survey LiveView intentionally omits `<.flash_group>` and the staff app chrome

The student-facing page renders directly into a `survey-gradient` `<main>` block — no top header, no breadcrumb, no user menu. Three render clauses (`:not_found`, `:submitted`, `:expired`) cover the non-form states with a centered card; the default clause runs the question-paging UI.

Because `<.flash_group>` is absent, the LiveView shows submit-validation errors by re-rendering the question card with the missing-required state intact, not by flashing a banner. Tests verify the persisted state (`assignment.state != :submitted`) rather than the absence of a flash.

## Consequences

**Positive**
- Phase 8 (Insightfull survey + 13 SEL dimensions) can layer scoring on top of `:submit` with no schema changes — just a new question_type + a change module that runs after `transition_state(:submitted)` to compute `IndicatorScore` rows.
- Auto-save upsert via `:unique_response_per_question` identity is browser-crash-resistant by construction. No client-side draft state to reconcile.
- The pinned `SurveyTemplateVersion` snapshot means a counselor editing the Get to Know Me wording mid-rollout doesn't retroactively change in-progress assignments — same pattern Insightfull surveys will need when SEL items are tuned per cohort.
- Bulk assign + reminder scanner reuse the Phase 4–6 notifier/Oban infrastructure with no new patterns; the entire delivery pipeline is now a fourth instance of the same well-exercised shape.
- `SurveyAssignment.Version` rows roll into the Student Hub's activity timeline (Phase 7P), so "Survey assigned / submitted / expired" events show up alongside Flags / High-5s / Notes in the student narrative.

**Negative**
- Five resources for one feature is heavier than Phase 4 Flags (one resource + two side-cars). Justified by versioning + response upsert + state-machine separation, but new contributors should expect more files than Flags.
- Reminder scanner walks every school every day. Fine for the demo single-district; multi-district at Phase 11 scale will need indexed query plans + per-school sharding.
- `:save_progress` rejected from `:submitted` is enforced by the state machine (no `submitted → in_progress` transition), but the LV doesn't currently re-route a re-opened submitted link — the submitted-screen render clause catches it before any save attempt.
- Survey page intentionally has no `<.flash_group>`, which means submit-time validation errors are silent in the UI. Phase 8 polish can add an inline-error region under the Submit button (without restoring the staff-app chrome).

## Alternatives rejected

- **Per-question paper-trail reconstruction instead of JSONB snapshot.** Rejected — N joins on a 13-question survey for every student-facing page render is a real cost, and the side-car pattern is already idiomatic in Ash.
- **AshOban per-row trigger for reminders.** Rejected — fans out one Oban row per pending assignment per tick; the scanner pattern only enqueues when something is actually due and threads `last_reminded_at` cooldown through the resource.
- **Promote students to `User` rows up front.** Rejected — Phase 11 portal is the right place. Token-based access is the established pattern from Phase 6.
- **Single-action `:complete` that auto-saves + submits in one shot.** Rejected — splits cleanly into `:save_progress` (per-question, upsert) + `:submit` (whole-assignment, validates). Composing them in one action would muddle the validation surface and break the auto-save resilience story.
- **Polymorphic `survey_question_options` table for choice questions.** Rejected — JSONB `metadata` is cheaper to query (single column read) and easier to evolve (no migration to add a new constraint type).

## Cross-references

- ADR-002 — multi-tenancy; all five Phase-7 resources inherit `global?: false`.
- ADR-004 — Student domain; `Student.has_many :survey_assignments` + `Student.open_survey_assignments_count` aggregate.
- ADR-006 — Flag workflow; same notifier + Swoosh sender pattern reused for invitation + reminder emails.
- ADR-007 — Phase 5 FilterCheck + custom Oban digest; reused for the `has_open_survey_assignment` FilterSpec + `DailySurveyReminderScanner`.
- ADR-008 — token-based public view + `Ash.bulk_create` with partial-failure reporting; both patterns reused unchanged for `:by_token` and `:bulk_assign_to_students`.
