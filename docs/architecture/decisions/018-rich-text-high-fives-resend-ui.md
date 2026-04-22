# ADR 018: Rich-text High 5 editor + per-row Re-send modal

**Status:** Accepted
**Date:** 2026-04-22
**Builds on:** ADR 008 (High Fives), ADR 016 (Branded emails + weekly digest — `:resend` action + `RecordResend` change module landed there), ADR 017 (Flag close-flow restructure — adjacent recent work).

## Context

Screenshot `11-14-04` shows the "New High 5" modal with a five-button rich-text toolbar (B / I / U / bulleted list / ordered list) and a submit button labelled **Re-send**. Two gaps vs the shipped Phase 6.5 UI:

1. The body input was a plain `<textarea>`. No formatting. Users couldn't bold a word or add a list.
2. The `:resend` action existed (Phase 6.5), but no UI button invoked it — only the resource action, with no affordance to edit title or body before re-sending.

Phase 6 retrofit closes both gaps with a single modal that branches on mode.

## Decisions

### 1. Rich text stored as sanitized HTML string

`body :string` (existing) now holds HTML like `<p>You were <strong>amazing</strong>...</p>`. Rejected alternatives:

- **ProseMirror / TipTap JSON** — heavier client dep, JSON ↔ HTML mapping on both sides, overkill for a 5-button toolbar.
- **Markdown** — requires an MD-to-HTML renderer on every display surface (Hub panel, email, public view). Bigger blast radius.

HTML wins on minimal surface area: existing `{h.body}` sites become `{raw(h.body)}` with sanitized writes.

### 2. Custom contenteditable + `document.execCommand` — no npm dep

Trix / TipTap would work but each adds ~50 KB + an npm dependency. A 5-button toolbar is ~60 lines of vanilla JS wrapping `document.execCommand`. `execCommand` is "deprecated" but universally supported; swapping to Trix later is a drop-in replacement if needed.

### 3. `html_sanitize_ex` on every write (defense-in-depth)

Even when the JS hook emits clean HTML, a crafted request could bypass the browser. `SanitizeBody` change module runs on `:send_to_student` + `:resend`, calling `HtmlSanitizeEx.basic_html/1`. A `<script>alert(1)</script>` attempt is stripped server-side before insert.

### 4. Unified `NewHighFiveModal` for create + resend via `:mode` attr

Rather than a second modal component, the existing modal takes `mode: :create | :resend`:

- `:create` — shows template pills, template dropdown, recipient email, submit → `:send_to_student`
- `:resend` — pre-fills from an existing HighFive, hides pills + recipient, submit → `:resend`

Shared HEEx cuts maintenance in half. The internal pill state attr (`mode: :template | :custom`) was renamed to `template_mode` to avoid name collision.

### 5. `:resend` action accepts optional `title` + `body` arguments

Signature: `argument :title, :string, allow_nil?: true, default: nil` + same for `:body`. `MaybeApplyResendEdits` change module reads them and calls `force_change_attribute/3` only when non-nil. Nil arguments keep existing values — useful for "send again, unchanged" from API callers.

### 6. `{raw(h.body)}` on Hub panel; `#{high_five.body}` in email

Hub panel is `IntellisparkWeb.StudentLive.Show.recent_high_fives_panel/1`. Email body is `HighFiveNotification`. Both use raw-interpolated HTML since the body is already sanitized at write time. Swap from `<p style="white-space:pre-line;">#{body}</p>` (which emits tag literals) to `<div>#{body}</div>` (which renders tags).

### 7. No data migration

Existing rows hold plain text. Rendering those via `raw/1` treats them as HTML — plain text with no tags is its own valid HTML. Going forward, new rows from the editor are HTML. Mixed fleet renders cleanly.

### 8. Per-row icon button (circular arrow), not a dropdown

Each Recent High 5 row gets a single `<button>` with `hero-arrow-path` icon, right-aligned next to the title. `aria-label="Re-send this High 5"`. No dropdown menu — one action, one click.

### 9. `title` stays plain text

Only `body` gets the rich editor. The `title` field shows as the email subject's green pill + the modal's Title field — HTML in there would be visually noisy (and break the subject line).

### 10. `phx-update="ignore"` on the contenteditable, NOT the wrapper

Applied only to the `<div data-rt-editor contenteditable>`. The wrapper `<div phx-hook="RichTextEditor">` continues to receive LiveView patches, so the hidden input's `value=` attribute updates on template autofill. The hook's `updated()` callback then syncs `editor.innerHTML ← hiddenInput.value`. Without this split, template autofill wouldn't populate the editor.

### 11. Integration tests submit via `render_submit(element, params)`, not `form/2`

`Phoenix.LiveViewTest.form/2` strict-validates hidden input values against the DOM — submitting a different body would raise because it treats hidden fields as read-only from the browser's POV. Since our editor flow mirrors body-edits through JS (which the DOM-level test doesn't simulate), we target the form element directly and push params through `render_submit/2`. The server-side resend path is still exercised end-to-end.

## Consequences

- One new dep (`html_sanitize_ex`), one new JS hook (~45 lines), one new component (`RichTextInput`), two new change modules (`SanitizeBody`, `MaybeApplyResendEdits`).
- The single `NewHighFiveModal` serves two product flows. Future variants (e.g., parent-recipient resend) can add a `:mode` value without forking the component.
- Rich-text adoption is optional — callers who pass plain text to `:send_to_student` or the resource action still work. Sanitizer is a no-op for tagless text.
- Old plain-text rows are rendered via `raw/1` without migration; there's a theoretical concern that a legacy body containing stray `<` or `>` could corrupt rendering, but live data audit showed none.

## Tests added (+9)

- `test/intellispark/recognition/changes/sanitize_body_test.exs` — 4 unit tests (strip script, keep allowed tags, preserve plain, sanitize on resend).
- `test/intellispark/recognition/high_five_resend_test.exs` — 2 new tests (title+body edits; nil keeps existing).
- `test/intellispark_web/live/high_five_resend_modal_test.exs` — 3 integration tests (open modal, submit edit, resent annotation).

Running total: **425** (was 416 after Phase 4 retrofit).

## Alternatives considered

- **Trix editor.** Cleaner API, built-in paste handling. Rejected for bundle size + npm dep.
- **Separate `ResendHighFiveModal` component.** Rejected — 80% code overlap with `NewHighFiveModal`; two components to sync.
- **Markdown body storage + server-side renderer.** Rejected — requires a renderer at every display site and double-conversion cost.
- **Dropdown menu on row (Re-send / View / Archive).** Rejected — one visible action, per screenshot. Archive already lives elsewhere.
