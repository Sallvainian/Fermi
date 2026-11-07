---
title: 'Every test kind runs in CI and fails the run'
type: feature
ticket: '3'
created: '2026-11-06'
status: done
baseline_revision: '027e8f4c20ee143b2eb5c6008b9e66553525d05b'
route: oneshot
route_source: auto
risk: medium
review: quick
review_source: pinned
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
closes_deferred: [DW-2, DW-3]
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 3 needs every test kind (ESLint and typecheck, Vitest with coverage, pgTAP, deno test, Playwright on Desktop Chrome and iPhone WebKit, every-test-ran checks, burn-in, the migration expand-only check, the check-site.sh tests for DW-2 and the Data API schema guard for DW-3) to run in `test.yml` on every pull request and push, each failing the run, with one `Test Summary` job, no secrets, the local-only staff sign-in helper, the shared test-user module, the time-as-parameter rule, and `.mcp.json`'s playwright-test server pointed at `app/`. The owner's TEA framework session built all of it by hand in d709727; what remains is proving it does what the ticket says.

**Approach:** Check the committed framework against each item of the ticket's description and verify list, run every lane locally with CI's commands against the local stack, inject one deliberate failure per guard to prove each lane goes red, and revert every injected failure. Change code only where a check fails.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [x] Run every lane of `test.yml` locally with CI's commands -- each passes.
- [x] Inject, then revert, one failure per guard (ESLint error, failing Vitest test, failing pgTAP test, failing Playwright assertion, a migration dropping a column, a grant of USAGE on `app` to authenticated) -- each lane exits non-zero.
- [x] Fix any lane or guard that does not behave as the ticket says.

**Acceptance Criteria:**
- Given the committed framework, when each lane runs locally against the local stack, then each passes, and Playwright's every-test-ran check reports the same count listed and run for chromium, webkit and api.
- Given one deliberate failure per guard, when its lane runs, then the lane exits non-zero; after reverting it, the lane passes again.
- Given `test.yml` and its two setup actions, when searched for `secrets.`, then no match.
- Given a Supabase URL whose host is not 127.0.0.1 or localhost, when the staff sign-in helper runs, then it throws before any request (`tests/unit/local-stack.test.ts`).
- Given a request with `Accept-Profile: app` or `internal`, signed out or in, then the local Data API answers 406 PGRST106, and a schema exposed in `[api] schemas` answers otherwise, so the api spec fails.

## Implementation Notes

Oneshot: the owner's hand session (d709727) committed the whole framework; the build's work is verification, expected to change no code.

- Before review, no code changed: the diff from the baseline was this plan only. Review patches are listed under the Review Triage Log.
- Checked against the ticket: `test.yml` has every lane named in the description, each in `Test Summary`'s `needs`, which accepts only `success` (burn-in may be `skipped` only on push and manual runs); 0 `secrets.` references in `test.yml` and both setup actions; Supabase CLI pinned at 2.122.0; deno lane skips while `supabase/functions` is absent; `.mcp.json`'s `playwright-test` runs `app/node_modules/.bin/playwright` with `app/playwright.config.ts`; Playwright runs against `npm run build` plus `vite preview`; the four open items live in `app/tests/support/helpers/local-stack.ts` and `staff-session.ts` (1), `app/tests/support/test-users.ts` and `supabase/tests/database/00_test_helpers.sql` (2), `scripts/check-migrations.ts` (3) and `app/tests/README.md`, Rules (4); `grep` finds no test sign-in in `app/src`.
- Local run, every lane green: lint and types; Vitest 43/43; migration check 2/2; site-check 4/4 cases (DW-2); pgTAP 14 tests in 3 files; Playwright chromium 1/1, webkit 1/1, api 5/5 with counts matching; burn-in 35/35; actionlint clean.
- Injected failures, each reverted (tree clean after): an unused variable in `src/App.tsx` made `npm run lint` exit 1; a failing test in `tests/unit/` made Vitest exit 1; a failing pgTAP file made `supabase test db` exit 1; a wrong expectation in `tests/e2e/shell.spec.ts` made Playwright exit 1; a migration with `drop column` made `check-migrations.ts` exit 1 with "drops a column".
- DW-3: inside a rolled-back transaction, `grant usage on schema app to authenticated` makes `has_schema_privilege('authenticated','app','usage')` true, which `01_schemas.sql` asserts false. The local Data API answers `app` with 406 PGRST106 and an exposed schema (`graphql_public`) with 404, so adding `app` or `internal` to `[api] schemas` breaks the api spec's 406/PGRST106 expectation. The config edit itself was not run, since it needs a stack restart.
- Surprise, not a defect: `00_test_helpers.sql` commits a `tests` schema to the local database on purpose (its header says so). Story 6's catalog test will see it on local and CI stacks.
- Review follow-up, DW-3 run through the real lanes: `grant usage on schema app to authenticated` applied to the local database made `supabase test db` report `Result: FAIL` (exit 1); after `revoke`, `Result: PASS`. The api spec with `internal` swapped for `graphql_public`, a schema in `[api] schemas`, failed both of that schema's tests (2 failed, 3 passed); reverted. This stands in for editing `[api] schemas`, which needs a restart of the shared local stack.
- Triage treats d709727 as part of this story's change, since the ticket says the build completes the story on top of it, so findings in its code were patched, not deferred as pre-existing.
- Not verified here: a real GitHub Actions run. `test.yml` is not on the default branch yet (`gh run list --workflow test.yml` returns 404), so the first hosted run is the loop's pull request.

## Plan Change Log

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 10 findings — high 0, medium 1, low 7, false 2, maybe-false 0
- findings:
  - `[false]` `[reject]` `.mcp.json`'s playwright-test entry ships in no commit — `.mcp.json` is gitignored by the owner's convention (`.gitignore:129`, and My-Love ignores its own at `.gitignore:93`), so the ticket's edit is a local one, and it is in place: the main checkout's `.mcp.json` matches. The `ENOENT` happened because this worktree had no `app/node_modules` when the session started (`npm ci` ran later). `app/node_modules/.bin/playwright run-test-mcp-server --help` works.
  - `[low]` `[patch]` The DW-3 grant guard was shown only in a rolled-back psql transaction, not through `supabase test db` — ran it for real: grant applied → `Result: FAIL`, revoked → `Result: PASS` (Implementation Notes).
  - `[low]` `[patch]` The `[api] schemas` guard (AC 5) rested on a curl probe, not the spec — ran the api spec with `graphql_public`, an exposed schema, in place of `internal`: its 2 tests failed; reverted. Same root cause as the row above.
  - `[low]` `[reject]` Execution checkboxes left unticked — the fix edits this build's plan; the boxes were ticked as normal bookkeeping at finalize.
  - `[low]` `[reject]` `stripSql` ignores backslash escapes in `E'...'` strings, so a statement after `E'..\'..'` can be hidden — real, but Fermi's migrations use no `E'` strings, and the fix adds an E-string branch to the scanner.
  - `[medium]` `[patch]` Dollar-quote tags with digits (`$fn1$`) are not recognised, so a function body's inner statements are linted (false failure) and an unbalanced quote inside could hide later statements — `scripts/migration-lint.ts:76` tag regex now `/^\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$/`; new unit test in `app/tests/unit/migration-lint.test.ts`, which fails on the old regex and passes on the new.
  - `[low]` `[reject]` The argument check compares type text, so `numeric(10,2)` vs `numeric(10, 2)` or `int` vs `integer` count as a change — it fails loudly with both argument lists in the message, so the cause is plain; a fix needs type-alias normalization.
  - `[low]` `[patch]` `scripts/ci-local.sh` ran Playwright without `CI=1`, unlike its "same commands" header — Playwright line now sets `CI=1`.
  - `[low]` `[patch]` `app/tests/README.md` said CI runs on "every pull request and push" — now "every pull request and every push to main", matching `test.yml`.
  - `[false]` `[reject]` No AGENTS.md or CLAUDE.md to check against — no rule is broken; AGENTS.md is story 13's.

## Verification

**Commands:**
- `cd app && npm run lint && npm run typecheck` -- expected: exit 0
- `cd app && npm run test:unit:coverage` -- expected: all tests pass, `src/api/**` threshold met
- `node scripts/check-migrations.ts` -- expected: `2 migration(s) checked: expand-only.`
- `scripts/test-check-site.sh` -- expected: `All 4 health check cases behaved as expected.`
- `supabase test db` -- expected: `Result: PASS`
- `cd app && for p in chromium webkit api; do f=tests/e2e; [ $p = api ] && f=tests/api; CI=1 npx playwright test --project=$p && CI=1 scripts/check-test-counts.sh $p $f; done` -- expected: all pass, counts match
- `cd app && CI=1 npm run test:burn-in -- --base-branch=main` -- expected: burn-in completes successfully
- `actionlint .github/workflows/test.yml` -- expected: no output
- `grep -c 'secrets\.' .github/workflows/test.yml` -- expected: 0

## Auto Run Result

Status: built

- **Summary:** The owner's TEA session (d709727) had already committed story 3's framework and `test.yml`. This build checked it against every item of the ticket, ran every lane locally with CI's commands against the local stack, proved each guard turns red on a deliberate failure and green after the revert, and applied four small review fixes.
- **Files changed:**
  - `scripts/migration-lint.ts` -- dollar-quote tags may contain digits after the first character.
  - `app/tests/unit/migration-lint.test.ts` -- test for a `$fn1$` body holding a `drop table`.
  - `scripts/ci-local.sh` -- Playwright runs with `CI=1`, as on GitHub's runners.
  - `app/tests/README.md` -- CI trigger wording matches `test.yml` (push to main only).
  - this plan.
- **Review findings:** 10 from the quick lens. Patched 5 (1 medium, 4 low): dollar-quote tag regex, DW-3 grant guard run through `supabase test db`, `[api] schemas` guard run through the api spec, `ci-local.sh` `CI=1`, README wording. Deferred 0. Rejected 5: `.mcp.json` not shipped (false: gitignored by convention, edit present locally); no agent files (false: nothing to break); unticked boxes (fix edits the plan); `E'...'` escapes (unlikely, fix adds complexity); argument-text comparison (fails loudly, fix needs type aliases).
- **Follow-up review recommended:** false. One medium and four low patches; no high.
- **Verification:** lint and types pass; Vitest 44/44 with coverage; migration check 2/2 expand-only; site-check 4/4 cases (DW-2); pgTAP `Result: PASS` (14 tests, 3 files); Playwright chromium 1/1, webkit 1/1, api 5/5, each count check matching; burn-in completed; actionlint clean; 0 `secrets.` in `test.yml`. Deliberate failures, each reverted: an ESLint error, a failing Vitest test, a failing pgTAP test, a failing Playwright assertion, a `drop column` migration, a USAGE grant on `app`, and an exposed schema in the api spec. Each one exited non-zero.
- **Residual risks:** No GitHub Actions run of `test.yml` exists yet (it is not on the default branch), so the red run naming each failed job and the green revert on GitHub are UNVERIFIED until the loop's pull request runs. Adding `internal` to `[api] schemas` was tested by swapping in an already-exposed schema, not by editing `supabase/config.toml` and restarting the stack. Rejected lint gaps remain: `E'...'` escapes and type-spelling false positives in `scripts/migration-lint.ts`.
- DW-2 and DW-3 are closed by this story (`closes_deferred` in frontmatter).
