# ADR 005: Student Hub at /students/:id

**Status:** Accepted
**Date:** 2026-04-20
**Builds on:** ADR 002 (multi-tenancy via attribute on `school_id`), ADR 003 (invite-driven membership), ADR 004 (Student domain).

## Context

Phase 2 made `/students` a real surface — a tenant-scoped list with chips, bulk-tag, and saved filters. Phase 3 is where a single row becomes a workable page. Every downstream phase hangs off `/students/:id`: Flags (Phase 4) as a panel, High-5s (Phase 5), Supports (Phase 6), Forms (Phase 7), Notes (Phase 8), Teams (Phase 10). Settling the Hub's layout + editing model now means those phases just swap an inner block, never rearrange the shell.

Three requirements shaped the Phase 3 decisions:

1. **Orient fast.** A counselor lands on the Hub mid-conversation; photo + name + preferred name + grade + current status need to be scannable in under a second.
2. **Edit without leaving the page.** Inline-edit tags, flip status, upload a photo, edit demographics — without routing to AshAdmin or a dedicated edit LiveView.
3. **Show what just happened.** The Activity timeline is a real FERPA audit surface, not a nice-to-have. Every action that modifies Student, StudentTag, or StudentStatus should appear there within the same render pass.

## Decisions

### 1. `AshPhoenix.Form` is the new default for multi-field updates

Phase 3 is the first feature that drives a resource update off a real form (the auth screens in Phase 1 had their own override machinery). `AshPhoenix.Form.for_update/2` + `validate/2` + `submit/2` replaced every line of manual `handle_event("validate", ...)` / changeset wrangling we'd have written by hand. `grade_level > 16` is rejected at validate time, returned as an `@edit_form[:grade_level].errors` entry, and rendered inline by `<.input>` — zero hand-rolled error plumbing.

From this ADR forward, **any new UI that updates more than one field of an Ash resource should use `AshPhoenix.Form`**. Single-value edits (tags, status) stay as LiveComponents because a form with one field is more overhead than value.

### 2. Inline editors are LiveComponents; multi-field is a modal

The Hub header carries two inline controls — a tag editor with a `<details>` dropdown and a status editor with a `<select>`. Both are `use IntellisparkWeb, :live_component` modules. They render independently from the parent and communicate upward via `send(self(), {__MODULE__, msg})` — no global event names, no assigns sharing from the parent, and the parent picks the message pattern up in `handle_info/2`.

Demographics (7 fields) is a `<.modal>`. A 7-field inline form would crowd the header; a 7-field LiveComponent would need its own state machine for modal open/close. The modal lives on the parent LiveView and is driven by the same `AshPhoenix.Form` workflow.

The rule: **single-value → inline LiveComponent; multi-field → modal + AshPhoenix.Form**.

### 3. Timeline reads AshPaperTrail Version rows, not a dedicated Activity resource

Every tenant-scoped resource is already paper-trailed (from Phase 2's `Intellispark.Resource` base module). Building a separate `Activity` resource to record actions would duplicate that truth — an obvious consistency bug waiting to happen. `StudentLive.Show.load_timeline/2` queries three Version tables (`Student.Version`, `StudentTag.Version`, `StudentStatus.Version`) for rows matching the current student, tags each with an internal `__kind__` atom, sorts desc on `version_inserted_at`, caps at 20. Rendering is one `<ol>` with `<li :for>`.

The prerequisite was **Phase B**: extend `attributes_as_attributes` on `StudentTag` + `StudentStatus` to include `:student_id` so Version rows carry that column for the filter. Without the extension, a `JOIN` through the join resource was the only path to "all versions for this student" — noticeably slower and the join rows themselves disappear on hard-deletes.

Every future phase that wants its resource's changes in the Hub timeline adds its Version module to `load_timeline/2`. Phase 12 will polish per-field diffs (e.g. "Grade: 10 → 11") — the data is already there in `changes`.

### 4. Photos stored on local disk; S3 adapter deferred

`Student.photo_url` is an opaque string — the storage adapter is a detail. Phase 3 writes to `priv/static/uploads/students/<id>/<uuid>.<ext>` via `File.cp!/2` inside a `before_action` on `:upload_photo`, and sets `photo_url` to `/uploads/students/<id>/<uuid>.<ext>` — served by `Plug.Static` through the `uploads` entry appended to `IntellisparkWeb.static_paths/0`.

Phase 11 (SIS integration) brings the media-hosting story: S3 + signed URLs + FERPA retention. Swap `UploadStudentPhoto.copy_to_uploads/2` for an S3 PUT; nothing in the Hub has to change.

Validation lives in the action, not the LiveView, so `mix.exs` can expose upload_photo through AshAdmin and the file picker there gets the same MIME + size checks without duplicating the rules.

### 5. Placeholder panels render real empty-states with phase tags, not hidden divs

The four main-column panels (Flags, High-5s, Supports, Notes) render a `<.future_panel>` component: title + disabled `+ New X` button with a `title="Arrives in Phase N"` tooltip + a heroicon empty_state explaining what the panel will hold. Three reasons this beats hiding them:

- **Honest.** A reviewer opening the Hub today knows exactly what's coming and when.
- **Cheap for later phases.** Phase 4 swaps `<.future_panel title="Flags" ...>` for `<.flags_panel student={@student}>`. The grid layout never moves.
- **Reduces PR surface.** Phase 2 → Phase 3 → Phase 4 each change a small piece of the LiveView; reviewers see a diff they can reason about instead of a layout rewrite.

### 6. Two PubSub topics: school-wide + per-student

Phase 2 already published Student create/update/destroy to `students:school:<school_id>` so the `/students` list LiveView could react to tenant-scoped events. Phase 3 adds `students:<id>` — a per-student topic — to the Student resource's `pub_sub` block so the Hub re-renders only when its own student changes, not when any student in the school does.

The `pub_sub` block had to drop its `prefix "students:school"` to do this, because the two topics have different shapes. Inline topic lists (`["students:school", :school_id]` and `["students", :id]`) replace the prefix.

`handle_info/2` in the Hub matches on `%Phoenix.Socket.Broadcast{topic: "students:" <> _}` so either topic triggers `reload_student/1`.

## Consequences

**Positive**
- Every future phase has a clear landing spot on the Hub — new panels follow the `<.card>` + `header_extra` + `empty_state`-fallback shell.
- `AshPhoenix.Form` becomes the org-wide default, reducing boilerplate in every later form feature.
- The timeline pattern is reusable — Phases 4/5/6/8 add their Version modules to `load_timeline/2`, no schema changes needed.
- AshAdmin exposes every new action (`upload_photo`, `clear_status`, `remove_tag`) for free. AshAdmin is the UI-of-last-resort for any action the LiveView doesn't cover.

**Negative**
- The Version-row timeline doesn't render field-level diffs yet ("Grade 10 → 11"); the data is there but the summariser is deliberately minimal. Phase 12 polishes.
- Local-disk photo storage means multi-instance prod deployments would need a shared volume (or the S3 swap in Phase 11 arrives first).
- The `:student_id` columns on `student_tags_versions` and `student_statuses_versions` are nullable to keep pre-Phase-3 rows valid. A later migration could backfill from the source and tighten to `NOT NULL`, but there's no behaviour reason to do it now.

## Alternatives rejected

- **Edit demographics inline, no modal.** 7 fields in the header would blow out the layout and fight the sidebar's fact sheet. Modal keeps the header quiet.
- **Base64 photos in `photo_url`.** Inflates every Version row for Student (paper-trail snapshots the full attribute map). Local disk + opaque URL keeps versions small.
- **Dedicated `Activity` resource.** Duplicates paper-trail; forces every action handler to remember to log twice.
- **Real-time over a custom Phoenix.Channel.** PubSub via `Phoenix.Endpoint.broadcast/3` (the mechanism `Ash.Notifier.PubSub` uses) is sufficient. A custom channel buys nothing for Phase 3's needs.
- **Inline demographics validation via `Ecto.Changeset` directly.** Works but loses the resource-level validation rules Ash already enforces (grade_level constraint, enrollment_status enum). `AshPhoenix.Form` wraps the existing action, so every constraint flows through one source of truth.

## Follow-ups (future phases)

- **Phase 4 — Flags:** Replace `<.future_panel title="Flags">` with a real panel; add `Flag.Version` to `load_timeline/2`. AshStateMachine on Flag (open/assigned/under_review/closed/reopened).
- **Phase 5/6/8** — same pattern for High-5s / Supports / Notes.
- **Phase 11 — SIS integration:** Swap the photo adapter from local disk to S3. Add SIS-sourced fields on Student (guardian_email, IEP_document_url).
- **Phase 12 — Timeline polish:** per-field diff rendering, "Load older activity" pagination.
- **Phase 10 — Teams:** tighten the read policy from "any staff in school" (permissive) to "teachers can only read students in their assigned classes".
- **Phase 13 — Collaboration:** comment threads on Timeline entries; mentions.
