# ADR 007: Actions, Supports & Notes — three resources, two state machines, shared support domain

**Status:** Accepted
**Date:** 2026-04-20
**Builds on:** ADR 004 (Student domain), ADR 005 (Student Hub), ADR 006 (Flag workflow — state machine + notifier template).

## Context

Phase 5 completes the Student Hub right-column workflow. Three new resources each fill a distinct slot on the hub: Actions (follow-up tasks with binary completion), Supports (intervention plans with a 4-state lifecycle), Notes (plain-text case notes with pin/unpin + paper-trailed edit history). Every one of them is tenant-scoped on `school_id`; every one of them paper-trails every change.

Phase 4 introduced a state-machine + notifier + AshOban template with Flag. Phase 5's goal was to prove that template is reusable — two more state machines, two more Oban cron workers, three more audit surfaces — without growing the mental model, and without requiring per-resource scaffolding hacks.

## Decisions

### 1. Reuse the existing `Intellispark.Support` domain for all three resources

`Intellispark.Support` was scaffolded empty in Phase 0. Rather than split into `Actions`, `Supports`, `Notes` domains, all three Phase-5 resources live in it. The domain is "student-support workflow" — Actions / Supports / Notes are each a facet of the same workflow and compose together. Three separate domains for three resources would have tripled the code-interface aliasing burden on `StudentLive.Show`.

**Rejected alternative — per-resource domains.** Adds three modules for zero organizational clarity.

### 2. Action as a two-state machine (`:pending → :completed` / `:cancelled`)

Screenshot `10-04-19` shows Actions as checkbox rows with due dates. The absolute minimum state machine is:
- `:pending` — initial; checkbox visible + active
- `:completed` — terminal; row drops from the panel after ``complete_action``
- `:cancelled` — terminal; exists so an action raised in error can be scrubbed without corrupting the audit trail

Boolean `completed?` would work for the happy path but loses the cancelled-vs-never-done distinction. No reopen path — if an action was completed in error, the user-facing recovery is to create a new one. That keeps the state machine minimal.

**Rejected alternative — boolean `completed?` column.** Collapses "never done" and "scrubbed" into the same absence-of-completion, which breaks reporting.

### 3. Support as a four-state machine even though the UI only surfaces two pills

Screenshots show "Offered" + "In progress" pills. But `:completed` and `:declined` are distinct audit outcomes — "Flex Time Pass ran its course" ≠ "family refused services." Both are terminal, but the audit trail needs to distinguish them. The detail-sheet buttons only expose the transitions that exist from the current state, so the UI never feels wider than the screenshots; the audit history is richer than what the pill list suggests.

**Rejected alternative — two-state (`:active → :resolved`).** Loses the declined-vs-completed distinction on a row that might be months old; compliance reporting would have to infer from side-channel data.

### 4. Notes ship as plain text, not rich text

The plan-specified rich-text editor (ProseMirror / TipTap) is 400+ lines of JS, a custom Ash type, and a migration. Plain text with CSS `whitespace-pre-line` ships Phase 5 in a tenth of the work and is indistinguishable from rich text for the 90% case (paragraphs + line breaks + no inline formatting). Phase 12 polish can swap in a real editor.

Notes store as `:string` (Postgres `text`), render with `<p class="whitespace-pre-line">`. Newlines preserve. That's the whole UX.

**Rejected alternative — TipTap / ProseMirror now.** Way too much JS for a v1. Changing to rich text later is data-compatible: plain text is valid ProseMirror input.

### 5. Pin/unpin as discrete actions, not a state machine

Pinning is orthogonal to lifecycle status. A state machine assumes a single linear-ish progression; `pinned?` is a flag that can flip any number of times. Two update actions (`:pin`, `:unpin`) that set `pinned?` + `pinned_at` are simpler to policy-gate ("only the author or an admin") than branching a state machine.

### 6. Sensitive-notes gating copies the `StaffReadsFlagsForStudent` FilterCheck verbatim

`StaffReadsNotesForStudent` is the same 15 lines with `notes` instead of `flags` in the entity references. The clinical-roles allowlist is identical (`:admin`, `:counselor`, `:clinician`, `:social_worker`). Non-clinical actors' reads are filtered down to `sensitive? == false` at the policy layer — no template-level branching, no role checks in the panel, aggregates drop sensitive rows automatically.

**Rejected alternative — a shared FilterCheck module parameterized by resource.** Would need to thread the resource-specific `sensitive?` column name through an opts keyword; the savings in duplicated LOC didn't justify the indirection. If we grow a third copy, we can reconsider.

### 7. Custom Oban workers for both reminder digests, not AshOban triggers

Mirror of the Phase 4 Flag `DailyFollowupReminderWorker` decision: AshOban would fire one email per row. We want one digest per assignee / provider. Two plain `Oban.Worker` modules registered directly on `Oban.Plugins.Cron` in `config.exs`:

- `DailyActionReminderWorker` at 7:00 — groups pending actions by assignee, one `ActionDigest` email each.
- `SupportExpirationReminderWorker` at 7:05 — groups supports expiring within 3 days by provider, one `SupportExpiring` email each.
- Phase 4's `DailyFollowupReminderWorker` continues at 8:00.

The 7:00 / 7:05 / 8:00 staggering avoids pool contention on shared DB connections.

**Rejected alternative — AshOban per-action trigger.** Produces one email per row, which violates the "digest" UX intent.

### 8. Layout — Actions + Supports in sidebar; Notes in main column

Real-product screenshots (`10-04-19`, `10-04-45`) put the Actions and Supports panels in the right column next to Flags. That's where staff scan for "what needs my attention right now." Notes has no real-product reference — we chose the main column because the wider column supports longer-form reading, and the Notes composer + pin/unpin UI wants more horizontal real estate than the sidebar can spare.

Final sidebar order: Profile → Flags → Actions → Supports → Status → Tags. Main column: Notes → High-5s placeholder → Activity timeline.

### 9. Activity timeline gets Note.Version but not Action.Version or Support.Version

Phase 3 timeline merged Student + StudentTag + StudentStatus Version rows. Phase 5 adds Note.Version rows as `:note_event` entries (create → "Posted a note", update → "Edited a note", pin/unpin noted too). Action and Support transitions are deliberately excluded — those lifecycles are already visible on their own panels in real time, and the timeline is meant to stay narrative-weight ("what did the counselor do this week?") rather than event-log-weight.

## Consequences

**Positive**
- Two more resources using the same state-machine + notifier + Oban template from Phase 4. The only new abstraction is `<.support_status_pill>` — a colour-map twin of `<.flag_status_pill>` — and the scoped-PubSub reload handlers (`reload_actions/1`, `reload_notes/1`) that avoid refetching the whole Student on narrow broadcasts.
- `open_supports_count` aggregate drives the roster Supports badge with the same pattern as `open_flags_count`. Phase 6 can swap `value={0}` for `value={s.high_fives_count}` the same way.
- Notes, Actions, and Supports each have a dedicated paper-trail surface. Compliance reports are trivial Version-table queries.
- Sensitive gating on Notes is the same mental model as Flag — one FilterCheck, no template branching.

**Negative**
- Both new Oban workers iterate tenants (O(schools) reads). Same tradeoff as Phase 4; Phase 11 multi-district will need a materialized view or a direct-SQL bypass.
- `edited?` calc on Note uses a 2-second threshold to distinguish "just created" from "edited." Editing within 2 seconds of creation won't flip the badge. Acceptable jitter for a UX detail; hard to hit in practice.
- The sheet's mini-timeline reads `Support.Version` on every mount — fine now with ~5 transitions per support, noticeable if a Support is touched hundreds of times. Phase 12 can paginate.
- Action / Support transitions are not in the main Activity timeline. If the product decides the counselor view should see "accepted Flex Time Pass yesterday," we can add a `:support_event` kind — it's a 20-line addition.

## Alternatives rejected

See per-decision sections above. The recurring theme: reuse the Phase 4 template (state machine + notifier + custom Oban digest + FilterCheck) rather than inventing new patterns per resource.

## Cross-references

- ADR-004 — Student domain; all three new resources `belongs_to :student`.
- ADR-005 — Student Hub layout; Phase 5 fills every panel on the right column and the main column's Notes slot.
- ADR-006 — Flag workflow; the state-machine + notifier + custom-Oban-digest template Phase 5 reuses.
