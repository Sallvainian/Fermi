# Review: Currency and Reality of Committed Technology Claims

- **Artifact:** `architecture-capacitor-supabase-port.md` (spine, status draft, 2026-11-05), with `.memlog.md`
- **Lens:** was each committed decision checked against the web or the existing project rather than asserted from training data; are versions current; do named technologies exist and fit; are the live defaults it leans on real
- **Reviewed:** 2026-11-05
- **Verdict:** Not ready as-is. One committed setting breaks student sign-in outright, one Stack pin breaks the lint job, and several Supabase and Google behaviours the spine leans on work differently from what it says, or need a manual step it does not mention. Everything else checks out.

## How this was checked

- `npm view <pkg> version` for every Stack row, plus peer ranges (`npm view ... peerDependencies`), run 2026-11-05.
- Source reading at current HEAD: `supabase/auth` (GoTrue) commit `d7955e9` (2026-11-03), `supabase/storage` commit `f870919` (2026-11-05), `supabase/cli` `develop` commit `34f4125` (2026-11-05) and tag `v2.120.0` (`apps/cli-go/pkg/config/auth.go`).
- Supabase docs and Google/Apple docs fetched 2026-11-05 (URLs inline).
- Read-only SQL on the Supabase project the MCP server is connected to (`mzbblbgmrvcgvzxwhptm`, Postgres 17.11). **Which project this is, and what plan it is on, is UNVERIFIED.** It shows what a hosted project provides, not necessarily Fermi's.
- My-Love repo read for precedent (`package.json`, `supabase/config.toml`, `supabase/functions/send-push/`, `capacitor.config.ts`, `src/services/nativeUpdates.ts`).

## Findings

### F1 — CRITICAL: `[auth.email] enable_signup = false` turns off email sign-in, so students cannot sign in

- **Where:** AD-7 ("`[auth.email] enable_signup = false`, so nobody self-registers with a password") and the Auth config row in Consistency Conventions. Memlog line 74 asserts this from the My-Love config comment and the CLI template, not from what the key does.
- **Evidence:**
  - CLI v2 (`apps/cli-go/pkg/config/auth.go` at v2.120.0, line 698): `body.ExternalEmailEnabled = nullable.NewNullableWithValue(e.EnableSignup)`. The key sets `external_email_enabled` on hosted projects. The CLI v3 local stack sets it as `GOTRUE_EXTERNAL_EMAIL_ENABLED` (`packages/stack/src/services/AuthSettings.ts:196`).
  - GoTrue `internal/api/token.go:94`: the password grant returns `"Email logins are disabled"` when `External.Email.Enabled` is false.
  - The CLI v3 schema describes the key as `"Deprecated: use auth.email.enabled instead. Allow/disallow the email provider; when false, users can't sign up or sign in with email."`
  - The migration guide says the same: "Note that `false` also stops existing users from signing in that way." https://supabase.com/docs/guides/local-development/cli/migrating-to-v3
- **Impact:** every student sign-in (email and password) fails. Admin user creation still succeeds (`adminUserCreate` does not check `External.Email.Enabled`), so `add-students` would appear to work in tests while no student can sign in.
- **Fix:** leave the email provider on (`[auth.email] enabled = true`; drop the deprecated `enable_signup`). Keep `[auth] enable_signup = true` for Google and Apple. Self-registration through `/auth/v1/signup` with a password is then blocked only by the `before_user_created` hook, which must refuse every sign-up whose `app_metadata.provider = 'email'` (see F2). Add a pgTAP or api test asserting that a plain `signUp({ email, password })` is refused, and a Playwright or api test asserting that a student created by `add-students` can sign in with `signInWithPassword`.

### F2 — HIGH: `before_user_created` does not fire for Auth admin `createUser`, which settles Open Question 1 and simplifies AD-7

- **Where:** AD-7 ("admits an email-and-password user only when `add-students` (AD-8) has staged that email … in the same request") and Open Questions bullet 1.
- **Evidence:** in GoTrue at `d7955e9`, `triggerBeforeUserCreated` / `triggerBeforeUserCreatedExternal` are called from `signup.go`, `external.go` (OAuth), `token_oidc.go` (ID token), `anonymous.go`, `invite.go`, `mail.go` (generate link), `samlacs.go` and `web3.go`. `admin.go` `adminUserCreate` (line 400 on) never calls either, and it does not check `DisableSignup`. The docs page does not list trigger paths either way: https://supabase.com/docs/guides/auth/auth-hooks/before-user-created-hook
- **Impact:** the "staged email" branch of the hook, and its pgTAP payload case, guard a path that never reaches the hook. If that branch were the only thing allowing email sign-ups, it would let a staged email self-register through `/signup` with a password the student chose, racing `add-students`.
- **Fix:** rewrite AD-7 so the hook admits only `google` and `apple` providers whose email is on `staff_invites` or equals the bootstrap email, and refuses every `email` provider sign-up. Remove the staging mechanism. Close Open Question 1 with this evidence. Keep a one-line spike on the local stack (`auth.admin.createUser` with the hook enabled) because the hosted GoTrue version can lag `master`.
- **Related, confirmed on the connected project:** `supabase_auth_admin` has no `USAGE` on schema `vault`, cannot `SELECT` `vault.decrypted_secrets`, and does not bypass RLS. The hook reads the bootstrap email from Vault and reads `staff_invites`, so that read must go through a `security definer` helper owned by `postgres`, with an explicit grant to `supabase_auth_admin` for `staff_invites`. AD-7 should say so (memlog line 20 records the RLS half, from a community source).

### F3 — HIGH: TypeScript 7.0.2 breaks typescript-eslint, which the lint job needs

- **Where:** Stack row "TypeScript 7.0.2"; Consistency Conventions (Tests) and the inherited My-Love `test.yml` lint job (memlog line 65).
- **Evidence:** `npm view typescript-eslint` reports 8.72.1 (latest) with peer `typescript: ">=4.8.4 <6.1.0"`. `typescript@7.0.2` exports only `./lib/version.cjs` and `./unstable/*` (no classic compiler API), so anything that imports `typescript` programmatically fails. My-Love pins `"typescript": "~6.0.3"` with `typescript-eslint ^8.72.1`. The memlog records 7.0.2 as the npm `latest` tag but never checked whether the tooling supports it. Background: https://github.com/typescript-eslint/tsgolint , https://mergify.com/blog/native-typescript-compiler-faster-typecheck
- **Fix:** pin `typescript` to 6.0.3, matching My-Love's ESLint setup, and add typescript-eslint 8.72.1 and ESLint to the Stack table. If the 7.x compiler speed matters, add it beside 6.0.3 for `tsc --noEmit` only, and record that the `typescript` package name stays on 6.x for ESLint.

### F4 — MEDIUM: Supabase CLI 2.122.0 is the previous major; v3.0.0 changed what the CI commands do

- **Where:** Stack row "Supabase CLI 2.122.0"; deploy diagram "migrate: supabase db push", "supabase functions deploy".
- **Evidence:** npm `supabase` 3.0.0 was published 2026-11-02, and the release notes list breaking changes. In v3, `db push` targets the local stack unless given `--remote`, and hosted mutations need `--yes` in CI or they fail with `HostedMutationConsentRequiredError`. v2 gets only fixes, no new features (installed as `supabase@v2.stable` or with `version: v2.stable` on `supabase/setup-cli`). https://supabase.com/docs/guides/local-development/cli/migrating-to-v3 . The memlog records "npm supabase 3.0.0" but the spine pins 2.122.0 without saying why.
- **Fix:** either adopt 3.0.0, write the CI steps as `supabase db push --remote --yes` and `supabase functions deploy --yes`, and use `[auth.email] enabled` (F1), or keep v2 on purpose and pin `setup-cli` to `v2.stable` with a one-line reason. Do not leave the CI commands bare: copied from My-Love's v2 workflow and run under v3, `db push` would silently migrate only the local stack.

### F5 — MEDIUM: Realtime "private channels only" needs a project setting that `config.toml` cannot carry, and revocation is not immediate

- **Where:** AD-19; AD-10 ("A student removed from a class loses that class chat … history included").
- **Evidence:** "To enforce private channels, turn off 'Allow public access' in Realtime Settings." Policies are "cached for the duration of the connection" and refreshed only on subscribe or when a new JWT is sent, so a revoked user "keeps receiving messages until the JWT expires." https://supabase.com/docs/guides/realtime/authorization . In the CLI, `realtime.private_only` exists only in the Management API contract and is deliberately not mapped from `config.toml` (`packages/config/src/project-config/api-attributes.ts`, "No `realtime.*` field is mapped").
- **Fix:** add a deploy step (a Management API `PATCH /v1/projects/{ref}/config/realtime` with `private_only: true`, or a documented one-time dashboard step that the health check verifies). State in AD-10 and AD-19 that a removed student can keep getting live broadcasts on an open connection for up to the JWT lifetime (default 3600 s), and either accept that or lower `[auth] jwt_expiry`.

### F6 — MEDIUM: Free-plan defaults the spine relies on but does not state

- **Evidence:** Free plan: Realtime 200 concurrent connections (a join over the limit is refused with `too_many_connections`), 100 messages/s, 20 presence messages/s (https://supabase.com/docs/guides/realtime/limits). Automatic daily backups "Not included" (https://supabase.com/pricing). The Vault root key survives Supabase-managed pause and restore, but a manual `pg_dump`/`pg_restore` into a new project cannot decrypt secrets until the old root key is copied over (https://supabase.com/docs/guides/database/vault).
- **Impact:** every open Fermi tab and app holds a Realtime connection, so a few full classes online at once can reach 200. With no backups, a bad migration has no fallback for grades or for the stored student passwords (AD-8). The Deferred "Moving to the Pro plan" trigger mentions neither.
- **Fix:** add both to the Deferred Pro-plan trigger ("Realtime connections near 200" and "the first real grades"). In AD-8, note that the Vault copy is lost on a dump/restore migration unless the root key moves too, and that Reset password (already in AD-8) is the recovery path. Optionally add a CI `pg_dump` of `public` as a stopgap backup.

### F7 — MEDIUM: web push from `send-push` has no library chosen or verified

- **Where:** AD-14 ("`webpush` rows (endpoint and keys, VAPID)"); Stack table.
- **Evidence:** My-Love's `send-push` does APNs only (`apns.ts` uses `crypto.subtle`), so there is no precedent. `npm:web-push` 3.6.7 failed on Deno until a fix merged on 2024-08-28 (https://github.com/denoland/deno/issues/23693, closed). `jsr:@negrel/webpush` 0.5.0 is built on Web APIs and supports Deno, but its author warns it has not been reviewed by crypto experts (https://jsr.io/@negrel/webpush). Hosted edge functions run Deno 2.1 (https://supabase.com/changelog?tags=edge+functions).
- **Fix:** name one library and version in the Stack table (for example `npm:web-push@3.6.7`), and make the first epic-notifications story a `supabase functions serve` spike that sends to a real Chrome and Safari subscription and handles 404/410 as "gone". Also set `timeout_milliseconds` explicitly on the `pg_net` call: the default is 2000 ms, nothing retries, and failures sit in `net._http_response` for only 6 h (https://supabase.com/docs/guides/database/extensions/pg_net).

### F8 — MEDIUM: Drive attach as written covers only the web; the iOS shell and students need a different path

- **Where:** AD-13 ("the client fetches the bytes with the user's `drive.file` token"); Open Questions bullet 3.
- **Evidence:** Google's Picker docs give a separate desktop/mobile flow. The picker opens in the system browser through the OAuth URL with `trigger_onepick=true` and `prompt=consent`, returns `picked_file_ids` and a code to the redirect URI, and allows only `drive.file`. For mobile apps the picker "can no longer be displayed within an embedded webview" (https://developers.google.com/workspace/drive/picker/guides/overview , https://developers.google.com/workspace/drive/picker/guides/overview-desktop). Capacitor iOS serves from `capacitor://localhost`, which Google's Authorized JavaScript origins field does not accept (https://forum.ionicframework.com/t/https-for-the-app-server-protocol-instead-of-capacitor-on-ios/200116). Students sign in with a password (AD-8), so they have no Google session or token.
- **Fix:** split AD-13's Drive clause by platform: the web uses the JS Picker plus a GIS token client for `drive.file`; iOS uses the onepick OAuth URL in the NativeAuth `ASWebAuthenticationSession`, an iOS OAuth client in `fermi-plus-513902`, and a PKCE code exchange. State that students get a separate Google consent at each attach, which is subject to the under-18 Workspace policy already noted. Whether `googleapis.com` answers CORS for `capacitor://localhost` is UNVERIFIED; plan to fetch the bytes through `CapacitorHttp` on iOS.

### F9 — LOW: Sign in with Apple through the OAuth web flow has costs the spine does not mention

- **Evidence:** the OAuth flow needs a client secret regenerated from the `.p8` key every 6 months, or sign-in fails. Native-only setups need no rotation, and Supabase calls native the best practice in app wrappers. The OAuth response carries no full name (https://supabase.com/docs/guides/auth/social-login/auth-apple). Hide My Email gives a relay address that will not match `staff_invites` (memlog line 26; not handled in AD-7). Guideline 4.8 requires an equivalent login, not a native one, so App Review acceptance of the web flow is plausible but UNVERIFIED.
- **Fix:** in AD-7, add the 6-month rotation as a calendar item (or a scheduled CI reminder), take `display_name` from the profile screen rather than the provider for Apple teachers, and either tell teachers to share their real email or let the admin add a relay address to `staff_invites`. Optionally use native `signInWithIdToken` for Apple on iOS. The memlog already shows `linkIdentity` and `signInWithIdToken` accept an ID token.

### F10 — LOW: Storage MIME allowlist trusts the declared type; "images" must not include SVG

- **Where:** AD-13 ("Storage enforces the size on the real bytes" is true; the type check is not a content check).
- **Evidence:** `supabase/storage` `src/storage/uploader.ts`: the MIME type checked is the request `Content-Type` header or the multipart `contentType` field (`validateMimeType(mimeType, …)`). The bytes are not sniffed. Size is enforced on the streamed bytes for standard and signed uploads (`enforceStreamedLimit: true` in `object.ts:361`, multipart `limits.fileSize`, `isTruncated()` raises `EntityTooLarge`), so the size claim holds.
- **Fix:** say in AD-13 that the type list blocks honest mistakes, not hostile files. List exact types rather than `image/*` (for example `image/jpeg`, `image/png`, `image/heic`, `image/webp`, `image/gif`) so `image/svg+xml` is excluded.

## Checked and current (no change needed)

| Claim | Result | Source |
| --- | --- | --- |
| Stack versions: @capacitor/* 8.6.0, push-notifications 8.1.3, capacitor-updater 8.54.2, supabase-js 2.119.0, react/react-dom 19.3.1, react-router 8.5.1, vite 8.3.6, @vitejs/plugin-react 6.2.1, tailwindcss 4.3.4, zustand 5.0.16, **zod 4.6.7**, vitest 5.1.0, wrangler 4.158.0 | All are npm `latest` on 2026-11-05. Peer ranges agree: plugin-react needs vite ^8; vitest 5.1.0 accepts vite ^8; react-router 8.5.1 needs react >=19.2.7; @tailwindcss/vite 4.3.4 accepts vite ^8; updater and push need @capacitor/core ^8. TypeScript is the exception (F3). | `npm view` |
| Supabase Vault from a `security definer` function | On the connected project, `postgres` can `SELECT vault.decrypted_secrets` and `EXECUTE vault.create_secret(text,text,text,uuid)`; `authenticated` cannot read it; `supabase_vault` 0.3.1 is installed. A `postgres`-owned definer `reveal_student_password` works. Plan of that project UNVERIFIED. | SQL on `mzbblbgmrvcgvzxwhptm`; https://supabase.com/docs/guides/database/vault |
| pg_cron and pg_net | Available on the connected project (pg_cron 1.6.4, pg_net 0.20.4, pgtap 1.3.3). The docs pages state no plan restriction; Free-plan availability comes from third-party sources only. Cron guidance: at most 8 concurrent jobs, each under 10 minutes. | `list_extensions`; https://supabase.com/docs/guides/cron |
| `before_user_created` as a Postgres function on Free | The Auth Hooks page lists it for "Free, Pro". The pricing page's Free row names only Custom Access Token and Send email/SMS; treat the hooks page as authoritative. | https://supabase.com/docs/guides/auth/auth-hooks |
| Bucket `file_size_limit` on real bytes | True (F10). The Free plan's 50 MB global cap sits above 10 MB. | storage source; https://supabase.com/pricing |
| Realtime private Broadcast with RLS on `realtime.messages`, `realtime.topic()` | Current API; `private: true` on the channel. See F5 for the setting and caching. | https://supabase.com/docs/guides/realtime/authorization |
| Edge runtime "Deno 2" | Hosted runs Deno 2.1. | https://supabase.com/changelog?tags=edge+functions |
| Live updates from a static `updates/latest.json` | Grounded in My-Love: `autoUpdate: false` plus a manual fetch in `src/services/nativeUpdates.ts`, so an assets-only Worker serving GET is enough. | My-Love repo |
| Items already verified in the memlog | Hook payload shape, anonymous and linking behaviour, guideline 4.8 and 5.1.1(v), Workspace under-18 policy, Free plan quotas and pausing, Drive export 10 MB, iOS web push only for Home Screen apps. Not re-checked. | `.memlog.md` |

## Not verified

- Whether App Review accepts the web-flow Sign in with Apple inside `ASWebAuthenticationSession` (F9).
- Whether `googleapis.com` Drive download/export answers CORS for `capacitor://localhost` (F8).
- Which Supabase project the MCP server points at, and its plan.
- Whether hosted GoTrue matches `master` on the admin-create hook path (F2); a local-stack spike settles it.
