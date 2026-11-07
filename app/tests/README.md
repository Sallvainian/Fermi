# Fermi tests

Every kind of test the port uses, how to run each one, and the rules they share. CI runs all of them on every pull request and every push to main (`.github/workflows/test.yml`), and its **Test Summary** job passes only when every lane passes.

| Lane | Tool | Where the tests live | Run locally |
| --- | --- | --- | --- |
| Lint and types | ESLint, `tsc -b` | `app/` | `npm run lint && npm run typecheck` (in `app/`) |
| Unit and component | Vitest 5.1.0, Testing Library, happy-dom | `app/tests/unit/`, or beside the code as `src/**/*.test.ts(x)` | `npm run test:unit` (`test:unit:coverage` for coverage) |
| Database | pgTAP through `supabase test db` | `supabase/tests/database/NN_*.sql` | `supabase test db` (repo root) |
| Edge functions | `deno test` | beside each `handler.ts` in `supabase/functions/`, and beside each `_shared/*.ts` | `deno test --no-lock --permit-no-files supabase/functions` (repo root) |
| Browser | Playwright: Desktop Chrome (`chromium`), iPhone WebKit (`webkit`) | `app/tests/e2e/*.spec.ts` | `npm run test:e2e -- --project=chromium` |
| API | Playwright `api` project (HTTP; Playwright Utils still opens a page) | `app/tests/api/*.spec.ts` | `npm run test:e2e -- --project=api` |
| Migration check | `scripts/check-migrations.ts` | `supabase/migrations/` | `node scripts/check-migrations.ts` (repo root) |
| Health check tests | `scripts/test-check-site.sh`, `scripts/test-check-hosted-config.sh`, `scripts/test-write-latest-json.sh` | the deploy health checks, `scripts/check-site.sh` and `scripts/check-hosted-config.sh`, and `scripts/write-latest-json.sh` | `scripts/test-check-site.sh`, `scripts/test-check-hosted-config.sh` and `scripts/test-write-latest-json.sh` (repo root) |
| Burn-in | Playwright Utils `runBurnIn` | changed Playwright specs | `npm run test:burn-in -- --base-branch=main` |

## Setup

1. `npm ci` in `app/`, then `npx playwright install chromium webkit`; the script lanes also need `jq`.
2. Start the local stack from the repo root: `supabase start`. Fermi's local ports are 563xx (`supabase/config.toml`), so it runs beside My-Love's stack.
3. Nothing else: the tests read the stack's URL and keys from `supabase status`. See `app/.env.example` for the variables you can override.

Playwright builds the shell (`npm run build`) and serves it with `vite preview` on port 4173, so the browser tests run against the same build Cloudflare serves. `npm run test:e2e:ui` opens the UI mode; `npm run test:e2e:debug` steps through a test.

## How the Playwright suite is built

Specs import from `tests/support/merged-fixtures.ts` and nowhere else, and use `@seontechnologies/playwright-utils` for every capability it covers (TEA's Playwright Utils mandate; story 13 records the rule in AGENTS.md). A vanilla Playwright equivalent needs a `// playwright-utils deviation: <reason>` comment.

- `test`, for browser and API specs alike: `apiRequest`, `recurse`, `interceptNetworkCall`, the network error monitor (fails a test on any 4xx or 5xx response the page receives), the auth fixtures, `testUsers`. `apiRequest` opens a page, so API specs start a browser too.
- `log.step` for milestones, never `console.log`.
- Declare `interceptNetworkCall({ url })` before `page.goto` and await it after (network first).
- Select by `data-testid` (the test design's list: `build-commit-id`, `signin-*`, `roster-*`, ...).
- Tag priority and level in the title: `[P0]`, `[P1]`, `@Security`, `@API`. Run a subset with `--grep @P0` or `--grep "\[P0\]"`.

`tests/e2e/shell.spec.ts` and `tests/api/data-api-schemas.spec.ts` are the reference specs to copy from.

## Users and sign-in

**One shared module for test users:** `tests/support/test-users.ts`, with the pgTAP side in `supabase/tests/database/00_test_helpers.sql` (story 3, decision 2; test design TC-3). Later epics extend it rather than inventing users: epic-invite-sign-in adds the admin and the teachers to `personaSetups`, epic-classes-rosters the students and classes. Persona names are snake_case (`teacher_a`) and map to the same email on both sides (`persona-teacher-a@test.example.com`).

- A signed-in persona: `test.use({ authOptions: { userIdentifier: 'teacher_a' } })` in a describe block, then use `authToken` or the already-signed-in `page`. Without it a test runs as the `default` persona. `test.use({ authSessionEnabled: false })` starts signed out.
- A throwaway user the test owns: `await testUsers.create()`; it is deleted after the test, pass or fail.
- In pgTAP: `tests.create_persona('teacher_a')`, `tests.authenticate_as('teacher_a')`, `tests.authenticate_as_anon()`, `tests.clear_authentication()`, `tests.persona_id('teacher_a')`. Every test file runs inside `begin ... rollback`, so it leaves nothing behind.

**Staff sign-in is test-only and local-only** (story 3, decision 1; TC-1). Staff sign in with Google, which no test can drive, so `tests/support/helpers/staff-session.ts` creates the persona with the local stack's service-role key and signs in with a password. It refuses any Supabase URL whose host is not `127.0.0.1` or `localhost` (`tests/unit/local-stack.test.ts` proves it). Nothing in `app/`, `supabase/functions/` or the hosted config adds a test sign-in. These users skip `before_user_created`, so admission is tested only by the hook's pgTAP tests (P0-003) and by hand on the deployed site.

## Rules

- **No secrets.** `test.yml` reads no repo or environment secret (AD-23). Tests use the local stack's demo keys from `supabase status`.
- **Time is a parameter** (story 3, decision 4; TC-2). Every scheduled job takes the current time as an argument that defaults to `now()`, so a test passes the time it needs and never waits on the clock.
- **Migrations only add** (AD-20; story 3, decision 3; TC-4). `scripts/check-migrations.ts` fails a migration that drops or renames a table, view, column, function or schema, moves one to another schema, or defines a function again with different arguments. A planned contract step passes when its first line is `-- contract: <why it is safe now>`.
- **Grants are listed** (AD-3; P0-006). Every migration that adds or changes a table, column, function or view in `public`, `app` or `internal` updates `supabase/tests/database/privilege_fixture.psql` in the same change; its header gives the line format. `03_privileges.sql` compares the live catalog to it and fails, naming each object, on an object the fixture does not list (every column of every table and view has a line, even with no grants), a stale line, a different grant, any grant to `anon` or PUBLIC (even if listed), an `internal` function executable by `authenticated`, and a `public` view without `security_invoker`. Only the first two failures print a line to paste into the fixture.
- **Coverage:** 80% of the lines in `app/src/api/` (owner decision 2026-11-06). Screens carry no threshold.
- **No hard waits.** Use `recurse` for anything eventually consistent and web-first assertions in the browser. The write-time hook (below) blocks `waitForTimeout`, `.only` and the other absolute rules.
- **Every test ran.** `app/scripts/check-test-counts.sh` fails a CI job whose run executed fewer Playwright tests than the suite lists.
- **Flaky tests fail where they are written.** On a pull request, burn-in repeats every changed or affected Playwright spec 5 times with no retries.

## Write-time enforcement hook

`.claude/hooks/tea-enforce.cjs` runs on every Write, Edit and Bash in Claude Code (registered in `.claude/settings.json`: `--pre`, `--post`, `--stop`) and blocks a test file that breaks an absolute rule, such as a hard wait (H1) or a file over 1000 lines (H5). The rules and their severity come from the `bmad-tea-test-review` criteria registry, not from the hook. `.tea/enforce-config.json` says which files count as tests (`testGlobs`). To turn a rule off, add its id to `disabledRules` and give the reason in the commit. The hook's sha256 is in `hookSha256`; `--stop` warns if the copy was edited.

## CI

`.github/workflows/test.yml` runs on every pull request, every push to main, Sundays at 02:00 UTC, and by hand (Run workflow).

| Job | What fails it |
| --- | --- |
| Lint & Type Check | an ESLint error or a TypeScript error |
| Unit Tests | a failing Vitest test, or under 80% line coverage in `app/src/api/` |
| Database Tests | a migration that does not apply to a fresh database, a failing pgTAP test, `scripts/test-check-job-health.sh` or `scripts/test-backup.sh` failing against the local stack |
| Edge Function Tests | a failing `deno test` |
| Migration Check | a migration that drops, renames or changes a function's arguments without a contract line |
| Health Check Tests | `scripts/check-site.sh` passing a stale id, a missing JavaScript file, an id missing from the JavaScript, a missing `updates/latest.json`, a stale `latest.json` version, or failing the right id (DW-2); `scripts/deploy-gate.sh` (deploy.yml's daily decision) skipping a deploy when main is ahead or no `latest.json` is served; `scripts/write-latest-json.sh` failing a case (writing more than `latest.json`, or not refusing an absent build id, an unset `GITHUB_SHA` or a missing build) |
| Playwright (chromium, webkit, api) | a failing test, or fewer tests run than listed |
| Burn-In | an affected spec failing in any of 5 runs (pull requests; every spec on Sundays) |
| **Test Summary** | any job above not passing |

**Test Summary** is the check story 13 makes required on main. A lane added later joins its `needs` in the same change (AD-23).

- **Secrets:** none. `test.yml` reads no repo or environment secret, so Dependabot pull requests run every lane. Never add one: a lane that needs a secret belongs in a deploy or scheduled workflow, where it blocks nothing.
- **Shared setup:** `.github/actions/setup-supabase` (pinned CLI 2.122.0, checksum-verified and cached; starts the local stack without Studio, the mail catcher, the edge runtime or analytics; exports its URL and demo keys) and `.github/actions/setup-playwright` (npm ci, cached browsers, then setup-supabase). A spec that calls an edge function through the API, or reads an auth email, must take `edge-runtime` or `mailpit` off the exclusion list in the same change.
- **Reports:** `app/playwright-report/` and `app/test-results/` are uploaded when a Playwright or burn-in job fails (14 and 7 days); `app/coverage/` on every unit run (7 days).
- **Retries:** Playwright retries a failed test twice in CI and reports it as flaky; burn-in never retries. `supabase start` is retried once.
- **Parallelism:** one job per Playwright project, 2 workers each. Shards are added only once a run takes longer than 15 minutes (test design).
- **Run it locally:** `scripts/ci-local.sh` from the repo root runs every lane but burn-in with CI's commands.
- **Failure notifications:** GitHub emails a failed push or scheduled run to whoever triggered it; a pull request shows the red job.

### CI troubleshooting

- **A Playwright job fails but every test passed:** read the "Check every ... test ran" step; a config change dropped files or tests from the run.
- **`supabase start` fails pulling an image:** the job retries once; rerun the job. Images come from ghcr.io, not the rate-limited public.ecr.aws.
- **Test Summary fails with every lane green:** a lane was cancelled or skipped; Test Summary accepts only success (burn-in may be skipped only on pushes and manual runs).

## Drafts and busy work

A form field that must survive the refresh page keeps its value with `useDraft(draftKey(feature, ...scopeIds, field), initial)` (`app/src/drafts/`); `draftKey` is the only builder of `fermi:draft:` keys, and `app/src/api/auth.ts` (`startAuth()`, called from `main.tsx`) wipes every draft on `SIGNED_OUT`. A flow of several calls (an upload, a CSV import) wraps itself in `runBusy(fn)` or `holdBusy()` (`app/src/busy/busy.ts`) so the refresh page waits for it. Their tests are `tests/unit/draftKey.test.ts`, `useDraft.test.tsx`, `auth.test.ts` and `busy.test.ts`.

## Folder layout

- `tests/support/merged-fixtures.ts`: the entry point (`test`, `expect`, `log`)
- `tests/support/auth-fixture.ts`, `tests/support/auth/supabase-auth-provider.ts`: Playwright Utils' auth-session, signed in as a persona
- `tests/support/test-users.ts`: the shared persona cast and user helpers
- `tests/support/fixtures/`: Fermi's own fixtures (`testUsers`) and `factories/` (pure data builders)
- `tests/support/helpers/`: the local-stack guard and the staff sign-in helper
- `tests/burn-in/`: the burn-in config and runner

## Troubleshooting

- **`Could not create persona ...` or `SUPABASE_URL is not set`:** the local stack is down. Run `supabase start` from the repo root.
- **`port is already allocated` on `supabase start`:** another project's stack holds a 563xx port. `docker ps` shows which; stop it, or move Fermi's ports in `supabase/config.toml`.
- **`Refusing to run test helpers against ...`:** `SUPABASE_URL` points somewhere other than this machine, often a value exported in your shell. Unset it.
- **After `supabase db reset`, delete `app/.auth/`.** The reset deletes the persona users, but their cached sessions stay valid until they expire, so a test would act as a user that no longer exists.
- **A browser test fails on a 4xx or 5xx it does not check:** the network error monitor caught a real failed request. Fix the request, or exclude that URL pattern in `merged-fixtures.ts` with the reason.
- **`check-test-counts.sh` fails locally on spec counts:** it counts spec files tracked by git, so a new spec counts once it is committed.
- **Burn-in says no tests need to run:** it diffs committed changes against the base branch and selects specs that change or import a changed file. Commit first, or run the spec with `--repeat-each`.

## Knowledge base

TEA fragments applied: `playwright-utils-mandate.md`, `overview.md`, `fixtures-composition.md`, `auth-session.md`, `api-request.md`, `recurse.md`, `log.md`, `burn-in.md`, `network-error-monitor.md`, `data-factories.md`, `intercept-network-call.md`, `ci-burn-in.md`. The test plan is `_bmad-output/test-artifacts/test-design/`.
