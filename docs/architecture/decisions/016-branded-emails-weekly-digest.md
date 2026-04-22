# ADR 016: Branded email templates + weekly digest + per-user preferences

**Status:** Accepted
**Date:** 2026-04-22
**Builds on:** ADR 006 (Flag workflow + first email patterns), ADR 008 (High Fives + token-based view), ADR 015 (Hub Tab Framework — adjacent UI work).

## Context

The 2026-04-21 screenshot review surfaced four email-related deltas:

1. **Branded HTML for Flag-assignment emails** (screenshot `11-12-42`) — logo, orange-gradient banner, white inner card, footer with company address + social icons.
2. **Branded HTML for High 5 emails** (screenshot `11-14-24`) — title in a green pill, 👋 hero icon above the card, school name in centered footer.
3. **Weekly digest** (screenshots `11-14-39 / 11-14-56 / 11-15-08`) — `New activity from last week` multi-section email (High 5s with body excerpts → Flags with `(assigned to you)` annotations → Action needed → Notes). Sent to staff Mondays.
4. **High 5 `Re-send` button** (screenshot `11-14-04`) — re-trigger the email for an existing recognition.

An audit of the existing pipeline revealed that **the shared branded layout was already built** (`IntellisparkWeb.EmailLayout.wrap/1`) and 11 email modules already routed through it. The actual scope shrunk to: visual polish of the layout, per-event template refresh, weekly-digest pipeline, per-user preferences, and the `:resend` action.

## Decisions

### 1. Polish `EmailLayout.wrap/1` in place; reject `phoenix_swoosh` templates

The existing inline-string + keyword-opts shape works. Adding `phoenix_swoosh` for HEEx `.html.heex` templates would mean a new dep, a separate `view` per email, and template-locating ceremony for marginal benefit. The polish (logo `<img>`, gradient bg, branded footer, `pill_green` heading, optional `hero_icon`) lands as new opts on the existing helper. One file edit; 11 callers refresh their bodies.

### 2. Logo embedded as a public URL, not `cid:`-attached

`<img src="https://intellispark.example.com/images/logo-150.png">` is dead-simple, works in dev with the local mailbox preview, and is supported by Resend in production. Risk: some corporate Outlook installs block external images by default — accepted; the layout degrades to text-only without breaking.

### 3. `:title_treatment` opt for per-event styling

`heading_block(text, :pill_green)` renders the title inside a green pill (matches High 5 screenshot). Other event kinds use the default `<h1>` styling. Adding a fourth treatment is a one-line clause — extensible without touching `wrap/1`.

### 4. `email_preferences :map` JSONB attribute on User (not a separate resource)

A `UserEmailPreference` resource would be 2 rows-per-event-per-user, queried only as a single record per user, joined to nothing. A JSONB `email_preferences` attribute on `User` (with `default: %{}`) is cheaper, simpler, and adequate for the per-event opt-in granularity we need. Trade-off: schema migrations for new event kinds require code changes, not data inserts — acceptable since event kinds are product-level constants in `EmailPreferences.valid_kinds/0`.

### 5. Default-in opt-out semantics

If the `email_preferences` map has no key for a given event kind, the user is opted IN. New users start with `%{}` and receive every email. This preserves backward compatibility (existing users get no behavior change post-deploy) at the cost of not asking for explicit consent. Phase 18.5 onboarding can flag this in the welcome flow.

### 6. Predicate-helper enforcement (no Swoosh middleware)

`EmailPreferences.opted_in?/2` is called at each notifier site rather than wired as a global Swoosh middleware. Three reasons: (a) testability — unit tests call the predicate directly; (b) the helper resolves `user.email_preferences[event_kind]` with the default-true fallback in one place per event; (c) global hooks would need to inspect Swoosh emails to figure out the event kind, which is fragile.

### 7. Cron-driven `WeeklyDigestWorker` (not AshOban trigger)

AshOban triggers are for "when this resource action fires, enqueue this worker." The weekly digest is "scan everyone with prefs at 7 AM Monday." The vanilla `Oban.Plugins.Cron` registration in `config/config.exs` is the natural fit. The worker has `unique: [period: 60 * 60 * 24]` to mitigate multi-node cron drift (Oban Cron runs once per cluster, but during deploys two nodes can briefly both schedule).

### 8. Cohort = `team_memberships.user_id`; parent recipients deferred

For each opted-in staff user, the digest scopes to students they're on the team of (via `Intellispark.Teams.TeamMembership`). Parent recipients are deferred — there's no parent User model yet. Phase 14 lands `ExternalPerson` and the parent-recipient path can layer on top.

### 9. Skip-empty-digests

`WeeklyDigestComposer.empty?(digest)` short-circuits delivery when all four sections are empty. No "you have nothing this week!" emails. The composer already filters per-section empty lists out of the `:sections` keyword list, so `empty?/1` is `sections == []` — cheap.

### 10. HighFive `:resend` is a separate update action (not `:send_to_student` re-call)

A new `:resend` update action sets `resent_at` and triggers `Recognition.Notifiers.Emails.notify_resent/1` in an `after_action`. The notifier enqueues the existing `DeliverHighFiveEmailWorker` with `event_kind: "high_five_resent"` so the worker can short-circuit on opt-out for the resend kind specifically. The original HighFive row (token, `sent_at`, `view_count`, audit log) stays intact.

## Consequences

**Positive**
- Every transactional email now matches the brand screenshots without per-notifier copy-paste.
- Weekly digest gives staff a low-friction "what happened last week" recap without spamming on quiet weeks.
- Per-user preferences are a foundation for Phase 13's multi-channel notifications (in-app + email + push) — same `EmailPreferences.opted_in?/2` predicate style.
- HighFive `:resend` is a tiny addition that closes a real workflow gap (a recipient lost the original email; admin re-sends).
- `WeeklyDigestComposer` is a pure module — easy to unit test, easy to extend with new sections (Phase 13 may add Notifications, Phase 14 may add Indicator changes).

**Negative**
- Logo image blocking by Outlook degrades the visual; mitigated by readable text fallbacks in the layout.
- Default-in semantics mean new users get every email until they opt out; could be perceived as spam during onboarding. Phase 18.5 should surface preferences in the welcome flow.
- Cohort = `team_memberships` excludes one-off mentions: a staff user who's been mentioned in a flag for a student they're NOT on the team of won't see that flag in the digest. Acceptable v1 — the "team membership" relationship is the canonical "who supports whom."
- Multi-node cron drift is mitigated by `unique: [period: 24h]`, but during week-1 deploys with multiple workers, the unique window may be too short. Increase if production sees duplicates.

## Alternatives rejected

- **`phoenix_swoosh` templates** — extra dep, indirection, doesn't fit the existing inline-string-plus-helper pattern.
- **Separate `UserEmailPreference` resource** — 2 rows per (user × event_kind), queried only as a single batch per user. JSONB is simpler.
- **AshOban trigger for the weekly digest** — wrong fit; the digest fires on a schedule, not on a resource action.
- **Global Swoosh middleware for opt-out enforcement** — would need to inspect outgoing emails to derive the event kind. Fragile.
- **Force re-consent on existing users** — would surprise current users who never asked for an email-prefs page. Default-in keeps them happy until they explicitly opt out.
- **HighFive `:resend` as a `:send_to_student` re-call** — would create a NEW HighFive row, polluting the recent-feed and orphaning the original token.

## Cross-references

- **ADR-006** — Phase 4 introduced the first transactional email pattern + `EmailLayout`. Phase 6.5 polishes that layout and threads opt-out through every notifier.
- **ADR-008** — Phase 6 introduced the High 5 token-based view + Oban worker email pattern. The digest worker reuses the same Oban queue (`:emails`) and the resend feature reuses the existing worker with an extra arg.
- **ADR-015** — Phase 3.5 Hub tab framework is unrelated UI work landed in the same iteration.
