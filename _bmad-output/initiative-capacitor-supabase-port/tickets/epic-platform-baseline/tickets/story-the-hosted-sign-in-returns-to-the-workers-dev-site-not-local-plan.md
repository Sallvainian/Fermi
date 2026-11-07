---
title: 'The hosted sign-in returns to the workers.dev site, not localhost'
type: feature
ticket: '18'
created: '2026-11-07'
status: done
baseline_revision: '5288a9f4eaf2843a538d98e90738f8a1cb8c0b63'
route: oneshot
route_source: auto
risk: low
review: quick
review_source: pinned
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
operator_actions:
  - 'After this branch merges to main, open the Deploy run for that push and confirm Hosted config and Health check are green, and that the Health check log''s "Check the hosted Auth and Realtime config" step shows "OK: site URL (site_url = "https://fermi-plus.sallvain.workers.dev")" and "OK: redirect URLs (uri_allow_list = https://fermi-plus.sallvain.workers.dev/**)".'
  - 'In the Supabase dashboard for project mzbblbgmrvcgvzxwhptm, open Authentication → URL Configuration and change Site URL to another value (for example http://localhost:3000), then in GitHub run the Deploy workflow by hand from main with "health_check_only" ticked, and confirm the Health check fails with "site URL is wrong" naming the value you set.'
  - 'Make the next push to main and confirm its Deploy run passes, and that the dashboard''s Site URL is https://fermi-plus.sallvain.workers.dev again.'
---

<intent-contract>

## Intent

**Problem:** `supabase/config.toml`'s `[remotes.production.auth]` sets the hosted `site_url` to `http://localhost:3000` and `additional_redirect_urls` to `[]` (checked 2026-11-07), so story 4's deploy-time `supabase config push` keeps a hosted Google sign-in returning to localhost, and the health check never notices (AD-7, AD-21).

**Approach:** Pin the hosted values in the remotes block to `site_url = "https://fermi-plus.sallvain.workers.dev"` and `additional_redirect_urls = ["https://fermi-plus.sallvain.workers.dev/**"]`, which story 4's Hosted config job then pushes; the local `[auth]` block keeps its `127.0.0.1` values. `scripts/check-hosted-config.sh` (interface unchanged: `<project-ref>`, so `deploy.yml` needs no edit) also asserts, against that origin pinned in the script, that `site_url` equals it and that `uri_allow_list` (the Management API's comma-separated string; null, absent or blank entries only count as empty) is non-empty with every entry equal to the origin or starting with `origin + "/"` (so `https://fermi-plus.sallvain.workers.dev.evil.com/**` fails). Each wrong value is printed as `<what> is wrong: ...` naming the field and the value, like the existing checks; a pass prints `OK:` with the values, so the deploy log shows them. `scripts/test-check-hosted-config.sh` fixtures carry the right values by default and add cases: localhost `site_url` fails naming site URL; a redirect URL on another origin fails naming that URL; a look-alike host fails; an empty `uri_allow_list` fails naming it empty. Update the scripts' header comments, `supabase/config.toml`'s remotes comment (site_url and redirect URLs are AD-7's, not hosted's 2026-11-06 values), and test.yml's Health Check Tests comment. Never touch `deploy.yml` (its comments are story 14's), ticket files or `deferred-work.md`; make no hosted write by hand.

</intent-contract>

## Implementation Notes

Oneshot: about 80 lines across `supabase/config.toml`, the two hosted-config scripts and one test.yml comment, all following story 4's existing patterns (`check()` with a JSON-quoted expected value; the `fixture` helper in the test script).

- Files touched: `supabase/config.toml` (remotes auth values + comment), `scripts/check-hosted-config.sh` (pinned `origin`, `site URL` check, redirect-URL block), `scripts/test-check-hosted-config.sh` (fixture now built with `jq -n`, optional site_url/uri_allow_list args defaulting to the right values; 4 new cases, 14 total), `.github/workflows/test.yml` (Health Check Tests comment only). `deploy.yml`, `scripts/ci-local.sh` and `app/tests/README.md` needed no change: the script's interface is unchanged and both already run/name it.
- Fixture's optional uri_allow_list uses `${7-...}` (no colon) so an explicit `''` stays empty for the empty-list case.
- Mutation check: making the empty-list branch unreachable failed 1 case; making every URL count as on-origin failed 2 (other origin, look-alike host); restored script passes 14/14.
- Live read-only (owner's token via fnox): `supabase config diff` uses `[remotes.production]` and lists exactly 2 updates, `auth.additional_redirect_urls` ([] → [origin/**]) and `auth.site_url` (localhost → origin); `check-hosted-config.sh mzbblbgmrvcgvzxwhptm` exits 1 naming only site URL and redirect URLs (empty) — sign-up, anonymous, email and private-only already pass after story 4's deploy. No hosted write was made.
- A non-string `uri_allow_list` would make the jq in the process substitution error (stderr in the log) and read as empty, so it still fails; acceptable since the API documents it as a string.

## Review Triage Log

### 2026-11-07 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `low` `patch` [quick] `supabase/config.toml:422` comment says "story 1.18" while every code comment names a story by its plain id ("story 3", "story 13", "story 16") and this ticket's id is 18 — changed to "story 18".
  - `low` `reject` [quick] the checker's null/absent/blank-entry handling of `uri_allow_list` is documented but untested (fixture always writes a string) — the API returns a string (hosted returns "" today, covered by the empty-list case), null/absent take the same `// ""` → empty branch, and testing them needs new fixture parameters; unlikely in everyday use and more than a direct correction.

## Verification

**Commands:**
- `scripts/test-check-hosted-config.sh` -- expected: exit 0, every case ok, including the four new ones.
- `shellcheck scripts/check-hosted-config.sh scripts/test-check-hosted-config.sh` and `actionlint .github/workflows/test.yml` -- expected: no findings.
- `fnox exec -- supabase config diff --project-ref mzbblbgmrvcgvzxwhptm` (read-only) -- expected: "using [remotes.production]", differences now include `site_url` and `additional_redirect_urls` moving to the workers.dev origin.
- `fnox exec -- scripts/check-hosted-config.sh mzbblbgmrvcgvzxwhptm` (read-only GETs) -- expected: exit 1 naming site URL and redirect URLs (hosted still localhost/empty until the next deploy).

**Manual checks (if no CLI):**
- After merge (operator): the Deploy run's Health check log shows `site_url` equal to the origin and every redirect URL on it; after changing site_url in the dashboard, a `health_check_only` dispatch fails naming it; the next push to main sets it back and passes.

## Auto Run Result

Status: awaiting-operator

**Summary:** The deploy's `supabase config push` now sets the hosted `site_url` to `https://fermi-plus.sallvain.workers.dev` and `additional_redirect_urls` to `["https://fermi-plus.sallvain.workers.dev/**"]` (the `[remotes.production.auth]` block; the local `[auth]` block keeps `127.0.0.1`). `scripts/check-hosted-config.sh`, run by the Health check, also fails, naming the wrong value, unless the hosted `site_url` equals that pinned origin and `uri_allow_list` is non-empty with every entry the origin or a path on it (a look-alike host such as `….workers.dev.evil.com` fails); on a pass it logs both values. `deploy.yml` is unchanged (same script interface).

**Files changed:**
- `supabase/config.toml` — hosted site_url and redirect URLs pinned to the workers.dev origin; remotes comment notes the AD-7 exception.
- `scripts/check-hosted-config.sh` — pinned origin; site URL check; redirect-URL check (empty list fails, each off-origin URL named).
- `scripts/test-check-hosted-config.sh` — fixtures built with jq and carrying the right values by default; cases for a localhost site_url, a redirect URL on another origin, a look-alike host and an empty list (14 cases).
- `.github/workflows/test.yml` — Health Check Tests comment names the new cases (no job or step change).

**Review:** quick lens, 2 findings (both low). Patched 1: the config.toml comment's "story 1.18" → "story 18", matching the repo's comment convention. Deferred 0. Rejected 1: null/absent/blank `uri_allow_list` handling is untested — the API returns a string, null/absent take the same empty branch, and testing needs new fixture parameters.

**Follow-up review recommended: false** — patched: high 0, medium 0, low 1.

**Verification:** `scripts/test-check-hosted-config.sh` 14/14 (after the patch too); two mutations of the checker (empty-list branch unreachable; every URL on-origin) made 1 and 2 cases fail; shellcheck on both scripts and actionlint on test.yml and deploy.yml clean; `supabase config diff --project-ref mzbblbgmrvcgvzxwhptm` (read-only) uses `[remotes.production]` and lists exactly 2 updates, `auth.site_url` (localhost → origin) and `auth.additional_redirect_urls` ([] → [origin/**]); live `scripts/check-hosted-config.sh mzbblbgmrvcgvzxwhptm` (read-only GETs) exits 1 naming only site URL and redirect URLs (empty). No hosted write was made.

**Owed by the operator (operator_actions):** confirm the first Deploy run on main is green and its Health check log shows the pinned site_url and redirect URL; change Site URL in the dashboard and confirm a health-check-only run fails naming it; confirm the next push to main restores it and passes.

**Residual risks:** the push to the hosted project runs for real only on main. Until the Google OAuth client (epic-invite-sign-in) lists the origin, a hosted Google sign-in is not yet usable; this change only fixes where Supabase returns users. The origin is pinned in both `config.toml` and the checker, so moving off workers.dev means changing both (the checker then fails until they agree).

## Operator Confirmation

Confirmed 2026-11-07: the external actions this story owed were carried out.

- After this branch merges to main, open the Deploy run for that push and confirm Hosted config and Health check are green, and that the Health check log's "Check the hosted Auth and Realtime config" step shows "OK: site URL (site_url = "https://fermi-plus.sallvain.workers.dev")" and "OK: redirect URLs (uri_allow_list = https://fermi-plus.sallvain.workers.dev/**)".
- In the Supabase dashboard for project mzbblbgmrvcgvzxwhptm, open Authentication → URL Configuration and change Site URL to another value (for example http://localhost:3000), then in GitHub run the Deploy workflow by hand from main with "health_check_only" ticked, and confirm the Health check fails with "site URL is wrong" naming the value you set.
- Make the next push to main and confirm its Deploy run passes, and that the dashboard's Site URL is https://fermi-plus.sallvain.workers.dev again.

_Appended by the bmad-loop orchestrator (`bmad-loop confirm`, #335): a human confirmed these external actions out of band, and the story was advanced from `awaiting-operator` to `done`._
