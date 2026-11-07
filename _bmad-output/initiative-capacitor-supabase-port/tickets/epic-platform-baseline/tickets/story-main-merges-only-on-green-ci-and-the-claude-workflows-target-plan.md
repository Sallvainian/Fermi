---
title: 'Main merges only on green CI, and the Claude workflows target the new app'
type: chore
ticket: '13'
created: '2026-11-06'
status: done
baseline_revision: '8244068a72a0fff51193449bdc53a9adffe9e2ef'
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
---

<intent-contract>

## Intent

**Problem:** The Main ruleset targets every branch (`~ALL`, which blocks Dependabot's own branches) and requires no check, so a pull request merges with red tests; there is no dependency review and no Dependabot auto-merge; `claude.yml` and `claude-code-review.yml` still install Flutter and prompt for Flutter/Firebase checks; README's CI/CD list still describes Gemini triage; there is no AGENTS.md carrying the merge-gate, native-group and Playwright Utils rules later builds must follow.

**Approach:** Add `dependency-review.yml` and `dependabot-auto-merge.yml` on My-Love's model, the latter holding any pull request that changes a package matched by `dependabot.yml`'s `native` group patterns; retarget both Claude workflows to `app/` and `supabase/`; drop README's last CI/CD item; write AGENTS.md's managed block per `bmad-project-context`'s template; then point the Main ruleset at `~DEFAULT_BRANCH` with exactly two required checks, `Test Summary` and `Dependency Review`.

## Boundaries & Constraints

**Always:** Native-hold matching uses the `native` group's `patterns` from the `/app` npm entry of `.github/dependabot.yml`, read at run time, against every name in fetch-metadata's `dependency-names` — never the PR's `dependency-group`. Fail closed: no patterns found or an empty name list fails the job and enables no merge. Keep the ruleset's existing deletion, non_fast_forward and pull_request rules and its bypass actors. Save the ruleset JSON before changing it. Claude workflows install npm packages before the agent runs (the review sandbox has no network).

**Never:** No change to `test.yml`, `deploy.yml`, `dependabot.yml`, or anything under `app/src`, `supabase/`, or the Flutter tree. No path filter on `dependency-review.yml` or on the Claude workflows. No deploy trigger from auto-merge (story 9's daily run deploys). No repo secret beyond the `GITHUB_TOKEN` in the new workflows. Never mark the ticket done.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Non-native npm group | names `react,react-dom` | auto-merge enabled | — |
| vitest group, majors | `vitest,@vitest/coverage-v8` | auto-merge enabled | — |
| Actions group | `supabase/setup-cli` | auto-merge enabled | — |
| Native group | `@capacitor/core,@capacitor/ios,@capacitor/cli` | held: notice + job summary, auto-merge disabled if on | — |
| Ungrouped security update | `@capgo/capacitor-updater` | held | — |
| Mixed list, spaces | `react, @capacitor/ios` | held | — |
| Empty names | `` | job fails, no merge | exit 2 |
| No native patterns | config without `groups.native.patterns` | job fails, no merge | exit 2 |
| Non-Dependabot PR | author is a human | job skipped | — |

</intent-contract>

## Code Map

- `.github/dependabot.yml` -- read-only; `native` group under the `package-ecosystem: npm`, `directory: /app` entry (`yq` path `.updates[] | select(.["package-ecosystem"] == "npm" and .directory == "/app") | .groups.native.patterns[]`). `yq` v4 is on ubuntu-latest and locally (`/opt/homebrew/bin/yq`).
- `/Users/sallvain/Projects/My-Love/.github/workflows/dependency-review.yml` -- model: `actions/dependency-review-action@v5`, `fail-on-severity: moderate`, `comment-summary-in-pr: always`, job name `Dependency Review`, permissions contents read / pull-requests write. Drop its `branches:` filter.
- `/Users/sallvain/Projects/My-Love/.github/workflows/dependabot-auto-merge.yml` -- model: `on: pull_request`, job id `dependabot` guarded by `user.login == 'dependabot[bot]'`, `gh pr merge --auto --squash`, fallback immediate squash when every check but `dependabot` is green (proven: My-Love runs on 2026-11-02 succeeded with `pull_request` + `permissions`).
- `dependabot/fetch-metadata` v3.1.0 = `25dd0e34f4fe68f24cc83900b1fe3fe149efef98`; output `dependency-names` (comma-separated); default verification rejects non-Dependabot commits.
- `.github/workflows/claude.yml:37-90` -- Flutter steps (lines 41-48) and Flutter/Firebase prompt (lines 67-90) to replace; keep triggers, permissions, action inputs.
- `.github/workflows/claude-code-review.yml:35-46,90-95,124-139,200-210` -- Flutter steps, generated-files list, Firebase/Flutter/go_router checks, `flutter` run line, FORBIDDEN style line, `allowedTools`; keep the filter gate, output format, sticky-comment and bot rules verbatim.
- `/Users/sallvain/Projects/My-Love/.github/workflows/claude.yml`, `claude-code-review.yml` -- shape of the npm setup step and prompt wording to follow.
- `app/package.json` -- scripts `lint`, `typecheck`, `test:unit`; `app/.node-version` (24); `app/package-lock.json`. Root has no package.json, so commands run as `npm --prefix app run <script>`.
- `scripts/check-migrations.ts` -- run from root as `node scripts/check-migrations.ts`. pgTAP, Playwright and `deno test` need a local stack, browsers or Deno, none present in the Claude jobs.
- `README.md:425-433` -- `### GitHub Actions Workflows`, its intro line, and its sole item (Code Review Automation, mentions Gemini).
- `.claude/skills/bmad-project-context/references/template.md`, `best-practices.md` -- AGENTS.md block shape and markers; no AGENTS.md exists (setup intent); `.gitignore` no longer ignores it (43c3519); `CLAUDE.md` is gitignored.
- `app/tests/support/merged-fixtures.ts`, `app/tests/README.md` -- Playwright Utils rule and its `// playwright-utils deviation: <reason>` comment form.
- `app/MIN_NATIVE_BUILD` (8), `app/ios/App/App.xcodeproj/project.pbxproj` `CURRENT_PROJECT_VERSION = 8` (Debug and Release).
- Ruleset `Main`, id 7391054, `repos/Sallvainian/Fermi/rulesets/7391054`: today `include: ["~ALL"]`, rules deletion, non_fast_forward, pull_request; bypass RepositoryRole 5 always; repo `allow_auto_merge: true`.

## Tasks & Acceptance

**Execution:**
- [ ] `.github/workflows/dependency-review.yml` -- add on My-Love's model, `on: pull_request` with no filter, concurrency per ref -- the second required check.
- [ ] `scripts/dependabot-native-hold.sh` -- add: args `<dependabot.yml> <names>`; trims names, glob-matches each against the native patterns; prints matches; exit 0 none, 3 native, 2 bad input -- one testable home for the AD-18 hold.
- [ ] `scripts/test-dependabot-native-hold.sh` -- add: runs every I/O matrix row except the PR-author row against the real `dependabot.yml` and a temp config without patterns; prints a pass line, exits non-zero on any mismatch -- proves the hold.
- [ ] `.github/workflows/dependabot-auto-merge.yml` -- add: job `dependabot`, contents/pull-requests write, fetch-metadata (pinned SHA), checkout of the base SHA, run the hold script; on 3 write a `::notice::` and step summary naming the packages and "merge by hand after raising MIN_NATIVE_BUILD", run `gh pr merge --disable-auto` tolerating "not enabled", exit 0; on 0 My-Love's merge logic; otherwise fail -- R12 self-merge.
- [ ] `.github/workflows/claude.yml` -- replace Flutter setup with setup-node (`node-version-file: app/.node-version`, npm cache on `app/package-lock.json`) and `npm ci` in `app`; rewrite the prompt for the Capacitor/Supabase stack: read `AGENTS.md`, run `npm --prefix app run lint|typecheck|test:unit` and `node scripts/check-migrations.ts` as touched, say pgTAP/Playwright/deno are not runnable here, the Flutter tree is being retired; no `01_ci` -- R13.
- [ ] `.github/workflows/claude-code-review.yml` -- same setup swap; replace Firebase/Flutter/Routing checks with Supabase (RLS, grants, expand-only migrations, edge-function auth), React/State, Capacitor (`Capacitor.isPluginAvailable` guard, native change without raising `MIN_NATIVE_BUILD`), Supabase client outside `app/src/api/`; run line and `allowedTools` name the npm/node commands; generated-files and FORBIDDEN lines drop Dart -- R13.
- [ ] `README.md` -- remove the `### GitHub Actions Workflows` subsection (heading, intro line, item); keep `## CI/CD Pipeline` and `### Deployment Commands`.
- [ ] `AGENTS.md` -- create with the managed block per the template (provenance: today, verified HEAD SHA): Orientation; Policy lines for the merge gate (blocking check = `test.yml` job in `Test Summary`'s `needs`, same change), `test.yml` reads no secret, a new Capacitor plugin joins the `native` group in the same change, a native change raises both `app/MIN_NATIVE_BUILD` and `CURRENT_PROJECT_VERSION`, a native-group PR stays open until the next planned App Store build unless it fixes a security advisory; Conventions line for Playwright Utils fixtures with the deviation comment. Only the ticket's rules; no interview, no other content.
- [ ] Main ruleset (`gh api`) -- after the files above pass verification: save current JSON to the scratchpad, PUT with `~DEFAULT_BRANCH`, existing rules and bypass kept, plus `required_status_checks` `[Test Summary, Dependency Review]`, `strict_required_status_checks_policy: false`.

**Acceptance Criteria:**
- Given the ruleset change, when `gh api repos/Sallvainian/Fermi/rulesets/7391054` runs, then `conditions.ref_name.include` is `["~DEFAULT_BRANCH"]` and the required contexts are exactly `Test Summary` and `Dependency Review`.
- Given every new or changed workflow, when actionlint runs, then it reports nothing, and no file under `.github/workflows/claude*.yml` mentions `flutter`, `dart`, `pub get` or `01_ci`.
- Given AGENTS.md, when read, then it states the Playwright Utils, merge-gate, no-secret, native-group, MIN_NATIVE_BUILD-plus-build-number and open-until-App-Store-build rules inside `<!-- bmad:context -->` markers.
- Given README.md, when searched, then it names no removed workflow and no Gemini triage.

## Implementation Notes

- Implemented by the full-route subagent: the two new workflows, the hold script and its test, both Claude workflows, README, AGENTS.md, and the ruleset PUT (previous JSON saved in the session scratchpad as `ruleset-main-before.json`). Live ruleset now: `~DEFAULT_BRANCH`, rules deletion, non_fast_forward, pull_request, required_status_checks (`Test Summary`, `Dependency Review`, strict off); bypass actor unchanged.
- The Claude prompts call the Flutter tree "the legacy mobile tree outside `app/` and `supabase/`", because the plan's own grep forbids the word in those files.
- AGENTS.md written in the `bmad-project-context` template's shape with setup intent but without its interview and approval step, since this run is unattended; it holds only the ticket's rules. `CLAUDE.md` is gitignored, so Claude Code reaches AGENTS.md through the workflow prompts and the BMad skills, not an import.
- Parent fixes after reading the diff: dropped a false claim in `claude.yml` that the build needs Supabase environment variables (`app/vite.config.ts` reads only `GITHUB_SHA`); replaced guessing at `gh pr merge --disable-auto`'s error text with a `gh pr view --json autoMergeRequest` check; added `timeout-minutes: 5`; added a test case asserting the workflow's Dependabot-author guard, so every matrix row has a check.
- The first Dependabot pull request after this reaches main runs the hold script from main, so pull requests opened before the merge fail that (non-required) job until Dependabot rebases them.

## Plan Change Log

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 1, false 2, maybe-false 0
- findings:
  - `[false]` `[reject]` `scripts/dependabot-native-hold.sh` reads only the first line of a newline-separated name list, so later packages would go unchecked — the only caller passes fetch-metadata's `dependency-names`, a single `", "`-joined line, which the script splits and trims; the reviewer agrees it is unreachable today.
  - `[false]` `[reject]` AGENTS.md's Orientation is two sentences where the template asks for three or four — no agent behavior changes: it already says what the repo is, the stack, and where planning and test docs live, which is what the template's Orientation asks for.
  - `[low]` `[patch]` `claude-code-review.yml`'s Capacitor check names only `app/MIN_NATIVE_BUILD`, while AGENTS.md requires raising it and `CURRENT_PROJECT_VERSION` together — the check line now names both; actionlint clean.

## Design Notes

Ruleset strict mode off: Monday brings several Dependabot pull requests at once (npm groups and the actions group). With "require branches to be up to date" on, the second one to go green is behind main and Dependabot rebases only on conflict, so it waits for a hand "Update branch" and does not merge itself. Each pull request's own checks still gate it; a rare combined break shows up in the next pull request's run or the Sunday scheduled run. GitHub's default for a new required check is off; My-Love has it on.

Hold step shape:

```bash
set +e; scripts/dependabot-native-hold.sh .github/dependabot.yml "$NAMES"; rc=$?; set -e
case $rc in 0) ;; 3) echo "::notice::..."; gh pr merge --disable-auto "$PR_URL" || true; exit 0 ;; *) exit 1 ;; esac
```

## Verification

**Commands:**
- `scripts/test-dependabot-native-hold.sh` -- expected: every case passes, exit 0
- `actionlint .github/workflows/*.yml` -- expected: no output
- `grep -n -i -E 'flutter|dart|pub get|01_ci' .github/workflows/claude.yml .github/workflows/claude-code-review.yml` -- expected: no output
- `grep -n -E '01_ci|02_deploy|03_windows|04_macos|05_Ignore|Gemini' README.md` -- expected: no output
- `cd app && npm ci && cd .. && npm --prefix app run lint && npm --prefix app run typecheck && npm --prefix app run test:unit && node scripts/check-migrations.ts` -- expected: exit 0 (the Claude prompts' commands work from the repo root)
- `gh api repos/Sallvainian/Fermi/rulesets/7391054 --jq '[.conditions.ref_name.include, [.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context]]'` -- expected: `[["~DEFAULT_BRANCH"],["Test Summary","Dependency Review"]]`

**Manual checks (if no CLI):**
- A red pull request into main cannot merge without bypass, a Dependabot pull request outside the native group merges itself after both checks pass, and a native one does not: live once this branch reaches main; the orchestrator's verification covers it.

## Auto Run Result

Status: built

- **Summary:** Main now merges only on green CI. The Main ruleset targets the default branch only and requires exactly `Test Summary` and `Dependency Review`, with strict (up-to-date) mode off. `dependency-review.yml` fails a pull request at moderate severity. `dependabot-auto-merge.yml` turns on auto-merge for Dependabot pull requests except any that change a package matching the `native` group's patterns in `dependabot.yml`, grouped or not; those get a notice and are left for the owner. Both Claude workflows now install `app/`'s npm packages instead of Flutter, and their prompts name the new stack's checks. README's Gemini/Code Review item is gone. AGENTS.md carries the merge-gate, no-secret, native-group, MIN_NATIVE_BUILD-plus-build-number, open-until-App-Store-build and Playwright Utils rules.
- **Files changed:**
  - `.github/workflows/dependency-review.yml` -- new; job `Dependency Review`, every pull request, moderate, summary comment.
  - `.github/workflows/dependabot-auto-merge.yml` -- new; fetch-metadata v3.1.0 (pinned SHA), native hold from the base commit, My-Love's merge logic for the rest.
  - `scripts/dependabot-native-hold.sh` -- new; matches package names against the native patterns; exit 0, 3 (hold), or 2 (fail closed).
  - `scripts/test-dependabot-native-hold.sh` -- new; 10 cases covering every I/O matrix row.
  - `.github/workflows/claude.yml` -- Node setup and `npm ci` in `app/`; prompt for Capacitor and Supabase checks; no Flutter or `01_ci`.
  - `.github/workflows/claude-code-review.yml` -- same setup; Supabase, React, Capacitor and data-access checks; npm and node commands in `allowedTools`.
  - `README.md` -- removed the GitHub Actions Workflows subsection (Code Review Automation, Gemini).
  - `AGENTS.md` -- new managed block per `bmad-project-context`'s template.
  - GitHub, not in the repo: Main ruleset 7391054 updated through `gh api`; the previous JSON was saved in the session scratchpad.
  - this plan.
- **Review findings:** quick lens, 3 findings. Patched 1 (low): the review prompt's Capacitor check now names both `MIN_NATIVE_BUILD` and `CURRENT_PROJECT_VERSION`. Deferred 0. Rejected 2: the newline-split names are unreachable (fetch-metadata emits one comma-separated line), and the Orientation sentence count changes no agent behavior.
- **Follow-up review recommended:** false. The only patch was one low; patched counts: high 0, medium 0, low 1.
- **Verification:** native-hold test passes 10/10; actionlint is clean on all workflows; there are no Flutter, Dart, `pub get` or `01_ci` mentions in the Claude workflows; there are no removed workflows or Gemini in README; `npm --prefix app run lint`, `typecheck` and `test:unit` plus `node scripts/check-migrations.ts` exit 0 from the repo root; the live ruleset returns `[["~DEFAULT_BRANCH"],["Test Summary","Dependency Review"]]`, with the deletion, non_fast_forward and pull_request rules and the bypass actor unchanged.
- **Residual risks:**
  - These live behaviors are UNVERIFIED until this branch reaches main, and the orchestrator's verification covers them: a red pull request refused, a moderate-advisory package refused, a non-native Dependabot pull request merging itself, a native one held, and a Claude review running without Flutter.
  - The admin bypass (`RepositoryRole` 5, always) is unchanged, so the owner can still merge a red pull request by ticking the bypass box. Auto-merge and everyone else cannot.
  - Dependency Review's always-on pull request requirement means pull requests opened against main before this lands (#88, #89, #90, and the loop PR #92 until it contains this story) show the check as expected but never reported. They merge only by admin bypass, or after a Dependabot rebase or a new push.
  - With strict mode off, two Dependabot pull requests that each pass can break main together. Main's push run does not start for a merge made by the auto-merge token, so a break like that shows up in the next pull request or the Sunday scheduled run.
  - AGENTS.md followed the skill's template without its interview and approval step, because this run is unattended. `CLAUDE.md` is gitignored, so Claude Code sessions reach AGENTS.md only through the workflow prompts and the BMad skills.
  - The native-hold test runs locally only; no `test.yml` lane runs it. A broken edit to the script fails closed, holding pull requests rather than merging them.
