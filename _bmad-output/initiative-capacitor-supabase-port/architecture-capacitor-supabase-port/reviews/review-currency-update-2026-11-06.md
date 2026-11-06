# Review: Currency of the 2026-11-06 Amendment's Technical Claims

- **Artifact:** `architecture-capacitor-supabase-port.md` (status final, updated 2026-11-06), the uncommitted diff against `eb7fd06`, plus `epic-map-capacitor-supabase-port.md` and `.memlog.md`
- **Lens:** were the Supabase claims the amendment adds or leans on researched or reality-checked, or asserted from training data? Stack versions are out of scope; `review-currency.md` covered them.
- **Reviewed:** 2026-11-06
- **Verdict:** The claims hold. Nothing the amendment asserts is wrong or out of date. It has one gap and one adjacent gap: the keep-alive, the stated reason epic 1 owns `pg_cron`, has no read path to `cron.job_run_details`, and the backup does not keep the Vault root key, so a restore cannot recover student passwords.

## What the amendment relies on, and how it was sourced

| Claim | Where | Sourced in memlog? | Result here |
| --- | --- | --- | --- |
| A migration on the Free plan can enable `pg_cron` and `pg_net` | AD-21 Extensions; epic map row 1 | No. Recorded as a user decision (memlog, 2026-11-06), with no source | Confirmed, with caveats (F2) |
| The Management API exposes the Auth config: hook registration, email provider, anonymous sign-ins | AD-21 Health check | Partly. The 2026-11-05 currency review read the CLI's `auth.go` mapping | Confirmed (F3) |
| The Management API sets and reads Realtime private-only | AD-21 Deploy order and Health check | Yes. Memlog line 82 (2026-11-05 currency review) | Confirmed (F3) |
| The admin reads a Vault secret through `reveal_student_password` (a SQL function), with reset handled by the `reset-student-password` edge function | AD-8 | Partly. Memlog line 82 records that `supabase_auth_admin` has no Vault access. The `postgres` side was never recorded | Confirmed from the catalog; not run end to end (F4) |
| The keep-alive reads `cron.job_run_details` "through the API" | AD-21 Keep-alive; memlog 2026-11-06, the reason epic 1 owns `pg_cron` | No | Gap (F1) |
| A weekly `db dump` backup covers the Free plan (K18, mapped by this amendment) | AD-21 Backups; Capability table K18 row | Pricing only (memlog line 55) | Gap for Vault (F5) |

## How this was checked

- Supabase docs fetched on 2026-11-06 (URLs inline).
- The Management API OpenAPI spec, downloaded from `https://api.supabase.com/api/v1-json` on 2026-11-06 and parsed for the request and response schemas of `/config/auth`, `/config/realtime`, `/pgsodium` and `/database/query`.
- Supabase CLI source on `develop` (`apps/cli/src/commands/config/push/SIDE_EFFECTS.md`, `apps/cli/src/commands/db/test/SIDE_EFFECTS.md`) via `gh api`.
- Read-only catalog SQL through the Supabase MCP server, which runs as `supabase_read_only_user`, on the same connected project the earlier review used (Postgres 17, Vault 0.3.1). **Which project this is and what plan it is on remain UNVERIFIED.** It shows what a hosted project provides, not necessarily what Fermi's project provides.

## Findings

### F1: MEDIUM. The keep-alive has no named path to read `cron.job_run_details` or `internal.job_failures`

- **Where:** AD-21 Keep-alive ("runs a real query through the API … fails … when `internal.job_failures` or `cron.job_run_details` holds new failures"). The memlog entry for 2026-11-06 gives this read as the reason epic-platform-baseline owns `pg_cron`.
- **Evidence:**
  - Supabase's install SQL grants the `cron` schema only to `postgres` (`grant usage on schema cron to postgres; grant all privileges on all tables in schema cron to postgres;`). https://supabase.com/docs/guides/cron/install
  - The Data API serves only exposed schemas. Neither `cron` nor `internal` is exposed, and AD-3 revokes `EXECUTE` on `internal` functions from `public`, `anon` and `authenticated`.
  - The free-pausing FAQ counts "opening the project in the dashboard or sending real requests from your app" as activity. It says nothing about the Management API SQL endpoint (`POST /v1/projects/{ref}/database/query/read-only`, marked Beta). If the read goes through the Management API instead of the Data API, it is unknown whether it counts toward keeping the project awake. https://supabase.com/kb/faqs/platform/free-project-pausing
- **Impact:** the epic-1 ticket built from this spine has no read path that works. The likely ad hoc fixes are exposing `internal` or granting `cron` to `service_role`, and AD-3's catalog test should catch either one.
- **Fix:** name the path in AD-21. One option is a `public` RPC wrapper over a `postgres`-owned `security definer` function in `internal` that returns new failure rows from both tables, with `EXECUTE` granted only to `service_role` and added to the privilege fixture. The keep-alive calls it with the secret key through the Data API, so the same request is both the activity and the check.

### F2: LOW. `pg_cron` and `pg_net` can be enabled in a migration; plan availability is undocumented and the schemas are unstated

- **Where:** AD-21 Extensions.
- **Evidence:**
  - `pg_cron`: `create extension pg_cron with schema pg_catalog;` (plus the two grants above). https://supabase.com/docs/guides/cron/install
  - `pg_net`: `create extension pg_net with schema "extensions";`. It is non-relocatable, so an install in the wrong schema must be dropped and recreated, which loses queued requests. Its API is in beta. https://supabase.com/docs/guides/database/extensions/pg_net
  - On the connected project, both are in `pg_available_extensions` (pg_cron 1.6.4, pg_net 0.20.4) and in `supautils.privileged_extensions`, so the `postgres` role a migration runs as can create them.
  - No Supabase doc found states a plan restriction either way. The Cron feature page says only "Beta" and "self-hosted: Yes" (https://supabase.com/features/supabase-cron). Free-plan availability rests on the absence of a restriction and on the connected project, whose plan is unverified.
  - Cron guidance is at most 8 concurrent jobs, each under 10 minutes. https://supabase.com/docs/guides/cron
  - pg_cron cannot fire while a Free project is paused (community reports; follows from the database being stopped). That is fine as long as the keep-alive works (F1).
- **Fix:** state the schemas in AD-21 (`pg_cron` in `pg_catalog`, `pg_net` in `extensions`). Make epic 1's first deploy to the hosted Free project the proof, and record it in the memlog. pgTAP needs no migration: `supabase test db` enables and disables it itself (CLI `db/test/SIDE_EFFECTS.md`).

### F3: LOW. Management API claims confirmed; the health check should assert values, not just presence

- **Where:** AD-21 Deploy order and Health check; epic map seam "Health check 1 → 2".
- **Evidence (OpenAPI spec, 2026-11-06):**
  - `GET /v1/projects/{ref}/config/auth` (scope `auth:read`, not Beta) returns `external_email_enabled`, `external_anonymous_users_enabled`, `hook_before_user_created_enabled`, `hook_before_user_created_uri` and `disable_signup`. https://supabase.com/docs/reference/api/v1-get-auth-service-config
  - `GET` and `PATCH /v1/projects/{ref}/config/realtime` carry `private_only` ("Whether to only allow private channels"). The response marks it `nullable`. https://supabase.com/docs/reference/api/v1-get-realtime-config , https://supabase.com/docs/reference/api/v1-update-realtime-config
  - `supabase config push` PATCHes `/config/auth`, including each Auth hook, but has no Realtime row. Its endpoints are api, auth, storage and webhooks (CLI `config/push/SIDE_EFFECTS.md`). The separate Management API step for Realtime is therefore needed, as the spine says.
  - The docs dashboard equivalent is the "Allow public access" toggle. https://supabase.com/docs/guides/realtime/authorization
  - Before User Created is available on Free and Pro; hook URIs take the form `pg-functions://postgres/<schema>/<function>`, so a function in schema `internal` is allowed. `supabase_auth_admin` needs `USAGE` on that schema. https://supabase.com/docs/guides/auth/auth-hooks
- **Fix (precision):** the hook assertion added in epic 2 should check `hook_before_user_created_enabled = true` and `hook_before_user_created_uri = 'pg-functions://postgres/internal/before_user_created'`, not only that a hook exists. The Realtime check should fail on `private_only` being `null` as well as `false`. Epic 2's hook migration must grant `USAGE ON SCHEMA internal` to `supabase_auth_admin`. AD-3 grants it `EXECUTE` only.

### F4: LOW. The Vault read through a `postgres`-owned `security definer` function is real; an edge function needs an RPC and an explicit grant

- **Where:** AD-8 (`reveal_student_password` for `app.teaches_student` or the admin; `reset-student-password` replaces).
- **Evidence (catalog on the connected project):**
  - `postgres` has `USAGE` on `vault`, `SELECT` on `vault.decrypted_secrets`, `DELETE` on `vault.secrets`, and `EXECUTE` on `vault._crypto_aead_det_decrypt`, `create_secret` and `update_secret`.
  - `service_role` has the same. `authenticated` has none of them.
  - `vault.decrypted_secrets` is owned by `supabase_admin` and is not `security_invoker`. Postgres checks function calls inside a view against the current user, so a reader needs `EXECUTE` on the decrypt function itself. Reading the view as a role without that grant failed here with `permission denied for function _crypto_aead_det_decrypt`. Inside a `postgres`-owned `security definer` function the current user is `postgres`, which holds the grant.
  - There is no `vault.delete_secret`. Deletion is `delete from vault.secrets where id = …`, which the docs show. https://supabase.com/docs/guides/database/vault
  - The docs page does not mention `security definer` or which roles get access. The pattern rests on the catalog check above and community answers, not on an official statement.
- **Not run end to end:** the MCP role is read-only, so I could not create a function and call it as `authenticated`. This is UNVERIFIED in practice.
- **Fix:** epic 3's pgTAP case should call `reveal_student_password` as `authenticated` (teacher, admin, unrelated teacher, student), so a broken decrypt grant surfaces in CI. `reset-student-password` cannot query `vault` through supabase-js because the schema is not on the Data API. Give it a `security definer` function granted `EXECUTE` to `service_role` explicitly, since AD-3's `revoke … from public` removes access for every role not named. Add that function to the privilege fixture.

### F5: MEDIUM (adjacent). The backup cannot recover Vault secrets without the project's root key

- **Where:** AD-21 Backups; the capability-table row "K18 Free plan | keep-alive, backup workflows" added by this amendment; AD-8 stores every student password in Vault.
- **Evidence:** "Backup files never contain the root key; they hold only encrypted data." A new project gets a fresh key, and restored Vault secrets "cannot be decrypted until you copy the old key across". The key is read through the Management API `pgsodium` endpoint (`GET /v1/projects/{ref}/pgsodium`, Beta, scope `secrets:read`), and "only for active (not paused or removed) projects". https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore , https://supabase.com/docs/guides/database/vault
- **Impact:** a manual restore after losing the Free project brings back every `student_credentials` row with an undecryptable secret. Every student password would need a reset, and `reveal_student_password` would error until then. The restore test into a throwaway local database cannot catch this, because it never decrypts a Vault secret.
- **Fix:** have `backup.yml` also fetch the root key while the project is active and encrypt it to the owner's age key, either inside the artifact or as a separate secret. The restore test should then decrypt one known test secret. The alternative is for AD-21 to accept, in writing, that a restore means resetting every student password.

## Not findings (checked and fine)

- Running Realtime private-only through the Management API, separately from `config push`: correct (F3).
- `before_user_created` on the Free plan: available (F3).
- `pgTAP` not listed under Extensions: `supabase test db` enables it for the run.
