# ADR 008: High 5s — positive recognition with token-based public view + bulk_create delivery

**Status:** Accepted
**Date:** 2026-04-21
**Builds on:** ADR 002 (multitenancy), ADR 004 (Student domain), ADR 006 (Flag workflow — notifier + Oban email pattern template), ADR 007 (Phase 5 FilterCheck + custom Oban digest precedent).

## Context

Phase 6 ships the signature feature of Intellispark — positive recognition messages ("High 5s") sent to students with an email link. The real product screenshots show a Recent High 5's card at the top of the Hub's main column, a roster count column, and "No High 5 in 30 days" custom-list filtering for equitable distribution.

Phase 6 is the first feature in the Elixir port with a **token-based public URL** (parents/students click an email link without having an account), a **bulk-create write path** (send to 50 students at once), and a **dedicated audit log** for view events.

## Decisions

### 1. Three resources — `HighFiveTemplate`, `HighFive`, `HighFiveView`

Templates evolve independently of sent records (a template can be renamed or deactivated without rewriting history). Views are an append-only audit table — making them a real resource lets AshAdmin surface the log and lets us aggregate "views per high 5" as a regular relationship + aggregate.

### 2. Plain-text composition, not rich text

Same precedent as Phase 5 Notes. The body field is `:string`, rendered with `whitespace-pre-line` in emails + UI. Phase 12 polish can add ProseMirror/TipTap.

### 3. 128-bit random URL-safe token stored raw (not hashed)

`:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)` → 22-character tokens in the URL. Stored raw because:
- Hashing adds no security value for 128-bit random (no reverse lookup risk)
- We need the URL to be reconstructable for admin resend flows

Unique index on `token` column catches the theoretical collision.

### 4. `:by_token` action uses `multitenancy :bypass`

Unauthenticated viewers have no tenant context. The token IS the auth. The action bypasses tenancy at the resource layer, and the policy is `authorize_if always()`. Worst-case exposure on a leaked token is one High 5 + sender's email — no sensitive data.

### 5. Unauthenticated public view at `/high-fives/:token`

Mounted inside the `:maybe_user` live_session (same scope as invitation links). The LiveView reads the row via `:by_token`, hydrates `:student / :sent_by / :school` with `authorize?: false`, and schedules `{:record_view, ...}` via `send(self(), ...)` only after `connected?/1` returns true so email-preview fetches don't bump the view count.

### 6. `recent_high_fives_count` aggregate filtered on 30-day window

Matches the feature-inventory purpose (equitable distribution). A student who received 47 High 5s in 2022 but none this month should register as "low recent." Used by the roster badge, hub header badge, and the `no_high_five_in_30_days` custom-list filter.

### 7. Email delivery via notifier → Oban job → Swoosh (not synchronous)

A Resend outage shouldn't block the LiveView. The notifier enqueues `DeliverHighFiveEmailWorker`; the worker hydrates the row + dispatches `HighFiveNotification.send/1`. Opposite tradeoff from Phase 4 Flag emails (synchronous in the notifier): email visibility is not latency-critical for the sender, and Oban's retry semantics handle transient Resend blips.

### 8. Bulk send via `Ash.bulk_create` with partial-failure reporting

`bulk_send_to_students` looks up the template once, builds N payloads, calls `Ash.bulk_create(payloads, HighFive, :send_to_student, ...)` with `return_records?: true, return_errors?: true, stop_on_error?: false, notify?: true`. Returns `%Ash.BulkResult{records, errors}` — the LiveView flashes "N sent, M failed (likely missing emails)" on partial success. Per-row authorization runs through `CanSendHighFive`, so a mixed-school bulk is rejected cleanly rather than leaking rows.

`notify?: true` is the critical kwarg — without it, `bulk_create` skips the notifier pipeline, and the Oban delivery jobs never enqueue.

### 9. `no_high_five_in_30_days` filter as a FilterSpec boolean

Extends `Intellispark.Students.FilterSpec` with one new attribute + a single clause in `RunCustomList.apply_filters/2`:

```elixir
defp apply_no_high_five_in_30_days(query, true) do
  query
  |> Ash.Query.load(:recent_high_fives_count)
  |> Ash.Query.filter(recent_high_fives_count == 0)
end

defp apply_no_high_five_in_30_days(query, _), do: query
```

Same shape as the other `apply_*` clauses. Zero new query-compilation infrastructure — the aggregate already exists.

## Consequences

**Positive**
- The `notifier → Oban → Swoosh` indirection is now a well-exercised pattern (Phase 4 used inline-notifier-sending, Phase 5 used Oban-digest workers; Phase 6 completes the matrix with Oban-single-email).
- `Ash.bulk_create` with partial-failure reporting is the first real exercise of batched write with per-row authorization in the codebase — Phase 9 Insights can reuse the pattern for cross-student bulk operations.
- Token-based public view opens the door for the student-facing survey flow in Phase 7 (same `:maybe_user` live_session + token-scoped read action shape).
- `HighFiveView.Version` paper-trails the audit log itself — compliance reports can reconstruct "who viewed this when + from what UA" without touching production tables.

**Negative**
- Token revocation is not wired in Phase 6. A compromised inbox leaks that student's High 5 forever (no time-based expiry, no admin revoke button). Phase 12 polish.
- Bulk-send on a 100-student list fans out 100 Oban jobs. At Phase 11 multi-district scale (thousands of simultaneous sends around report-card time) this hits Oban pool contention. Phase 15 can rate-limit at the worker level.
- `view_audit_count` aggregate on HighFive fires a subquery per row when listed — O(N) extra reads on the "Previous High 5's" drawer. Fine now (<20 rows typical) but may need caching at scale.
- `recipient_email` override persists forever on the HighFive row. If a student's email changes (typo correction, account merge), old High 5s still link to the old address. Accepted — the send is an immutable event.

## Alternatives rejected

- **Hash the view token.** No security gain for 128-bit random; costs us the ability to reconstruct the URL for admin resend.
- **Family account login instead of token URL.** Phase 14 Parent Portal scope. Phase 6 must work for parents without accounts.
- **Synchronous email in the notifier (Phase 4 pattern).** Blocks LiveView on Resend latency. Phase 4 accepted this because Flag assignees are internal staff on a well-monitored outbound address; High 5 recipients are external parents whose MX records we can't count on.
- **`Ash.bulk_create` with `stop_on_error?: true`.** A single missing email would drop the whole batch. Partial success is the desired UX.

## Cross-references

- ADR-002 — multi-tenancy; HighFive / HighFiveTemplate inherit `global?: false`.
- ADR-004 — Student domain; `Student.has_many :high_fives` + `Student.recent_high_fives_count` aggregate.
- ADR-006 — Flag workflow; first place the notifier + Swoosh sender pattern lived.
- ADR-007 — Phase 5 FilterCheck + custom Oban digest; same template reused for `CanSendHighFive` + `DeliverHighFiveEmailWorker`.
