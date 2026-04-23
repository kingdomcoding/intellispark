# Intellispark

A faithful Phoenix/LiveView/Ash recreation of the Intellispark K-12 student-support platform.

## Live demo

- **App:** https://intellispark.josboxoffice.com — start here, click "Open the app as a demo admin" for a one-click sign-in.
- **Status:** ![CI](https://github.com/kingdomcoding/intellispark/actions/workflows/ci.yml/badge.svg) · 564 tests · deployed from `main`


This repository now ships **Phase 14** — ScholarCentric resiliency + Academic Risk Index + About-the-Student Hub tab + `/students/risk` Risk Dashboard + Intervention Library chooser modal. See "What Phase 14 delivers" below. Tagged `v0.14.0-scholarcentric-complete` (552 tests green). On top of **Phase 11** — SIS ingestion pipeline (CSV first-class + OneRoster/Clever/ClassLink stubs), Xello bidirectional integration (webhook → `XelloProfile`; public `/embed/student/:token` LiveView with `frame-ancestors *.xello.com` CSP), Cloak-encrypted provider credentials, `IntegrationSyncRun` state machine, per-record dead-letter queue, and `/admin/integrations` LiveView for district admins — on top of **Phase 3 + Phase 10 retrofits** — Student demographics fields (`gender`, `ethnicity_race`, `phone`), Status `⋯` overflow + `Actions` header button (Phase 11.5 stubs), hover popovers on roster Flags/Supports badges, plus a sectioned New Team Member modal (Family/community drill-in + School staff multi-select) backed by a lifted-forward `ExternalPerson` resource and a polymorphic `KeyConnection` — on top of **Phase 18.5** — per-school subscription tiers (`:starter | :plus | :pro`), a district-admin onboarding wizard, a feature matrix + `RequiresTier` policy, and a manual tier-set billing stub — on top of **Phase 6 retrofit** — rich-text High 5 editor (B / I / U + bulleted/ordered list toolbar) + unified `NewHighFiveModal` with per-row Re-send icon on Hub's Recent High 5's panel — on top of **Phase 4 retrofit** — flag close-flow restructure (inline Check-up date input + red Close Flag button) + Phase 3.5 deprecated-shim cleanup — on top of **Phase 6.5** — Branded email templates + weekly digest + per-user email preferences + HighFive `:resend` — on top of **Phase 3.5** — Hub Tab Framework (URL-driven `?tab=` strip replacing flag/support side-sheets on desktop, mobile keeps sheets) — on top of **Phase 10.5** (CustomList composer UI), **Phase 10** (Team Members, Key Connections, Strengths + teacher-class read scoping), **Phase 9** (Insights view), **Phase 8** (Insightfull + 13 SEL indicators), **Phase 7** (Surveys Framework), **Phase 6** (High 5s), **Phase 5** (Actions / Supports / Notes), **Phase 4** (Flag workflow), **Phase 3** (Student Hub), **Phase 2** (Students / Tags / Status / CustomLists), **Phase 1.5** (admin invitations), **Phase 1** (auth + multi-tenancy), and the Phase 0 design-system + tooling baseline. See `../phase-10.5-custom-list-composer.md`, `../phase-10-teams-connections-strengths.md`, `../phase-9-insights-modal.md`, `../phase-8-insightfull-indicators.md`, `../phase-7-surveys.md`, `../phase-6-high-fives.md`, `../phase-5-actions-supports-notes.md`, `../phase-4-flags.md`, `../phase-3-student-hub.md`, `../phase-2-students-tags-lists.md`, `../phase-1-implementation.md`, and `../phase-1.5-school-invitations.md` for the plans, and ADRs under `docs/architecture/decisions/`.

## What Phase 14 delivers

- **About-the-Student Hub tab** — `?tab=about` pane now renders a 3-zone layout matching the 2026-04-21 screenshot review: hero row (Personality Style donut + trait list / Learning Style circle + label / Lessons Complete N-of-8), 4+4 overview grid (Education Goals / Career Clusters / Skills / Interests | Places / Resiliency Skills / Academic Risk Index), Suggested Clusters pill row. PRO-tier gated — Starter/Plus schools see tier-CTA placeholders.
- **Resiliency framework** — `ResiliencyAssessment` (state machine `:assigned → :in_progress → :submitted`/`:expired`, token + version stamped at assign) + `ResiliencyResponse` (0-5 Likert, upsert by identity) + `ResiliencySkillScore` (per student per skill, upsert by `(student_id, skill)`). Question bank in `QuestionBank` module: 3 grade bands × 18 questions × 6 skills (Confidence / Persistence / Organization / Getting Along / Resilience / Curiosity).
- **`AcademicRiskIndex` + `ContributingFactors` calculations on Student** — composite banding (`:low | :moderate | :high | :critical`) from the 6 skill-score means. Always computed on read; no cache. Contributing factors returns up to 2 lowest non-high skills when the index isn't `:low`.
- **`SkillScoreWorker`** — Oban worker (queue `:indicators`) triggered by `Assessment.:submit` via `after_action`. Groups responses by skill via `QuestionBank`, upserts 6 `SkillScore` rows per assessment. Idempotent on re-run.
- **`InterventionLibraryItem` + `Support.:create_from_intervention`** — per-school configurable library (title, description, MTSS tier, default_duration_days, active?). Selecting an item opens an `NewInterventionModal` two-view live_component (list → form) that prefills a new Support via the `PrefillFromIntervention` change. Hub's Supports panel gains a `+ Intervention` button visible only on PRO.
- **`/students/risk` Risk Dashboard LV** — PRO-tier-gated (redirects non-PRO), lists active students ranked by risk band (critical → high → moderate → low → not-assessed), filter bar with band + contributing-skill selects. Cross-link added to `/students` header for PRO actors.
- **Tier gating** — `Tiers.@features` now includes `:scholarcentric`, `:academic_risk`, `:intervention_library` (all PRO). Every write action uses two policy blocks (clinical role AND `RequiresTier(:pro)`) following the ADR-021 + ADR-022 pattern.
- **44 new tests** — 18 resiliency (QuestionBank + Assessment + SkillScore + worker + full-flow) + 8 calculations (risk index bands + contributing factors) + 6 intervention library (CRUD + `:create_from_intervention` + tier-gate) + 5 About-tab LV (PRO happy / no-Xello / no-resiliency / Starter CTA / PubSub) + 3 intervention modal (list → form / creates Support / hidden on Starter) + 4 Risk Dashboard LV (ranked sort / band filter / skill filter / Starter redirect). Total: **552 tests, 0 failures**.
- **ADR-023** — captures the 12 decisions: sub-namespace not new domain; code-defined question bank + version stamp; calculation-not-stored risk index; up-to-2 contributing factors; per-school library; distinct `:create_from_intervention` action; separate Risk Dashboard route; two-layer tier gating (policy + render); Oban scoring pattern; compile-time personality vocabulary; scoped PubSub subs for About tab; `XelloProfile.completed_lessons` schema addition.

## What Phase 11 delivers

- **`Intellispark.Integrations` domain** — 5 new Ash resources: `IntegrationProvider` (per-school, encrypted credentials, provider_type enum), `IntegrationSyncRun` (AshStateMachine: `:pending → :running → {:succeeded | :failed | :partially_succeeded}`), `IntegrationSyncError` (dead-letter log with retry action), `XelloProfile` (per-student Xello snapshot), `EmbedToken` (public-embed authorization). All paper-trailed.
- **Cloak vault** — `Intellispark.Vault` + new Ash type `Intellispark.Encrypted.Map` encrypt provider credentials at rest using AES-GCM. Key loaded from `CLOAK_KEY` env in prod; dev/test use `cloak_key_fallback` config.
- **Transformer-per-provider pattern** — `Intellispark.Integrations.Transformer` behaviour; `CSV` is first-class (OneRoster 1.2 header format via `NimbleCSV`); `OneRoster`/`Clever`/`ClassLink`/`Xello`/`Custom` are stubs returning `{:ok, []}` pending partner credentials.
- **`Student.:upsert_from_sis`** — uses existing `unique_external_id_per_school` identity for idempotent bulk upserts. Ingestion worker calls `Ash.bulk_create(..., upsert?: true, stop_on_error?: false, return_errors?: true)` — per-record failures go to the DLQ without aborting the batch.
- **AshOban cron trigger** — `scheduler_cron "0 */6 * * *"`, `where active? == true`. Scheduler enqueues `IngestionWorker` jobs per active provider. `Integrations.run_sync_now/2` code interface provides manual-trigger path for admins.
- **Xello inbound** — `/api/xello/webhook` endpoint with `LoadXelloProvider` plug (multitenancy-bypass `:webhook_lookup` read action) + `CacheRawBody` body reader for HMAC verification. `XelloWebhookController.receive/2` validates `X-Xello-Signature: t=<ts>,v1=<hmac>` (HMAC-SHA256, 5-minute replay window, `Plug.Crypto.secure_compare/2`) before upserting `XelloProfile`.
- **Xello outbound** — `/embed/student/:embed_token` unauthenticated LiveView. Dedicated `:embed` router pipeline sets `Content-Security-Policy: frame-ancestors *.xello.com *.app.xello.com;` and strips `x-frame-options` so the view embeds inside Xello iframes. Renders SEL & Well-Being 3-column grid (High/Moderate/Low) + Flags table (Flag / Opened by / Date / Status / Assigned). Revoked + expired tokens render safe fallback states.
- **Tier gating** — `IntegrationProvider.:create` uses two AND'd policy blocks: `DistrictAdminForSchoolScopedCreate` (admin of the school's district) + `RequiresTierForXello` (only kicks in for `provider_type: :xello`; delegates to Phase 18.5's `RequiresTier(:pro)` policy). Starter/Plus admins can create CSV / OneRoster providers; only PRO admins can create Xello.
- **`/admin/integrations` LiveView** — district-admin-gated dashboard. Providers table (type / name / active? / last synced / last success / last failure / activate-deactivate + run-now actions) + sync runs table (status pill + counts + timestamps). No new-provider form yet (AshAdmin covers it) but in-line toggles work end-to-end.
- **31 new tests** — 5 IntegrationProvider + 5 IntegrationSyncRun + 2 IngestionWorker + 3 CSV transformer + 3 XelloProfile + 3 EmbedToken + 4 Xello webhook + 3 public embed LV + 3 encryption round-trip. Total: **495 tests, 0 failures** (was 464).
- **ADR-021** — captures 17 design decisions: domain separation, transformer pattern, CSV first-class, state machine, DLQ, bulk upsert, Cloak vault, functional default for encrypted attrs, Xello tier gate via split policies, HMAC ceremony, raw-body reader, multitenancy-bypass provider lookup, embed audience/revocation, CSP + embed LV, embed = aggregate-only (no PII), AshOban trigger explicit module names, manual `run_sync_now` interface.

## What Phase 3 + Phase 10 retrofits deliver

- **Student demographics** — `gender :atom` (5 values), `ethnicity_race :atom` (8 NCES-aligned values), `phone :string` on `Student`. Migration generated via `mix ash.codegen add_student_demographics`. Profile card displays them; edit modal renders inputs (`<select prompt="—">` for the enums). AshPaperTrail captures changes automatically.
- **Status `⋯` overflow + `Actions` header** — both wired on the Student Hub. Archive + Mark withdrawn fire real `Intellispark.Students.{archive_student, mark_student_withdrawn}` actions available to any clinical-role staff (admin / counselor / social_worker / clinician / psychologist); Transfer is PRO-tier + district-admin-only (cross-school clone + source archive via `TransferToSchool` change with AND-semantic policy blocks, hidden from the menu for non-eligible actors); Generate report remains parked and now flashes "Reports ship in a future release." Shipped in Phase 11.5 as `v0.11.5-student-lifecycle-complete` (508 tests green). See `markdowns/phase-11.5-student-lifecycle.md` + ADR 022.
- **Hover popover on roster badges** — new `count_badge_with_popover/1` UI component wraps the existing `count_badge/1` in a `group` span with a `hidden group-hover:block group-focus-within:block` panel. Pure CSS — no JS hook. Top-3 open flags + supports come from extending the existing roster `Ash.Query.load/2` call with two filtered/sorted relationship preloads (`{:flags, open_flags_query}`, `{:supports, open_supports_query}`).
- **`Intellispark.Teams.ExternalPerson`** — new school-tenant Ash resource (paper_trail, pub_sub, multitenancy) with `first_name`, `last_name`, `relationship_kind` (`:parent | :guardian | :sibling | :coach | :community_partner | :other`), `email`, `phone`. Lifted forward from the deferred Phase 14 plan. Backs the Family/community drill-in flow on the New Team Member modal.
- **Polymorphic `KeyConnection`** — `connected_user_id` and `connected_external_person_id` are both nullable `belongs_to`. New `Teams.Changes.ValidateConnectedTarget` change asserts exactly one is set. Two partial unique indexes replace the old single full unique index. New `:create_for_external_person` action lives alongside the primary `:create`; both share the validator.
- **Sectioned NewTeamMemberModal** — three-state component (`:menu`, `:family`/`:family_new`, `:staff`). Family flow: list existing `ExternalPerson`s + button to create a new one (single submit creates the person + the `KeyConnection` in one flow). Staff flow: searchable list with per-row checkbox + role select; bulk-add button creates one `TeamMembership` per selected staff. Same `{__MODULE__, :team_member_added}` parent contract as before — show.ex didn't change.
- **25 new tests** — 5 demographics + 3 status overflow + 1 popover + 5 ExternalPerson + 4 polymorphic KeyConnection + 7 NewTeamMemberModal flows. Total: **464 tests, 0 failures** (was 439 after Phase 18.5).
- **ADR-020** — captures 10 decisions: demographics scope, lifecycle stubs, CSS-only popover, preload-not-LATERAL, `ExternalPerson` lift-forward, two-belongs_to-not-Ash.Union for `KeyConnection`, separate action per target, inline view dispatch, modal owns create flows, `CiString.downcase` boundary normalization.

## What Phase 18.5 delivers

- **`Intellispark.Billing` domain** — new Ash domain with `SchoolSubscription` (tier / status / seats / started_at / renews_at / stripe_subscription_id) and `SchoolOnboardingState` (6-step `current_step` enum + per-step + overall `completed_at` timestamps). `has_one` relationships on `School` for both; `identity :unique_school` on each.
- **`School.:create` auto-seeds billing rows** — new `Intellispark.Accounts.Changes.SeedBillingState` after-action creates a `:starter` Subscription + `:school_profile` OnboardingState atomically (`authorize?: false` since the creating actor may not yet have membership). Guarantees every school has billing siblings.
- **`lib/intellispark/tiers.ex` feature matrix** — compile-time `@features` + per-tier `@tier_caps` maps. `Tiers.allows?/2` + `Tiers.cap_for/2` + `Tiers.label/1` + `Tiers.all/0`. 7 features (xello_integration, insights_export, automation_rules, custom_lists, weekly_digest, bulk_high_fives, api_access).
- **`RequiresTier` SimpleCheck policy** — `authorize_if {IntellisparkWeb.Policies.RequiresTier, tier: :pro}` on any action. Reads `actor.current_school.subscription.tier` and compares via rank. Denies on nil actor / missing current_school / tier below required.
- **Actor loader upgrade** — `LiveUserAuth.:assign_current_school` and the `AssignCurrentSchool` plug now load `[:subscription, :onboarding_state]` on the current school and attach it to the actor via `Map.put(user, :current_school, school)`. Policies reach it without extra loads.
- **`/onboarding` LiveView** — district-admin-only 6-step wizard: school profile → invite co-admins → seed starter Tags + Statuses → SIS placeholder (Phase 11) → pick tier → done. Every step has Skip; progress persists in `SchoolOnboardingState` with per-step `_completed_at` stamps via the `StampStepCompletion` change module.
- **Top-nav Get Started pill** — `LoadOnboardingState` on_mount hook assigns `:onboarding_incomplete?`; `Layouts.app/1` gained the attr + conditional `.link` to `/onboarding`. Visible to district admins with an incomplete onboarding state; hides automatically once the wizard finishes.
- **School-switcher tier badge** — Plus renders `PLUS` brand-tinted pill, Pro renders `PRO` solid brand pill next to the school name. Starter gets nothing (keeps the nav calm).
- **Billing stub** — no Stripe. District admins change tier via AshAdmin (`/admin` → SchoolSubscription → set_tier) or the resource action directly. Paper-trailed.
- **Data backfill** — existing schools pre-Phase-18.5 get `:starter` Subscription + `:done` OnboardingState so current admins don't see the wizard.
- **14 new tests** — 4 SchoolSubscription + 3 SchoolOnboardingState + 3 Tiers + 5 RequiresTier (including missing current_school case) + 2 onboarding integration. Total: **439 tests, 0 failures** (was 425 after Phase 6 retrofit).
- **ADR-019** — captures 15 decisions: tier on Subscription not School, three-tier ladder, compile-time feature matrix, SimpleCheck policy shape, actor-carries-current-school convention, one-per-school onboarding state, atom step enum, skip-at-every-step, district-admin gating, starter+done backfill, after-action seed, hidden starter badge, dedicated Billing domain, AshAdmin day-1 surface, `district_id` calculation on both Billing resources.

## What Phase 6 retrofit delivers

- **Rich-text body editor** — `IntellisparkWeb.Components.RichTextInput.rich_text_input/1` renders a contenteditable `<div>` plus a 5-button toolbar (B / I / U / bulleted list / ordered list). Paired with the `RichTextEditor` JS hook (`assets/js/hooks/rich_text_editor.js`) which mirrors the editor's HTML into a hidden form input and delegates toolbar clicks to `document.execCommand`. ~45 lines of vanilla JS; no npm dep. Replaces the old `<textarea>` in `NewHighFiveModal`.
- **`SanitizeBody` change module** — `lib/intellispark/recognition/changes/sanitize_body.ex`. Runs on `:send_to_student` + `:resend`; calls `HtmlSanitizeEx.basic_html/1` to strip anything outside the safe tag allowlist. Defense-in-depth even if the JS hook is bypassed.
- **Unified `NewHighFiveModal`** — a new `:mode` attr routes the modal between `:create` (template pills, recipient field, `:send_to_student`) and `:resend` (pre-filled title + body, hidden pills/recipient, `:resend`). Internal template-vs-custom attr renamed to `:template_mode` to avoid collision. One LiveComponent now serves both flows.
- **`:resend` action accepts optional edits** — `argument :title, :string, allow_nil?: true` + `argument :body, :string, allow_nil?: true`. `MaybeApplyResendEdits` change module writes them only when non-nil; nil keeps existing values. Same sanitizer runs on resend edits too.
- **Hub per-row Re-send icon** — each Recent High 5 row on the student hub shows a circular-arrow icon button to the right of the title. Click dispatches `open_resend_high_five_modal` with the high_five id; modal opens in `:resend` mode pre-filled with that row's title + body. After submit, the row re-renders with a `· re-sent <relative time>` annotation.
- **Email body renders HTML** — `HighFiveNotification` swaps `<p style="white-space:pre-line;">#{body}</p>` for `<div>#{body}</div>`. `<strong>`, `<em>`, `<u>`, `<ul>`, `<ol>`, `<li>` render correctly in Gmail / Outlook / Apple Mail. Old plain-text rows still render cleanly.
- **No data migration** — existing rows hold plain text; rendered via `raw/1` they emit verbatim (plain text is valid HTML). New rows from the editor are HTML. Mixed fleet renders cleanly.
- **9 new tests** — 4 `SanitizeBody` unit (script stripped, allowed tags preserved, plain text unchanged, resend sanitizes edits) + 2 `:resend` edit cases (title+body applied; nil-keeps-existing) + 3 integration against the resend modal (icon opens modal, submit edits persist + flash, re-sent annotation appears on row). Total: **425 tests, 0 failures** (was 416 after Phase 4 retrofit).
- **ADR-018** — captures 11 design decisions: HTML storage vs ProseMirror JSON / Markdown, contenteditable + execCommand (no Trix), server-side sanitizer, unified modal with `:mode` attr, `:resend` signature extension, `{raw(body)}` render sites, no migration, per-row icon vs dropdown, plain-text title, `phx-update="ignore"` scoped to contenteditable only, test-submit via `render_submit(element, params)` to bypass hidden-input strict check.

## What Phase 4 retrofit delivers

- **`:close_with_resolution` action signature change** — `resolution_note` argument now optional (`allow_nil?: true, default: ""`); new optional `followup_at :date` argument lets the close action set a check-up reminder atomically. Code-interface switches from `define :close_flag, action: :close_with_resolution, args: [:resolution_note]` → no positional args (callers pass an input map).
- **`MaybeSetFollowup` change module** — `lib/intellispark/flags/changes/maybe_set_followup.ex`. Pattern-matches the `:followup_at` argument: `nil` → no-op (preserves existing followup); `%Date{}` → `force_change_attribute`. Mirrors Phase 10's `StampAddedBy` precedent.
- **Inline close bar** — both `FlagDetailPane` (desktop tab) and `FlagDetailSheet` (mobile sheet) replace the old "Close" transition button + form-expand + resolution_note textarea pattern with an always-visible bottom-bar: `Check-up date` date input + red `Close Flag` button. Matches screenshots `11-12-07` + `11-12-27`.
- **Phase 3.5 deprecated shim cleanup** — the four `# DEPRECATED` event handlers in `show.ex` (`open_flag_sheet` / `close_flag_sheet` / `open_support_sheet` / `close_support_sheet`) deleted. `FlagDetailSheet` and `SupportDetailSheet` close buttons now dispatch `phx-click="close_tab" phx-value-tab="profile"` directly. Grep-clean: zero remaining references.
- **`resolution_note` attribute stays on the resource** — AshAdmin still edits it; PaperTrail still captures it; auto-close worker still writes its default. Only the action's argument-validation changed.
- **5 new tests** — 3 unit cases (close accepts empty `resolution_note`; close sets `followup_at` when provided; close ignores nil `followup_at`) + 2 integration cases against the new bottom-bar form (close without date → `followup_at: nil`; close with ISO8601 date → `followup_at == date`). Plus 5 existing positional-arg callers migrated to params-map form (fixtures + 3 policy tests). Total: **416 tests, 0 failures** (was 411).
- **ADR-017** — captures the 9 design decisions: optional `resolution_note`, optional `followup_at`, closed flags don't move to `:pending_followup` on close-with-date, code-interface params-map switch, inline bar replaces form-expand, sheet + pane copy-paste (no shared component), mobile shims dropped in favor of `close_tab`, `resolution_note` attribute preserved, dedicated change module over inline `set_attribute`.

## What Phase 6.5 delivers

- **`EmailLayout` polish** — orange-gradient outer body, embedded logo image (`logo-150.png`), branded footer with company address (1390 Chain Bridge Road · McLean VA · +1 703-397-8700) + social icons. New opts: `:hero_icon` (emoji shown above the white card — 👋 for High 5s) and `:title_treatment` (`:default | :pill_green` — green pill for High 5 titles per screenshot). `:cta_url` + `:cta_label` are now optional.
- **Per-event template refresh** — every existing email module switched to first-name salutation (`Hi #{first}`) and screenshot-matched copy. High 5 uses 👋 hero + green-pill title; Flag-assigned uses inline `here` link instead of a CTA button.
- **`User.email_preferences :map`** — new JSONB attribute (default `%{}`); `:set_email_preference` action with `:event_kind` + `:enabled?` arguments; owner-only policy.
- **`Intellispark.Accounts.EmailPreferences`** — pure module with `valid_kinds/0` (6 kinds) + `opted_in?/2` predicate (default-in semantics: missing key = `true`).
- **Notifier enforcement** — every email-sending notifier (HighFive worker, Flag notifier, Daily Followup Reminder, Daily Action Reminder, Support Expiration Reminder) gates on `EmailPreferences.opted_in?(user, event_kind)`.
- **Weekly digest pipeline** — `WeeklyDigestComposer` (pure module: 4 sections — High 5s / Flags / Action needed / Notes), `WeeklyDigestEmail` (renderer with section + row helpers, `(assigned to you)` flag annotation), `WeeklyDigestWorker` (Oban cron `0 7 * * 1`, `unique: 24h` to mitigate multi-node drift, skip-empty-digests).
- **`/me/email-preferences` LV** — auto-saving 6-toggle settings page; phx-change updates the user's `email_preferences` map per kind.
- **HighFive `:resend` action** — sets `resent_at`, fires `Recognition.Notifiers.Emails.notify_resent/1` after_action, enqueues the existing `DeliverHighFiveEmailWorker` with `event_kind: "high_five_resent"`. Original token / view audit / `sent_at` preserved.
- **24 new tests** across 6 files — 6 EmailLayout (logo, pill_green, CTA optional, hero icon, gradient bg) + 5 EmailPreferences (default-in, false override, true override, nil user, valid_kinds) + 6 WeeklyDigestComposer (empty cohort, no activity, 1 high-five, flag annotation, empty?/1 true/false) + 3 WeeklyDigestWorker (sends, opt-out skipped, empty-skipped) + 2 EmailPreferencesLive (renders 6 toggles, toggle persists) + 2 HighFiveResend (`:resend` enqueues with `high_five_resent`, opt-out preserved). Total: **411 tests, 0 failures** (was 387).
- **ADR-016** — captures the 10 design decisions: polish-in-place, public-URL logo, `:title_treatment` extensibility, JSONB attribute (not separate resource), default-in semantics, predicate-helper enforcement, cron worker (not AshOban trigger), team-membership cohort, skip-empty, `:resend` as separate action.

## What Phase 3.5 delivers

- **`Tabs` URL parser** — pure module at `lib/intellispark_web/live/student_live/tabs.ex` translating `?tab=` query param into `:profile | :about | {:flag, uuid} | {:support, uuid}`. Whitelist atom-from-string with `Ecto.UUID.cast/1` validation; garbage input falls back to `:profile` silently.
- **`<.tab_strip>` function component** — desktop (`md:`+) horizontal strip with pinned Profile tab plus closeable entity tabs. Mobile (`<md`) shows only "← Back to Profile" link. Uses `<.link patch={...}>` so URL state is the source of truth.
- **`<.hub_pane>` switcher** — pattern-matches on `@active_tab`: `:profile` renders the existing 3-col panel grid + activity card; `{:flag, id}` renders `<.live_component module={FlagDetailPane}>`; `{:support, id}` renders `<.live_component module={SupportDetailPane}>`; `:about` renders a Phase 11/14 placeholder.
- **`FlagDetailPane` + `SupportDetailPane`** — LiveComponent variants of the Phase 4/5 sheets with the `<aside class="fixed">` wrapper + close button replaced by a card wrapper. Same `update/2`, same handlers, same helpers.
- **`/students/:id?tab=...` routing** — `handle_params/3` parses the param every navigation, dedup-appends the active tab into `@open_tabs`, and `sync_legacy_sheet_assigns` keeps the mobile-sheet legacy assigns in sync until the sheets retire (Phase 16).
- **Backward-compat shims** — legacy `open_flag_sheet` / `close_flag_sheet` / `open_support_sheet` / `close_support_sheet` event handlers alias the new `open_tab` / `close_tab` flow. Tagged `# DEPRECATED: remove in Phase 4 retrofit`.
- **Mobile fallback** — existing `FlagDetailSheet` + `SupportDetailSheet` LiveComponents wrapped in `<div class="md:hidden">` so the bottom-sheet UX still works on narrow viewports.
- **12 new tests** — 6 unit (`tabs_test.exs`: parser round-trips, defaults, UUID validation) + 6 integration (`hub_tabs_test.exs`: Profile active by default, `?tab=flag:<id>` opens pane, click flag patches URL, close tab falls back, garbage param silent fallback, PubSub reload preserves open tabs). Total: **387 tests, 0 failures** (was 375 at end of Phase 10.5).
- **ADR-015** — captures the 10 design decisions: URL as source of truth, pinned Profile + dynamic open_tabs, atom whitelist, mobile-sheet stays, compat shim, pane duplication, generic labels, fallback to :profile, push_patch (not push_navigate), legacy-assigns sync shim.

## What Phase 10.5 delivers

- **Expanded `/students` filter bar** — `IntellisparkWeb.UI.FilterBar` grows multi-select tags + status + enrollment controls (`<details>` disclosure with checkboxes) + a grade checkbox group. Each control updates `@filter_spec` via `phx-change="filter_change"`. Search box now writes to `filter_spec.name_contains` instead of a legacy `@search` assign.
- **`Save view` button** — appears at the right of the filter bar; disabled when no filters active; label flips between "Save view as…" (no `@from_list`) and "Save view" (editing an existing list).
- **`<.list_composer>` shared LiveComponent** — `lib/intellispark_web/live/custom_list_live/composer.ex` owns the modal for both Save (`mode: :create`) and Rename (`mode: :update`). `transform_params` callback injects `filters` (a serialized `FilterSpec` map) on submit so form fields stay limited to `name / description / shared?`. Read-only "Filters in this view" summary humanizes every filter key including the 13 SEL dimensions.
- **`/lists` per-card `⋯` menu** — `Rename` (opens composer) / `Edit filters` (`<.link navigate={~p"/students?from_list=<id>"}>`) / `Delete` (with `data-confirm` + AshArchival soft-delete). Built-in "All Students" pseudo-card has no menu.
- **`?from_list=<id>` round-trip** — `/students` `handle_params/3` loads the saved list, copies `list.filters` into `@filter_spec`, and the bar pre-populates. Tweaks update assigns (URL is ignored after mount); Save persists back to the same row via `:update`.
- **`OwnerOrAdminForCustomList` SimpleCheck** — Phase 2's `:update / :destroy` policy was owner-only. Phase 10.5 widens to "owner OR same-school admin" so admins can clean up lists owned by departed staff.
- **CustomList `archive_*` is now truthful** — `AshArchival` was already wired through the base `Intellispark.Resource` macro; the `archive_custom_list` code interface now correctly soft-deletes (sets `archived_at`) instead of hard-deleting. Restore path: `/admin?show_archived=true`.
- **12 new tests** across 2 files — `custom_list_policies_test.exs` (5 unit cases: owner update + archive, non-owner teacher denied, same-school admin update + archive) + `custom_list_composer_test.exs` (7 integration cases: save button disabled state, tag enables button, submit creates + navigates via `assert_redirect`, rename in place, delete archives, non-owner teacher invisibility, edit-filters round-trip preserves dimension filters set in JSON). Total: **375 tests, 0 failures** (was 363 at end of Phase 10).
- **ADR-012** — captures the 10 design decisions: shared composer, assigns-as-source-of-truth, `<details>` disclosures, dimension filters JSONB-only, `JS.toggle` for ⋯ menu, `data-confirm` for delete, binary `shared?`, `OwnerOrAdminForCustomList` widened policy, archival via base macro, `assert_redirect` test pattern for async `send/2`.

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
