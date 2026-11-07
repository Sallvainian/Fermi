---
title: 'The keep-alive keeps the Free project awake and reports failed jobs'
type: feature
ticket: '7'
created: '2026-11-06'
status: blocked
baseline_revision: '9587352a26599f239055e6b9ce9b5379cfe9872e'
route: full
route_source: auto
risk: medium
review: quick
review_source: pinned
lenses_ran: [quick]
review_loop_iteration: 1
followup_review_recommended: false
context: []
warnings: [oversized]
operator_actions:
  - "After this branch is merged and deploy.yml on main has applied migration 20261106230000 to the hosted project, run Actions > Keep alive > Run workflow on main, and confirm both jobs, Job health and Re-enable schedule, are green."
  - "In the hosted project's SQL editor run: insert into internal.job_failures (job, error_code) values ('operator-test', 'manual_check');"
  - "Wait for the next scheduled Keep alive run (05:17 or 17:17 UTC; not a manual run, which emails whoever started it), and confirm it is red with an error naming operator-test and that GitHub emailed the owner; if no email arrives, record that the monthly re-enable call moved failure emails away from the owner (deferred item in this plan)."
  - "Delete the test row in the hosted SQL editor: delete from internal.job_failures where job = 'operator-test';"
deferred:
  - summary: >-
      A twice-daily keep-alive sees only the last 6 hours of pg_net responses, because pg_net deletes net._http_response rows after pg_net.ttl.
    evidence: |-
      Local stack: show pg_net.ttl = 6 hours, context sighup; alter database / alter role ... set pg_net.ttl as postgres fail ("cannot be changed now"), so no migration can raise it. R8 and AD-21 fix the cadence at twice daily. Fix options for the owner or architect: check every 6 hours or less, or add a pg_cron job that copies non-2xx responses into internal.job_failures. No pg_net call exists until a later epic (sweep-storage, send-push) adds one.
    location: >-
      supabase/migrations/20261106230000_enable_cron_net_and_job_health.sql (http source of public.job_health)
    severity: medium
  - summary: >-
      The monthly re-enable call made with github.token may make GitHub send failed scheduled-run emails to github-actions[bot] instead of the owner.
    evidence: |-
      GitHub's notification docs: when a scheduled workflow is disabled and then re-enabled, notifications go to the user who re-enabled it. Whether PUT /actions/workflows/{id}/enable on an already-enabled workflow counts is undocumented. Settles it: after a manual keep-alive run (which runs the re-enable job), a failing scheduled run emails the owner. If it does not, call the enable endpoint with the owner's token, or drop the call and rely on other repository activity.
    location: >-
      .github/workflows/keep-alive.yml (re-enable job)
    severity: high (unverified)
blocked_at: "2026-11-06"
blocked_reason: "awaiting operator: After this branch is merged and deploy.yml on main has applied migration 20261106230000 to the hosted project, run Actions > Keep alive > Run workflow on main, and confirm both jobs, Job health and Re-enable schedule, are green.; In the hosted project's SQL editor run: insert into internal.job_failures (job, error_code) values ('operator-test', 'manual_check');; Wait for the next scheduled Keep alive run (05:17 or 17:17 UTC; not a manual run, which emails whoever started it), and confirm it is red with an error naming operator-test and that GitHub emailed the owner; if no email arrives, record that the monthly re-enable call moved failure emails away from the owner (deferred item in this plan).; Delete the test row in the hosted SQL editor: delete from internal.job_failures where job = 'operator-test';"
---

<intent-contract>

## Intent

**Problem:** The Free Supabase project pauses after a quiet week, and nothing reports a failed scheduled job, a failed `pg_cron` run or a failed `pg_net` call (AD-21 "silent failures", R7, R8, P1-002, P1-015). Epics 2, 4 and 5 need `pg_cron`, `pg_net` and `internal.job_failures` to exist.

**Approach:** One migration enables `pg_cron` (schema `pg_catalog`) and `pg_net` (schema `extensions`), creates `internal.job_failures`, a check log `internal.job_health_checks`, and `public.job_health(run_at)`, a `postgres`-owned definer function only `service_role` may execute, which returns every failure since the previous check and records this check. `keep-alive.yml` calls it twice daily through the Data API with the secret key (the call is the real query that keeps the project awake) and fails, so GitHub emails the owner, when it returns any failure; it re-enables itself monthly through the GitHub API.

## Boundaries & Constraints

**Always:** the function runs with `set search_path = ''` and fully qualified names; EXECUTE revoked from PUBLIC, `anon` and `authenticated`, granted to `service_role`; both tables have no grant to any API role; every new object has its fixture lines in the same change; the function takes the run time as a parameter defaulting to `now()` (TC-2); errors raise SQLSTATE `22023` with a snake_case key (AD-17); `keep-alive.yml`'s job-health job runs in environment `Production` and reads only `SUPABASE_SECRET_KEY` and `vars.SUPABASE_PROJECT_ID`; the secret key goes only in the `apikey` header.

**Never:** expose `internal` or `cron` to the Data API or grant them to an API role; retry the `job_health` POST (a retry after a lost response would move the check window past failures it already returned); create a new `test.yml` job or change `Test Summary`'s `needs`; add any scheduled job, edge function or `pg_net` call; touch other migrations, `deploy.yml`, `config.toml`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Clean | no failure rows since last check | `{"since":…,"until":…,"failures":[]}`; workflow green | — |
| Job failure | `internal.job_failures` row with `failed_at` in `[since, run_at)` | one `failures` item, `source` `job_failures`; workflow red, `::error::` names job and error | — |
| Failed cron run | `cron.job_run_details` `status = 'failed'`, end (or start) time in window | item `source` `cron`, job name from `cron.job` (or `job <id>`), `return_message` | — |
| Non-2xx HTTP | `net._http_response` with `status_code` outside 200–299, or null (`timed_out`/`error_msg`) | item `source` `http` | — |
| Succeeded rows | cron `succeeded`, HTTP 200/204 | not reported | — |
| Reported once | same failure, next call | not reported again | — |
| First check ever | empty `internal.job_health_checks` | `since` null, no lower bound | — |
| Run time before last check | `run_at` < latest `checked_at` | nothing recorded | raises `22023` `run_at_before_last_check` |
| Wrong caller | `anon` / `authenticated`, or publishable key over the API | refused | `42501`; API 401/403; workflow red |
| API down or not JSON | HTTP ≠ 200, or body not an object with a `failures` array | workflow red naming status | no retry |

</intent-contract>

## Code Map

- `supabase/migrations/20261106190000_*.sql`, `20261106210000_enable_pgtap.sql` -- header style to follow ("Checked by:" line). Read-only.
- `supabase/tests/database/privilege_fixture.psql` -- add the lines in Design Notes below its header line, before `\.`.
- `supabase/tests/database/03_privileges.sql` -- the catalog test; unchanged. Extension-member objects (`cron.*`, `net.*`) are outside its three schemas anyway.
- `supabase/tests/database/01_schemas.sql` -- pgTAP style: header naming R/AD, `begin; select plan(n); … select * from finish(); rollback;`.
- `.github/workflows/test.yml` `db-tests` (line ~90) -- add one step after `pgTAP`; the job is already in `Test Summary`'s needs.
- `.github/workflows/deploy.yml` -- style for env usage (`environment: Production`, `actions/checkout@v7`, `vars.SUPABASE_PROJECT_ID`).
- `scripts/check-hosted-config.sh`, `scripts/test-check-hosted-config.sh` -- style for the checker and its test (usage header, `::error::`, `expect_pass`/`expect_fail` counting cases).
- `scripts/ci-local.sh` -- add the new test after `supabase test db`.
- `app/tests/README.md` line ~70 -- Database Tests row of the lane table.
- Probed on the local stack (CLI 2.122.0, port 56322, `PGPASSWORD=postgres`): pg_cron 1.6.4 and pg_net 0.20.4 available, not installed; both `create extension` statements work as `postgres`; `postgres` has `rolbypassrls`, so it reads every `cron.job_run_details` row despite that table's `username = current_user` policy, and can select and insert in `cron.job_run_details` and `net._http_response` but only select `cron.job` (create a job with `cron.schedule()` inside the test transaction) (columns `id, status_code, content_type, headers, content, timed_out, error_msg, created`). Default privileges grant EXECUTE on new `public` functions to anon, authenticated and service_role, so the revoke is needed; `internal` has no default privileges. `supabase status -o env` prints `API_URL`, `DB_URL`, `SECRET_KEY`, `PUBLISHABLE_KEY` (local demo keys, not secrets).
- The local stack is shared with the main checkout; apply the migration with `supabase migration up` (no reset).

## Tasks & Acceptance

**Execution:**
- [ ] `supabase/migrations/20261106230000_enable_cron_net_and_job_health.sql` -- extensions (with the docs' `grant usage on schema cron to postgres; grant all privileges on all tables in schema cron to postgres;`), both tables, `failed_at` index, the function, owner `postgres`, revokes and grant -- R7, R8.
- [ ] `supabase/tests/database/privilege_fixture.psql` -- the 10 lines below -- AD-3.
- [ ] `supabase/tests/database/04_job_health.sql` -- pgTAP: extensions installed in their schemas; tables and columns exist; function is definer, owned by `postgres`, has `search_path=""`; `has_function_privilege` false for anon and authenticated, true for service_role; every I/O matrix row except the API ones, passing explicit `run_at` values inside the transaction; a `job_failures` row dated before the previous check but not yet reported (the late-commit case) is reported by the next check and its `reported_at` set; cron and http rows are bounded by the shifted window (a row 5 minutes before `run_at` is reported by the next check, not this one); `run_at` equal to the last check raises `22023`; calling as `authenticated` (`set local role`) throws `42501` -- P1-015.
- [ ] `scripts/check-job-health.sh` -- POST `$SUPABASE_URL/rest/v1/rpc/job_health` with `{}`, headers `apikey` and `Content-Type: application/json`, `--max-time 30`, no retry; fails on non-200 (printing the first 500 characters of the response body, which carries PostgREST's error code) or bad shape; prints the window; one `::error::` per failure (`source`, `job`, `error`, `at`); writes a table to `$GITHUB_STEP_SUMMARY` when set; exit 1 on any failure, 2 on missing env -- the one place the workflow's logic lives.
- [ ] `scripts/test-check-job-health.sh` -- against the local stack from `supabase status -o env`, refusing a non-`127.0.0.1`/`localhost` API URL: clean call passes; a `job_failures` row inserted with `psql "$DB_URL"` fails naming it; the next call passes; a failed `cron.job_run_details` row and a 500 `net._http_response` row, each dated 11 minutes ago so the settle lag has passed, each fail; an HTTP 200 HTML body and a JSON body with no `failures` array (a python3 fake API) each fail; publishable key fails; wrong key fails; deletes the rows it inserted (marker job name `test-check-job-health`, runid/id it chose) on exit -- proves the real API path.
- [ ] `.github/workflows/test.yml` -- `db-tests` step "check-job-health.sh passes and fails as it should" running the test script; a one-line comment -- CI coverage with no secret.
- [ ] `scripts/ci-local.sh` -- run the test script after `supabase test db`.
- [ ] `.github/workflows/keep-alive.yml` -- per Design Notes.
- [ ] `app/tests/README.md` -- Database Tests row adds "or `scripts/test-check-job-health.sh` failing against the local stack".

**Acceptance Criteria:**
- Given the branch's migrations applied to the local stack, when `supabase test db` runs, then `Result: PASS` with `03_privileges.sql` and `04_job_health.sql` ok.
- Given the same stack, when `scripts/test-check-job-health.sh` runs, then every case behaves as listed and it exits 0, leaving no row it inserted.
- Given `node scripts/check-migrations.ts`, when it runs, then it exits 0.
- Given `keep-alive.yml`, when `actionlint` and `shellcheck` check it and the two new scripts, then they report nothing, and the file has schedules `17 5,17 * * *` and `41 4 1 * *`, `workflow_dispatch`, the job-health job in `Production`, and the re-enable job with `actions: write` only.
- Given the repo tree, when `git diff --stat` runs against `baseline_revision`, then only the files above and this plan changed.

## Design Notes

Function sketch (plpgsql, `security definer`, `set search_path = ''`):

```sql
lock table internal.job_health_checks in exclusive mode;  -- serialise checks
select max(checked_at) into since from internal.job_health_checks;
if since is not null and run_at <= since then raise exception using errcode = '22023', message = 'run_at_before_last_check'; end if;
-- job_failures: every row not yet reported with failed_at < run_at, then mark them reported_at = run_at
-- cron and http: rows timed in [since - settle, run_at - settle), settle = interval '10 minutes'
insert into internal.job_health_checks (checked_at) values (run_at);
return jsonb_build_object('since', since, 'until', run_at, 'failures', coalesce(<union of three sources ordered by at>, '[]'));
```

Why two rules: a failure row becomes visible only when its writer commits, but its time is set when the writer's transaction starts (`now()`), so a window on time alone loses a row whose transaction started before a check and committed after it. `internal.job_failures` rows, written from inside long job transactions (AD-15), are therefore picked by `reported_at is null` and marked, which is exact whatever the commit timing. `cron.job_run_details` (dated by `coalesce(end_time, start_time)`) and `net._http_response` (dated by `created`) cannot be marked (extension-owned), and their writers commit within seconds of that time, so they use the time window shifted back by a 10-minute settle lag: consecutive windows still tile with no gap or overlap, and a row committed within 10 minutes of its time is always seen. `since` null means no lower bound. A `run_at` equal to or before the last check raises `22023` `run_at_before_last_check` and records nothing. Each failure item: `source`, `job`, `error` (first 500 characters), `at`, plus `detail` (jsonb, `job_failures` only). `internal.job_failures`: `id uuid primary key default gen_random_uuid()`, `job text not null`, `error_code text not null`, `detail jsonb not null default '{}'`, `failed_at timestamptz not null default now()`, `reported_at timestamptz` (null until a check returns the row; index on `failed_at` where `reported_at is null`). `internal.job_health_checks`: `checked_at timestamptz primary key`. A uuid key, not identity, so no sequence escapes the catalog test.

Known limit, not fixed here (deferred): pg_net deletes `net._http_response` rows after `pg_net.ttl` (6 hours, a `sighup` setting `postgres` cannot change), so a twice-daily check sees only HTTP failures from the last 6 hours (plus the lag). No pg_net call exists yet.

Fixture lines:

```
table|internal.job_failures|
column|internal.job_failures.id|
column|internal.job_failures.job|
column|internal.job_failures.error_code|
column|internal.job_failures.detail|
column|internal.job_failures.failed_at|
column|internal.job_failures.reported_at|
table|internal.job_health_checks|
column|internal.job_health_checks.checked_at|
function|public.job_health(run_at timestamp with time zone)|service_role:EXECUTE
```

`keep-alive.yml`: `on: schedule` (`17 5,17 * * *` job health; `41 4 1 * *` monthly), `workflow_dispatch`; top-level `permissions: contents: read`; `concurrency: keep-alive`, no cancel. Job `job-health` ("Job health"), every trigger: `environment: Production`, checkout, run `scripts/check-job-health.sh` with `SUPABASE_URL: https://${{ vars.SUPABASE_PROJECT_ID }}.supabase.co`, `SUPABASE_SECRET_KEY: ${{ secrets.SUPABASE_SECRET_KEY }}`. Job `re-enable` ("Re-enable schedule"), only on the monthly schedule or dispatch, no environment, `permissions: actions: write`: `gh api --method PUT repos/${{ github.repository }}/actions/workflows/keep-alive.yml/enable` with `GH_TOKEN: ${{ github.token }}`. Header comment: why twice daily (Free pause), why monthly (GitHub disables schedules after 60 days without repo activity), that a failed scheduled run emails whoever last changed the schedule lines, or, per GitHub's docs, whoever last re-enabled a disabled workflow (whether the enable call counts when the workflow is already enabled is unverified; the operator check settles it), and why no retry.

## Verification

**Commands:**
- `supabase migration up` then `supabase test db` -- expected: `Result: PASS`
- `scripts/test-check-job-health.sh` -- expected: all cases behaved as expected, exit 0
- `node scripts/check-migrations.ts` -- expected: exit 0
- `actionlint .github/workflows/keep-alive.yml .github/workflows/test.yml && shellcheck scripts/check-job-health.sh scripts/test-check-job-health.sh` -- expected: no output
- `scripts/test-check-hosted-config.sh` -- expected: still passes (unchanged lane)
- `git diff --stat 9587352a26599f239055e6b9ce9b5379cfe9872e` -- expected: the files above and this plan

**Manual checks (if no CLI):**
- After merge (operator): a manual run of `keep-alive.yml` is green with both jobs; a test row in hosted `internal.job_failures` makes the next scheduled run red and GitHub emails the owner (a scheduled run, since a manual run emails whoever started it, and the manual run's re-enable call may change who a scheduled run emails); the row is then deleted.

## Implementation Notes

- Built by a Sonnet subagent from this plan; the parent read the whole diff and re-ran every verification command.
- Files: the migration `20261106230000_enable_cron_net_and_job_health.sql`; `04_job_health.sql` (40 pgTAP tests); 9 fixture lines; `scripts/check-job-health.sh` (one POST, key in a curl header file so it stays out of the process list, no retry); `scripts/test-check-job-health.sh`; `keep-alive.yml`; one `db-tests` step in `test.yml`; one line in `ci-local.sh`; the README lane row.
- Surprise: `postgres` holds only SELECT on `cron.job` (the planning probe checked SELECT only), so the pgTAP test creates its named job with `cron.schedule()` inside the rolled-back transaction, and the shell test uses an unscheduled job id (`job 999999998`).
- A `run_at` equal to the last `checked_at` hits the primary key (`23505`); the plan's 22023 rule covers only an earlier one. With the `now()` default it cannot happen in practice.
- The shell test's priming call moves the shared local stack's check window to now; on a fresh CI stack that is a no-op.
- Matrix audit (parent): the "API down or not JSON" row lacked a not-JSON case, so the parent added a python3 fake API to the shell test with two cases (HTTP 200 with HTML, JSON with no `failures` array); 12 cases now.
- Verification (parent): `supabase migration up` applied; `supabase test db` `Result: PASS`, 5 files, 60 tests; `scripts/test-check-job-health.sh` all 12 cases; `node scripts/check-migrations.ts` 3 migrations expand-only; `actionlint` and `shellcheck` clean; `scripts/test-check-hosted-config.sh` 10 cases; diff touches only the planned files. Not run: a fresh `supabase db reset` (the stack is shared with the main checkout); CI's Database Tests job applies every migration to a fresh database.

- Re-derivation (loop 1), by a fresh Sonnet subagent starting from `attempt1/`: `internal.job_failures` gains `reported_at` and a partial index on `failed_at` where `reported_at is null`; `job_health` marks and returns unreported `job_failures` rows, reads cron and http through the window shifted back 10 minutes, and refuses `run_at <= since` with `22023`; the checker prints the first 500 characters of a non-200 body; the fixture has 10 lines; `04_job_health.sql` has 48 tests (late-commit, lag-boundary, equal-`run_at` and `reported_at` cases added).
- Deviation (loop 1): rows dated 11 minutes back never reach a back-to-back call's shifted window, so the shell test's `rewind_checks` replaces `internal.job_health_checks` with one row an hour old before the cron and http cases; this wipes the shared local stack's earlier check rows (stated in the script's header; a fresh CI stack has none). After review pass 2, `cleanup` deletes the rows `rewind_checks` inserted; the check rows the API calls write stay.
- Review pass 2 patches (same subagent): the rewound rows are deleted on exit; the checker keeps curl's printed status on a non-zero exit and uses `000` only when none was printed; the lock comment in the migration says what the lock does.
- Verification (parent, after the pass-2 patches): `supabase test db` `Result: PASS`, 5 files, 68 tests; `scripts/test-check-job-health.sh` all 12 cases, no marker rows left; `node scripts/check-migrations.ts` 3 migrations expand-only; `actionlint` and `shellcheck` clean; `scripts/test-check-hosted-config.sh` 10 cases; `git diff --stat` 10 files, all planned. Still not run: a fresh `supabase db reset` (shared stack); CI's Database Tests job applies every migration to a fresh database.

## Plan Change Log

### 2026-11-06 — Review pass 1, bad_plan
- **Trigger:** the plan's single time window `[since, run_at)` loses a failure whose writer's transaction started before a check and committed after it: the row is dated by `now()` at transaction start, so it is invisible to the check and falls before the next window (finding 2, verified against the attempt's `job_health`: every source filtered by time only, `run_at` defaulting to `now()`). AD-15 writes `job_failures` from inside job transactions, so later epics would hit it.
- **Amended:** Design Notes (job_failures picked by `reported_at is null` and marked; cron and http windows shifted back by a 10-minute settle lag; `run_at <= since` raises `22023`; new `reported_at` column and partial index; the pg_net TTL limit stated); fixture lines (10, with `reported_at`); the pgTAP task (late-commit, lag-boundary and equal-`run_at` cases); the checker task (prints the error body on non-200, finding 5); the shell-test task (cron and http rows dated 11 minutes back; the two wrong-body cases the parent added in attempt 1); the operator check (a scheduled run, not a manual one); the workflow header comment (re-enable caveat); Code Map probe line (`cron.job` is select-only).
- **Known-bad state avoided:** a failed job reported by no check; an equal `run_at` failing with an unkeyed `23505`; a red run whose log hides PostgREST's error code.
- **KEEP:** attempt 1 is saved at `/private/tmp/claude-501/-Users-sallvain-Projects-Fermi--bmad-loop-runs-20261106-192429-3aab-worktrees-1-7/a2123a03-fdb9-4b77-abd4-d9a3ec90e60a/scratchpad/attempt1/` (the six new or changed files at their repo paths, and `attempt1.patch` with the whole diff including `test.yml`, `ci-local.sh` and README). It passed every verification command. Start from it and change only what the amendments name. Keep: the migration's header, extension statements and grants, revokes and grant, `alter function ... owner to postgres`, the union's three source shapes, item fields and 500-character cut, ordering by time; `04_job_health.sql`'s structure (clearing the four sources inside the transaction, `cron.schedule()` for the named job, `res` temp table, explicit January 2030 times, the privilege and wrong-caller tests); `check-job-health.sh`'s key in a curl header file, no retry, step summary table, workflow-command escaping; `test-check-job-health.sh`'s local-URL guard, marker rows and cleanup, priming call, python3 fake API (written to `$work`, run with `-I`); `keep-alive.yml` as it was apart from the header comment; the `test.yml` step, `ci-local.sh` line and README row unchanged.

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 7 findings — high 0, medium 2, low 4, false 0, maybe-false 1
- findings:
  - `[medium]` `[defer]` pg_net deletes `net._http_response` rows after 6 hours, so a twice-daily check misses HTTP failures older than that — verified locally: `show pg_net.ttl` is `6 hours`, its context is `sighup`, and `alter database`/`alter role ... set pg_net.ttl` as `postgres` both fail ("cannot be changed now"), so no migration can raise it. Every fix (checking more often than R8's twice daily, or a new pg_cron job copying failed responses into `job_failures`) is a choice the intent does not make, and the limit comes from AD-21/R8's own cadence; no pg_net call exists until a later epic adds one. Deferred for the architect and the first epic that adds a pg_net call.
  - `[medium]` `[bad_plan]` A failure whose transaction starts before a check and commits after it is reported by no check (time-only window, `now()` dating) — verified in the attempt's `job_health`. Amendment: `reported_at` marking for `job_failures`, a 10-minute settle lag for cron and http (Plan Change Log, pass 1).
  - `[maybe-false]` `[defer]` After the re-enable job's `PUT .../enable` with `github.token`, GitHub may send scheduled-run failure emails to whoever re-enabled the workflow (`github-actions[bot]`) instead of the owner, so a red run would email no one — GitHub's docs say this for a workflow that was disabled and then re-enabled; whether the call counts when the workflow is already enabled is not documented. Settled by the operator check: after a manual run (which runs the re-enable job), a failing scheduled run must email the owner. High if true.
  - `[low]` `[bad_plan]` A `run_at` equal to the last check raises an unkeyed `23505` instead of `22023` — verified (`run_at < v_since` guard, then the primary-key insert). Folded into the re-derivation: the guard is `<=`.
  - `[low]` `[bad_plan]` `check-job-health.sh` drops PostgREST's error body on a non-200, so a red run does not say whether the key, the grant or the migration is wrong — verified (status-only `::error::`). Folded into the re-derivation: the checker prints the first 500 characters of the body.
  - `[low]` `[reject]` Enabling pg_net lets Supabase's `grant_pg_net_access` event trigger give `anon`, `authenticated` and `service_role` usage on `net`, EXECUTE on `net.http_post` and SELECT on `net._http_response` — true (seen in the planning probe), but `net` is not in `[api] schemas`, so no API request reaches it, and revoking would break future pg_net triggers that run as the inserting user unless each is a definer function, a design choice for the epics that add those triggers. Noted under residual risks.
  - `[low]` `[reject]` An empty `vars.SUPABASE_PROJECT_ID` would make the run fail as `HTTP 000` (exit 1) rather than exit 2 — `gh variable list` shows `SUPABASE_PROJECT_ID` set at repo level (readable from every job), and an empty value would still turn the run red; guarding it adds a branch for a state not shown to occur.

### 2026-11-06 — Review pass (loop 1)
- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `rewind_checks` in `scripts/test-check-job-health.sh` inserts a `job_health_checks` row that `cleanup` never removes (AC "leaving no row it inserted") and wipes the shared stack's earlier check rows — verified in the script. Patched: `rewind_checks` records the timestamps it inserts (`returning`) and `cleanup` deletes exactly those; the wipe stays, stated in the header, since the shifted window cannot be reached otherwise and a CI stack is fresh.
  - `[low]` `[reject]` Implementation Notes describe attempt 1 (40 tests, 60 total, 9 fixture lines, the `23505` note), not the re-derived code — true, but the fix edits this build's plan; the notes are append-only and the loop-1 notes appended below them record the current counts and verification.
  - `[low]` `[patch]` `check-job-health.sh` replaced the status curl received with `000` whenever curl exited non-zero, so a timeout after the headers logged "HTTP 000" for a server that answered — verified (`|| status="000"`). Patched: `|| true` then `status="${status:-000}"`; the not-answering case still reports 000.
  - `[low]` `[patch]` The comment above `lock table internal.job_health_checks` overstated the lock: with the `now()` default, the later-locking concurrent call raises `run_at_before_last_check` instead of recording a window — verified against the guard. Patched: the comment now says the second call waits, then records a later window or raises, so no failure is returned twice.

## Auto Run Result

Status: awaiting-operator

- **Summary:** The Free Supabase project now has a twice-daily keep-alive that also reports failed background jobs. A migration enables `pg_cron` (in `pg_catalog`) and `pg_net` (in `extensions`), adds `internal.job_failures` (where later epics' jobs record a failure), `internal.job_health_checks` (one row per check), and `public.job_health(run_at)`, which only `service_role` may call. Each call returns every failure since the previous one: unreported `job_failures` rows (marked as reported, so a late-committing job is never lost), failed `pg_cron` runs and non-2xx or failed `pg_net` responses (both read through a window 10 minutes behind, so slow commits are seen), and records the check. `keep-alive.yml` calls it at 05:17 and 17:17 UTC through the Data API with the Production secret key (the real query that keeps the project awake) and goes red, naming each failure, when there is one; on the 1st of each month, and on a manual run, it re-enables itself through the GitHub API. The checker is tested against the local stack in CI's existing Database Tests job.
- **Files changed:**
  - `supabase/migrations/20261106230000_enable_cron_net_and_job_health.sql` -- extensions, the two internal tables, `public.job_health`, grants.
  - `supabase/tests/database/04_job_health.sql` -- 48 pgTAP tests of extensions, tables, privileges and every database row of the I/O matrix.
  - `supabase/tests/database/privilege_fixture.psql` -- 10 lines for the new objects.
  - `scripts/check-job-health.sh` -- the one call and its pass/fail logic, used by the workflow.
  - `scripts/test-check-job-health.sh` -- 12 cases against the local Data API and a fake API.
  - `.github/workflows/keep-alive.yml` -- the twice-daily and monthly schedules.
  - `.github/workflows/test.yml` -- one step in Database Tests running the checker test (no new job, no secret).
  - `scripts/ci-local.sh` -- runs the checker test locally.
  - `app/tests/README.md` -- Database Tests row.
  - this plan.
- **Review findings:** pass 1, 7 findings: 1 medium routed bad_plan (a failure committed after a check was reported by no check), which amended the plan and re-derived the code, with 2 low findings folded in (equal `run_at` raised `23505`; non-200 body not printed); 2 deferred (pg_net keeps responses only 6 hours, medium; the monthly re-enable may redirect failure emails to `github-actions[bot]`, high if true, unverified); 2 low rejected (Supabase's own `net` grants to API roles: `net` is not exposed and revoking would break later pg_net triggers; an empty `SUPABASE_PROJECT_ID`: the variable is set and the run would still be red). Pass 2 (loop 1), 4 low: 3 patched (test leaves its rewound check rows; curl status lost on a late timeout; lock comment), 1 rejected (stale notes; fix edits this plan).
- **Follow-up review recommended:** false. Patched entries in pass 2: high 0, medium 0, low 3.
- **Verification:** `supabase test db` `Result: PASS`, 5 files, 68 tests; `scripts/test-check-job-health.sh` 12/12 (real API path with the local secret key; publishable key refused with `42501`; reported once; wrong bodies and no answer fail); `node scripts/check-migrations.ts` expand-only; `actionlint` and `shellcheck` clean; `scripts/test-check-hosted-config.sh` 10/10. Not run here: a fresh `supabase db reset` (shared local stack; CI applies every migration to a fresh database), and anything on the hosted project, which gets the migration only when `deploy.yml` runs on main.
- **Residual risks:**
  - pg_net deletes responses after 6 hours, which `postgres` cannot change, so the twice-daily check sees only recent HTTP failures (deferred; matters once a later epic adds a pg_net call).
  - Whether the monthly re-enable call keeps the 60-day timer reset and leaves failure emails going to the owner is unverified (deferred; the operator check below settles the email part).
  - Enabling pg_net lets Supabase's own event trigger grant `anon` and `authenticated` access to schema `net`; nothing reaches it while `net` is not in `[api] schemas`.
  - `deploy.yml` has not yet applied this migration to the hosted project; until it does, `keep-alive.yml` fails with PostgREST's missing-function error.
