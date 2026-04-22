# Intellispark

A faithful Phoenix/LiveView/Ash recreation of the Intellispark K-12 student-support platform.

This repository now ships **Phase 10** — Team Members, Key Connections, Strengths + teacher-class read scoping — on top of **Phase 9** (Insights view), **Phase 8** (Insightfull + 13 SEL indicators), **Phase 7** (Surveys Framework), **Phase 6** (High 5s), **Phase 5** (Actions / Supports / Notes), **Phase 4** (Flag workflow), **Phase 3** (Student Hub), **Phase 2** (Students / Tags / Status / CustomLists), **Phase 1.5** (admin invitations), **Phase 1** (auth + multi-tenancy), and the Phase 0 design-system + tooling baseline. See `../phase-10-teams-connections-strengths.md`, `../phase-9-insights-modal.md`, `../phase-8-insightfull-indicators.md`, `../phase-7-surveys.md`, `../phase-6-high-fives.md`, `../phase-5-actions-supports-notes.md`, `../phase-4-flags.md`, `../phase-3-student-hub.md`, `../phase-2-students-tags-lists.md`, `../phase-1-implementation.md`, and `../phase-1.5-school-invitations.md` for the plans, and ADRs under `docs/architecture/decisions/`.

## What Phase 10 delivers

- **New `Intellispark.Teams` domain** with three resources — `TeamMembership` (student ↔ staff with 8-role enum + source + permissions_override + `added_at`), `KeyConnection` (student ↔ staff with provenance note + `:self_reported | :added_manually` source), `Strength` (free-text description with auto-assigned `display_order`). All three are AshPaperTrail + AshArchival + AshAdmin-exposed + tenant-scoped on `school_id` + PubSub-broadcasting.
- **Teacher-class read scoping** — Student read policy now `authorize_if AdminOrClinicalRoleInSchool` (SimpleCheck — admins + counselors + social workers + clinicians + psychologists bypass) chained with `authorize_if TeacherOnlySeesTeamStudents` (FilterCheck — teachers see only students where `exists(team_memberships, user_id == ^actor.id)`). Revoking a TeamMembership instantly revokes read access.
- **Student Hub gains three panels** — role-grouped Team Members (Current Teachers / Family / Other Staff, matches screenshot `10-08-17`), 2-column Key Connections + Strengths grid in the right column. Each panel has a "+ X" button + empty state + PubSub-driven real-time refresh.
- **Three add modals** — `NewTeamMemberModal` (staff select + role select), `NewConnectionModal` (staff select + optional provenance textarea), `NewStrengthModal` (single description input). All follow the Phase 5 live_component pattern with parent `send({__MODULE__, :added})` on success.
- **Bulk toolbar "Assign team members"** — the `hero-user-plus` icon on `/students` (previously "coming in Phase 10") is enabled. `TeamBulkModal` runs `Ash.bulk_create(..., notify?: true)` so per-student Hubs light up via PubSub; partial-failure flash messages on duplicates.
- **`add_members_from_roster/4` generic action** — idempotent bulk upsert on `(school_id, student_id, user_id, role)` identity. Phase 11 SIS roster sync will call this on every tick with no duplicates.
- **Timeline integration** — three new event kinds (`:team_event`, `:connection_event`, `:strength_event`) with `hero-user-plus` / `hero-user-circle` / `hero-sparkles` icons and create/update/destroy summaries.
- **Seeds** — Marcus gets "Creativity" + "Relationship building" strengths, Curtis Murphy as his Coach (TeamMembership), and Curtis as a self-reported Key Connection. All idempotent (re-running seeds.exs is a no-op).
- **28 new tests** across 8 files — 4 unit (team_membership_test / key_connection_test / strength_test / teacher_scoping_test — 17 cases) + 4 integration LV (team_members_panel / key_connections_panel / strengths_panel / team_bulk_modal — 11 cases). Total: **363 tests, 0 failures** (was 335 at end of Phase 9).
- **ADR-014** captures the 9 decisions — 3 resources-not-polymorphic, role as enum, FilterCheck + SimpleCheck OR chain for reads, SimpleCheck for creates (FilterCheck can't filter creates), StampAddedBy cross-resource reusable, Elixir-side display_order max+1, bulk_create upsert for roster, role-grouped panel UI, 2-col grid right-column layout.

## What Phase 9 delivers

- **`/insights` LiveView** — full-screen analytics surface with a 13-dimension sidebar (Belonging → Well-Being), individual breakdown table (Student | Reported level), donut chart + legend (Levels / Total students / % of group), and a Cancel/close action that respects the `?return_to=` param.
- **Three cohort modes via query params** — `?student_ids=<comma-sep-uuids>` (bulk selection), `?list_id=<uuid>` (CustomList cohort), or no params (school-wide).
- **`?dimension=<atom>` deep-linking** — sidebar clicks do `push_patch` so URL is the source of truth + back-button works.
- **`IntellisparkWeb.UI.Donut` pure-SVG component** — ~100 lines, zero JS deps, `role="img"` + `<title>` + `aria-label` accessible, segment colors via `var(--color-indicator-{high,moderate,low}-text)` CSS custom properties.
- **`Intellispark.Indicators.summary_for/3` + `individual_for/3`** — two pure data helpers that use Phase 8's 13 Student calculations; `summary_for/3` returns `%{low, moderate, high, unscored, total}`, `individual_for/3` returns `[%{id, name, level}]` sorted by last+first name.
- **`GET /insights/export.csv` controller** — `NimbleCSV.RFC4180`-formatted attachment with `Student,Dimension,Level` columns, filename pattern `insights-<dim>-<YYYY-MM-DD>.csv`.
- **Bulk-toolbar integration** — the `hero-chart-bar` icon on `/students` (previously disabled with "coming in Phase 8") is now enabled and navigates to `/insights?student_ids=<csv>&return_to=/students`.
- **CustomList header link** — `/lists/:id` grows a "View insights →" link that navigates to `/insights?list_id=<uuid>&return_to=/lists/<id>`.
- **Donut styleguide section** — three example donuts (empty / partial / full) in `/styleguide` for visual regression.
- **21 new tests** across 4 files — `indicators/insights_test.exs` (7 unit cases: empty-cohort, distribution, partial coverage, sort order, unscored nil, cross-tenant drop), `insights_live_test.exs` (8 integration cases: 3 cohort modes, dimension switch, student link, Cancel with return_to, empty cohort), `insights_controller_test.exs` (3 CSV cases: 200 + headers, parsed body, empty cohort), `donut_test.exs` (3 component cases: empty → base circle only, full → 3 paths in order, aria-label counts). Total: **335 tests, 0 failures** (was 314 at end of Phase 8).
- **ADR-013** captures the 9 decisions — route-not-modal, 3-param cohort resolution, push_patch URL truth, pure-helpers-not-custom-action, SVG-not-library, controller-not-LV-download, tenant-filter security, "— not measured" placeholders, single-dimension-at-a-time.

## What Phase 8 delivers

- `Intellispark.Indicators` domain now holds one resource — **IndicatorScore** — one row per `(student_id, dimension)`, upsertable, paper-trailed, tenant-scoped on `school_id`.
- **`Intellispark.Indicators.Dimension` module** with 13 canonical SEL dimensions in product-defined display order: `:belonging, :connection, :decision_making, :engagement, :readiness, :relationship_skills, :relationships_adult, :relationships_networks, :relationships_peer, :self_awareness, :self_management, :social_awareness, :well_being`.
- **`:dimension_rating` question type** added to SurveyQuestion's enum + `ValidateDimensionMetadata` change — requires `metadata.dimension` to be one of the 13 canonical values. Student-facing LV renders a horizontal 5-radio scale (Never / Rarely / Sometimes / Often / Always).
- **Pure `Intellispark.Indicators.Scoring` module** with threshold constants `@low_threshold 2.5` and `@high_threshold 3.75`. Deterministic + idempotent by construction. Property-tested for boundary behaviour + monotonicity.
- **Submit→Oban pipeline:** `SurveyAssignment.:submit` now has an `EnqueueIndicatorScoring` after_action that enqueues `ComputeIndicatorScoresWorker` on the new `:indicators` queue. Worker calls `Indicators.compute_for_assignment/2` and broadcasts `{:indicator_scores_updated, student_id}` when done.
- **13 calculations on Student** — `student.belonging`, `student.connection`, …, `student.well_being` return `:low | :moderate | :high | nil` as if they were attributes. Backed by the `IndicatorLevel` calculation module.
- **Hub Key SEL & Well-Being Indicators panel** inserted between Recent High 5's and Notes — 2-column grid (first 7 dims left, 6 right) of filled chips (red-pink Low / amber Moderate / green High) or "—" placeholders for dimensions without scores. Labels use `Dimension.humanize/1` so "Relationships (Adult)" + "Well-Being" render with the correct punctuation.
- **Real-time Hub reload** — StudentLive.Show subscribes to `"indicator_scores:student:#{id}"`; worker broadcast triggers `reload_indicators/1` which re-loads all 13 calculations + the activity timeline.
- **13 per-dimension custom-list filters** on `FilterSpec` — `filters: %{belonging: :low}` returns only students whose latest IndicatorScore for that dimension matches. Implementation: one `apply_dimension_filters/2` reducer + `exists(indicator_scores, dimension == ^d and level == ^l)` for SQL pushdown.
- **`Student.has_many :indicator_scores`** relationship for the exists-based filter path.
- **`mix indicators.recompute` mix task** — idempotent backfill, `--school <id>` scopes to one tenant, walks submitted assignments chronologically so the latest submission wins the upsert.
- **Insightfull seed** — 26 items (2 per dimension) with research-backed Likert prompts, published template, Marcus assignment — idempotent on template name + assignment target.
- **Activity timeline extension** — merges `IndicatorScore.Version` rows as `:indicator_event` ("Indicators computed" / "Indicators refreshed") alongside the existing Student/Tag/Status/Note/High-5/Survey streams.
- **AshAdmin exposure** — Indicators domain surfaces at `/admin` under the existing district-admin gate from Phase 1.5; no router changes.
- **32 new tests** across 6 files — dimension module (5), scoring (9 unit + 2 property), IndicatorScore resource (5), Oban worker (2), Hub panel (4), Insightfull flow (3), mix task (2). Total: **316 tests, 0 failures** (was 284 at end of Phase 7).
- **ADR-010** captures the 9 decisions — IndicatorScore-as-resource, Dimension-as-constant, pure scoring deferred to Oban, compile-time-unrolled calculations, documented thresholds, explicit `:indicators` queue, FilterSpec 13-dim extension via exists(), 26-item seed, chip tooltip deferred to Phase 9.

## What Phase 7 delivers

- `Intellispark.Assessments` domain now holds five resources — **SurveyTemplate** (per-school template with publish workflow + `current_version_id` pinning), **SurveyQuestion** (positioned, typed, with JSONB `metadata` for per-type config), **SurveyTemplateVersion** (immutable JSONB snapshot of the entire template tree at publish time), **SurveyAssignment** (per-student assignment with state machine + 22-character URL-safe token), **SurveyResponse** (per-question answer with upsert identity on `(assignment, question)`). All tenant-scoped on `school_id`.
- **`:by_token` read action** with `multitenancy :bypass` — powers the unauthenticated student-facing page at `/surveys/:token`.
- **Student-facing LiveView** at `/surveys/:token` (Insightfull-branded orange `survey-gradient`) — one question per page with progress bar, `phx-blur`/`phx-change` auto-save calling `:save_progress`, Previous/Next navigation, Submit on the last question. Three fallback render clauses for `:not_found` / `:submitted` / `:expired`. Closing the tab and re-opening the link restores every saved answer because responses are upserted, not buffered in LV state.
- **Five question types** — `:short_text`, `:long_text`, `:single_choice`, `:multi_choice`, `:likert_5` — all rendered by a `<.answer_input>` dispatcher.
- **State machine** — `:assigned → :in_progress → :submitted` with `:expired` as a terminal dead-letter; `:save_progress` self-transitions to `:in_progress`, `:submit` runs `ValidateRequiredResponses` then transitions to `:submitted`, `:expire` rejects from `:submitted`.
- **Bulk assign** via `Ash.bulk_create` — `bulk_assign_to_students` takes `student_ids + template_id + mode`. Two modes match the screenshot wording: `:skip_if_previously_assigned` pre-filters students with any prior assignment for this template (any state); `:assign_regardless` creates one row per id unconditionally.
- **Notifier → Oban → Swoosh** pipeline for invitation emails — `Notifiers.Emails` enqueues `DeliverSurveyInvitationWorker` on `:assign_to_student` + `:bulk_assign_to_students`. `SurveyInvitation.send/1` renders the branded email.
- **Daily reminder scanner** — `DailySurveyReminderScanner` runs at 9:00 daily, walks every school, queries assignments matching `state in [:assigned, :in_progress] and assigned_at <= now() - 2d`, enqueues `DeliverSurveyReminderWorker` per due row with a 4-day cooldown via `last_reminded_at`.
- **AshOban hourly expiry trigger** — transitions stale assignments to `:expired` when `expires_at <= now()`.
- **Forms & Surveys panel** on the Hub main column (between Notes and Activity timeline) — lists current assignments with template name, assigner, date, and a state pill (`Not started` / `In progress` / `Expired` / `Completed on MMM D, YYYY`). "+ Form assignment" button opens the new-assignment modal.
- **New survey assignment modal** (`NewSurveyModal` LiveComponent) — template select + Assign button, sends `:survey_assigned` upstream on success.
- **Bulk survey modal** (`SurveyBulkModal` LiveComponent) opened from the `/students` BulkToolbar — "Assign a survey to N students" with template select + two submit buttons matching the real product's "Assign even if previously completed" / "Assign only if never assigned".
- **`Student.open_survey_assignments_count` aggregate** + **`has_open_survey_assignment: boolean` CustomList filter** — same pattern as Phase 6's `recent_high_fives_count` + `no_high_five_in_30_days`.
- **Activity timeline extension** — merges `SurveyAssignment.Version` rows as `:survey_event` ("Survey assigned" / "Survey submitted" / "Survey expired") alongside the existing streams.
- Seeded **"Get to Know Me"** template with 9 verbatim questions (4 short_text required + 5 free-text optional) + one assignment on Marcus.
- **56 new tests** across 11 files — template publish + version pinning, question type round-trips, assignment state-machine + token uniqueness + paper-trail, response upsert + tenant isolation, bulk assign with two modes + partial-failure, policies for staff vs unauth callers, Oban scanner + expiry trigger, hub Forms & Surveys panel, student-facing LV happy path + fallback states, bulk modal flow. Total: **280 tests, 0 failures** (was 224 at end of Phase 6).
- **ADR-009** captures the nine decisions — five-resource split, JSONB schema snapshots, four-state machine with `:expired` dead-letter, token-based unauth access, `:save_progress` upsert + `:submit` validating action, JSONB `metadata` per-type config, bulk-assign two-mode action, custom cron scanner over per-row AshOban trigger, survey LV intentionally chrome-less.

## What Phase 6 delivers

- `Intellispark.Recognition` domain now holds three resources — **HighFiveTemplate** (per-school reusable messages with a 6-category enum), **HighFive** (sent record with a 128-bit URL-safe token + view counters), **HighFiveView** (append-only audit log of public-view clicks). All tenant-scoped on `school_id`.
- **`:by_token` read action** with `multitenancy :bypass` + `authorize_if always()` — powers the unauthenticated public view at `/high-fives/:token`.
- **Unauthenticated LiveView** at `/high-fives/:token` (mounted in the `:maybe_user` live_session) — renders the branded message, records the view after the socket connects, and falls back to a "Link expired" card for unknown tokens.
- **`Ash.bulk_create` bulk send** via `HighFive.:bulk_send_to_students` generic action — one template_id + N student_ids → one payload batch with partial-failure reporting through `%Ash.BulkResult{records, errors}`. `notify?: true` ensures the Oban email job fires per row.
- **Notifier → Oban → Swoosh** email pipeline: `Intellispark.Recognition.Notifiers.Emails` subscribes to `:send_to_student` + `:bulk_send_to_students`, enqueues `DeliverHighFiveEmailWorker`, which hydrates + dispatches `HighFiveNotification.send/1`. A Resend outage no longer blocks the LiveView.
- **One policy** — `CanSendHighFive` SimpleCheck gating staff-role (teacher / counselor / clinician / social_worker / admin) on the target student's school. Reads + destroys reuse existing Phase 2 policies.
- **Recent High 5's panel** on the Hub main column (first card, above Notes) — green-tinted cards with title + body + "Sent by · time ago" footer, "+ High 5" button, "View previous High 5's" link when the student has more than 5.
- **New High 5 modal** (`NewHighFiveModal` LiveComponent) — two modes (template picker / custom message) toggled via pill buttons, `recipient_email` prefilled from `Student.email`, AshPhoenix.Form wiring.
- **Previous High 5's drawer** (`PreviousHighFivesDrawer` LiveComponent) — slide-over listing every High 5 reverse-chronologically with `view_audit_count` footers.
- **Bulk High 5 modal** (`HighFiveBulkModal` LiveComponent) opened from the `/students` BulkToolbar — "Send a High 5 to N students" with a template select + partial-failure flash.
- **`Student.recent_high_fives_count` aggregate** filtered on `sent_at >= ago(30, :day)` — wired into the roster High-5s column, the custom-list row template, and the hub header badge (all previously hard-coded `0`).
- **`Student.email` attribute** — nullable, SIS-populated in Phase 11. Drives the `recipient_email` fallback on `HighFive.:send_to_student`.
- **`no_high_five_in_30_days: boolean` CustomList filter** on `FilterSpec` — one attribute + one `apply_filters/2` clause that loads the aggregate + filters to `recent_high_fives_count == 0`.
- **Activity timeline extension** — merges `HighFive.Version` rows as `:recognition_event` ("Sent a High 5" / "High 5 viewed") alongside the existing Student/Tag/Status/Note version streams.
- Seeded 5 templates (achievement / effort / kindness / behavior / attendance) + 2 high 5s on Marcus (4 days and 2 days old, backdated via `force_change_attribute`).
- **39 new tests** across 9 files — template identity + category enum, HighFive send+token+view count, audit-log append-only, bulk_create partial failure + Oban job enqueue, CanSendHighFive matrix, LiveView panel rendering, public-view mount + fallback. Total: **224 tests, 0 failures** (was 185 at end of Phase 5).
- **ADR-008** captures the nine decisions — three-resource split, plain text, token strategy, multitenancy bypass, public view, aggregate window, notifier→Oban indirection, bulk_create with `notify?: true`, FilterSpec extension.

## What Phase 5 delivers

- `Intellispark.Support` domain now holds three new resources — **Action** (two-state machine `:pending → :completed / :cancelled`), **Support** (four-state `:offered → :in_progress → :completed / :declined`), **Note** (plain-text case note with pin/unpin + paper-trailed edits). All tenant-scoped on `school_id` with `global?: false`.
- **Five new policies** — `AssigneeOrOpenerOrAdminForAction`, `AssigneeOrAdminForAction`, `ProviderOrClinicalActorForSupport`, `StaffReadsNotesForStudent` (FilterCheck copying the Flag pattern for sensitive gating), `AuthorOrAdminForNote`.
- **Two new Oban digest workers**: `DailyActionReminderWorker` (7:00 cron, groups due + overdue pending Actions by assignee) and `SupportExpirationReminderWorker` (7:05 cron, groups in-progress Supports ending within 3 days by provider) — each sends one digest email per recipient via `ActionDigest` / `SupportExpiring` Swoosh senders.
- **`Student.open_supports_count` aggregate** — populates the blue Supports chip on `/students` + `/lists/:id` rows; Phase 3 placed a `0` placeholder, Phase 5 makes it real.
- **Actions panel** (sidebar, below Flags) with checkbox-to-complete, assignee + description + due-date rendering, empty state, and a "View completed actions" link that flashes a Phase-12 pointer.
- **Supports panel** (sidebar, below Actions) with title + colored status pill + date range + description line-clamp; rows open a slide-over **Support detail sheet** with state-conditional Accept / Decline / Complete buttons and a mini paper-trail timeline.
- **Notes panel** (main column) with an inline composer (plain text, newline-preserving, optional sensitive checkbox), a pinned-first feed, per-card pin/unpin + inline edit for the author, "edited" badge from the virtual `edited?` calc, and a chocolate "sensitive" badge.
- **New-action modal** and **New-support modal** built with `AshPhoenix.Form.for_create` — description + assignee + due date for Actions; title + description + provider + start/end for Supports.
- **Activity timeline extended** — merges `Note.Version` rows as `:note_event` entries; Action / Support transitions stay on their own panels (timeline is narrative-only).
- **PubSub topics** — `actions:student:<id>`, `supports:student:<id>`, `notes:student:<id>`. The hub reloads the affected panel only on scoped broadcasts.
- Seeded 2 actions (due today + due in 7 days), 2 supports (Academic Focus Plan 30-day + Flex Time Pass 14-day), and 2 notes (1 pinned + 1 unpinned) for demo purposes.
- **51 new tests** — resource actions, paper trail, state-machine rejections, policy matrix across all three resources, both Oban workers + no-op cases, LiveView panel empty/populated states + complete/pin/sensitive-gate flows. Total: **185 tests, 0 failures** (was 134 at end of Phase 4).
- **ADR-007** captures the nine decisions — single `Support` domain over three, state-machine shapes, plain text over ProseMirror, pin as action-not-state, sensitive FilterCheck copy, custom Oban digests, sidebar-vs-main layout, timeline scope.

## What Phase 4 delivers

- `Intellispark.Flags` domain with four resources — **FlagType** (per-school category), **Flag** (seven-state machine), **FlagAssignment** (Flag ↔ User join with paper-trail), and **FlagComment** (schema-only; UI lands in Phase 13). All tenant-scoped on `school_id` with `global?: false`.
- **AshStateMachine** on Flag — states: `:draft`, `:open`, `:assigned`, `:under_review`, `:pending_followup`, `:closed`, `:reopened`. Seven transition actions (`:open_flag`, `:assign`, `:move_to_review`, `:set_followup`, `:close_with_resolution`, `:auto_close`, `:reopen`), each with its own `accept`, arguments, and per-action policy. Invalid transitions raise at the resource layer.
- **Policies** split by action type: reads use a new `StaffReadsFlagsForStudent` FilterCheck that gates `sensitive? == true` flags behind clinical roles (`:admin`, `:counselor`, `:clinician`, `:social_worker`); close uses `AssigneeOrClinicalActorForFlag` (SimpleCheck); reopen uses `OpenerOrAdminForFlag`.
- **AshOban background jobs**:
  - `:auto_close_stale_flags` — hourly trigger on Flag that calls `:auto_close` for any flag past its `auto_close_at`; the email notifier follows up.
  - `DailyFollowupReminderWorker` — custom Oban worker that groups today's `:pending_followup` flags by assignee and sends exactly one digest email per user (not one per flag).
- **Three Swoosh email senders** (`FlagAssigned`, `FlagAutoClosed`, `FollowupDigest`) dispatched by a dedicated notifier module so action definitions stay mailer-free.
- **Two PubSub topics** — `flags:school:<school_id>` and `flags:student:<student_id>`. The Student Hub subscribes to the narrow topic and re-renders the Flags panel on any transition.
- **Sidebar Flags panel** on `/students/:id` (Profile → Flags → Status → Tags ordering matches the real product screenshots) with a `+ New flag` button, type chip, short description, status pill, assignee count, and an empty-state fallback.
- **New-flag modal** driven by `AshPhoenix.Form.for_create` chained with `Students.open_flag` — pick type, description, sensitive?, followup date, assignees, click Open flag; assignees receive an email within ~100ms.
- **Flag detail side-sheet** with state-conditional transition buttons (Move to Review / Set follow-up / Close / Reopen — conditional on current status + actor role), inline resolution + follow-up forms, assignee list, and a timeline pulled from `Flag.Version`.
- **`Student.open_flags_count` aggregate** — populates the amber Flags chip on `/students` + `/lists/:id` rows (Phase 3 placed a `0` placeholder; Phase 4 makes it real).
- Seeded 5 flag types per school (Academic, Attendance, Behavioral, Mental health, Family) + one open Academic flag on Marcus + one pending-followup Attendance flag on Elena for demo purposes.
- **23 new tests** — resource actions, paper-trail, state machine rejections, policy matrix (read scoping + close + reopen), Oban digest worker + empty-case no-op, LiveView Flags panel empty / populated / closed-excluded. Total: **134 tests, 0 failures** (was 111 at end of Phase 3).
- **ADR-006** captures the seven decisions — AshStateMachine over changeset guards, per-action policies, FlagAssignment as a real join, sensitivity as a FilterCheck, notifier-driven emails, AshOban triggers + custom workers, schema-now-UI-later for FlagComment.

## What Phase 3 delivers

- `/students/:id` **Student Hub** with a two-column grid (header card + sidebar + main-column panels + activity timeline)
- **Header card**: avatar (photo or initials fallback), display_name, grade, external_id, current status chip, inline tag chips, three count badges (High-5s / Flags / Supports — all `0` until Phases 4/5/6), "Edit profile" button
- **Inline tag editor** as a LiveComponent — `<details>` dropdown lists the school's un-applied tags; picking one calls `Students.apply_tag_to_students/2` and reloads the student without a page refresh; `×` on a chip destroys the StudentTag via a new `Student.remove_tag` action
- **Inline status editor** as a LiveComponent — `<select>` cycles through the school's Statuses; picking one routes through `Student.set_status`; `Clear` button flips to `Student.clear_status` which nils `current_status_id` and stamps `cleared_at` on the active StudentStatus ledger row
- **Demographics edit modal** driven by `AshPhoenix.Form.for_update/2` — validates inline (grade_level enum, enrollment_status enum), submits via `AshPhoenix.Form.submit/2`, closes modal + re-reads student on success
- **Photo upload** end-to-end: `allow_upload(:photo, ...)` + `<.live_file_input>` + `consume_uploaded_entries/3` piped through `Student.upload_photo` which validates MIME + size and copies the file into `priv/static/uploads/students/<id>/<uuid>.<ext>`. `uploads` added to `IntellisparkWeb.static_paths/0` so the file serves at `/uploads/students/...` via `Plug.Static`.
- **Activity timeline** assembled from `Student.Version` + `StudentTag.Version` + `StudentStatus.Version` rows (join tables now carry `:student_id` via `paper_trail attributes_as_attributes`), sorted newest-first, capped at 20, rendered as an `<ol>` with icons + summaries + hand-rolled relative timestamps
- **Placeholder panels** for Flags / High-5s / Supports / Notes — real `<.empty_state>` components with disabled `+ New X` buttons and hover tooltips naming the arrival phase (4 / 5 / 6 / 8)
- **Two PubSub topics**: `students:school:<school_id>` (inherited from Phase 2 for the list view) + `students:<id>` (new, narrow) — the Hub subscribes to both so it updates on any change to its own student within ~100ms across tabs
- **New Ash actions** on `Student`: `:clear_status`, `:upload_photo`, `:remove_tag` (plus the `:age_in_years` calculation for the sidebar fact sheet). All require_atomic? false, all paper-trailed, all exposed in AshAdmin for free via the existing `use AshAdmin.Resource` on `Intellispark.Resource`.
- **20 new tests** — 10 unit tests exercise the new actions + calculations + paper-trail student_id propagation, 8 LiveView integration tests cover rendering, modal validate + save, inline tag + status, PubSub broadcast-driven reload, and 2 timeline tests exercise the merged-feed + empty states. Total: **111 tests, 0 failures** (was 91 at end of Phase 2).
- ADR-005 captures the `AshPhoenix.Form` default / inline-vs-modal heuristic / version-row timeline / local-disk photo storage / narrow-topic PubSub decisions

## What Phase 2 delivers

- `Intellispark.Students` domain with six resources — Student, Tag, StudentTag, Status, StudentStatus, CustomList — each tenant-scoped on `school_id` with `global?: false` so forgetting tenant raises rather than silently leaking cross-school data
- `Student` with `:display_name` + `:initials` calculations, a `:set_status` update action that maintains a paper-trailed StudentStatus ledger (append-only; denormalized pointer on Student), and partial unique identity on `(school_id, external_id) WHERE external_id IS NOT NULL` for SIS round-trip
- `Tag.apply_to_students` bulk action — `Ash.bulk_create` with `upsert?: true, stop_on_error?: false, return_errors?: true` so 30-student bulk-apply survives partial failure and surfaces a count via the LiveView flash (see ADR-004)
- `CustomList.filters` as an embedded `FilterSpec` Ash resource (tag_ids, status_ids, grade_levels, enrollment_statuses, name_contains) + a generic `:run` action that composes `Ash.Query.filter` clauses — new filter dimensions need no migration
- Per-action policy split between `StaffReadsStudentsInSchool` / `StaffEditsStudentsInSchool` (FilterCheck for read/update/destroy) and `ActorBelongsToTenantSchool` (SimpleCheck for create + generic actions), because FilterCheck can't authorize a create
- `/students` LiveView — brand-blue title, filter bar, 7-column table (Student(N) | High-5s | Flags | Status | Supports | Tags), inline status chips + tag chips with "+ N more" overflow, per-row and select-all checkboxes, white-bg bulk toolbar with 6 icons + charcoal tooltips, apply-tag modal wired through `Tag.apply_to_students`
- `/lists` LiveView — card grid of the user's own lists + shared lists in the school + a built-in "All Students" card linking to `/students`; `/lists/:id` renders the same 6-column table filtered through the saved FilterSpec
- `/students/:id` stub that 302s to a placeholder hub page (real hub lands in Phase 3) so row clicks don't 404
- School-scoped PubSub: Student create/update/destroy broadcasts to `students:school:<school_id>` and `/students` subscribes; bulk-tag applies surface in other tabs immediately
- `SetAdminActorCookies` auto-seeds the AshAdmin `tenant` session cookie from `current_school` so admins land in the right tenant on `/admin` without picking manually
- Seeds include 5 demo students (Ava/Marcus/Ling/Elena/Noah), 3 tags (IEP, 1st Gen, Academic Focus), 3 statuses (Active, Watch, Withdrawn), and 2 CustomLists (shared "At-risk (IEP)" + private "Seniors graduating") — all idempotent
- 88 tests, 0 failures — unit coverage for resources + policies + bulk, plus LiveView acceptance for signed-out redirect, tenant isolation, search, bulk-tag, and private-list visibility
- ADR-004 captures the tenant-scope / policy-split / bulk-apply / FilterSpec decisions

## What Phase 1 delivers

- AshAuthentication password strategy with email confirmation + password reset (`require_interaction? true` for the security advisory; `session_identifier :jti`)
- Branded sign-in / reset / confirm / sign-out LiveViews via `IntellisparkWeb.AuthOverrides`
- District → School → SchoolTerm hierarchy + UserSchoolMembership join with role + source enums
- `Intellispark.Tenancy.to_tenant/1` helper — Phase 2+ resources will be tenant-scoped on `school_id` and forgetting tenant raises
- FilterCheck policies (`DistrictAdminOfUser`, `…OfSchool`, `…OfSchoolTerm`, `…OfMembership`) so reads filter rows rather than gating actions
- AshPaperTrail on every Accounts resource, `hashed_password` excluded from snapshots, deny-all policies on auto-generated `.Version` resources via `Intellispark.PaperTrail.VersionPolicies` mixin
- School switcher dropdown in the app header (only renders when the user has more than one membership)

## What Phase 1.5 delivers

- `Intellispark.Accounts.SchoolInvitation` resource — email + role + status + expires_at, paper-trailed, with a partial unique index blocking duplicate pending invites per (email, school) pair
- `:invite` create action with a `DistrictAdminCanInvite` SimpleCheck policy; `:accept_by_token` update action with a transactional `AcceptInvitation` change that upserts User + UserSchoolMembership (`source: :invitation`); `:revoke` update action
- Branded invitation email via `EmailLayout.wrap/1` linking to `/invitations/:id` (the invitation's UUID primary key *is* the token — see ADR-003)
- Public `IntellisparkWeb.InvitationLive.Accept` LiveView with four states: pending/ready, accepted, revoked, invalid; on success redirects into AshAuthentication's `sign_in_with_token` flow so the invitee lands signed-in
- AshAdmin wired at `/admin` gated to district admins via a new `:require_district_admin` on_mount hook — provides the MVP invite-creation UI
- Self-service `/register` removed and the "Need an account?" toggler suppressed — account creation is strictly invite-only now
- Idempotent dev seed includes one pending invitation (`newcoach@sandboxhigh.edu` → `:counselor`) so `/admin` has data on a fresh boot and `/dev/mailbox` has a click-through URL
- 49 tests, 0 failures across all suites

## What Phase 0 still delivers

- Phoenix 1.8 + LiveView + Ash 3.24 ecosystem wired end-to-end
- Nine Ash domains (Accounts is now populated; Students, Support, Recognition, Assessments, Indicators, Teams, Integrations, Automations remain ready for later phases)
- Full Intellispark design system in Tailwind v4 (colors, typography, spacing, components)
- Core component library: Button, Card, Chip primitives, Modal, Avatar, Empty state, Status badges, Level indicators, Count badges
- `/styleguide` LiveView rendering every component for visual QA
- Unified Docker workflow (one `Dockerfile`, one `docker-compose.yml`) usable for both dev and prod via `APP_TARGET`
- Policy audit test that fails CI if a future resource ships without policies (FERPA posture)
- Ready for NPM-proxy-based production deployment

## Quickstart (local dev)

```bash
cp .env.example .env
docker compose up -d --build --wait
docker compose exec app mix ash.setup
```

Then open:
- <http://localhost:4800> — placeholder landing page
- <http://localhost:4800/sign-in> — branded login (sign in with `admin@sandboxhigh.edu` / `phase1-demo-pass`)
- <http://localhost:4800/register> — registration with email confirmation
- <http://localhost:4800/reset> — password reset
- <http://localhost:4800/styleguide> — every design primitive
- <http://localhost:4800/dev/mailbox> — Swoosh local mailbox preview (password-reset and confirmation emails land here)

Edit source on the host; the `.:/app` mount + `inotify-tools` in the dev image propagate changes immediately via Phoenix LiveReload.

## Running the app natively (without Docker)

If you already have Elixir 1.18+ and Postgres 16 locally:

```bash
POSTGRES_HOST=localhost mix setup
POSTGRES_HOST=localhost mix phx.server
```

## Production deployment

See Section 13 of `../phase-0-implementation.md`. TL;DR after NPM + DNS are configured:

```bash
# On the server:
docker compose up -d --build --wait
```

Migrations run automatically at container start via the runtime image's `CMD`.

## Tests and quality checks

```bash
POSTGRES_HOST=localhost mix test
POSTGRES_HOST=localhost mix compile --warnings-as-errors
mix format --check-formatted
mix credo
mix sobelow --config
```

## Tech stack

| Layer | Tool |
|---|---|
| Language | Elixir 1.18+ (OTP 27+) — this dev box runs 1.20-rc.1 / OTP 28 |
| Web | Phoenix 1.8.5 + LiveView 1.1 + Bandit |
| Domain | Ash 3.24 (+ AshPostgres, AshPhoenix, AshAuthentication, AshOban, AshPaperTrail, AshArchival, AshStateMachine, AshAdmin) |
| Database | PostgreSQL 16 |
| Background jobs | Oban 2.21 |
| Email | Swoosh — `Swoosh.Adapters.Local` in dev, `Swoosh.Adapters.Resend` in prod |
| Styling | Tailwind v4 (CSS `@theme`) + Figtree from Google Fonts |
| Container | Alpine-based multi-stage Dockerfile |
| Reverse proxy | Nginx Proxy Manager (GUI-managed) |

## Roadmap

Phases 0 through 4 are complete. Next up: **Phase 5** — Actions, Supports & Notes. See `../build-plan-ash.md` for the full 20-phase roadmap.
