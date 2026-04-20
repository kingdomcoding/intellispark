# ADR 006: Flag workflow with AshStateMachine + AshOban + notifier-driven emails

**Status:** Accepted
**Date:** 2026-04-20
**Builds on:** ADR 002 (multi-tenancy), ADR 004 (Student domain), ADR 005 (Student Hub).

## Context

Phase 4 is the first feature in the product with a real lifecycle. A flag is raised, triaged, assigned, worked, and ultimately closed (or reopened). Every state transition is a decision point that needs an audit trail, per-role authorization, and sometimes a notification. Prior phases shipped CRUD + inline editors; Phase 4 is where declarative workflow tooling earns its keep.

Three requirements shaped the decisions:

1. **The state machine should be the source of truth.** A bad "close → open" attempt needs to be rejected at the resource layer, not guarded in LiveView.
2. **Emails and PubSub should be cleanly decoupled.** The `:open_flag` action shouldn't import Swoosh. Adding SMS later shouldn't touch action code.
3. **Scheduled background work should be wire-once.** Hourly auto-close + daily digest reminders are well-known patterns; we want them declared on the resource, not assembled by hand.

## Decisions

### 1. AshStateMachine over hand-rolled changeset guards

Seven states (`:draft`, `:open`, `:assigned`, `:under_review`, `:pending_followup`, `:closed`, `:reopened`) + seven transitions declared in a single `state_machine do` block on the `Flag` resource. Each transition maps 1:1 to an `update` action (`:open_flag`, `:assign`, `:move_to_review`, `:set_followup`, `:close_with_resolution`, `:auto_close`, `:reopen`) that carries its own `accept`, `argument` list, and policies.

Invalid transitions are rejected at the resource layer with a clean `AshStateMachine.Errors.NoMatchingTransition` error — the LiveView never has to guard "can this action happen in this state?" The side-sheet UI just conditionally renders transition buttons based on current status; a teacher who tries the wrong action through AshAdmin gets the same rejection.

**Rejected alternative — a single `:transition` action with a `to:` argument.** Would have collapsed the seven actions into one with a big `case` statement for per-target authorization and validation. The per-action split keeps every transition's behaviour in one obvious place, and `AshStateMachine` was designed for exactly this decomposition.

### 2. Each transition carries its own policies, not a blanket one

- `:open_flag` / `:assign` / `:move_to_review` / `:set_followup` — `StaffEditsStudentsInSchool` (FilterCheck), permissive within school.
- `:close_with_resolution` — new `AssigneeOrClinicalActorForFlag` (SimpleCheck): a current assignee, or someone holding `:admin` / `:counselor`.
- `:reopen` — new `OpenerOrAdminForFlag` (SimpleCheck): either the user who opened the flag or an admin.
- `:auto_close` — `always()`. Server-initiated only; the Oban trigger is the "actor".
- `:destroy` — `actor_attribute_equals(:role, :admin)`. Never through the UI; admin-only cleanup.

Reads have their own FilterCheck — `StaffReadsFlagsForStudent` — that scopes to the actor's schools **and** gates `sensitive? == true` flags behind clinical roles (`:admin`, `:counselor`, `:clinician`, `:social_worker`). Teachers see non-sensitive flags for their students; sensitive ones are invisible at the resource layer. No template-level role checks.

### 3. FlagAssignment as a real join resource

Multi-assignee is the rule, not the exception. A join table (Flag ↔ User with `assigned_at`, `assigned_by_id`, `cleared_at`) gives us per-assignment timestamps + paper-trail history. "Who was assigned to this flag last Tuesday?" is a Version-row query.

`SyncAssignments` change module reconciles the current assignment set against an `:assignee_ids` argument on every `:open_flag` / `:assign` call: creates missing, clears removed, **reactivates** previously cleared rows (via a new `:reactivate` action) instead of tripping the unique `(flag_id, user_id)` index when a user is re-added.

**Rejected alternative — an `{:array, :uuid}` column on Flag.** Works for simple cases but collapses the "when was each person added?" audit surface.

### 4. Sensitivity as a row attribute + a single FilterCheck

`sensitive?: boolean` on Flag, inherited from `FlagType.default_sensitive?` at create time (unless the user explicitly passes it). One policy expression on `:read` — `StaffReadsFlagsForStudent` — filters non-clinical actors down to `sensitive? == false`. Every other read path (list views, aggregates, LiveView panels) inherits the filter automatically.

**Rejected alternative — per-call sensitivity checks in LiveViews and aggregates.** Would have scattered "if role in clinical_roles then render flag else nil" across every template. Policy-at-read means the sensitive flag never leaves the database for a teacher, aggregates drop it, and nothing downstream has to remember.

### 5. Emails decoupled via a dedicated notifier module

`Intellispark.Flags.Notifiers.Emails` subscribes to Flag update notifications and dispatches:
- `FlagAssigned.send/3` per active assignee on `:open_flag` or `:assign`
- `FlagAutoClosed.send/2` per active assignee on `:auto_close`
- Fallback `:ok` for anything else so the notifier pipeline never crashes

The `:open_flag` action doesn't import `Intellispark.Mailer`. Adding an `InAppNotification` sender later is a new notifier clause, not a new branch in the action.

**Rejected alternative — calling `Swoosh` directly from `SyncAssignments` change.** Couples the action module to the mailer and duplicates side-effect logic if multiple actions produce the same notification.

### 6. AshOban triggers on the resource; custom workers for shaped behavior

Two scheduled jobs:

- **`:auto_close_stale_flags`** — declared as an `oban trigger` block on the Flag resource with an explicit `worker_module_name`. Hourly cron filters for flags where `auto_close_at <= now()` and status is in a working state; invokes `:auto_close` per flag. Notifier picks up the transition and fires `FlagAutoClosed` emails. All wire-once behaviour.

- **`DailyFollowupReminderWorker`** — a plain `Oban.Worker` at `lib/intellispark/flags/oban/`. AshOban's per-action trigger would fire one email per flag; we want one digest email per user. The worker reads matching flags across all schools (iterating tenants because Flag is `global?: false`), groups by assignee, and sends `FollowupDigest.send/2` exactly once per recipient. Registered directly on the `Oban.Plugins.Cron` plugin in `config/config.exs`.

**Rejected alternative — using the auto-generated AshOban worker for the digest.** Would have required a custom `read` action + per-flag email, then either N emails per user or a complex aggregation step inside the action. A plain Oban.Worker was simpler and honest about what's happening.

### 7. FlagComment schema now, UI deferred to Phase 13

Comment thread is Phase 13 scope — but the schema costs ~20 lines and prevents a schema migration + paper-trail snapshot churn later. The resource exists, has `:create` / `:read` / `:destroy` actions and standard policies, and `Flag.has_many :comments` plus `comment_count` aggregate are wired. Phase 13 adds the LiveView and a PubSub topic for real-time comment rendering.

**Rejected alternative — ship the table with Phase 13.** Means one migration perturbing `flags_versions`, another adding the `flag_comments` table, plus the reciprocal relationship on Flag. Landing the schema now costs nothing and makes Phase 13 a pure-UI change.

## Consequences

**Positive**
- Seven clean Ash actions, one per transition. Every button in the Hub detail side-sheet maps to exactly one action.
- Policies live with the resource. The Hub LiveView has zero role-based template branching.
- Realtime updates on Phase-4 flag events flow through the existing `students:<id>` pattern (via the narrow `flags:student:<id>` topic on Flag) — Phase 3 plumbing didn't need to change.
- The generated migration trails `student_id` through `flags_versions` + `flag_assignments_versions` + `flag_comments_versions`, so the Hub timeline can filter by student without joins.
- Adding SMS / webhook notifications later is a new notifier module, not a change to any action.

**Negative**
- AshStateMachine wants a dedicated `state` column by default; we override with `state_attribute :status` to reuse the existing enum. If we ever add a second state machine to the same resource, that convention won't extend.
- The `DailyFollowupReminderWorker` iterates schools to accumulate the cross-tenant query. With `global?: false` that's the correct approach — but it scales O(schools) with a read each. Phase 11's multi-district expansion will need a materialized view or a bypass.
- FlagComment's paper-trail rows accumulate per comment; if the eventual UI allows high-frequency comment editing, those Version rows might need pruning. Not a Phase 4 problem.
- The notifier synchronously sends emails inside `Ash.Notifier.Notification` dispatch. A Resend outage would slow down Flag transitions. A Phase 15 follow-up should move email sends into Oban jobs dispatched from the notifier (Resend already supports retries, so this is a latency optimization, not a correctness issue).

## Alternatives rejected

See per-decision sections above. The recurring theme: keep workflow logic in Ash (actions + policies + state machine + notifiers), keep the LiveView templates thin, and let Oban handle the schedules.

## Cross-references

- ADR-002 — multi-tenancy foundation; Flag inherits `global?: false` on school_id
- ADR-004 — Student domain; Flag `belongs_to :student`
- ADR-005 — Student Hub layout; Phase 4 fills the sidebar Flags card and moves it out of the main column per the real-product screenshots
