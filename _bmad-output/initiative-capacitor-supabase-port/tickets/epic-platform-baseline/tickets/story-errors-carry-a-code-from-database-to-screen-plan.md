---
title: 'Errors carry a code from database to screen'
type: feature
ticket: '5'
created: '2026-11-06'
status: done
baseline_revision: '492284b790f4a422601eff1419f2f7fa6f8eb49e'
route: full
route_source: auto
risk: low
review: quick
review_source: pinned
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
operator_actions:
  - Once the loop's pull request for this branch runs test.yml on GitHub, confirm the Unit Tests and Edge Function Tests jobs pass and list the src/api Vitest files and the supabase/functions/_shared deno tests.
  - On that pull request (or a scratch branch from it), push a commit adding a failing Deno.test to supabase/functions/_shared/errors.test.ts, confirm Edge Function Tests and Test Summary go red, then revert it and confirm both go green.
  - After this branch merges to main, open the Deploy run for that push and confirm the jobs run Migrate, Hosted config, Edge functions, Build, Deploy, Health check in that order and all green, with the Edge functions log saying "no edge functions to deploy".
---

<intent-contract>

## Intent

**Problem:** No app code talks to Supabase yet, and nothing fixes how an error travels: a refused SQL call, an edge function failure and a network failure would each reach a screen in its own shape. Later epics need one client, one error map and one edge-function error helper to build on (AD-17), and the deploy has no edge-functions step (R2's order: migrations, Auth config, Realtime, edge functions, build).

**Approach:** Add `app/src/api/` with the env config, the one Supabase client and the one error map (SQLSTATE and snake_case key → text, for both PostgREST errors and edge-function `{ error: { code, message } }` bodies), and an ESLint rule refusing `@supabase/*` imports anywhere else in app code. Add `supabase/functions/_shared/` with the helper every edge function answers errors through. Add a deploy.yml job that deploys every function folder and passes when there are none.

## Boundaries & Constraints

**Always:** AD-17's SQLSTATEs (`42501` refused, `P0002` not found, `22023` bad input, `23505` duplicate) and edge statuses (401, 403, 404, 409, 422, 500). Error text comes only from the map in `app/src/api/`; a server's `message` is kept for logs, never shown. Unknown codes fall back to the SQLSTATE's or status's text, then to one generic text, never to raw server text. Edge helper has no third-party imports (plain Deno + Web APIs). New deploy job: `environment: Production`, main-only guard, skipped on `health_check_only`, Supabase CLI 2.122.0 via the pinned `supabase/setup-cli` SHA, only `SUPABASE_ACCESS_TOKEN`, runs no npm code. Pinned stack versions unchanged.

**Never:** No new npm or Deno dependency. No real edge function, table, RPC or screen that uses the client. No new `test.yml` job (the `Edge Function Tests` lane already runs `deno test` over `supabase/functions`). No change to the root `.gitignore`, `deferred-work.md` or any ticket file. No `--prune` on functions deploy.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| SQL key known | PostgREST error `{code:'42501', message:'not_class_teacher'}`, key in map | ApiError code `not_class_teacher`, its mapped text | — |
| SQL key unknown | `{code:'P0002', message:'no_such_thing'}` | code `no_such_thing`, P0002's "not found" text | — |
| SQLSTATE unknown | `{code:'XX000', message:'boom'}` or code `''` | generic text, code `unknown_error` | — |
| Edge body | 409 Response, body `{error:{code:'already_enrolled',message:'..'}}` | code from body; mapped text, else 409's text | body not JSON or wrong shape → status text, code from status |
| Edge network | FunctionsFetchError / FunctionsRelayError | code `network_error`, its text | — |
| Helper, known | `new HttpError(403,'not_class_teacher','..')` | Response 403, JSON `{error:{code,message}}`, JSON content type | — |
| Helper, unknown throw | `toErrorResponse(new Error('db password'))` | 500 `{error:{code:'internal_error',message:'Internal error'}}`; thrown text not in body | logged with `console.error` |
| Helper, from RPC | RPC error `{code:'23505', message:'duplicate_email'}` | 409, code `duplicate_email`; unknown SQLSTATE → 500 `internal_error` | — |
| Deploy, none | `supabase/functions` has only `_shared` | step prints "no edge functions" and exits 0 | CLI not called (it exits 1 with NoFunctionsToDeployError) |
| Env | `VITE_SUPABASE_URL`/`_PUBLISHABLE_KEY` both unset | local stack: `http://127.0.0.1:56321`, `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH` | one set without the other, or a bad URL → throws naming the variable |

</intent-contract>

## Code Map

- `app/eslint.config.js` -- flat config; add a block for `**/*.{ts,tsx,js}` with `no-restricted-imports` `patterns: [{ group: ['@supabase/*'], message }]`, and a later block turning it off for `src/api/**` and `tests/**` (test helpers `tests/support/test-users.ts`, `helpers/staff-session.ts` import supabase-js on purpose, against the local stack only).
- `app/src/vite-env.d.ts` -- add `ImportMetaEnv` with the two optional `VITE_SUPABASE_*` strings.
- `app/vitest.config.ts` -- already enforces 80% line coverage on `src/api/**`; Vitest includes `src/**/*.test.ts` and `tests/unit/**`.
- `@supabase/supabase-js` 2.119.0 exports `createClient`, `FunctionsHttpError` (`.context` is the Response), `FunctionsFetchError`, `FunctionsRelayError`, `PostgrestError` type.
- Local stack: `supabase/config.toml` `[api] port = 56321`; CLI 2.122.0's local publishable key is the fixed demo key above (`supabase status -o env`).
- `.github/workflows/deploy.yml` -- jobs migrate → hosted-config → build → deploy → health-check; `hosted-config` is the model for the new job (guard `if: github.ref == 'refs/heads/main'`, skipped via `needs` on a health-check-only run). Build job has no environment and no secrets.
- Repo variables: `SUPABASE_PROJECT_ID` = `mzbblbgmrvcgvzxwhptm`, `SITE_URL`. No publishable-key variable yet; the hosted project has a `publishable default` key (`supabase projects api-keys`).
- `.github/workflows/test.yml:117-127` -- `deno test --no-lock --permit-no-files supabase/functions`, skipped while the folder is absent; comment says story 5 adds the first function.
- `scripts/ci-local.sh` -- mirrors the deno lane; unchanged logic.
- `app/tests/README.md` -- lane table; Edge functions row says tests sit beside `handler.ts`.
- My-Love reference: its functions job runs `supabase functions deploy --project-ref ... --use-api` with no prune, after migrate, before build.

## Tasks & Acceptance

**Execution:**
- [ ] `app/src/api/env.ts` -- pure `parseSupabaseEnv(raw)` returning `{ url, publishableKey }` per the Env row; `supabaseEnv()` reads `import.meta.env`.
- [ ] `app/src/api/client.ts` -- `createSupabase(env)` and a lazy singleton `supabase()`; created on first call, so the shell never touches it today.
- [ ] `app/src/api/errors.ts` -- `ApiError` (`code`, `text`, `status?`, `sqlstate?`, `detail?`), the one key→text map (AD-17 SQLSTATEs, statuses, `network_error`, `unknown_error`, `internal_error`; later epics add keys here), `fromPostgrestError(err)`, async `fromFunctionsError(err)`, `errorText(code)`.
- [ ] `app/src/api/errors.test.ts`, `app/src/api/env.test.ts`, `app/src/api/client.test.ts` -- Vitest for every app-side matrix row; `src/api/**` stays ≥80% lines.
- [ ] `app/src/vite-env.d.ts` -- `ImportMetaEnv` typing.
- [ ] `app/eslint.config.js` -- the restriction above, with a message naming `app/src/api/` and AD-17.
- [ ] `supabase/functions/_shared/errors.ts` -- `HttpError`, `errorResponse(status, code, message)`, `toErrorResponse(err)`, `fromRpcError(err)` (SQLSTATE → status: 42501→403, P0002→404, 22023→422, 23505→409, else 500 `internal_error`); responses carry `corsHeaders` from `_shared/cors.ts` (`*`, `authorization, x-client-info, apikey, content-type`) so the browser can read error bodies.
- [ ] `supabase/functions/_shared/cors.ts` -- `corsHeaders`.
- [ ] `supabase/functions/_shared/errors.test.ts` -- `deno test` for every helper matrix row, using `jsr:@std/assert`-free plain asserts or Deno's built-in test API.
- [ ] `.github/workflows/deploy.yml` -- job `functions` (name `Edge functions`) needs `hosted-config`; step lists `supabase/functions/*/` whose name matches `^[A-Za-z][A-Za-z0-9_-]*$`, exits 0 with a message when none, else `supabase functions deploy --project-ref "$PROJECT_ID" --use-api`; `build` needs `functions`; build step gets `VITE_SUPABASE_URL: https://${{ vars.SUPABASE_PROJECT_ID }}.supabase.co` and `VITE_SUPABASE_PUBLISHABLE_KEY: ${{ vars.SUPABASE_PUBLISHABLE_KEY }}`, and a step before it failing when either is empty; update the Production-jobs comment.
- [ ] Repo variable `SUPABASE_PUBLISHABLE_KEY` -- set with `gh variable set` from the hosted `publishable default` key (public by design, not a secret).
- [ ] `.github/workflows/test.yml`, `app/tests/README.md` -- comment and lane row: `_shared` exists; tests sit beside `handler.ts` and `_shared/*.ts`.

**Acceptance Criteria:**
- Given a file in `app/src/` outside `api/` (or an app config file) importing `@supabase/supabase-js`, when `npm run lint` runs, then it fails naming `app/src/api/`; the same import in `app/src/api/` or `app/tests/` passes.
- Given the branch, when the Unit Tests and Edge Function Tests lanes run, then both pass, and a deliberately failing `deno test` makes the deno lane exit non-zero.
- Given deploy.yml, when actionlint runs, then nothing is reported; on a push the order is Migrate → Hosted config → Edge functions → Build → Deploy → Health check; with `health_check_only` the Edge functions job is skipped.
- Given a scratch project whose `supabase/functions` holds only `_shared`, when the new step's script runs, then it exits 0 without calling the CLI; with one function folder, it calls `supabase functions deploy`.

## Implementation Notes

- Implemented by a Sonnet subagent from this plan; the parent re-ran every verification command.
- Planning checked CLI 2.122.0 in a scratch project: `supabase functions deploy --use-api` with only `_shared` exits 1 with `NoFunctionsToDeployError` before any API call, hence the step's own folder scan.
- Repo variable `SUPABASE_PUBLISHABLE_KEY` set with `gh variable set`; the parent confirmed it equals the hosted `publishable default` key (compared, not printed).
- The ESLint restriction is off for `tests/**` as well as `src/api/**`: story 3's `tests/support/test-users.ts` and `helpers/staff-session.ts` import supabase-js with the local stack's service-role key, which must never go through the app's client.
- Deno tests use two local assert helpers: `node:assert` failed `deno test`'s type check here (no `@types/node` resolution), and the plan forbids a new dependency.
- The known-key test rows add `not_class_teacher` and `already_enrolled` to `ERROR_TEXT` for the test and delete them after, since no domain key exists yet.
- Surprise: the owner's shell exports `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY` for another project (`xojempkrugifnaveqtqc`, My-Love's naming). Vite reads `VITE_*` from the process, so in that shell a local build gets that URL and no `VITE_SUPABASE_PUBLISHABLE_KEY`, and `supabase()` would throw naming the key. Nothing calls the client yet; CI is unaffected. The client tests stub both variables.
- Matrix row "Deploy, none" has no automated test (inline workflow shell); the parent extracted the step's script and ran it against a stub CLI: only `_shared` → "no edge functions to deploy", exit 0, CLI not called; one folder → `supabase functions deploy --project-ref abc --use-api`.
- Verification run by the parent: lint and typecheck exit 0; Vitest 87/87, `src/api` 100% lines; deno test 9/9; actionlint clean; an `@supabase/supabase-js` import in `src/App.tsx` fails lint with the AD-17 message (reverted); a deliberately failing `Deno.test` makes `deno test` exit 1 (reverted, 9/9 again).

## Plan Change Log

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 5 findings — high 0, medium 1, low 3, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` A SQL call that fails offline reached the screen as `unknown_error`, not `network_error` — confirmed in postgrest-js 2.119.0 (`dist/index.cjs:439-460`: empty `code`, message `'<ErrorName>: <message>'`, status 0). `fromPostgrestError` now maps an empty code with a `TypeError:`/`AbortError:`/`TimeoutError:`/`FetchError:` message to `network_error`; two Vitest tests added (that case, and an empty code with other text staying `unknown_error`).
  - `[low]` `[patch]` The migrate job's comment in `deploy.yml` did not list the new functions job among those that need it — added.
  - `[low]` `[patch]` The ESLint restriction covered only `.ts/.tsx/.js`, so a `.mts`/`.cts`/`.mjs`/`.cjs` file could import supabase-js — removed the block's `files` key so it applies to every linted file; an `import '@supabase/supabase-js'` in `src/probe.mts` now fails lint (probe deleted). The dynamic `import()` part of the same finding is not patched: `no-restricted-imports` does not see `import()`, covering it needs a `no-restricted-syntax` selector, and nothing in the app uses dynamic imports.
  - `[low]` `[patch]` `env.test.ts` called `vi.unstubAllEnvs()` inside a test its `afterEach` already cleans, plus a double blank line — both deleted.
  - `[false]` `[reject]` Deno tests might fail type-checking because `let x: T | undefined` assigned in a callback could narrow to `never` — `deno test` type-checks before running and passed 9/9 here.

## Design Notes

Both error shapes end in one `ApiError` so a screen shows `error.text` and branches on `error.code` without knowing where the error came from. Lookup order: the key (SQL message or edge `code`) → the SQLSTATE or HTTP status → `unknown_error`.

Env falls back to the local stack, not to an error, because `test.yml` builds the production shell for Playwright against the local stack; the deploy build is the only build that must target the hosted project, so the guard lives there. The publishable key is a repo variable like `SUPABASE_PROJECT_ID`, not a committed file: the root `.gitignore` ignores `.env*`, and a rotation needs no commit.

## Verification

**Commands:**
- `cd app && npm run lint && npm run typecheck` -- expected: exit 0.
- `cd app && npm run test:unit:coverage` -- expected: all pass, `src/api/**` ≥80% lines.
- `deno test --no-lock --permit-no-files supabase/functions` -- expected: all pass.
- `actionlint .github/workflows/deploy.yml .github/workflows/test.yml` -- expected: no output.
- Lint guard: add `import '@supabase/supabase-js';` to `app/src/App.tsx`, `npm run lint` fails; revert.
- Deno guard: add a failing assertion to `_shared/errors.test.ts`, `deno test` exits non-zero; revert.
- Deploy step script run in a scratch copy with only `_shared` → exit 0, no CLI call.
- `gh variable list` -- expected: `SUPABASE_PUBLISHABLE_KEY` present.

## Auto Run Result

Status: awaiting-operator

**Summary:** `app/src/api/` is now the only app code that may import Supabase: `env.ts` reads `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` (both unset → the local stack; one without the other or a bad URL → an error naming the variable), `client.ts` builds the one client lazily, and `errors.ts` holds the one key→text map and turns PostgREST errors, edge-function `{ error: { code, message } }` responses and network failures into one `ApiError` whose text always comes from the map. An ESLint rule refuses `@supabase/*` imports anywhere in `app/` outside `src/api/` and `tests/`. `supabase/functions/_shared/` holds the helper every edge function answers errors through (real status, AD-17 body, CORS headers, unknown throws logged and answered as a bare 500, RPC SQLSTATE → status). deploy.yml gains an Edge functions job between Hosted config and Build that deploys every function folder and passes with none, and the deploy build now targets the hosted project through repo variables.

**Files changed:**
- `app/src/api/env.ts`, `client.ts`, `errors.ts` — env config, the one client, the one error map.
- `app/src/api/env.test.ts`, `client.test.ts`, `errors.test.ts` — Vitest, 45 tests, `src/api` 100% lines.
- `app/src/vite-env.d.ts` — typing for the two env variables.
- `app/eslint.config.js` — `@supabase/*` import restriction outside `src/api/` and `tests/`.
- `supabase/functions/_shared/errors.ts`, `cors.ts`, `errors.test.ts` — the edge error helper and its 9 deno tests.
- `.github/workflows/deploy.yml` — Edge functions job; build variable guard; hosted URL and publishable key passed to the build; comments.
- `.github/workflows/test.yml`, `app/tests/README.md` — deno lane comment and lane row mention `_shared`.
- Outside the repo: repo variable `SUPABASE_PUBLISHABLE_KEY`, set to the hosted project's publishable key (public by design).

**Review findings:** 5 from the quick lens. Patched 4 (1 medium: offline SQL errors now map to `network_error`; 3 low: stale migrate comment, lint rule now covers every linted extension, duplicate test cleanup). Deferred 0. Rejected 1: Deno narrowing concern (false: `deno test` type-checked and passed). Not patched within a patched row: dynamic `import()` of Supabase escapes the lint rule (needs a `no-restricted-syntax` selector; no dynamic imports exist).

**Follow-up review recommended: false** — patched one medium and three low; no high.

**Verification:** `npm run lint` and `npm run typecheck` exit 0; Vitest 89/89 with `src/api` 100% lines; `deno test --no-lock --permit-no-files supabase/functions` 9/9; actionlint clean on deploy.yml and test.yml; a supabase-js import in `src/App.tsx` and in a `.mts` file each fail lint (reverted); a deliberately failing `Deno.test` makes `deno test` exit 1 (reverted); the Edge functions step's script, extracted from deploy.yml and run against a stub CLI, exits 0 without calling the CLI when only `_shared` exists and calls `supabase functions deploy --project-ref abc --use-api` with one function folder; `SUPABASE_PUBLISHABLE_KEY` matches the hosted publishable key (compared, not printed).

**Owed by the operator (operator_actions):** confirm the pull request's Unit Tests and Edge Function Tests are green on GitHub; confirm a deliberately failing deno test turns the run red and its revert green; after merge, confirm the Deploy run shows Edge functions green in its place in the order.

**Residual risks:** No GitHub run of the new Edge functions job or of the Vitest/deno tests exists yet. The owner's shell exports `VITE_SUPABASE_URL` for another project (`xojempkrugifnaveqtqc`) without `VITE_SUPABASE_PUBLISHABLE_KEY`, so in that shell a local build's `supabase()` would throw naming the key; nothing calls it yet and CI is unaffected. CORS allows any origin (`*`), which is safe with bearer-token auth and no cookies, but a later epic may want to narrow it. Dynamic `import()` of Supabase is not caught by lint. The map holds only generic texts; domain keys arrive with later epics.

## Operator Confirmation

Confirmed 2026-11-06: the external actions this story owed were carried out.

- Once the loop's pull request for this branch runs test.yml on GitHub, confirm the Unit Tests and Edge Function Tests jobs pass and list the src/api Vitest files and the supabase/functions/_shared deno tests.
- On that pull request (or a scratch branch from it), push a commit adding a failing Deno.test to supabase/functions/_shared/errors.test.ts, confirm Edge Function Tests and Test Summary go red, then revert it and confirm both go green.
- After this branch merges to main, open the Deploy run for that push and confirm the jobs run Migrate, Hosted config, Edge functions, Build, Deploy, Health check in that order and all green, with the Edge functions log saying "no edge functions to deploy".

_Appended by the bmad-loop orchestrator (`bmad-loop confirm`, #335): a human confirmed these external actions out of band, and the story was advanced from `awaiting-operator` to `done`._
