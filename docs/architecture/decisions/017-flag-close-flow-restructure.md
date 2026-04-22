# ADR 017: Flag close-flow restructure — inline check-up date + close button

**Status:** Accepted
**Date:** 2026-04-22
**Builds on:** ADR 006 (Flag workflow), ADR 015 (Hub Tab Framework — pane lifted from sheet), ADR 016 (Branded emails — adjacent work).

## Context

Screenshots `11-12-07` and `11-12-27` show the flag detail's close UX as a single always-visible bottom-bar: an empty `Check-up date` input on the left, a red `Close Flag` button on the right. Click into the date input → native HTML5 calendar opens. There's no resolution-note textarea, no "Close" button that expands into a form, no multi-step modal.

The Phase 4 implementation (carried forward verbatim into Phase 3.5's `FlagDetailPane`) had a 3-state UI:

1. Default — transition buttons row (Move to Review / Set follow-up / Close / Reopen)
2. Close form open — required `resolution_note` textarea + Cancel/Submit
3. Followup form open — required `followup_at` date input + Cancel/Submit

Three problems:
- **Extra clicks.** Every close: click Close → form expands → type note → submit.
- **Forced content.** `resolution_note` was `allow_nil?: false`. Staff often close because the situation resolved naturally — no note to invent.
- **Doesn't match screenshots.** Inline bar, not a Close-then-expand pattern.

Phase 4 retrofit restructures the close flow to match the screenshots and removes the four Phase 3.5 backward-compat sheet-event shims that were tagged for this phase.

## Decisions

### 1. `resolution_note` becomes optional on `:close_with_resolution`

`argument :resolution_note, :string, allow_nil?: true, default: ""`. The `:string` attribute itself stays nullable (Ash normalizes `""` → `nil` on write — that's fine; both represent "no note"). AshPaperTrail still captures the action's argument value.

### 2. `followup_at` added as optional argument

`argument :followup_at, :date, allow_nil?: true, default: nil`. When present, the new `MaybeSetFollowup` change module sets it on the flag before `transition_state(:closed)`. Atomic close + check-up reminder in one transaction.

### 3. Closed flags with `followup_at` stay `:closed`, not `:pending_followup`

The check-up date is a reminder annotation on a closed row. If the staff member wants the flag to re-appear on their follow-up digest as `:pending_followup`, they use the separate `:set_followup` action (which DOES transition to that state). Don't conflate the two workflows.

### 4. `close_flag` code-interface switches from `args: [:resolution_note]` to no positional args

Callers now pass an input map: `Flags.close_flag(flag, %{resolution_note: note, followup_at: date}, actor:, tenant:)`. Cleaner than a 2-positional-arg variant; future args slot in without breaking the call signature.

### 5. Inline bottom-bar replaces the "Close" button + form expansion

The bar is always visible when the flag is in any non-closed state. Date input + red Close Flag button. No `close_form_open?` assign, no `close_note` assign, no `open_close_form` / `cancel_close` / `open_close_form` event handlers.

### 6. `FlagDetailPane` and `FlagDetailSheet` copy-paste the close bar (no shared component)

Extracting a `<.flag_close_form>` function component would be premature. The mobile sheet is scheduled for retirement in Phase 16 (Mobile/PWA refresh). Until then, two ~12-line HEEx blocks are easier to maintain than a third file with attr declarations.

### 7. Mobile sheet's close buttons use `close_tab` directly

The Phase 3.5 backward-compat shims (`open_flag_sheet` / `close_flag_sheet` / `open_support_sheet` / `close_support_sheet`) routed legacy events to the new `open_tab` / `close_tab` handlers. Phase 4 retrofit deletes the shims and updates the sheet's two close-button HEEx attrs to dispatch `phx-click="close_tab" phx-value-tab="profile"` directly. The Phase 3.5 `sync_legacy_sheet_assigns/2` helper still keeps `@flag_detail_open?` in sync — no behavior change.

### 8. `resolution_note` attribute stays on the resource (not deprecated)

AshAdmin still displays it; PaperTrail still captures it; the `:auto_close` action still writes a default string into it. The change here is the action's argument-validation, not the attribute itself.

### 9. `MaybeSetFollowup` is a dedicated change module, not inline

Inline `change set_attribute(:followup_at, arg(:followup_at))` would always set the attribute (overwriting an existing followup with `nil` when the arg isn't passed). The dedicated module pattern-matches: `nil` arg → no-op (preserve existing); `%Date{}` → `force_change_attribute`. Aligns with Phase 10's `StampAddedBy` precedent.

## Consequences

**Positive**
- One-click close. The bar matches the screenshot exactly.
- Optional follow-up. Closing + scheduling a check-up is one transaction.
- Code surface shrinks: ~50 lines of close-form HEEx + 4 handlers gone in each of pane + sheet.
- Phase 3.5 deprecated shims gone; `show.ex` event-routing is cleaner.

**Negative**
- Long-form resolution notes are no longer authorable from the UI. Edge cases handled via AshAdmin or future Phase 12 polish.
- The auto-close worker still writes "Auto-closed: no activity for 30 days." into `resolution_note` — that's intentional (different action, different default), but it means flags can have a resolution_note even though no UI surfaces it. Acceptable.
- Sheet + pane copy-paste means future close-bar tweaks need two edits. Tagged as a Phase 16 cleanup.

## Alternatives rejected

- **Keep `resolution_note` required.** Rejected — forces staff to type ceremonial content for routine closes.
- **Two separate actions** (`:close` + `:close_with_followup`). Rejected — the params-map syntax is one signature for both paths; an extra action would just be an arg-shape proxy.
- **Retire `FlagDetailSheet` entirely in this phase.** Rejected — mobile UX needs a bottom-sheet pattern, not an inline pane. Sheet retirement is Phase 16 territory.
- **Shared `<.flag_close_form>` function component.** Rejected — premature abstraction with two callers and one of them on the chopping block.
- **Inline `change set_attribute(:followup_at, arg(:followup_at))`** instead of the dedicated change module. Rejected — would overwrite existing followup with `nil` on close-without-date.

## Cross-references

- **ADR-006** — original Flag workflow + first `:close_with_resolution` action. The action signature change is here.
- **ADR-015** — Phase 3.5 Hub Tab Framework. The pane was lifted from the sheet here; Phase 4 retrofit restructures both.
- **ADR-016** — Phase 6.5 Branded emails. The `FlagAssigned` notifier emits a click-through link to `?tab=flag:<id>` — adjacent UX surface.
