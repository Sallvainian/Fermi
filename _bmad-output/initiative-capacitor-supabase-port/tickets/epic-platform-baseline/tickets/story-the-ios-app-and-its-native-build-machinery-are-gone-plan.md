---
title: 'The iOS app and its native-build machinery are gone'
type: chore
ticket: '14'
created: '2026-11-07'
status: done
baseline_revision: '10fef350835e983b5bf6ea3b5982a73302bb53cb'
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
closes_deferred: [DW-4, DW-8]
---

<intent-contract>

## Intent

**Problem:** The owner dropped the iPhone app and Capacitor (initiative Decision 2026-11-07), but `app/` still carries the iOS project, Capacitor packages and `MIN_NATIVE_BUILD`; CI still runs a Native Build Check; Dependabot still holds native-group pull requests; every deploy still zips the build for an updater that will never exist; and the docs, prompts and AGENTS.md still describe a Capacitor iOS app (R4, R2, R11, R12).

**Approach:** Delete the iOS project, Capacitor config and packages, `MIN_NATIVE_BUILD` and every native-build script, job, group and hold; rename `scripts/package-live-update.sh` to `scripts/write-latest-json.sh`, which writes `updates/latest.json` as `{"version": "<id>"}` only; trim `check-site.sh` to the version check; move the packaging refusals into a new test run by the Health Check Tests job; correct every description of the removed parts.

## Boundaries & Constraints

**Always:**
- `latest.json` keeps `version` = the build's commit id, the same id the build bakes in; `deploy-gate.sh` and the health check keep reading it unchanged.
- `write-latest-json.sh` still refuses, writing nothing: `GITHUB_SHA` unset (exit 2), no build in `DIST` (exit 2), the id absent from `dist/assets` as a quoted literal, including a bare-substring match (exit 1); it removes any previous `dist/updates/` first.
- `check-site.sh` still fails a `latest.json` that is not 200, is served as non-JSON (SPA fallback), is not a JSON object, or names another version.
- Test Summary's `needs` and `check` list change in the same edit that removes the job (AD-23); the new packaging test runs as a step of the existing `site-check-tests` job, which Test Summary already waits on.
- Every caller, test and doc that names `package-live-update.sh` names `write-latest-json.sh` instead, except `_bmad-output/` (the spine keeps the old path until the architect amends it).
- Scripts keep `scripts/check-site.sh` style: header with usage and exit codes, `set -euo pipefail`, runnable from any cwd.

**Never:**
- No change to the Flutter app (`ios/`, `lib/`, `pubspec.yaml`, `scripts/ios_build.sh`), `scripts/deploy-gate.sh`, `app/src/`, `supabase/`, or `_bmad-output/` other than this plan; `deferred-work.md` is not edited (bmad-loop closes DW-4/DW-8 from `closes_deferred`).
- No `app` id in `latest.json`, no `max-age` assertion (story 16).
- No new test.yml job; no secret anywhere in test.yml.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Write, happy | `dist/` with `assets/x.js` holding `"abc123"`, `GITHUB_SHA=abc123`, stale `dist/updates/old.txt` | `dist/updates/` holds only `latest.json` = exactly `{"version":"abc123"}` (jq `-c`/`-S` compare), exit 0 | — |
| Write, id mismatch | assets hold `"abc123"`, `GITHUB_SHA=deadbeef` | exit 1 naming deadbeef; no `dist/updates` | — |
| Write, substring only | assets hold `xabc123x`, `onabc123` | exit 1 | — |
| Write, no build | `DIST` missing | exit 2, "holds no build" | — |
| Write, no id | `GITHUB_SHA` unset | exit 2 naming GITHUB_SHA | — |
| Site, right | served build + `latest.json` of that id | pass | — |
| Site, stale version | `latest.json` version `stale-version` | fail: "latest.json version is 'stale-version', not the expected <id>" | — |
| Site, no latest.json | `updates/` removed (SPA answers HTML) | fail: "served as 'text/html" | — |

</intent-contract>

## Code Map

- Delete (git rm): `app/ios/` (21 tracked files; untracked leftovers none), `app/capacitor.config.ts`, `app/MIN_NATIVE_BUILD`, `scripts/check-native-build.sh`, `scripts/test-check-native-build.sh`, `scripts/ios-sim-check.sh`, `scripts/ocr-text.swift`, `scripts/dependabot-native-hold.sh`, `scripts/test-dependabot-native-hold.sh`.
- `app/package.json` + `app/package-lock.json` -- `@capacitor/core`, `@capacitor/ios` (deps), `@capacitor/cli` (devDeps) 8.6.0; remove with `npm uninstall` in `app/` (network available) so the lockfile prunes their transitive packages. No `node_modules` in this worktree yet: run `npm ci` first.
- `app/tsconfig.node.json:24` -- `include` drops `capacitor.config.ts`. `app/eslint.config.js:13` -- drop `'ios/**'`.
- `app/playwright.config.ts:48-49` -- webkit comment: "Not iOS Safari (test design TC-8); that is checked by hand."
- `app/tests/support/helpers/staff-session.ts:5,8,15` -- "Google or Apple" → "Google" (AD-7), "Google and Apple as the only" → "Google as the only", "by hand in the Simulator" → "by hand on the deployed site".
- `scripts/package-live-update.sh` → `git mv` to `scripts/write-latest-json.sh` and rewrite: drop the native check, MIN read, zip, checksum, `UPDATE_BASE_URL`, `url`; keep env `GITHUB_SHA`, `DIST`, the dist check, `rm -rf "$dist/updates"`, the quoted-literal id grep; write `jq -n --arg version "$id" '{version: $version}'`. Header: what it writes and who reads it (deploy.yml's daily gate, the health check; story 16 adds the app's update check). Final echo e.g. `latest.json written for <id>`.
- `scripts/test-write-latest-json.sh` (new) -- the matrix's Write rows against fake `dist/` dirs under `mktemp -d`, using `run`/`expect` helpers lifted from `scripts/test-check-native-build.sh` (exit code + message substring), "wrote nothing" checks, a final "All N ... cases" count. Needs only bash and jq; no git repo fixture (the script no longer reads git).
- `scripts/check-site.sh` -- drop `EXPECTED_MIN_NATIVE_BUILD`, the MIN file read and its exit-2 path, and the `url`/`checksum`/`min_native_build` checks and download; keep 200, `application/json`, object, `version`. Header and usage/exit-code lines follow; the latest.json comment names `write-latest-json.sh` and deploy-gate.
- `scripts/test-check-site.sh` -- call `write-latest-json.sh` (no `UPDATE_BASE_URL`); delete `bad-checksum`, `other-min`, `foreign-url` variants and cases; keep `bad-json` (gate uses it); header lines and final count (6 site + 5 gate = 11) follow.
- `scripts/ci-local.sh` -- Needs line: drop yq, zip, unzip (keep jq); Health Check Tests adds `scripts/test-write-latest-json.sh`; delete the Native Build Check step.
- `.github/workflows/test.yml` -- delete `native-build-check` job and its comment; remove it from `test-summary` `needs`, `NATIVE_BUILD` env and `check "Native Build Check"`; `site-check-tests` gains step "write-latest-json.sh writes and refuses as it should" (`scripts/test-write-latest-json.sh`) and its comment drops zip checksum/min_native_build/url and mentions the new test.
- `.github/workflows/deploy.yml` -- line 4-5 opening comment: every push deploys and writes a new `version`; only a change under `app/` will bring open clients the refresh page, once story 16 adds the app id (AD-24); keep "no path filter" reasoning. Build-job comment (~l.196) and step `Package live update` → `Write latest.json` running `../scripts/write-latest-json.sh`, no env. Health-check comment (~l.296): latest.json's version, not zip/min_native_build.
- `.github/dependabot.yml` -- delete the `native` group and its comment; ordering comment says vitest comes before the two catch-all groups.
- `.github/workflows/dependabot-auto-merge.yml` -- rewrite to My-Love's model (`/Users/sallvain/Projects/My-Love/.github/workflows/dependabot-auto-merge.yml`): header "every Dependabot PR, majors included; ruleset requires Test Summary and Dependency Review; a merge does not deploy, deploy.yml's daily run does"; no checkout, no fetch-metadata, no hold; keep `timeout-minutes: 5`, permissions, author guard.
- `.github/workflows/claude.yml:71` -- "Fermi is a web app: a Vite + React app in `app/` on Supabase (...)"; `:94-95` -- "This job has no device or browser, so ...".
- `.github/workflows/claude-code-review.yml:89-90` -- generated files: drop the `app/ios/` clause (keep generated Supabase types); `:136-139` -- delete the **Capacitor** bullet.
- `app/tests/README.md` -- l.14 Health check row adds `scripts/test-write-latest-json.sh` (and `scripts/write-latest-json.sh` as covered); delete l.15 Native build check row and l.75 CI row; l.20 tools: `jq` only; l.46 "Google or Apple" → "Google", "in the Simulator" → "on the deployed site"; l.74 Health Check Tests row: drop checksum/min_native_build/url-off-site, add `write-latest-json.sh` failing a case.
- `AGENTS.md` -- parent session, not the subagent (bmad-project-context refresh, see Design Notes).

## Tasks & Acceptance

**Execution:**
- [ ] Deletions in Code Map -- `git rm -r` -- R4.
- [ ] `app/package.json`, `app/package-lock.json` -- `npm ci` then `npm uninstall @capacitor/core @capacitor/ios @capacitor/cli` -- R4.
- [ ] `app/tsconfig.node.json`, `app/eslint.config.js`, `app/playwright.config.ts`, `app/tests/support/helpers/staff-session.ts` -- edits per Code Map.
- [ ] `scripts/write-latest-json.sh` (renamed), `scripts/test-write-latest-json.sh` (new, executable) -- matrix Write rows -- R2.
- [ ] `scripts/check-site.sh`, `scripts/test-check-site.sh`, `scripts/ci-local.sh` -- per Code Map.
- [ ] `.github/workflows/test.yml`, `deploy.yml`, `dependabot-auto-merge.yml`, `claude.yml`, `claude-code-review.yml`, `.github/dependabot.yml` -- per Code Map -- R11, R12, R13.
- [ ] `app/tests/README.md` -- per Code Map.

**Acceptance Criteria:**
- Given this branch, when `git ls-files | grep -E '^app/ios/|capacitor\.config|MIN_NATIVE_BUILD'` runs, then it prints nothing, and `jq '[.dependencies,.devDependencies] | add | keys[] | select(startswith("@capacitor"))' app/package.json` prints nothing, and `grep -c capacitor app/package-lock.json` is 0.
- Given this branch, when `grep -rniE 'capacitor|MIN_NATIVE_BUILD|native[- ](group|hold|build)' app scripts .github AGENTS.md --exclude-dir=node_modules --exclude-dir=dist | grep -v initiative-capacitor-supabase-port` runs, then it prints nothing; and `git grep -niE 'simulator|apple' -- app scripts .github AGENTS.md ':!scripts/ios_build.sh'` prints nothing.
- Given this branch, when `git grep -n package-live-update -- . ':(exclude)_bmad-output'` runs, then it prints nothing.
- Given a real build with `GITHUB_SHA=$(git rev-parse HEAD)`, when `scripts/write-latest-json.sh` runs, then `app/dist/updates/` holds only `latest.json` equal to `{"version":"<HEAD>"}`.
- Given test.yml, when read, then no job named Native Build Check exists, Test Summary's `needs` lists exactly lint, unit-tests, db-tests, function-tests, migration-check, site-check-tests, playwright, burn-in, and `site-check-tests` runs `scripts/test-write-latest-json.sh`.

## Implementation Notes

AGENTS.md refresh (bmad-project-context rules applied by hand, provenance line now "Verified 2026-11-07 against 10fef35"):
- Orientation: `rewrite` -- "Capacitor iOS app: a Vite + React shell" became "A web app: a Vite + React app"; the Capacitor claim is false.
- Policy, "A new Capacitor plugin joins the `native` group": `delete` -- the group and Capacitor are gone.
- Policy, "A native change raises `app/MIN_NATIVE_BUILD` and `CURRENT_PROJECT_VERSION`": `delete` -- the iOS project and MIN_NATIVE_BUILD no longer exist.
- Policy, "A pull request that changes a `native`-group package stays open": `delete` -- no native group, no hold.
- Merge-gate, no-secret and Playwright Utils lines: `retain`, still true (checked against test.yml and the specs).

Parent notes:
- A Sonnet subagent implemented the plan. The parent re-read the whole diff and re-ran every verification command.
- The plan gave the AGENTS.md refresh to the parent, but the subagent did it. The parent checked the result against the Design Notes ledger and it matches, so it was kept.
- Parent fixes after reading the diff:
  - deploy.yml's opening comment still said "a docs-only push redeploys the same build", which the ticket says to correct. It now says that every push writes a new `version` (its own commit id).
  - The health-check comment there is rewrapped.
  - write-latest-json.sh's header claimed a wrong `version` would refresh clients. AD-24 keys the refresh on the `app` id, so the header now names the health check and the daily gate instead.
- git records `write-latest-json.sh` as delete plus add, not as a rename, because most of the content changed.
- `npm uninstall` only removed lines from `app/package-lock.json` (930 removed, 0 added).

## Plan Change Log

## Review Triage Log

### 2026-11-07 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` "live update" (the removed iOS zip) still named the version file in deploy.yml's gate step, test.yml's site-check comment, the tests README's Health Check Tests row, and test-check-site.sh's header, comment and case names. Each now says `latest.json`. The cases' reason substrings are unchanged, and `scripts/deploy-gate.sh` is left as it is (plan Never). test-check-site.sh still passes 11/11.
  - `[low]` `[patch]` `scripts/check-site.sh:111` said the app's update check reads latest.json, but none exists yet. The comment now names deploy-gate.sh and says story 16's check will read it too.
  - `[low]` `[patch]` `scripts/test-write-latest-json.sh`'s header had no exit codes, which the plan's script-style rule requires. Exit 0 and 1 are now documented, and the test passes 10/10.

## Design Notes

The packaging refusals move into their own script rather than into `test-check-site.sh`, because that test builds and serves the real app with vite; the refusals need only a fake `dist/` and run in under a second. Running it as a step of `site-check-tests` keeps Test Summary's `needs` to one removal (AD-23) instead of a removal plus a new job.

AGENTS.md: `bmad-project-context` is conversational and requires the user's approval of each write; this run is unattended, so the parent applies the skill's refresh rules itself (re-verify paths, ledger entry per changed or removed line, provenance line with today's date and the verified SHA) and records the ledger in Implementation Notes, as story 13 did. Ledger: Orientation `rewrite` (Fermi is a web app; the Capacitor claim is false); three native policy lines `delete` (the iOS project, `MIN_NATIVE_BUILD`, the native group and its hold no longer exist, ground: the thing they govern is gone); the merge-gate, no-secret and Playwright Utils lines `retain`.

## Verification

**Commands:**
- `cd app && npm ci && npm run lint && npm run typecheck && npm run test:unit` -- expected: exit 0.
- `scripts/test-write-latest-json.sh` -- expected: exit 0, every case ok.
- `scripts/test-check-site.sh` -- expected: exit 0, "All 11 health check and deploy gate cases behaved as expected."
- `(cd app && GITHUB_SHA=$(git rev-parse HEAD) npm run build) && GITHUB_SHA=$(git rev-parse HEAD) scripts/write-latest-json.sh && ls app/dist/updates && cat app/dist/updates/latest.json` -- expected: only `latest.json`, `{"version":"<HEAD>"}`.
- `actionlint .github/workflows/*.yml && shellcheck scripts/write-latest-json.sh scripts/test-write-latest-json.sh scripts/check-site.sh scripts/test-check-site.sh scripts/ci-local.sh` -- expected: no output.
- The three grep ACs above -- expected: no output.
- `git diff --stat 10fef350835e983b5bf6ea3b5982a73302bb53cb -- ios lib pubspec.yaml scripts/ios_build.sh scripts/deploy-gate.sh app/src supabase` -- expected: empty.
- `git status --porcelain` -- expected: only intended files (`app/dist` ignored).

**Manual checks (if no CLI):**
- After merge (orchestrator): the next push's Deploy is green, `https://fermi-plus.sallvain.workers.dev/updates/latest.json` shows that push's commit id and no zip under `updates/`; a `daily_check` dispatch stops at "Check for a new commit"; Test Summary passes without a native-build job.

## Auto Run Result

Status: built

**Summary:** The iOS app and its native-build machinery are gone, and `app/` is now a web build only.
- **Removed:**
  - `app/ios/`, `app/capacitor.config.ts`, `app/MIN_NATIVE_BUILD` and the three `@capacitor/*` packages.
  - The native-build and Simulator scripts.
  - test.yml's Native Build Check job. It was taken out of Test Summary's `needs` in the same change (AD-23).
  - dependabot.yml's `native` group, and the native hold in `dependabot-auto-merge.yml`. Every Dependabot pull request now merges itself once both required checks pass.
- **Renamed:** `scripts/package-live-update.sh` is now `scripts/write-latest-json.sh`. It writes only `updates/latest.json` = `{"version": "<commit id>"}`, with no zip, checksum or `min_native_build`, and keeps its refusals: an id the build lacks, an unset `GITHUB_SHA`, and no build. Those refusals are tested by the new `scripts/test-write-latest-json.sh`, a step of the Health Check Tests job, which Test Summary already waits on.
- **Trimmed:** `check-site.sh` now checks only `latest.json`'s presence, JSON type and version.
- **Updated text:** the docs, the Claude workflow prompts, the Playwright comment, the staff-session wording (Google only; checked by hand on the deployed site) and AGENTS.md.
- **Deferred items:** `closes_deferred: [DW-4, DW-8]` is declared for bmad-loop.

**Files changed:**
- Deleted:
  - `app/ios/**` (21 files), `app/capacitor.config.ts`, `app/MIN_NATIVE_BUILD`.
  - `scripts/check-native-build.sh`, `test-check-native-build.sh`, `ios-sim-check.sh`, `ocr-text.swift`, `dependabot-native-hold.sh`, `test-dependabot-native-hold.sh`.
- `app/package.json`, `app/package-lock.json`: Capacitor packages and their transitive dependencies removed.
- `app/tsconfig.node.json`, `app/eslint.config.js`: no capacitor config, no `ios/**` ignore.
- `app/playwright.config.ts`, `app/tests/support/helpers/staff-session.ts`: iPhone-era wording corrected.
- `scripts/write-latest-json.sh` (renamed and rewritten), `scripts/test-write-latest-json.sh` (new, 10 cases).
- `scripts/check-site.sh`, `scripts/test-check-site.sh` (11 cases), `scripts/ci-local.sh`: follow the version-only latest.json.
- `.github/workflows/test.yml`: no native job; Health Check Tests runs the new test.
- `.github/workflows/deploy.yml`: comments corrected, including the opening comment (AD-24); the step is now `Write latest.json`.
- `.github/dependabot.yml`, `.github/workflows/dependabot-auto-merge.yml`: no native group or hold; auto-merge follows My-Love's model.
- `.github/workflows/claude.yml`, `claude-code-review.yml`: web app, no Capacitor check, no `app/ios/` generated files.
- `app/tests/README.md`: rows, tools and wording follow.
- `AGENTS.md`: refreshed; the web-app orientation is rewritten and the three native policy lines are deleted (ledger in Implementation Notes).

**Review (quick):** 3 findings: high 0, medium 0, low 3.
- Patched (3, all low): leftover "live update" wording, a check-site comment naming a reader that does not exist yet, and missing exit codes in the new test's header.
- Deferred: none. Rejected: none.

**Follow-up review recommended: false.** This is a first pass, and the patched counts are high 0, medium 0, low 3.

**Verification:**
- In `app/`, `npm run lint`, `typecheck` and `test:unit` (89/89) pass.
- `test-write-latest-json.sh` passes 10/10 and `test-check-site.sh` passes 11/11.
- A real build at HEAD 10fef350835e983b5bf6ea3b5982a73302bb53cb leaves `app/dist/updates/` holding only `latest.json`, `{"version":"10fef350835e983b5bf6ea3b5982a73302bb53cb"}`.
- `actionlint` is clean on every workflow, and `shellcheck` is clean on the touched scripts.
- The three grep acceptance checks print nothing, and `grep -c capacitor app/package-lock.json` = 0.
- Test Summary's `needs` lists exactly the eight remaining lanes.
- Nothing changed in the Flutter tree, `scripts/ios_build.sh`, `scripts/deploy-gate.sh`, `app/src` or `supabase/`.
- Not run: the Playwright suites (nothing under `app/src` changed) and the Database Tests lane (no `supabase/` change).

**Residual risks:**
- The ticket's post-merge checks wait for this branch to reach main; the orchestrator's verification covers them:
  - the next push's Deploy is green;
  - the live `updates/latest.json` shows that commit id and there is no zip under `updates/`;
  - a `daily_check` dispatch stops at "Check for a new commit";
  - Test Summary passes on GitHub without a native job.
- The first deploy after the merge leaves the old `bundle-*.zip` files out of `dist/`, and wrangler's assets-only deploy publishes only what `dist/` holds, so the zips stop being served. This is UNVERIFIED until that deploy runs.
- Open Dependabot pull requests (#89, #90) still run the hold workflow from the old base until they rebase. Neither touches a Capacitor package (they would have auto-merged before this change too).
- `scripts/deploy-gate.sh:29` still prints "The live update is ..."; the plan put that file out of scope.
- The spine's AD-24 and Structural Seed still name `scripts/package-live-update.sh` until the architect next amends them (ticket note).
