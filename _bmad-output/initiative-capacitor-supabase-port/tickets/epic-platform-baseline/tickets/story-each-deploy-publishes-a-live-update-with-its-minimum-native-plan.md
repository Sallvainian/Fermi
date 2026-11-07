---
title: 'Each deploy publishes a live update with its minimum native build'
type: feature
ticket: '9'
created: '2026-11-06'
status: blocked
baseline_revision: '1e5bc44ca005dd1f300c5b61fc5373630a48b9af'
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
deferred:
  - summary: >-
      A native change passes the check when it raises MIN_NATIVE_BUILD to a value at or below a build number that already shipped without that change.
    evidence: |-
      scripts/check-native-build.sh requires head MIN > base MIN and MIN <= every CURRENT_PROJECT_VERSION, as the ticket and this plan's intent define "raised". Once a web-only App Store build puts CURRENT_PROJECT_VERSION above MIN (e.g. Xcode 10, MIN 8), a native change raising MIN to 9 and leaving the pbxproj at 10 passes; installs on build 10, which lack the new native code, would then accept the bundle that needs it. AGENTS.md says a native change raises both numbers, which would close it (new MIN above the base's highest CURRENT_PROJECT_VERSION). Not reachable today (8/8, no App Store build until epic-app-store-release). Settling it changes AD-18's / the ticket's rule, which is the owner's or architect's call.
    location: >-
      scripts/check-native-build.sh:390
    severity: medium
operator_actions:
  - Once the loop's pull request for this branch runs test.yml on GitHub, confirm the Native Build Check and Health Check Tests jobs pass and Test Summary lists Native Build Check.
  - On a scratch branch from main, push a commit adding "@capacitor/app" to app/package.json dependencies without raising app/MIN_NATIVE_BUILD, open a pull request, and confirm Native Build Check and Test Summary fail naming @capacitor/app; then push a second commit setting app/MIN_NATIVE_BUILD to 9 with CURRENT_PROJECT_VERSION left at 8 and confirm it still fails naming the build numbers; close the pull request and delete the branch.
  - After this branch merges to main, open https://fermi-plus.sallvain.workers.dev/updates/latest.json and confirm version is that push's commit id and min_native_build is 8, and that the Deploy run's Build log shows "Live update <id> packaged" and its Health check passes.
  - With main's latest commit live, run Deploy by hand with "daily_check" ticked and confirm it stops at "Check for a new commit" with the notice "already live" and Migrate skipped; after a later commit lands on main without a deploy (e.g. an auto-merged Dependabot pull request), run it again with "daily_check" ticked, or wait for the 08:17 UTC schedule, and confirm it deploys.
blocked_at: "2026-11-06"
blocked_reason: "awaiting operator: Once the loop's pull request for this branch runs test.yml on GitHub, confirm the Native Build Check and Health Check Tests jobs pass and Test Summary lists Native Build Check.; On a scratch branch from main, push a commit adding \"@capacitor/app\" to app/package.json dependencies without raising app/MIN_NATIVE_BUILD, open a pull request, and confirm Native Build Check and Test Summary fail naming @capacitor/app; then push a second commit setting app/MIN_NATIVE_BUILD to 9 with CURRENT_PROJECT_VERSION left at 8 and confirm it still fails naming the build numbers; close the pull request and delete the branch.; After this branch merges to main, open https://fermi-plus.sallvain.workers.dev/updates/latest.json and confirm version is that push's commit id and min_native_build is 8, and that the Deploy run's Build log shows \"Live update <id> packaged\" and its Health check passes.; With main's latest commit live, run Deploy by hand with \"daily_check\" ticked and confirm it stops at \"Check for a new commit\" with the notice \"already live\" and Migrate skipped; after a later commit lands on main without a deploy (e.g. an auto-merged Dependabot pull request), run it again with \"daily_check\" ticked, or wait for the 08:17 UTC schedule, and confirm it deploys."
---

<intent-contract>

## Intent

**Problem:** A deploy ships the website but no live update for the iOS shell, so story 10's updater has nothing to download; nothing stops a pull request that changes native code without raising `app/MIN_NATIVE_BUILD` (AD-18); and a Dependabot pull request merged by story 13's auto-merge never reaches the site, because GitHub starts no workflow from its own token's merges (R1, R2, R12).

**Approach:** `scripts/package-live-update.sh` zips the build into `dist/updates/` with a `latest.json` (`version`, `url`, `checksum`, `min_native_build`) and refuses a mismatched build id or a `MIN_NATIVE_BUILD` above the Xcode build number; `scripts/check-native-build.sh` fails a change that touches native files without raising `MIN_NATIVE_BUILD`, run as a new `test.yml` job that Test Summary waits on; `deploy.yml` packages after the build, its health check asserts `latest.json`, and a daily schedule deploys only when the live `latest.json` is behind main.

## Boundaries & Constraints

**Always:**
- The native package list is the `native` group's `patterns` of the npm `/app` entry in `.github/dependabot.yml`, read with `yq` exactly as `scripts/dependabot-native-hold.sh` does; the check takes the union of the base's and the head's patterns, so a pull request can neither drop a pattern to escape nor add a plugin under a new pattern unchecked.
- A native change = any changed path under `app/ios/`, any `app/capacitor.config.*`, or a native-pattern package added, removed or changed in `dependencies` or `devDependencies` of `app/package.json`. "Raised" = head `MIN_NATIVE_BUILD` > base `MIN_NATIVE_BUILD`, both integers.
- `MIN_NATIVE_BUILD` must be ≤ every `CURRENT_PROJECT_VERSION` in `app/ios/App/App.xcodeproj/project.pbxproj` (Debug and Release); no entry or a non-integer value fails.
- `test.yml` stays secret-free (AD-23); the new job is in Test Summary's `needs` and `check` list in the same change.
- The daily gate deploys on anything other than an exact `version` match (missing file, SPA HTML, bad JSON, network error), and runs no npm code and reads no secret.
- Scripts follow `scripts/check-site.sh` style: header comment with usage and exit codes, `set -euo pipefail`, run from any cwd.

**Never:**
- No updater code, plugin, `@capgo/*` package or App Store message (story 10); no native file change, so `MIN_NATIVE_BUILD` and the pbxproj stay at 8.
- No hand-kept second list of native packages; no change to `dependabot-auto-merge.yml` or `dependabot-native-hold.sh`.
- No secret or Production environment in the daily gate or in `test.yml`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Package, happy | `dist/` built with `GITHUB_SHA=X`, MIN 8, Xcode 8/8 | `dist/updates/bundle-X.zip` (index.html at zip root, no `updates/`), `latest.json` `{"version":"X","url":"<base>/updates/bundle-X.zip","checksum":"<sha256 hex of zip>","min_native_build":8}`, exit 0 | — |
| Package, id mismatch | `dist/assets` lacks `"X"` as a quoted literal | nothing written, exit 1 naming X | — |
| Package, MIN above Xcode | MIN 9, Xcode 8 | nothing written, exit 1 naming both numbers | — |
| Check, no native change | only `app/src/` changed | exit 0 | — |
| Check, plugin without raise | `@capacitor/app` added to `app/package.json`, MIN 8→8 | exit 1 naming the package and MIN_NATIVE_BUILD | — |
| Check, plugin with raise | same, MIN 8→9, Xcode 9/9 | exit 0 | — |
| Check, ios or config without raise | a file under `app/ios/` or `app/capacitor.config.ts` changed, MIN same | exit 1 naming the path | — |
| Check, new pattern in head | head adds pattern `capacitor-foo` and package `capacitor-foo`, MIN same | exit 1 | — |
| Check, non-native bump | `react` version changed | exit 0 | — |
| Check, MIN above Xcode | MIN 9, Debug 9, Release 8 (or no base given) | exit 1 naming the build numbers | — |
| Check, bad input | MIN not an integer, no pbxproj entries, unreadable dependabot.yml | exit 2 with a message | callers treat non-zero as failure |
| Health, live update | `/updates/latest.json` | passes only when 200 `application/json`, `version` = expected id, `url` starts with the base URL and its download's sha256 = `checksum`, `min_native_build` = `app/MIN_NATIVE_BUILD` | each failure names its reason |
| Daily, current | schedule (or dispatch with `daily_check`), live `version` = `github.sha` | gate job prints "already live" and outputs `deploy=false`; Migrate and every later job skipped | — |
| Daily, behind | live `version` ≠ `github.sha`, or file missing/invalid | `deploy=true`; full deploy runs | — |

</intent-contract>

## Code Map

- `.github/workflows/deploy.yml` -- jobs migrate → hosted-config → functions → build → deploy → health-check. Later jobs carry `if: github.ref == 'refs/heads/main'` with no status function, so a skipped `migrate` skips them (how `health_check_only` works today). Health-check's `if` runs on deploy success or a health-check-only dispatch, so a daily skip skips it. Build job: `working-directory: app`, no secrets; `GITHUB_SHA` is what `vite.config.ts` bakes in as `__BUILD_ID__` and the `fermi-build` meta.
- `.github/workflows/test.yml` -- `test-summary` job's `needs` and `check "<label>" "$X"` lines; `site-check-tests` job is the model for a script-test job. `ubuntu-latest` has `yq` (mikefarah v4), `jq`, `zip`, `sha256sum`.
- `scripts/dependabot-native-hold.sh` -- the `yq` expression that reads the native patterns and the bash glob match (`[[ "$name" == $pattern ]]`); copy that logic, do not call the script (its exit codes mean something else).
- `scripts/check-site.sh` -- `fetch` sets `$status`/`$ctype` into `$body_file`; add the live-update checks at the end of `check_once`, before `return 0`. Header lists each assertion; extend it.
- `scripts/test-check-site.sh` -- builds into `$work/good` with `vite build --outDir`, serves with `vite preview` (answers a missing file with the app's HTML, like Cloudflare), `expect_pass`/`expect_fail <case> <dir> <id> <reason substring>`; the final message counts cases.
- `wrangler.jsonc` -- serves `./app/dist`, SPA fallback; `dist/updates/` is served with no config change.
- `app/MIN_NATIVE_BUILD` (`8`), `app/ios/App/App.xcodeproj/project.pbxproj:303,326` (`CURRENT_PROJECT_VERSION = 8;`).
- Model, read only: `/Users/sallvain/Projects/My-Love/scripts/package-live-update.sh` (id check as quoted literal, zip from inside dist excluding `updates/*`, sha256 via `sha256sum` or `shasum -a 256`), and its deploy.yml health check of `updates/latest.json` as `application/json`.
- `scripts/ci-local.sh`, `app/tests/README.md` (lane table row "Health check tests", CI job table) -- add the new lane.
- Repo variable `SITE_URL` = `https://fermi-plus.sallvain.workers.dev/` (trailing slash); readable without an environment.

## Tasks & Acceptance

**Execution:**
- [ ] `scripts/check-native-build.sh` -- `check-native-build.sh [<base-rev> [<head-rev>]]` (head default `HEAD`), run from the repo to check; reads every file with `git show <rev>:<path>`. Without a base: only the MIN ≤ Xcode check on head. With a base: native-change detection between the two revs (`git diff --name-only`, `jq` over both `package.json`s' dependencies+devDependencies) then the raise rule, then the Xcode check. Prints what it found; exit 0 pass, 1 rule broken, 2 bad input.
- [ ] `scripts/package-live-update.sh` -- as the matrix; env `GITHUB_SHA` (required), `DIST` (default `<repo>/app/dist`), `UPDATE_BASE_URL` (default `https://fermi-plus.sallvain.workers.dev`, trailing slash stripped). Runs `check-native-build.sh` (no base, from the script's own directory) before writing anything; `rm -rf "$DIST/updates"` first; `min_native_build` written as a JSON number.
- [ ] `scripts/test-check-native-build.sh` -- builds a throwaway git repo in a temp dir with fixture `.github/dependabot.yml`, `app/package.json`, `app/MIN_NATIVE_BUILD`, `app/capacitor.config.ts`, `app/ios/App/App.xcodeproj/project.pbxproj`, copies `check-native-build.sh` and `package-live-update.sh` into its `scripts/`, and asserts every Check and Package row of the matrix (exit code and a message substring); for packaging, a fake `dist/` (index.html + `assets/x.js` holding `"<id>"`), then unzips and re-hashes to prove the checksum and zip root. Counts cases like `test-check-site.sh`.
- [ ] `scripts/check-site.sh` -- after the deep-path check: `GET ${base}updates/latest.json` must be 200 with `application/json` (else reason says the SPA fallback answered); `jq` reads `version`, `url`, `checksum`, `min_native_build`; each must match as in the matrix (expected min from `app/MIN_NATIVE_BUILD` beside the script's repo, overridable by env `EXPECTED_MIN_NATIVE_BUILD`); download `url`, compare sha256. Update the header.
- [ ] `scripts/test-check-site.sh` -- package the good build with `DIST="$work/good" GITHUB_SHA="$build_id" UPDATE_BASE_URL="http://localhost:$port"`; the existing variants copy it; add fail cases: no `updates/` (SPA answers), stale `version`, checksum not matching the zip, `min_native_build` differing. Update the case count and header.
- [ ] `.github/workflows/test.yml` -- job `native-build-check`, name `Native Build Check`, checkout with `fetch-depth: 0`; step running `scripts/test-check-native-build.sh`; step running the real check: pull_request → `scripts/check-native-build.sh HEAD^1 HEAD` (the merge commit's parents: base tip and the merged result), push → `"$BEFORE" HEAD` with `BEFORE` from `github.event.before` via `env:`, falling back to no base when it is all zeros or not in history, schedule/dispatch → no base. Add to `test-summary` `needs`, env and `check "Native Build Check"`; header comment.
- [ ] `.github/workflows/deploy.yml` -- `schedule: cron '17 8 * * *'` with a comment (story 13's auto-merges start no workflow); dispatch input `daily_check` (boolean: behave as the daily trigger). New first job `gate` (name `Check for a new commit`, no environment) with output `deploy`: on `schedule` or `inputs.daily_check`, curl `${SITE_URL}updates/latest.json`, `deploy=false` only when `.version` equals `github.sha`, with a notice; otherwise `deploy=true`. `migrate` needs `gate` and adds `&& needs.gate.outputs.deploy == 'true'`. Build job: step `Package live update` after `Build application` (`run: ../scripts/package-live-update.sh`, `UPDATE_BASE_URL: ${{ vars.SITE_URL }}`). Update the header comments of the trigger and jobs.
- [ ] `scripts/ci-local.sh`, `app/tests/README.md` -- the Native Build Check lane (lane table row, CI job table row), and the new Health Check Tests failure cases.

**Acceptance Criteria:**
- Given this branch, when `scripts/test-check-native-build.sh` and `scripts/test-check-site.sh` run, then both exit 0 and every listed case reports `ok`.
- Given this branch, when `scripts/check-native-build.sh <baseline_revision> HEAD` runs, then it exits 0 (no native file changed); and given a scratch commit on top that adds `"@capacitor/app": "8.6.0"` to `app/package.json` dependencies, it exits 1 naming `@capacitor/app` and MIN_NATIVE_BUILD; raising `app/MIN_NATIVE_BUILD` to 9 with both pbxproj numbers at 9 makes it exit 0; MIN 9 with the pbxproj at 8 makes it exit 1. Scratch commits are discarded after.
- Given `npm run build` in `app/` with `GITHUB_SHA=$(git rev-parse HEAD)`, when `scripts/package-live-update.sh` runs with the same `GITHUB_SHA`, then `app/dist/updates/latest.json` shows that id, `min_native_build` 8 and a checksum equal to `sha256sum` of the zip it names; with `GITHUB_SHA=deadbeef` it exits 1 and writes nothing.
- Given both workflows, when `actionlint` runs, then it reports nothing; `Native Build Check` is in Test Summary's `needs`; deploy.yml's `migrate` waits on `gate` and is skipped when `gate` outputs `deploy=false`.
- Given the gate step's script extracted and run against a local server serving a `latest.json` whose version equals the given sha, then it outputs `deploy=false`; with a different version, a 404, or HTML, it outputs `deploy=true`.

## Implementation Notes

- Implemented by a Sonnet subagent from this plan; the parent re-read the whole diff and re-ran every verification command.
- `package-live-update.sh` reads `min_native_build` from `HEAD:app/MIN_NATIVE_BUILD`, the revision `check-native-build.sh` judges, not the working tree.
- Matrix audit (parent): the Daily rows had no test that ran, only an extracted-step run by the subagent. The gate's logic moved from inline workflow shell into `scripts/deploy-gate.sh` (the gate job now checks out the repo), and `scripts/test-check-site.sh` runs it against the served builds: live commit → `deploy=false`; main ahead, no live update, no server → `deploy=true`. The Health row's url-prefix rule also had no case; one was added. The `min_native_build` fail case no longer hard-codes `9`.
- Verification run by the parent: `test-check-native-build.sh` 31/31; `test-check-site.sh` 13/13; lint and typecheck exit 0; `check-native-build.sh` exits 0 with no base and against the baseline; a real build packaged at the HEAD id with `min_native_build` 8 and a checksum equal to `sha256sum` of the zip; `GITHUB_SHA=deadbeef` exits 1; actionlint and shellcheck clean.
- Not run here: the new jobs on GitHub (first real run is the loop's pull request and the next push to main).

## Plan Change Log

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 7 findings — high 0, medium 1, low 6, false 0, maybe-false 0
- findings:
  - `low` `patch` the gate's 404 and bad-JSON paths are untested, and without curl --fail a non-200 JSON body naming the commit would skip the deploy — added `--fail` to scripts/deploy-gate.sh (a non-200 now takes the same failed-curl branch as the no-server case) and a "latest.json that is not JSON" case to scripts/test-check-site.sh; ran, deploy=true.
  - `low` `patch` app/tests/README.md's local command `check-native-build.sh origin/main HEAD` fails a branch that is behind a main that raised MIN — now uses `$(git merge-base origin/main HEAD)`, as ci-local.sh does.
  - `low` `patch` test.yml's site-check-tests header omits the url-off-site and deploy-gate cases and overruns the wrap width — comment rewritten and rewrapped.
  - `low` `patch` ci-local.sh's Needs line and the tests README Setup omit yq, jq, zip and unzip — added to both.
  - `low` `patch` check-site.sh's min_native_build message names app/MIN_NATIVE_BUILD even when EXPECTED_MIN_NATIVE_BUILD supplied the value — message now says "not the expected N".
  - `low` `patch` package-live-update.sh removed dist/updates only after the checks, so a refused run left the previous latest.json and zip in dist — removal moved before the checks; a GITHUB_SHA=deadbeef run after a good one now exits 1 with dist/updates gone (run).
  - `medium` `defer` the check accepts a native change that raises MIN to a value at or below an already-shipped CURRENT_PROJECT_VERSION, so older-native installs on a higher build would take the bundle — real once a web-only App Store build puts Xcode above MIN; the code matches the ticket's and the intent's definition of "raised", so closing it changes AD-18's rule (owner/architect decision); deferred, not reachable before epic-app-store-release.

## Design Notes

The pull-request check compares the merge commit with its first parent, so it judges exactly what merging would change against today's main: a pull request that branched before main raised `MIN_NATIVE_BUILD` must raise it past main's value. A Dependabot native-group pull request fails this check by design; it is held open anyway, and the owner raises `MIN_NATIVE_BUILD` and `CURRENT_PROJECT_VERSION` on it before merging (AGENTS.md).

The health check verifies the served `latest.json` against the push, the checked-in `MIN_NATIVE_BUILD` and the zip itself, so the ticket's own verification ("latest.json shows that push's commit id, a url whose zip matches the checksum, and min_native_build equal to the checked-in value") runs on every deploy. The daily gate fails open: an extra deploy of an unchanged commit is harmless (migrations and config pushes are idempotent), a missed one leaves a merged update unshipped.

## Verification

**Commands:**
- `scripts/test-check-native-build.sh` -- expected: exit 0, every case ok.
- `cd app && npm ci && npm run lint && npm run typecheck && cd .. && scripts/test-check-site.sh` -- expected: exit 0, every case ok.
- `scripts/check-native-build.sh <baseline_revision> HEAD` -- expected: exit 0.
- `scripts/check-native-build.sh` -- expected: exit 0 (8 ≤ 8, 8).
- `(cd app && GITHUB_SHA=$(git rev-parse HEAD) npm run build) && GITHUB_SHA=$(git rev-parse HEAD) scripts/package-live-update.sh && cat app/dist/updates/latest.json` -- expected: the HEAD id, min_native_build 8, checksum = `sha256sum app/dist/updates/bundle-*.zip`.
- `actionlint .github/workflows/test.yml .github/workflows/deploy.yml && shellcheck scripts/check-native-build.sh scripts/package-live-update.sh scripts/test-check-native-build.sh scripts/check-site.sh scripts/test-check-site.sh` -- expected: no output.
- `git status --porcelain` -- expected: only intended source files (`app/dist` is ignored).

## Auto Run Result

Status: awaiting-operator

**Summary:** Each deploy now publishes a live update for the iOS shell. `scripts/package-live-update.sh` zips the build into `dist/updates/` with a `latest.json` (`version` = the commit id baked into the build, `url`, sha256 `checksum`, `min_native_build` from `app/MIN_NATIVE_BUILD`). It refuses a build whose id does not match, and a `MIN_NATIVE_BUILD` above the Xcode build number. `scripts/check-native-build.sh`, run as the new test.yml job **Native Build Check** that Test Summary waits on, fails a pull request that changes `app/ios/`, `app/capacitor.config.*` or a native-group package without raising `MIN_NATIVE_BUILD`, reading the package list from dependabot.yml's native group. The health check now verifies the served `latest.json` against the push, the checked-in number and the zip itself. deploy.yml also runs daily at 08:17 UTC and stops at its first job when the live `latest.json` already names main's latest commit.

**Files changed:**
- `scripts/package-live-update.sh` (new): builds the live-update zip and `latest.json`.
- `scripts/check-native-build.sh` (new): the native-change and build-number rules.
- `scripts/deploy-gate.sh` (new): the daily run's deploy-or-skip decision.
- `scripts/test-check-native-build.sh` (new): 31 cases against throwaway git repos.
- `scripts/check-site.sh`: asserts `updates/latest.json` (JSON, version, min_native_build, url on the site, zip checksum).
- `scripts/test-check-site.sh`: packages the test build; 14 cases, including 5 for the deploy gate.
- `.github/workflows/test.yml`: Native Build Check job, in Test Summary's `needs` and checks.
- `.github/workflows/deploy.yml`: daily schedule, `daily_check` input, `gate` job before Migrate, Package live update step.
- `scripts/ci-local.sh`, `app/tests/README.md`: the new lane, cases and tools.

**Review (quick):** 7 findings: high 0, medium 1, low 6.
- Patched (6, all low): the gate now uses `curl --fail`, with a bad-JSON test; the README's local command is corrected; the test.yml comment is completed; the tool lists are completed; the check-site message is fixed; a refused package now removes stale output.
- Deferred (1, medium): a native change can pass by raising MIN only up to a build number that already shipped without it. This is a gap in the ticket's rule, not reachable before epic-app-store-release; see `deferred`.
- Rejected: none.

**Follow-up review recommended: false.** First pass; patched counts are high 0, medium 0, low 6.

**Verification:** `test-check-native-build.sh` 31/31; `test-check-site.sh` 14/14; `npm run lint` and `typecheck` exit 0; `check-native-build.sh` exits 0 with no base and against the baseline; a real build packaged at the HEAD id with `min_native_build` 8 and a checksum equal to `sha256sum` of the zip; `GITHUB_SHA=deadbeef` exits 1 and leaves no `dist/updates`; actionlint on every workflow and shellcheck on every touched script are clean. The implementing subagent ran AC2's scratch commits (plugin without raise → exit 1 naming `@capacitor/app`; raise to 9/9 → 0; MIN 9 with Xcode 8 → 1) in a temporary worktree it then removed.

**Residual risks:**
- The new jobs have not run on GitHub; the first runs are the loop's pull request and the next push to main (operator_actions).
- A Dependabot native-group pull request fails Native Build Check by design until MIN_NATIVE_BUILD is raised on it.
- The deferred MIN-versus-shipped-build gap above.
- Scheduled workflows stop after 60 days without a commit to the repo; the daily deploy would stop with them.
