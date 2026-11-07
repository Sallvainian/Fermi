---
title: 'Deploys set and assert the hosted Auth and Realtime config'
type: feature
ticket: '4'
created: '2026-11-06'
status: blocked
baseline_revision: 'f43e1c5417125aac2c3534f0d273dcd60c4c73c6'
route: full
route_source: auto
risk: medium
review: quick
review_source: pinned
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
operator_actions:
  - After this branch merges to main, open the Deploy run for that push and confirm Migrate, Hosted config, Build, Deploy and Health check are all green (the first Hosted config run turns hosted sign-up off and sets Realtime private-only).
  - In the Supabase dashboard for project mzbblbgmrvcgvzxwhptm, open Authentication → Sign In / Providers and turn on "Allow anonymous sign-ins", then in GitHub run the Deploy workflow by hand from main with "health_check_only" ticked, and confirm the Health check fails with "anonymous sign-ins is wrong".
  - Make the next push to main and confirm its Deploy run passes, and that the dashboard shows anonymous sign-ins off again.
blocked_at: "2026-11-06"
blocked_reason: "awaiting operator: After this branch merges to main, open the Deploy run for that push and confirm Migrate, Hosted config, Build, Deploy and Health check are all green (the first Hosted config run turns hosted sign-up off and sets Realtime private-only).; In the Supabase dashboard for project mzbblbgmrvcgvzxwhptm, open Authentication → Sign In / Providers and turn on \"Allow anonymous sign-ins\", then in GitHub run the Deploy workflow by hand from main with \"health_check_only\" ticked, and confirm the Health check fails with \"anonymous sign-ins is wrong\".; Make the next push to main and confirm its Deploy run passes, and that the dashboard shows anonymous sign-ins off again."
---

<intent-contract>

## Intent

**Problem:** The hosted Supabase project `mzbblbgmrvcgvzxwhptm` is configured by hand: right now sign-up is on (`disable_signup: false`) and Realtime `private_only` is `null` (read 2026-11-06 through the Management API), and nothing in the deploy sets or checks either.

**Approach:** After Migrate, a new deploy job pushes the Auth config from `supabase/config.toml` (`supabase config push`) and sets Realtime private-only through the Management API; the Health check also runs a new script that reads both back and fails, naming each wrong setting, unless email sign-in is on, anonymous sign-ins are off, sign-up is off and `private_only` is `true`. A manual dispatch can run the Health check alone.

## Boundaries & Constraints

**Always:** Supabase CLI 2.122.0 via the pinned `supabase/setup-cli` SHA. The config push changes on the hosted project only what this ticket asks: a `[remotes.production]` block (project_id `mzbblbgmrvcgvzxwhptm`) restates the hosted project's current values for every other setting where the local defaults differ, so `supabase config diff` shows only `auth.enable_signup` (plus `password_requirements` local_only ""). Provider secrets stay `env()` references; unset ones are not pushed by the CLI. Secrets only in jobs with `environment: Production`; jobs holding secrets run no npm code. Every new deploy/hosted job keeps the main-only guard. The new health-check script runs with no Supabase CLI (curl + jq) and its tests run in test.yml's existing `Health Check Tests` job with no secret.

**Never:** No hand call that writes to the hosted project. No new workflow file. No new `test.yml` job (add a step to `site-check-tests`). No edge functions, live-update packaging, sign-in hook, site_url change or other Auth product setting change. Do not edit `deferred-work.md` or any ticket file.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Push to main | hosted sign-up on, private_only null | Hosted config job turns sign-up off and sets private_only true; Health check passes | — |
| Realtime already private | private_only true | PATCH skipped (no Realtime restart) | — |
| Health check alone | dispatch with `health_check_only: true` on main | only Health check runs (site + config) | — |
| Anonymous on | `external_anonymous_users_enabled: true` | config check exits 1 naming "anonymous sign-ins" | all wrong settings listed, not only the first |
| private_only missing | field `null` or absent | exit 1 naming Realtime private-only | — |
| API failure | non-200 / not JSON | exit 1 naming the URL and status | curl retries transient errors |

</intent-contract>

## Code Map

- `.github/workflows/deploy.yml` -- jobs migrate → build → deploy → health-check. `migrate` has `if: github.ref == 'refs/heads/main'` (Production has no branch policy). Health-check job today has no environment and runs `scripts/check-site.sh "${{ vars.SITE_URL }}" "$GITHUB_SHA"`. Vars: `SUPABASE_PROJECT_ID` = `mzbblbgmrvcgvzxwhptm`, `SITE_URL`. Production secret `SUPABASE_ACCESS_TOKEN` exists.
- `scripts/check-site.sh` -- site health check; leave its logic untouched.
- `scripts/test-check-site.sh` -- style model for the new test script (mktemp work dir, trap cleanup, `failures` counter, `::error::`, a failing case passes only on the expected reason).
- `supabase/config.toml` -- `[auth] enable_signup = false`, `enable_anonymous_sign_ins = false`, `[auth.email] enable_signup = true`; local ports 563xx. Without an override, a push would also set on hosted: site_url `http://127.0.0.1:3000` (hosted `http://localhost:3000`), additional_redirect_urls `["https://127.0.0.1:3000"]` (hosted `[]`), email enable_confirmations false (hosted true), max_frequency `1s` (hosted `1m0s`), otp_length 6 (hosted 8), mfa.totp enroll/verify false (hosted true), db.pooler default_pool_size 20 (hosted 15), max_client_conn 100 (hosted 200), storage.vector.enabled true (hosted false). A `[remotes.production]` block with exactly those hosted values was proven in a scratch copy: `supabase config diff` then reports "using [remotes.production]" and only `auth.enable_signup` + `password_requirements`.
- CLI 2.122.0 facts: `config push` prompts per resource and, non-interactive, skips without `--yes`; `--project-ref` needs no `link`; unresolved `env()` secrets are not pushed. Management API: `GET/PATCH /v1/projects/{ref}/config/realtime` (PATCH body `{"private_only": true}`, 204; GET returns `private_only: boolean|null`); `GET /v1/projects/{ref}/config/auth` returns `disable_signup`, `external_anonymous_users_enabled`, `external_email_enabled`.
- `.github/workflows/test.yml:146-168` -- `site-check-tests` job ("Health Check Tests"), already in Test Summary's needs.
- `scripts/ci-local.sh:31-32` -- local mirror of the Health Check Tests step.
- `app/tests/README.md:14` -- lane table row for Health check tests.

## Tasks & Acceptance

**Execution:**
- [ ] `supabase/config.toml` -- append `[remotes.production]` (`project_id = "mzbblbgmrvcgvzxwhptm"`) with sub-tables restating the hosted values listed in the Code Map; comment: hosted project's values as of 2026-11-06, kept so the deploy's push changes only what config.toml decides for both; a later epic changes a hosted value here -- push touches only the ticket's settings.
- [ ] `scripts/check-hosted-config.sh` (executable, `set -euo pipefail`) -- args `<project-ref>`; env `SUPABASE_ACCESS_TOKEN` (required, exit 2 if unset), `SUPABASE_API_URL` (default `https://api.supabase.com`). GET auth and realtime config (curl `--retry 3`, 30 s timeout), fail on non-200 or invalid JSON. Assert `external_email_enabled == true`, `external_anonymous_users_enabled == false`, `disable_signup == true` (comment: epic-invite-sign-in replaces this assertion with the hook URI one), `private_only == true` (null or absent fails). Print one line per wrong setting with plain name, field and value; print OK per setting on pass; exit 1 if any wrong. Never print the token.
- [ ] `scripts/test-check-hosted-config.sh` (executable) -- serves fixture JSON with `python3 -m http.server --bind 127.0.0.1 --directory <work>` on `PORT` (default 4181) at `v1/projects/<ref>/config/{auth,realtime}`, one ref per case, `SUPABASE_API_URL` pointed at it, dummy token. Cases: all correct → pass; anonymous on; sign-up on; email off; private_only false; private_only null; private_only absent; two wrong settings → both named; missing ref (404) → fails naming HTTP 404. Each failing case must fail for its own reason (grep the output).
- [ ] `.github/workflows/deploy.yml` -- `workflow_dispatch.inputs.health_check_only` (boolean, default false, description). Migrate `if` adds `&& !inputs.health_check_only`. New job `hosted-config` (name `Hosted config`, needs migrate, env Production, setup-cli 2.122.0): step failing unless `supabase/config.toml` has `project_id = "<vars.SUPABASE_PROJECT_ID>"` (so the remotes block is the one applied); `supabase config push --project-ref "$REF" --yes` with only `SUPABASE_ACCESS_TOKEN` (comment: provider secrets join this step's env from Production as `env()` names); Realtime step: GET, PATCH `{"private_only":true}` only when not already true, curl `--fail-with-body`. `build` needs `hosted-config`. `health-check`: `environment: Production`, `if: ${{ !cancelled() && github.ref == 'refs/heads/main' && (needs.deploy.result == 'success' || (inputs.health_check_only && needs.deploy.result == 'skipped')) }}`, adds step `scripts/check-hosted-config.sh "${{ vars.SUPABASE_PROJECT_ID }}"` with the token; update comments (it now holds one secret, runs no npm code).
- [ ] `.github/workflows/test.yml` -- in `site-check-tests`, add step `scripts/test-check-hosted-config.sh`; update the job comment.
- [ ] `scripts/ci-local.sh` -- run `scripts/test-check-hosted-config.sh` in the Health Check Tests step.
- [ ] `app/tests/README.md` -- Health check tests row names both scripts.

**Acceptance Criteria:**
- Given the branch, when `supabase config diff --project-ref mzbblbgmrvcgvzxwhptm` runs (read-only, owner's token), then it compares "using [remotes.production]" and lists only `auth.enable_signup` and `auth.password_requirements`.
- Given the local test harness, when `scripts/test-check-hosted-config.sh` runs, then every case behaves as the I/O matrix states and the script exits 0; when the checker's anonymous assertion is deliberately broken, it exits non-zero.
- Given the current hosted project, when `scripts/check-hosted-config.sh mzbblbgmrvcgvzxwhptm` runs read-only with the owner's token, then it exits 1 naming sign-up and Realtime private-only (and nothing else).
- Given deploy.yml, when actionlint runs, then it reports nothing; on a push the job order is Migrate → Hosted config → Build → Deploy → Health check; with `health_check_only: true` only Health check runs.

## Implementation Notes

- Implemented by a Sonnet subagent from this plan; review fixes by the same subagent.
- Planning read the hosted project read-only (Management API GETs and `supabase config diff`, owner's token via fnox): sign-up on, anonymous off, email on, Realtime `private_only` null. No hosted write was made.
- The subagent's first test run caught its own jq bug (`// null` turned `false` into null); fixed before hand-back.
- `set -o pipefail` added to the Realtime step by the parent, since GitHub's default `bash -e` has no pipefail and a failed GET would otherwise read as "not private".
- Matrix rows "Push to main", "Realtime already private" and "Health check alone" are workflow behaviour with no automated test: covered by actionlint, the live read-only check and diff, and the operator actions. The other rows are covered by `scripts/test-check-hosted-config.sh`, which ran and passed.

## Plan Change Log

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `medium` `patch` [quick] the config step is skipped when the site check fails, so a health_check_only run on a not-yet-live HEAD never names a wrong hosted setting; the input description said "against what is live" — added `if: ${{ !cancelled() }}` to the config step and reworded the description to say the site check expects main's latest commit.
  - `low` `patch` [quick] the comment above the deploy job claimed only deploy and migrate can read the Production secrets, untrue now that hosted-config and health-check use Production — comment corrected to list the four Production jobs and say only deploy references the Cloudflare secrets.
  - `low` `patch` [quick] the matrix's "not JSON" API failure had no test case — added a `not-json` fixture (HTTP 200 HTML body) and a case requiring "not a JSON object"; 10/10 cases pass.
  - `low` `reject` [quick] the project_id guard matches the line anywhere in config.toml, not only under `[remotes.production]` — the only other project_id is `"fermi"`, a moved line is unlikely, and enforcing the table would need a TOML parse in the step.

## Design Notes

The remotes block exists because `config push` writes every property config.toml declares, and `supabase init` declares local-dev defaults (localhost site_url, confirmations off, pooler sizes) that would silently change the hosted project. Restating hosted's current values keeps this story to the four settings it owns and makes config.toml the one place a later epic changes a hosted setting. The config check is its own script, not part of `check-site.sh`, because it needs a secret and an API the site check does not, and epic-invite-sign-in swaps one of its assertions.

## Verification

**Commands:**
- `scripts/test-check-hosted-config.sh` -- expected: exit 0, every case ok.
- `scripts/test-check-site.sh` (after `npm ci` in app/) -- expected: exit 0 (unchanged).
- `actionlint .github/workflows/deploy.yml .github/workflows/test.yml` and `shellcheck scripts/check-hosted-config.sh scripts/test-check-hosted-config.sh` -- expected: no findings.
- `fnox exec -- supabase config diff --project-ref mzbblbgmrvcgvzxwhptm` -- expected: "using [remotes.production]", 2 differences (enable_signup, password_requirements).
- `fnox exec -- scripts/check-hosted-config.sh mzbblbgmrvcgvzxwhptm` -- expected: exit 1 naming sign-up and Realtime private-only only (read-only GETs).
- `supabase start` then `supabase test db` (local stack) -- expected: config.toml with the remotes block still loads; tests pass.

**Manual checks (if no CLI):**
- After merge (operator): the Deploy run's Hosted config and Health check jobs are green; then, with anonymous sign-ins turned on in the dashboard, a `health_check_only` dispatch fails naming that setting, and the next push to main passes.

## Auto Run Result

Status: awaiting-operator

**Summary:** A push to main now runs Migrate → Hosted config → Build → Deploy → Health check. Hosted config pushes `supabase/config.toml`'s Auth settings with `supabase config push --yes` and sets Realtime private-only through the Management API (PATCH only when not already true). The Health check also runs `scripts/check-hosted-config.sh`, which reads the hosted Auth and Realtime config and fails, naming each wrong setting, unless email sign-in is on, anonymous sign-ins are off, sign-up is off and `private_only` is true (null or absent fails). A manual Deploy run with `health_check_only` runs the Health check alone. A `[remotes.production]` block in config.toml restates the hosted project's current values for every setting where local-dev defaults differ, so the push changes only sign-up (on → off today), proven by `supabase config diff`.

**Files changed:**
- `.github/workflows/deploy.yml` — `health_check_only` input; new Hosted config job; Health check on Production with the config step.
- `supabase/config.toml` — `[remotes.production]` block keeping hosted values for site_url, redirect URLs, email confirmations/frequency/OTP length, TOTP, pooler sizes, storage vector.
- `scripts/check-hosted-config.sh` — new hosted config check (curl + jq).
- `scripts/test-check-hosted-config.sh` — new fixture-server tests, 10 cases.
- `.github/workflows/test.yml` — new step in the existing Health Check Tests job.
- `scripts/ci-local.sh`, `app/tests/README.md` — run and document the new test.

**Review:** 4 findings. Patched 3 (1 medium: config step now runs after a failed site check; 2 low: Production-secrets comment, non-JSON test case). Deferred 0. Rejected 1: the project_id guard does not check its TOML table — only other project_id is "fermi", fix needs a TOML parse.

**Follow-up review recommended: false** — one medium patched, no high.

**Verification:** `scripts/test-check-hosted-config.sh` 10/10; `scripts/test-check-site.sh` 4/4; `supabase test db` 14 tests PASS; actionlint on all workflows and shellcheck on both scripts clean; `supabase config diff` against the hosted project uses `[remotes.production]` and lists only `auth.enable_signup` and `auth.password_requirements` (local "" vs unset); live `scripts/check-hosted-config.sh mzbblbgmrvcgvzxwhptm` exits 1 naming only sign-up and Realtime private-only (read-only GETs).

**Owed by the operator (operator_actions):** confirm the first Deploy run on main is green; turn anonymous sign-ins on in the dashboard and confirm a health-check-only run fails naming it; confirm the next push to main passes and turns it off.

**Residual risks:** the config push, the Realtime PATCH and the health_check_only path run for real only on main. The remotes block pins hosted values as of 2026-11-06, including the hosted site_url `http://localhost:3000`, which epic-invite-sign-in will need to set to the real site. DW-1 (hosted sign-up and exposed schemas) is settled by this change once the first Deploy run passes; `deferred-work.md` was not edited.

