---
title: 'The empty app ships to workers.dev from a push to main'
type: feature
ticket: '1'
created: '2026-11-06'
status: done
baseline_revision: 'bca95df3f3e398379b2c103fa98acd196926f0fe'
route: full
route_source: auto
risk: high
review: thorough
review_source: pinned
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: [oversized]
deferred:
  - summary: >-
      The hosted project's Auth sign-up and exposed-schemas settings are not set by this story; config.toml governs only the local stack until a config push runs.
    evidence: |-
      deploy.yml runs supabase link and db push only (no supabase config push, by the plan's Never list and the epic's R2 split). Whether hosted sign-up is currently on is UNVERIFIED; the migration's REVOKE does reach the hosted database. Settled by the story that adds the hosted Auth config push and its health-check assertion.
    location: >-
      .github/workflows/deploy.yml
    severity: medium (unverified)
  - summary: >-
      scripts/check-site.sh's failure branches (stale id, asset served as HTML, id missing from JS) have no automated test that runs regularly.
    evidence: |-
      They were exercised only by this build's verification commands; the repo has no shell test harness and no app/ CI lane yet. The epic gives CI lanes to story 3 (test.yml), where a run against vite preview with a right and a wrong id would cover them.
    location: >-
      scripts/check-site.sh
    severity: medium
  - summary: >-
      Nothing automated guards that anon and authenticated lack USAGE on schemas app and internal, or that neither is added to [api] schemas, until the pgTAP lane and the privilege fixture exist.
    evidence: |-
      The migration's check ran once on a scratch local stack (2 schemas, 0 objects, has_schema_privilege false x4, PGRST106). Story 3 owns the pgTAP lane and story 6 the catalog test; a schema-privilege case belongs in the first of them.
    location: >-
      supabase/migrations/20261106190000_create_app_and_internal_schemas.sql
    severity: medium
operator_actions:
  - After this branch merges to main, open the Deploy run for that push and confirm Migrate, Build, Deploy and Health check are all green, and that https://fermi-plus.sallvain.workers.dev/ shows "Build <that commit id>".
  - Once that Deploy run is green, delete the repo-level Cloudflare secrets with `gh secret delete CLOUDFLARE_API_TOKEN` and `gh secret delete CLOUDFLARE_ACCOUNT_ID`, then confirm `gh secret list` shows no CLOUDFLARE_ entry (the Production environment keeps its own copies).
  - In GitHub, open Insights → Dependency graph → Dependabot and confirm the /app npm and github-actions version-update jobs ran without errors (security-update runs on functions/ are expected to stay red).
---

<intent-contract>

## Intent

**Problem:** The repo has no new app, no Supabase project files and a dead deploy (02_deploy_web.yml, wrangler.toml with a fermi-plus.com route, a Flutter-era root package.json that cannot install in CI), and Dependabot still targets pub, gradle and npm at `/`.

**Approach:** Scaffold `app/` as a shell page showing its build's commit id, add `supabase/` with sign-up off and one migration creating empty `app` and `internal` schemas, add an assets-only root `wrangler.jsonc` and a `deploy.yml` (migrate → build → deploy → health check), delete the dead files, and rewrite `dependabot.yml` on My-Love's model.

## Boundaries & Constraints

**Always:** Stack versions exact (`.npmrc` `save-exact=true`): @capacitor/core, @capacitor/ios, @capacitor/cli 8.6.0; @supabase/supabase-js 2.119.0; react, react-dom 19.3.1; react-router 8.5.1; vite 8.3.6; @vitejs/plugin-react 6.2.1; typescript 6.0.3; typescript-eslint 8.72.1; tailwindcss and @tailwindcss/vite 4.3.4; zustand 5.0.16; zod 4.6.7; wrangler 4.158.0 (in app/ devDependencies); Supabase CLI 2.122.0. Others at current latest: eslint 10.14.0, @eslint/js 10.0.1, eslint-plugin-react-hooks 7.1.1, eslint-plugin-react-refresh 0.5.7, globals 17.14.0, @types/react, @types/react-dom 19.3.0, @types/node 26.6.6. Node 24. Secrets are read only by jobs with `environment: Production`; the build job, which runs npm code, has none; the deploy job installs with `npm ci --ignore-scripts`. Leave the Flutter app, functions/, Firebase files, `build-for-cloudflare.sh` and other workflows untouched.

**Never:** No Worker script (`main`), no route or custom domain, no Firebase SDK in app/ or supabase/. No Vitest, Playwright, pgtap, pg_cron, pg_net, Auth config push, Realtime setting, edge functions, live-update packaging, `capacitor.config.ts` or `npx cap add ios` (later stories). No `app/src/api/` yet. Never deploy, push migrations or call the hosted project by hand. Do not touch README items 1, 3, 4.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Push to main | commit SHA S | jobs Migrate, Build, Deploy, Health check green; site HTML carries S | — |
| Stale or failed deploy | site still serves an older build | Health check fails after retries naming expected vs served id | job exits 1 |
| SPA fallback | GET `/anything` | index.html with 200 | — |
| Local build | no `GITHUB_SHA` | build id `local` | — |

</intent-contract>

## Code Map

- `wrangler.toml`, `src/index.js`, `.github/workflows/02_deploy_web.yml`, `package.json`, `package-lock.json` (root) -- delete.
- `README.md:435-440` -- delete only list item 2 (`02_deploy_web.yml`) and its bullets; keep other numbers as-is.
- `.github/dependabot.yml` -- full rewrite. Model: `/Users/sallvain/Projects/My-Love/.github/dependabot.yml` (read it); drop its preactjs ignore; directory `/app`.
- `/Users/sallvain/Projects/My-Love/.github/workflows/deploy.yml` -- model for deploy.yml: action versions (`actions/checkout@v7`, `actions/setup-node@v7`, `actions/upload-artifact@v7`, `actions/download-artifact@v8`, `supabase/setup-cli@45a513f8c64c0bc8e0e3dfe572b5c95be85f6359 # v3.0.1`), link/dry-run/push migrate steps, environment split, health-check retry loop. Fermi's environment is named `Production` (capital P). Repo vars: `SITE_URL` (`https://fermi-plus.sallvain.workers.dev/`, trailing slash), `SUPABASE_PROJECT_ID`. Production secrets: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.
- `/Users/sallvain/Projects/My-Love/wrangler.jsonc`, `vite.config.ts` (`__BUILD_ID__` define), `eslint.config.js`, `tsconfig.app.json`, `tsconfig.node.json` -- models; take only what an empty shell needs (no PWA, visualizer, checker, chunk groups).
- `.gitignore` -- already ignores `node_modules/`, `.env*`; `dist` is not ignored, so add `app/.gitignore` with `dist/`.
- My-Love's local Supabase stack occupies ports 54321-54324 on this machine; keep Fermi's committed config at defaults and verify on a scratch copy (Verification).

## Tasks & Acceptance

**Execution:**
- [ ] delete the five root files above and README item 2 -- R3 and the ticket's deletions.
- [ ] `app/` -- `package.json` (name `fermi-app`, private, type module; scripts `dev`, `build` = `tsc -b && vite build`, `typecheck` = `tsc -b --force`, `lint` = `eslint .`, `preview`), `package-lock.json`, `.npmrc`, `.node-version` (`24`), `.gitignore`, `index.html` (title `Fermi+`), `vite.config.ts` (react + `@tailwindcss/vite`; define `__BUILD_ID__` from `GITHUB_SHA` else `local`; an inline plugin's `transformIndexHtml` adds `<meta name="fermi-build" content="<id>">`), `tsconfig.json`/`tsconfig.app.json`/`tsconfig.node.json`, `eslint.config.js`, `src/main.tsx` (React Router `createBrowserRouter`, one route), `src/App.tsx` (heading "Fermi+" and "Build <full id>"), `src/index.css` (`@import "tailwindcss";`), `src/vite-env.d.ts` (declares `__BUILD_ID__`) -- the shell every later story builds on.
- [ ] `supabase/config.toml` -- `supabase init` (CLI 2.122.0) output, `project_id = "fermi"`, `[auth] enable_signup = false`; `[api] schemas` stay `public`, `graphql_public` -- R7 not exposed.
- [ ] `supabase/migrations/20261106190000_create_app_and_internal_schemas.sql` -- header comment naming its check; `create schema app; create schema internal;` and `revoke all on schema app, internal from public, anon, authenticated;` -- R7 (AD-3 anon gets nothing).
- [ ] `wrangler.jsonc` (repo root) -- `$schema` `app/node_modules/wrangler/config-schema.json`, name `fermi-plus`, `compatibility_date` `2026-11-04` (workerd 1.20261104.1 shipped with wrangler 4.158.0), `send_metrics: false`, `assets.directory` `./app/dist`, `not_found_handling: single-page-application`; comment that the name is the workers.dev host label.
- [ ] `.github/workflows/deploy.yml` -- name `Deploy`; on push to main and `workflow_dispatch`; `permissions: contents: read`; concurrency `deploy`, no cancel. Jobs: `migrate` (name Migrate, env Production: setup-cli 2.122.0, `supabase link --project-ref ${{ vars.SUPABASE_PROJECT_ID }}`, migration list, `db push --dry-run`, `db push`); `build` (needs migrate, no env, working-directory app: setup-node from `app/.node-version` with npm cache on `app/package-lock.json`, `npm ci`, `npm run lint`, `npm run build`, upload `app/dist`); `deploy` (needs build, env Production with url `vars.SITE_URL`: `npm ci --ignore-scripts` in app, download to `app/dist`, `app/node_modules/.bin/wrangler deploy` from repo root with the Cloudflare secrets); `health-check` (name Health check, needs deploy, no secrets: checkout, then `scripts/check-site.sh "${{ vars.SITE_URL }}" "$GITHUB_SHA"`).
- [ ] `scripts/check-site.sh` (executable bash, `set -euo pipefail`) -- args: base URL (trailing slash optional), expected build id; optional env `ATTEMPTS` (default 6) and `RETRY_DELAY` (default 10 s). Each attempt fails unless the base URL returns 200 `text/html`, its `fermi-build` meta equals the expected id, the referenced `/assets/*.js` returns 200 with a JavaScript content type, and a deep path (`check-site/deep/path`) returns 200 `text/html`; on final failure print expected vs served id and exit 1 -- AD-21's health check, one file later stories add assertions to.
- [ ] `.github/dependabot.yml` -- npm `/app` weekly Monday, prefix `deps` include scope, labels dependencies/npm; groups in order: `native` (`@capacitor/*`, `@capgo/*`; comment: AD-18's one list of native packages, add each Capacitor plugin here; all update types), `vitest` (`vitest`, `@vitest/*`, majors included), `production-dependencies` and `dev-dependencies` minor/patch; comment that Dependabot uses the first matching group. github-actions `/` weekly Monday, prefix `ci` include scope, one `actions` group `*` minor/patch. Nothing else.

**Acceptance Criteria:**
- Given the branch, when `npm ci && npm run lint && npm run typecheck && npm run build` run in app/ with `GITHUB_SHA=abc123`, then all exit 0 and `app/dist/index.html` contains `content="abc123"`.
- Given the built app served with `npx vite preview`, when a browser opens `/` and `/some/deep/path`, then each shows "Fermi+" and the build id.
- Given the local stack (scratch copy), when `supabase db reset` runs, then schemas `app` and `internal` exist and are empty, `anon` and `authenticated` lack USAGE on them, and REST with `Accept-Profile: app` is refused (PGRST106).
- Given the repo, when listed, then the five deleted files are gone and `wrangler deploy --dry-run` from the root uploads assets from `app/dist` with no script.

## Implementation Notes

- Implemented by a Sonnet subagent from this plan; all files as listed in Tasks. No commit, deploy, push or hosted-project call was made.
- Local Supabase check ran on a scratch copy with project_id fermi-verify and 553xx ports, because My-Love's stack holds 54321-54324; the committed config keeps defaults.
- `npm audit` reports 10 moderate advisories, all minimatch via eslint/typescript-eslint dev tooling; the only offered fix downgrades eslint to 9.x, so left as is.
- `npm ci` notes workerd's postinstall is skipped (npm script approval); build and wrangler dry-run work.
- No favicon: the preview logs one 404 for /favicon.ico; out of the plan.

## Plan Change Log

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 35 findings — high 0, medium 7, low 20, false 5, maybe-false 3
- findings:
  - `low` `reject` [blind] migrate runs before build, so a failed build leaves the schema ahead of the live site — the intent and K7 fix the order migrate → build → deploy, and AD-20 (expand then contract) keeps the previous bundle working on the new schema.
  - `medium` `reject` [blind] no pre-merge lint/typecheck/migration check for app/ or supabase/ — the epic gives CI lanes to story 3 and records that pull requests run no CI until story 3's test.yml.
  - `medium` `patch` [blind] workflow_dispatch from any branch pushes that branch's migrations and deploys it — verified: Production has no deployment-branch policy (gh api: null); added `if: github.ref == 'refs/heads/main'` to Migrate, which every later job needs.
  - `low` `patch` [blind] migration comment overclaims that callers get only explicit grants, but Postgres grants function EXECUTE to PUBLIC — comment reworded to say it closes schema USAGE and each function's migration revokes EXECUTE (AD-3); SQL unchanged.
  - `low` `reject` [blind] deleting the root package.json breaks .mcp.json's playwright-test server — the intent mandates the deletion, .mcp.json is gitignored local tooling, and the epic gives repointing it at app/ to story 3.
  - `low` `reject` [blind] the pipeline's vars, environment and secrets are documented nowhere in-tree — deploy.yml names every var and secret it reads; README rewrite is story 13's.
  - `low` `reject` [blind] check-site.sh does not check the CSS asset — assets upload as one set, so a missing CSS file alone is unlikely, and the fix adds another branch.
  - `low` `reject` [blind] empty base URL retries for ~60 s before failing — it still fails loudly with HTTP 000; a guard adds complexity for a misconfiguration that is visible.
  - `low` `reject` [blind] GitHub's own actions use tags, not SHA pins — they are GitHub-owned, match the My-Love model the ticket names, and Dependabot's github-actions entry updates them.
  - `false` `reject` [blind] `${{ vars.* }}` in run: allows script injection — repo variables are set only by repo admins, so no untrusted input reaches the shell.
  - `low` `patch` [blind] wrangler.jsonc's date comment goes stale on the first wrangler bump (CLI version not Dependabot-managed is by Stack pin) — comment reworded to state the rule and the version it matched.
  - `low` `reject` [blind] lint warnings do not fail the build — matches the model; the one warn-level rule (react-refresh) is deliberately a warning.
  - `low` `reject` [blind] local site_url points at port 3000 and seed.sql is missing — supabase init defaults; Auth flows and seeding are later stories, and the missing seed only prints a notice.
  - `low` `reject` [blind] wrangler deploy has no --message, and observability logs were dropped — an assets-only Worker runs no script to log; a message is optional polish.
  - `medium` `patch` [edge] workflow_dispatch from a non-main ref deploys to production — same root cause and fix as the blind finding above.
  - `low` `reject` [edge] lint/build failing after migrate leaves the schema ahead — same as the blind deploy-order finding: order is mandated, AD-20 covers it.
  - `low` `reject` [edge] re-running an old run rolls the site back — needs a deliberate manual re-run; AD-20 keeps the older bundle working; the fix adds a remote lookup guard.
  - `low` `reject` [edge] empty base URL is hidden behind HTTP 000 retries — same as the blind finding: fails loudly.
  - `low` `reject` [edge] ATTEMPTS=0 or non-numeric runs no attempt — the script still exits 1; only a caller misusing the env var meets it.
  - `low` `reject` [edge] a base URL with a path breaks the /assets join — SITE_URL is the origin root and Vite's base is '/'; not reachable today.
  - `low` `patch` [edge] GITHUB_SHA set but empty gives an empty build id — changed `??` to `||` in app/vite.config.ts.
  - `maybe-false` `defer` [edge] enable_signup = false is local-only; the hosted project keeps its own setting — would need the hosted Auth config read through the Management API; deferred to the config-push story.
  - `medium` `patch` [verification-gap] the health check never proves the id reached the app code (a dropped define leaves a blank page with a matching meta) — check-site.sh now fails unless the fetched JS contains the expected id; tested pass and fail.
  - `medium` `defer` [verification-gap] check-site.sh's failure branches have no regularly running test — CI lanes are story 3's (AD-23 test.yml); deferred there.
  - `medium` `defer` [verification-gap] nothing guards the closed app/internal schemas until story 6 — pgTAP lane is story 3's, catalog test story 6's; deferred there.
  - `low` `reject` [verification-gap] the meta regex depends on attribute order — a reorder fails the deploy loudly, not silently.
  - `low` `reject` [verification-gap] lint only runs on push after migrate — tracked by the test design as R-005/P1-001, owned by story 3.
  - `false` `reject` [intent] R10's secret deletion is not in the diff — it is conditional on a green post-merge Deploy run; recorded under operator_actions with status awaiting-operator.
  - `maybe-false` `defer` [intent] hosted sign-up is untouched by the diff — same root cause as the edge finding; deferred with it.
  - `maybe-false` `defer` [intent] hosted Data API exposed schemas are set in the dashboard, not by the diff — same root cause; the migration's REVOKE does reach the hosted DB; deferred with it.
  - `medium` `patch` [intent] the health check reads the meta, not what the page renders — same root cause as the verification-gap finding; the JS-contains-id check now ties the rendered value to the push.
  - `false` `reject` [intent] a fermi-plus Worker may already exist — the epic records that no fermi-plus Worker or fermi-plus.com zone exists.
  - `false` `reject` [intent] Capacitor iOS is packages only — the ticket asks for the packages; the iOS project is story 2's.
  - `low` `reject` [intent] README list now reads 1, 3, 4 — Markdown renders it 1, 2, 3, and items 1, 3, 4 belong to stories 12 and 13.
  - `false` `reject` [intent] Dependabot's no-errors can only be judged after merge — recorded under operator_actions.

## Design Notes

The health check reads the `fermi-build` meta from HTML so it proves *this* push is live without running JS. Every push to main deploys (no `paths-ignore`): simple, and a docs-only push only redeploys the same build. After merge the owner verifies the Deploy run, deletes the repo-level `CLOUDFLARE_*` secrets (R10) and checks the Dependabot jobs; none can happen before the merge.

## Verification

**Commands:**
- `cd app && npm ci && npm run lint && npm run typecheck && GITHUB_SHA=abc123 npm run build && grep -c 'name="fermi-build" content="abc123"' dist/index.html` -- expected: exit 0, count 1.
- With `GITHUB_SHA=abc123` build served by `npx vite preview --port 4173` in app/: `scripts/check-site.sh http://localhost:4173/ abc123` -- expected exit 0; `ATTEMPTS=1 RETRY_DELAY=0 scripts/check-site.sh http://localhost:4173/ wrongid` -- expected exit 1 naming both ids. Then `cd app && npm run build` with `GITHUB_SHA` unset and `grep -c 'content="local"' dist/index.html` -- expected 1.
- `app/node_modules/.bin/wrangler deploy --dry-run` (repo root) -- expected: exit 0, assets-only, no credentials needed.
- Scratch copy: `cp -R supabase <scratch>/sb/`, change `project_id` and every port in its config.toml to unused ones (e.g. 553xx), `supabase start --workdir <scratch>/sb -x studio,imgproxy,mailpit,edge-runtime,logflare,vector,supavisor,realtime,storage-api` (adjust names to what 2.122.0 accepts), `supabase db reset --workdir <scratch>/sb`, then psql: `select nspname from pg_namespace where nspname in ('app','internal')` → 2 rows; `has_schema_privilege('anon','app','USAGE')` and same for `authenticated`/`internal` → false; curl REST `-H 'Accept-Profile: app'` → PGRST106; then `supabase stop --workdir <scratch>/sb --no-backup` -- expected as stated.
- `actionlint .github/workflows/deploy.yml` if installed, else `npx --yes yaml-lint`/python yaml parse of deploy.yml and dependabot.yml -- expected: no errors.

**Manual checks (if no CLI):**
- `git ls-files wrangler.toml src/index.js package.json package-lock.json .github/workflows/02_deploy_web.yml` -- expected: empty.

## Auto Run Result

Status: awaiting-operator

**Summary:** `app/` now holds the Vite + React shell at the Stack's exact versions; it shows "Fermi+" and "Build <commit id>" and writes the id into a `fermi-build` meta tag. `supabase/` has `config.toml` with sign-up off and one migration creating empty `app` and `internal` schemas closed to anon and authenticated. A root assets-only `wrangler.jsonc` and a new `deploy.yml` (Migrate → Build → Deploy → Health check, main only) replace the Flutter-era deploy. `dependabot.yml` covers only `/app` npm and GitHub Actions.

**Files changed:**
- `.github/workflows/deploy.yml` — new four-job deploy; secrets only in Migrate and Deploy (Production); Migrate gated to main.
- `.github/dependabot.yml` — rewritten: npm `/app` with groups native, vitest, production, dev; github-actions grouped minor/patch.
- `scripts/check-site.sh` — health check: HTML 200, meta id equals the push, JS asset served as JavaScript and containing the id, SPA deep path 200.
- `wrangler.jsonc` — Worker fermi-plus, assets only from `app/dist`, SPA fallback.
- `app/*` — package.json, lockfile, .npmrc, .node-version, .gitignore, index.html, vite/ts/eslint configs, src/main.tsx, App.tsx, index.css, vite-env.d.ts.
- `supabase/config.toml`, `supabase/.gitignore`, `supabase/migrations/20261106190000_create_app_and_internal_schemas.sql` — local project, sign-up off, schemas.
- `README.md` — CI/CD item 2 removed.
- Deleted: `wrangler.toml`, `src/index.js`, `.github/workflows/02_deploy_web.yml`, root `package.json`, root `package-lock.json`.

**Review:** 35 findings. Patched 5 entries (2 medium: main-only guard; JS-contains-id health check — 3 low: migration comment, wrangler comment, empty GITHUB_SHA). Deferred 3 (hosted Auth/exposed-schema settings until the config-push story; check-site.sh failure-path test and schema-privilege test for story 3). Rejected 27, each with its reason in the Review Triage Log.

**Follow-up review recommended: true** — two medium entries were patched. The unverified risk: the main-only `if:` and the JS id check are only proven locally; the first Deploy run on main is their first real run.

**Verification:** `npm ci`, `npm run lint`, `npm run typecheck`, `npm run build` exit 0; `dist/index.html` carries the id once, and `local` when GITHUB_SHA is empty. `scripts/check-site.sh` against `vite preview` exits 0 for the right id and 1 for a wrong id; the subagent also proved the JS-missing-id failure. `wrangler deploy --dry-run` exits 0 with assets only and no bindings. actionlint clean; dependabot.yml parses. Scratch local Supabase stack: schemas app and internal exist with 0 objects, anon/authenticated lack USAGE on both, REST with `Accept-Profile: app` returns PGRST106. Browser preview showed "Fermi+" and the id at `/` and a deep path (subagent).

**Owed by the operator (operator_actions):** confirm the first Deploy run on main and the live site's id; then delete the repo-level CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID; confirm Dependabot's version-update jobs run clean.

**Residual risks:** the first `supabase link`/`db push` and the first `wrangler deploy` (which creates the Worker) run for the first time on main; hosted sign-up stays at its current setting until the config-push story; 10 moderate dev-only npm advisories (minimatch via eslint).

## Operator Confirmation

Confirmed 2026-11-06: the external actions this story owed were carried out.

- After this branch merges to main, open the Deploy run for that push and confirm Migrate, Build, Deploy and Health check are all green, and that https://fermi-plus.sallvain.workers.dev/ shows "Build <that commit id>".
- Once that Deploy run is green, delete the repo-level Cloudflare secrets with `gh secret delete CLOUDFLARE_API_TOKEN` and `gh secret delete CLOUDFLARE_ACCOUNT_ID`, then confirm `gh secret list` shows no CLOUDFLARE_ entry (the Production environment keeps its own copies).
- In GitHub, open Insights → Dependency graph → Dependabot and confirm the /app npm and github-actions version-update jobs ran without errors (security-update runs on functions/ are expected to stay red).

_Appended by the bmad-loop orchestrator (`bmad-loop confirm`, #335): a human confirmed these external actions out of band, and the story was advanced from `awaiting-operator` to `done`._
