# ADR 021: SIS Integration + Xello bidirectional embed

**Status:** Accepted
**Date:** 2026-04-23
**Builds on:** ADR 008 (High Fives token pattern), ADR 014 (Teams / Connections), ADR 016 (Branded emails + HMAC pattern reuse), ADR 017 (Flag close-flow state machine), ADR 019 (Tiers), ADR 020 (Phase 3+10 retrofits — ExternalPerson + Student demographics already in place).

## Context

The job posting calls out "data ingestion and automation pipelines." Phase 11 is the ingestion half; Phase 12 the automation half. The Ash build-plan scoped Phase 11 to: (a) generic SIS ingestion pipeline with CSV-first + OneRoster/Clever/ClassLink stubs; (b) Xello inbound via webhook → `XelloProfile`; (c) Xello outbound via `/embed/student/:token` public LiveView; (d) `ExternalPerson` + Student demographics — **both of which already shipped in the Phase 3+10 retrofit (ADR-020)**; so Phase 11's Phase F was skipped.

## Decisions

### 1. New `Intellispark.Integrations` domain

Five resources land here: `IntegrationProvider`, `IntegrationSyncRun`, `IntegrationSyncError`, `XelloProfile`, `EmbedToken`. `ExternalPerson` lives in `Intellispark.Teams` (not here) — relocated by ADR-020. AshAdmin surface enabled for each.

### 2. Transformer-per-provider pattern

Plain Elixir `@behaviour` modules (`Intellispark.Integrations.Transformer`) — not Ash resources. Each provider type has `transform_students/2` + `transform_rosters/2` callbacks. `for_provider/1` dispatches by atom. CSV is the only fully implemented transformer; OneRoster / Clever / ClassLink / Xello / Custom are stubs that return `{:ok, []}`.

### 3. CSV is first-class; OneRoster 1.2 header format

CSV transformer uses `NimbleCSV`. Headers: `sourcedId, givenName, familyName, email, grades, status, gender, phone` — matching OneRoster 1.2. Full OneRoster REST implementation is future work; we avoid a real implementation because sandbox access requires vendor agreements.

### 4. `AshStateMachine` for `IntegrationSyncRun`

States: `:pending → :running → {:succeeded, :failed, :partially_succeeded}`. Mirrors `Flag`'s pattern. `:start` transitions from `:pending`; `:succeed` / `:partial_succeed` / `:fail` from `:running`. Invalid transitions raise `%Ash.Error.Invalid{}`.

### 5. Per-record DLQ via `IntegrationSyncError`

`Ash.bulk_create` with `stop_on_error?: false` + `return_errors?: true` — failed records get recorded as DLQ rows, batch continues. Admins can edit `raw_payload` and retry via the resource's `:retry` action.

### 6. `Ash.bulk_create` with `upsert?: true` + `upsert_identity`

Student already has `unique_external_id_per_school` identity (Phase 2). The ingestion worker calls `Ash.bulk_create(payloads, Student, :upsert_from_sis, upsert?: true, upsert_identity: :unique_external_id_per_school, ...)`. Strips `school_id` from payloads since multitenancy sets it via `tenant:`.

### 7. Cloak vault for encryption at rest

New `Intellispark.Vault` module using `Cloak.Ciphers.AES.GCM`. Key loaded from `CLOAK_KEY` env (base64-decoded 32 bytes) in prod; dev/test use a hardcoded fallback via `cloak_key_fallback` config. New Ash type `Intellispark.Encrypted.Map` wraps vault encrypt/decrypt around JSON-encoded map values. Used for `IntegrationProvider.credentials`.

### 8. Compile-time defaults use functional form for encrypted attributes

`default fn -> %{} end` instead of `default %{}` — the latter triggers `Ecto.Schema.validate_default!/3` which calls `Intellispark.Vault.encrypt/1` at compile time before the vault is started.

### 9. Xello PRO-gated via split policy blocks

Two separate `policy action(:create)` blocks on `IntegrationProvider`: one authorizes via `DistrictAdminForSchoolScopedCreate`; the other authorizes via `RequiresTierForXello`. Both must pass (policies are AND'd across blocks). `RequiresTierForXello` is a SimpleCheck that returns `true` when `provider_type != :xello` OR actor is on PRO tier. Non-PRO admins creating CSV/OneRoster pass; non-PRO admins creating `:xello` get `%Ash.Error.Forbidden{}`.

### 10. HMAC-SHA256 webhook verification, 5-minute replay window

Xello webhooks carry `X-Xello-Signature: t=<ts>,v1=<hmac_hex>`. Signature is `hmac_sha256(secret, "<ts>.<body>")`. Replay window: `abs(now - ts) <= 300`. Per-provider `webhook_secret` stored in encrypted `credentials` blob. `Plug.Crypto.secure_compare/2` for constant-time comparison.

### 11. Raw body reader for HMAC verification

`IntellisparkWeb.Plugs.CacheRawBody.read_body/2` is wired as `Plug.Parsers` body_reader. It caches raw bytes on `conn.assigns[:raw_body]` so the webhook controller can HMAC-verify after JSON parsing.

### 12. Dedicated `:webhook_lookup` action on `IntegrationProvider`

Reading the provider in the `LoadXelloProvider` plug requires bypassing multitenancy (we don't know the tenant — we're discovering it). The dedicated read action has `multitenancy :bypass` and `policy authorize_if always()` — safe because the plug uses `authorize?: false` and the caller must still pass a valid `X-Xello-Provider-Id` that belongs to a Xello-type provider.

### 13. `EmbedToken` audience + revocation semantics

Audience atom (only `:xello` for v1). Two identities — `:unique_token` (prevents duplicates) + `:unique_per_student_audience` (one token per student per audience; regenerate rotates in place). `revoke_at :utc_datetime_usec` sets revoked; public LV returns a revoked-state render. Tokens expire in 365 days from `:mint`.

### 14. Public `/embed/student/:token` LiveView with frame-ancestors CSP

Routes in a dedicated `:embed` pipeline that sets `content-security-policy: frame-ancestors *.xello.com *.app.xello.com;` + deletes `x-frame-options`. LiveView reads token via `Ash.read_one(EmbedToken |> Ash.Query.for_read(:by_token, %{token: token}), authorize?: false)`. The `:by_token` action uses `multitenancy :bypass`.

### 15. Embed content is aggregate-only — no PII

The embed renders SEL & Well-Being indicator bands (High / Moderate / Low) + flag table (Flag type / Opened by / Date / Status / Assigned). No student name, no email, no notes. Opened-by displays the staff name (which is acceptable — staff consent to being listed as flag openers).

### 16. AshOban cron trigger on `IntegrationProvider.:run_now`

`scheduler_cron "0 */6 * * *"` + `where active? == true`. Creates a `:pending` SyncRun + Oban job for each active provider. `worker_module_name` + `scheduler_module_name` explicit (AshOban requires it for stable dangling-job behavior when trigger names change).

### 17. Manual `Integrations.run_sync_now` code interface

District admins can trigger a sync on-demand via `/admin/integrations` → Run now button → calls `run_sync_now` which dispatches through the same `EnqueueSyncRun` after-action change. Trigger source atom `:manual | :scheduled | :webhook` differentiates them in the SyncRun row.

## Consequences

- Five new resources + one new vault module + one new Ash type + two new plugs + one new controller + one new public LiveView + one /admin LV.
- Migration adds 10 tables (5 core + 5 versions) + 4 indices.
- `Student.:upsert_from_sis` new action — existing Student policies already cover it (create-type).
- Every webhook request reads the raw body into conn assigns. Memory impact: bounded by Plug.Parsers.
- Seeds include no Phase 11 providers — added in next seeds.exs update so demos can load `/admin/integrations` with content.

## Tests added (+28)

- `test/intellispark/integrations/integration_provider_test.exs` — 5 cases (CSV create, Xello tier gate starter/PRO, credentials encrypted at rest, activate/deactivate)
- `test/intellispark/integrations/integration_sync_run_test.exs` — 5 cases (pending initial, start, succeed, partial_succeed, invalid transition rejected)
- `test/intellispark/integrations/workers/ingestion_worker_test.exs` — 2 cases (happy path 3 rows, partial failure + DLQ row)
- `test/intellispark/integrations/transformers/csv_test.exs` — 3 cases (OneRoster 3-row parse, missing optional fields, empty input)
- `test/intellispark/integrations/xello_profile_test.exs` — 3 cases (upsert new, upsert existing, last_synced_at refresh)
- `test/intellispark/integrations/embed_token_test.exs` — 3 cases (mint + 1-year expiry, revoke, regenerate clears revoked_at)
- `test/intellispark_web/controllers/xello_webhook_controller_test.exs` — 4 cases (valid signature 204, bad sig 400, replay 400, unknown provider 401)
- `test/intellispark_web/live/embed_live/student_test.exs` — 3 cases (valid token renders, revoked token message, unknown token message)

Running total: **492 tests, 0 failures** (was 464 after Phase 3+10 retrofits).

## Alternatives considered

- **ExternalPerson in `Intellispark.Integrations`.** Rejected — ADR-020 landed it in `Intellispark.Teams` before Phase 11 started; moving would break existing wiring.
- **Single polymorphic policy on `IntegrationProvider.:create`.** Rejected in favor of two AND'd `policy` blocks; clearer semantics + easier unit-testing.
- **Real OneRoster / Clever / ClassLink clients.** Rejected — sandbox agreements required. Stubs are honest.
- **ETS-cached `IntegrationProvider` lookup for webhook.** Rejected for v1 — DB round-trip is <1ms for a UUID index lookup.
- **Persistent webhook retry queue.** Rejected — Xello's infra retries on non-2xx.
