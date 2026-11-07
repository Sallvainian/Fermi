---
title: 'A weekly encrypted backup that proves it restores'
type: feature
ticket: '8'
created: '2026-11-06'
status: done
baseline_revision: '4e831cb766aebdc0fc8b4806951b361f32d8f0d5'
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
  - "After this branch merges to main, run Actions > Backup > Run workflow on main and confirm the Backup job is green, including its step Restore into a throwaway database, whose log ends with 'restored N tables, M rows'."
  - "On that run's page, confirm its one artifact, fermi-db-backup-<run id>, holds only fermi-db-<date>.tar.gz.age, with a 90-day expiry."
  - "Download the artifact on the Mac, unzip it, and decrypt it with: age -d -i ~/.age/key.txt fermi-db-<date>.tar.gz.age | tar -tz — confirm it lists roles.sql, schema.sql, data.sql, history_schema.sql and history_data.sql; then delete the decrypted and downloaded copies."
  - "On the Sunday after the merge, confirm the scheduled Backup run (06:23 UTC) ran and is green."
---

<intent-contract>

## Intent

**Problem:** The Free Supabase plan keeps no backups, and the repo is public, so a plain dump can never be committed or shown in logs (R9, K18, AD-21).

**Approach:** A weekly `backup.yml` in environment Production dumps the hosted database (roles, schema, data, migration history) through the Session pooler, encrypts the dump to the owner's age keys, keeps only the encrypted file as a 90-day artifact, and restores the plaintext into a throwaway local Supabase database, failing the run if the restore or its row counts fail. The three steps are scripts, tested on every pull request against the local stack.

## Boundaries & Constraints

**Always:** Supabase CLI 2.122.0. Secret `SUPABASE_SESSION_POOLER_URL` (password inside, URL-safe) and repo variable `BACKUP_AGE_RECIPIENTS` (two `age1…` keys, one per line) are the only inputs. Plaintext lives only under `$RUNNER_TEMP`/`mktemp`, never in the workspace or an artifact. Logs never show row data: psql runs with `VERBOSITY=sqlstate`, and the restore check prints totals and only the names and counts of mismatched tables. bash `set -euo pipefail`, no `set -x`; shellcheck and actionlint clean.

**Never:** No secret in `test.yml` (AD-23). No restore into anything but the database the check itself starts. No Storage bytes. No change to deploy.yml, keep-alive.yml or migrations. No re-enable job (see Design Notes).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Weekly or manual run | hosted project up | artifact `fermi-db-backup-<run id>` holding one `fermi-db-<UTC date>.tar.gz.age`, retention 90; restore step green | — |
| Restore SQL error | dump with a failing statement | restore check exits 1 naming file:line and SQLSTATE only | single transaction, `ON_ERROR_STOP=1` |
| Row count drift | restored table count ≠ COPY rows in dump | exits 1 naming each mismatched table with both counts | — |
| Bad recipients | empty or non-`age1` line | encrypt exits 1 before writing output | — |
| Dump fails | pooler down / bad password | dump step red; nothing uploaded | — |

</intent-contract>

## Code Map

- `.github/workflows/keep-alive.yml` -- model for header comment, `on: schedule + workflow_dispatch`, `permissions: contents: read`, concurrency, `environment: Production`, `actions/checkout@v7`.
- `.github/workflows/deploy.yml` -- `supabase/setup-cli@45a513f8c64c0bc8e0e3dfe572b5c95be85f6359 # v3.0.1` with `version: 2.122.0`; `actions/upload-artifact@v7`.
- `.github/workflows/test.yml:90-107` -- job `db-tests` (Database Tests): local stack via `./.github/actions/setup-supabase`, then `scripts/test-check-job-health.sh`; add the backup test as a step after it. `Test Summary` needs list is unchanged (no new job).
- `scripts/test-check-job-health.sh` -- model for a test script: header listing cases, `supabase status -o env` for `DB_URL`, localhost guard, case counter, cleanup trap.
- `scripts/ci-local.sh` (Database Tests block) and `app/tests/README.md:70` (Database Tests row) -- add the new test.
- Verified locally with CLI 2.122.0: `supabase db dump --db-url URL -f F` with `--role-only`; plain (schema); `--data-only --use-copy`; `--schema supabase_migrations`; `--data-only --use-copy --schema supabase_migrations`. The CLI already comments out `\restrict`. The data dump includes `auth`/`storage` rows; the schema dump excludes managed schemas.
- Verified: a throwaway DB from `supabase init --yes` in a temp dir, then sed `project_id` to `fermi-restore-check` and every `port`/`shadow_port` to 575xx (563xx is Fermi's stack, 543xx My-Love's), copy `major_version` from `supabase/config.toml`, `supabase db start --workdir DIR` (~15 s) gives `auth.users` and `storage.objects`. Restore as `postgres` fails (`GRANT SET ON PARAMETER log_min_messages` in roles.sql: postgres is not superuser locally); as `supabase_admin:postgres@127.0.0.1:57522` it passes: `psql -X --single-transaction -v ON_ERROR_STOP=1 -f roles.sql -f schema.sql -c 'SET session_replication_role = replica' -f data.sql -f history_schema.sql -f history_data.sql`. Stop with `supabase stop --no-backup --workdir DIR`.
- COPY text format puts one row per line (newlines escaped), so rows = lines between `COPY "s"."t" (...) FROM stdin;` and `\.`.

## Tasks & Acceptance

**Execution:**
- [ ] `scripts/backup-dump.sh` -- args `<db-url> <out-dir>`; writes `roles.sql`, `schema.sql`, `data.sql`, `history_schema.sql`, `history_data.sql` with the five commands above; exits 2 on wrong args, 1 if any file is missing or empty -- one dump path for the workflow and the test.
- [ ] `scripts/backup-encrypt.sh` -- args `<dump-dir> <recipients-file> <out-file>`; rejects an empty file or any non-blank, non-`#` line not matching `^age1[0-9a-z]+$`; `tar -czf - -C dump-dir <the five files> | age -R recipients -o out`; fails unless out's first line is `age-encryption.org/v1` -- encryption to the owner's keys.
- [ ] `scripts/backup-restore-check.sh` -- arg `<dump-dir>`; starts the throwaway DB as above (trap stops it and deletes the temp dir), restores as `supabase_admin` with `VERBOSITY=sqlstate`, stderr to a temp file of which only `psql:file:line: ERROR: <sqlstate>` lines print; then for each COPY block in data.sql and history_data.sql compares rows to `count(*)`; prints `restored N tables, M rows` or each mismatch and exits 1 -- the restore proof.
- [ ] `scripts/test-backup.sh` -- against the local stack (localhost guard): inserts a marker `internal.job_failures` row whose `detail` holds a newline and tab (deleted on exit); dumps it; restore check passes; encrypt to a fresh `age-keygen` key, output holds no marker text and decrypts with `age -d` + `tar -xz` to files identical to the dump (`diff -r`); fails as it should for: a dump with `select 1/0;` appended to schema.sql; data.sql with `delete from "internal"."job_failures";` appended (must name that table); an empty recipients file; a recipients line `not-a-key`; missing args (exit 2). Prints pass/fail per case, exits 1 on any failure.
- [ ] `.github/workflows/backup.yml` -- name `Backup`; `schedule: cron '23 6 * * 0'` + `workflow_dispatch`; `permissions: contents: read`; concurrency `backup`, no cancel; one job `backup` (name Backup), `timeout-minutes: 30`, environment Production; steps: checkout, setup-cli, install age (`sudo apt-get update && sudo apt-get install -y age`), dump (env from the secret), encrypt (recipients from `vars.BACKUP_AGE_RECIPIENTS` written to `$RUNNER_TEMP`), upload (`if-no-files-found: error`, `retention-days: 90`, `compression-level: 0`, path the one `.age` file), restore check. Header comment: why (Free plan, public repo), what is and is not in the dump (no Storage bytes, no Vault root key), the not-in-test.yml reason, and how the owner decrypts and restores (`age -d -i <key> f.tar.gz.age | tar -xz`, then the psql command; into a hosted project as `postgres`, drop roles.sql's `GRANT SET ON PARAMETER` line) -- R9.
- [ ] `.github/workflows/test.yml` -- in `db-tests`, after the job-health step: install age, then run `scripts/test-backup.sh` -- regression on every pull request, no secret.
- [ ] `scripts/ci-local.sh`, `app/tests/README.md` -- add `scripts/test-backup.sh` to the Database Tests block and row.

**Acceptance Criteria:**
- Given the local stack, when `scripts/test-backup.sh` runs, then every case passes and the stack holds no marker row or extra container afterwards.
- Given a dump encrypted to `vars.BACKUP_AGE_RECIPIENTS`, when decrypted with the owner's key at `~/.age/key.txt (fnox's FNOX_AGE_KEY_FILE)`, then the five SQL files come back unchanged.
- Given the workflow files, when actionlint and shellcheck run, then both are clean, and `test.yml` references no `secrets.`.

## Implementation Notes

- Implemented by a Sonnet subagent from this plan; files as listed in Tasks. No commit, workflow run or hosted-project call.
- The plan first named `~/.config/fnox/age.txt` as the owner's key; that is the Linux recipient (`age1y45wg6…`), in neither backup recipient. fnox's `FNOX_AGE_KEY_FILE` is `~/.age/key.txt` (`age1nh6eru…`, recipient 1). AC and Verification corrected; the real-recipient round trip passes with it.
- Parent session added: job-level `SUPABASE_INTERNAL_IMAGE_REGISTRY: ghcr.io` in backup.yml (as setup-supabase does, against public.ecr.aws rate limits); the decrypt comment's key path; a test case for a refused dump connection (matrix row "Dump fails", which had none).
- `test-backup.sh`: 17 cases, about 60 s locally (two throwaway database starts). The marker row's newline and tab are in `error_code`, not `detail` (jsonb).
- `backup-dump.sh` leaves the CLI's stderr visible for diagnosis; a refused connection prints host, port and user, never the password.

## Plan Change Log

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 8 findings — high 0, medium 0, low 8, false 0, maybe-false 0
- findings:
  - `low` `patch` [quick] the leftover-container check ran only after the first restore check, not after the two failing ones — moved the docker ps check after the last restore-check case; passes.
  - `low` `patch` [quick] a failed marker-row delete in cleanup only warned and exited 0 — cleanup now prints ::error:: and exits 1.
  - `low` `reject` [quick] Implementation Notes say two throwaway database starts, the test runs three; db-tests timeout fit unverified — the fix edits this build's plan; the test takes about 60 s locally against db-tests' 15-minute timeout.
  - `low` `reject` [quick] parallel local runs in several worktrees share project fermi-restore-check and port 57522 and stop each other's database — local-only (each CI job has its own runner), every worktree already shares one local stack (project_id fermi) for the existing database tests, and per-run port allocation adds complexity.
  - `low` `patch` [quick] supabase init output went to /dev/null, so its failure printed nothing — output now goes to init.log, printed with an ::error:: on failure.
  - `low` `patch` [quick] a failed restore or count printed only SQL ERROR lines, missing psql connection and invalid-command errors — a shared print_psql_errors helper also prints `psql: error:` and `invalid command` lines (file name only); DETAIL lines still dropped.
  - `low` `patch` [quick] the comment above the count query said "first two fields" while awk takes $2 — comment corrected.
  - `low` `patch` [quick] scripts/ci-local.sh's Needs line omitted age and age-keygen — added.

## Design Notes

Upload runs before the restore check: a dump that fails the local restore (say, a hosted Auth column the pinned CLI's local schema lacks) is still the newest copy of the data; the run is red either way. The restore runs on the pre-encryption plaintext, since CI must never hold a private key; the round trip is proven by the test and by the owner's decrypt. A re-enable job is left out: GitHub disables schedules after 60 days without repo activity, but keep-alive's open deferred item says such a call may redirect failure emails away from the owner.

## Verification

**Commands:**
- `scripts/test-backup.sh` (local stack running) -- expected: all cases pass, exit 0.
- `scripts/test-check-job-health.sh` -- expected: still 12/12.
- `printf '%s\n' "$(gh variable get BACKUP_AGE_RECIPIENTS)" > R; scripts/backup-dump.sh postgresql://postgres:postgres@127.0.0.1:56322/postgres D && scripts/backup-encrypt.sh D R out.age && age -d -i ~/.age/key.txt out.age | tar -xzO | cmp - <(cat D/{roles,schema,data,history_schema,history_data}.sql)` in a scratch dir -- expected: exit 0.
- `actionlint .github/workflows/backup.yml .github/workflows/test.yml && shellcheck scripts/backup-*.sh scripts/test-backup.sh` -- expected: clean.
- `grep -c 'secrets\.' .github/workflows/test.yml` -- expected: 0.

## Auto Run Result

Status: awaiting-operator

**Summary:** A weekly workflow, `backup.yml` (Sundays 06:23 UTC, and by hand), now backs up the hosted Supabase database. It runs in environment Production and dumps through the Session pooler: roles, the schema, the data of every schema including `auth` and `storage` rows, and the migration history. It encrypts the dump to the owner's two age keys from `BACKUP_AGE_RECIPIENTS` and keeps only the encrypted `.tar.gz.age` as a 90-day artifact. It then restores the plaintext into a throwaway local Supabase database and fails unless every table's restored row count equals the dump's. The logs never show row data. The three scripts are tested on every pull request in the Database Tests job against the local stack, with no secret.

**Files changed:**
- `.github/workflows/backup.yml` — the weekly backup; its header comment says what the dump holds and leaves out, and how to decrypt and restore.
- `scripts/backup-dump.sh` — the five `supabase db dump` calls.
- `scripts/backup-encrypt.sh` — checks the recipients, then tar and gzip and `age -R`, checking the age header.
- `scripts/backup-restore-check.sh` — the throwaway database (project fermi-restore-check, ports 575xx), a single-transaction restore as supabase_admin, row counts, and error output that shows only position and SQLSTATE.
- `scripts/test-backup.sh` — 17 cases (pass, round trip, a failing statement, lost rows, bad recipients, a refused connection, missing arguments, no leftover container).
- `.github/workflows/test.yml` — the age install and the test-backup step in `db-tests` (no new job, no secret).
- `scripts/ci-local.sh`, `app/tests/README.md` — list the new test.

**Review:** one quick pass, 8 findings, all low. 6 patched (test coverage of cleanup and containers, error output, init failure, one comment, the Needs line). 2 rejected: a note count whose fix edits this plan, and a local-only collision between parallel runs. Nothing deferred.

**Follow-up review recommended: false** — patched entries: high 0, medium 0, low 6.

**Verification:**
- `scripts/test-backup.sh`: 17/17.
- `scripts/test-check-job-health.sh`: 12/12.
- actionlint and shellcheck: clean.
- `grep -c 'secrets\.' test.yml`: 0.
- Round trip with the real recipients: a dump of the local stack encrypted to `BACKUP_AGE_RECIPIENTS` decrypts with `~/.age/key.txt` to identical files.
- No restore-check container is left.

Not run here: anything on GitHub or the hosted project, the runner's `apt-get install age`, and the dump through the real pooler. Those are the operator actions.

**Residual risks:**
- The hosted Auth or Storage schema could get a column ahead of the local schema that CLI 2.122.0 bundles. The restore check would then go red until the CLI is bumped. The encrypted dump is still uploaded first.
- GitHub disables a schedule after 60 days without repository activity, and this workflow does not re-enable itself (Design Notes).
- Whether hosted `cron.job` rows reach the data dump is UNVERIFIED. There are no jobs yet.
- A restore into a new hosted project loses Storage bytes and Vault secrets, and needs roles.sql's `GRANT SET ON PARAMETER` line removed (header comment).

## Operator Confirmation

Confirmed 2026-11-07: the external actions this story owed were carried out.

- After this branch merges to main, run Actions > Backup > Run workflow on main and confirm the Backup job is green, including its step Restore into a throwaway database, whose log ends with 'restored N tables, M rows'.
- On that run's page, confirm its one artifact, fermi-db-backup-<run id>, holds only fermi-db-<date>.tar.gz.age, with a 90-day expiry.
- Download the artifact on the Mac, unzip it, and decrypt it with: age -d -i ~/.age/key.txt fermi-db-<date>.tar.gz.age | tar -tz — confirm it lists roles.sql, schema.sql, data.sql, history_schema.sql and history_data.sql; then delete the decrypted and downloaded copies.
- On the Sunday after the merge, confirm the scheduled Backup run (06:23 UTC) ran and is green.

_Appended by the bmad-loop orchestrator (`bmad-loop confirm`, #335): a human confirmed these external actions out of band, and the story was advanced from `awaiting-operator` to `done`._
