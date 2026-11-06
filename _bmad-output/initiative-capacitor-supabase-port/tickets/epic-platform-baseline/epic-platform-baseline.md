---
type: epic
title: "The new app ships from CI"
parent: initiative-capacitor-supabase-port
covers: [R23]
sources: [_bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md]
companions: [_bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md]
after: []
refined: true
risk: high
---

# The new app ships from CI

## Description

A Capacitor web build and iOS shell live in a new app/ folder beside the untouched Flutter app, the iOS project taking over bundle com.academic-tools.fermi and its build numbers, with the app/src/api/ client and its error map (AD-17); a new deploy workflow replaces 02_deploy_web.yml and, on a push to main, applies Supabase migrations, pushes the hosted Auth config and sets Realtime private-only, deploys edge functions, builds, packages the live update with its minimum native build (AD-18), deploys the fermi-plus Worker from an assets-only wrangler.jsonc on workers.dev, which replaces wrangler.toml and passes a health check that also asserts the Auth and Realtime config, with sign-up off until epic 2's hook exists (AD-21); the empty app and internal schemas, pg_cron, pg_net and pgtap, the job-health check the keep-alive calls, the job-failure table, the privilege fixture and its catalog test exist (AD-3); access-policy and edge-function tests run in CI; scheduled workflows keep the Free project awake and take a weekly encrypted backup (K18); an iOS build running in the iOS Simulator offers to restart onto each new deploy; the dead Flutter-era workflows 01_ci, 03, 04 and 05 and the repo secrets only they use are removed, Dependabot covers app/ and GitHub Actions, the Main ruleset requires test.yml's summary check before a merge and Dependabot pull requests merge themselves once it passes, and the Claude workflows target app/ and supabase/. Every later epic builds on this pipeline.

## Outcome

Every later epic ships by pushing to main: the website on workers.dev and the iOS app update themselves with no hand deploy, and the Free Supabase project stays awake and backed up (initiative K7, K18, R23).

## Requirements

- R1 (parent R23, AD-18): after a deploy, the iOS app downloads the new bundle in the background and offers to restart onto it, shown in the iOS Simulator; a bundle whose `min_native_build` is above the app's own build is skipped, and web code guards every plugin with `Capacitor.isPluginAvailable`
- R2 (parent K7, AD-21): a push to main runs, in order and with no hand step: migrations, the hosted Auth config push, Realtime private-only, edge functions, build and live-update packaging, `wrangler deploy`, and a health check that fails unless the site and `updates/latest.json` are served and the hosted config has email sign-in on, anonymous sign-ins off, sign-up off and Realtime private-only
- R3 (parent K6): the Worker `fermi-plus` on workers.dev (`fermi-plus.sallvain.workers.dev`) serves the Capacitor web build as static assets only from `wrangler.jsonc`; `wrangler.toml`, `src/index.js` and `02_deploy_web.yml` are gone
- R4 (parent K1, K11, spine Structural Seed): `app/` holds the Vite React web build and an iOS project for bundle `com.academic-tools.fermi` (team W778837A9L) with a build number above the listing's last, which runs in the iOS Simulator; the Flutter app is untouched
- R5 (parent K13, AD-3): every pull request and push runs ESLint, typecheck, Vitest, pgTAP, `deno test` and Playwright (Desktop Chrome, iPhone WebKit), and any failure fails the run; a checked-in privilege fixture lists the expected grants for every table, column, function and view, and a pgTAP catalog test fails on any object missing from it or differing
- R6 (AD-17): `app/src/api/` is the only code that imports the Supabase client and maps every error key to text in one place; edge functions answer with the real HTTP status and `{ "error": { "code", "message" } }` through one shared helper
- R7 (AD-3, AD-21, spine Structural Seed): schemas `app` and `internal` exist, empty and not exposed by the Data API; `pg_cron`, `pg_net` and `pgtap` are enabled, by this epic only; `internal.job_failures` exists
- R8 (parent K18, AD-21): a twice-daily workflow calls `public.job_health()` (executable by `service_role` only) through the API and fails, so GitHub emails the owner, on new rows in `internal.job_failures`, failed `cron.job_run_details` or non-2xx `net._http_response`; it re-enables itself monthly
- R9 (parent K18, AD-21): a weekly workflow dumps the hosted database (roles, schema, data) through the Session pooler, encrypts it to the owner's age key, keeps it as a 90-day artifact never committed, and proves it by restoring into a throwaway local database
- R10 (Decision 2026-11-06): workflows 01_ci, 03, 04 and 05 are gone with the ten repo secrets only they used, and the Cloudflare secrets exist only in the Production environment
- R11 (Decision 2026-11-06): Dependabot opens grouped weekly update pull requests for `app/`'s npm packages (vitest packages together, majors included; production and dev minor and patch grouped) and for GitHub Actions, and for nothing else, and its jobs run without errors
- R12 (Decision 2026-11-06): Main accepts a merge only after `test.yml`'s summary check passes; every pull request gets a dependency review that fails at moderate severity; a Dependabot pull request merges itself once the required check passes
- R13 (Decision 2026-11-06): `claude.yml` and `claude-code-review.yml` work on `app/` and `supabase/` with no Flutter setup, and no doc describes a removed workflow or secret

## Constraints

- K1 (parent K1): one Capacitor codebase ships the website and an iOS app; no Android or desktop shell
- K2 (parent K2): Supabase is the only backend; no Firebase SDK, config or project dependency in `app/`, `supabase/` or the new workflows
- K6 (parent K6): Cloudflare Workers static assets only, Worker `fermi-plus` on the free workers.dev subdomain `sallvain`, no bought domain, no Worker script
- K7 (parent K7): deploy order migrate, Auth config and Realtime private-only, edge functions, build and live-update package, wrangler deploy, health check; the live update is served from the Workers site with no Capgo account; nothing is deployed by hand
- K11 (parent K11): the iOS project keeps bundle `com.academic-tools.fermi` and team W778837A9L so it ships as an update to Fermi's existing listing
- K13 (parent K13): access policies and edge functions have automated tests that run in CI
- K15 (parent K15, AD-18): a change to native code, a plugin, `Info.plist`, entitlements or `capacitor.config` is an App Store build that raises `MIN_NATIVE_BUILD`; live updates carry web code only
- K18 (parent K18): Supabase Free plan; keep-alive twice daily; weekly backup encrypted to the owner's key, never committed, because the repo is public; Storage bytes are not backed up
- Stack (spine Stack, Deferred): the Stack table's versions are pinned; Supabase CLI 2.122.0, as in My-Love's workflows

## Done when

- A push to main runs migrations, the Auth config push, the Realtime private-only setting, edge functions, build, live-update packaging, wrangler deploy and a health check that asserts the hosted config, with no hand step
- The workers.dev site serves the Capacitor web build from an assets-only `wrangler.jsonc`, and `wrangler.toml`, `src/index.js`, `02_deploy_web.yml` and the Flutter-era root `package.json` are gone
- Access-policy, privilege-fixture and edge-function tests run in CI and fail the run when they fail
- The keep-alive and weekly backup workflows run on schedule, and the backup restores into a throwaway local database
- The iOS app in the iOS Simulator offers to restart onto the next deploy, and skips a bundle above its native build
- Workflows 01_ci, 03, 04 and 05 are gone, and `gh secret list` shows none of the ten secrets only they used and no repo-level Cloudflare secret
- Dependabot's jobs for `app/` npm and GitHub Actions run without errors; Main refuses a merge while `test.yml`'s summary check is red, and a Dependabot pull request merges itself once it is green
- The Claude workflows install no Flutter and target `app/` and `supabase/`
- A `bmad-tea-trace` run at closure maps R1–R13 to passing tests or each story's runnable check, and its gate is PASS or each gap has a waiver in Notes

## Boundaries

- Out: any user-facing feature; the landing page is epic-invite-sign-in's
- Out: removing the Flutter app, functions/, Firebase config, the email worker and the Pages project fermi (epic-app-store-release)
- Out: the sign-in hook and its health-check assertion (epic-invite-sign-in)
- Out: TestFlight and App Store builds (epic-app-store-release)
- Touch point: the Cloudflare account — Worker `fermi-plus` on `sallvain.workers.dev`, deployed with the Production environment's account token; owner: epic-platform-baseline
- Touch point: the hosted Supabase project `mzbblbgmrvcgvzxwhptm` (Free) — linked, migrated, configured, kept awake and backed up; owner: epic-platform-baseline
- Touch point: the GitHub repo — workflows, repo and environment secrets, Dependabot and the Main ruleset; owner: epic-platform-baseline

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R23, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-3, AD-17, AD-18, AD-20, AD-21, Structural Seed, Stack
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 1 Platform baseline, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md
- reference — /Users/sallvain/Projects/My-Love/.github/dependabot.yml; workflows/dependency-review.yml, dependabot-auto-merge.yml
- reference — /Users/sallvain/Projects/My-Love/.github/workflows/deploy.yml, test.yml; scripts/package-live-update.sh; src/services/nativeUpdates.ts; README.md, Cloudflare Workers and secrets

## Notes

- Decision: 2026-11-06, refined: Requirements R1–R9 deepen R23 with K6, K7, K13, K18 and AD-3, AD-17, AD-18, AD-21, since R23 alone does not describe this epic
- Decision: 2026-11-06, the iOS app is checked in the iOS Simulator in this epic, not on TestFlight, which is for beta releases and first matters at epic-app-store-release
- Decision: 2026-11-06, the source conflict with spine Consistency Conventions, Tests is settled: the architect amended it so native-only paths are checked in the Simulator in the epic that builds them, and AD-18 so native changes ship only in Simulator builds until epic-app-store-release's first TestFlight build
- Decision: 2026-11-06, `MIN_NATIVE_BUILD` stays a separate number from the Xcode build number and goes up only with a native change, as Expo's runtime version does; story 9's packaging fails when it is above the build number, and a CI check fails a pull request that changes native files without raising it (answers the spine memlog's MIN_NATIVE_BUILD question)
- Decision: 2026-11-06, tracer bullet is story 1, web only: the shell reaches workers.dev through migrate, build, wrangler deploy and the health check; iOS follows as story 2, the least certain part, because its setup is all hand steps
- Decision: 2026-11-06, sequencing: stories 1, 4, 5 and 9 edit deploy.yml in that order; story 3 owns the CI lanes and pgtap before the fixture (6) and the keep-alive (7); stories 2, 3, 4 and 8 can run in parallel after story 1
- Decision: 2026-11-06, the shared edge-function error helper in `supabase/functions/_shared` is this epic's (story 5); the epic map names no owner
- Decision: 2026-11-06, story 1 deletes the Flutter-era root `package.json` and `package-lock.json`, whose `file:../mcp-firestore-fixed` dependency cannot install in CI; wrangler is pinned in `app/`; story 3 points `.mcp.json`'s playwright-test server at `app/`
- Decision: 2026-11-06, story 3 is built by one TEA run of `bmad-tea-framework` with framework and CI scope, to My-Love's test rigor
- Decision: 2026-11-06, Cloudflare is set up as in My-Love: environment Production holds `CLOUDFLARE_API_TOKEN` (Edit Cloudflare Workers account token, verified active) and `CLOUDFLARE_ACCOUNT_ID`; repo variable `SITE_URL` is `https://fermi-plus.sallvain.workers.dev/`; no `fermi-plus` Worker or fermi-plus.com zone exists, so no route is detached
- Decision: 2026-11-06, the refactor sweep closes the epic; no closing end-to-end suite, since the sources hold no test plan
- Decision: 2026-11-06, a .github audit found the old CI dead or broken: 01_ci fails on every pull request and checks out main, 04 and 05 fail on every pull request (apps/fermi does not exist), 03 builds a Flutter Windows app the new stack does not ship and a v* tag fires 03, 04 and 05 together, 02 fails on every push, Dependabot's npm / entry fails and loses its target in story 1, and the Main ruleset requires no check; Gemini, Copilot, the inert config files and 44 unreferenced secrets were removed outside the plan in 01d3424. R10–R13 added; story 12 removes 01_ci, 03, 04, 05 and the ten secrets only they use, moved from epic-app-store-release and built now; story 1 rewrites dependabot.yml on My-Love's model and deletes the repo-level Cloudflare secrets
- Decision: 2026-11-06, pull requests run no CI from story 12 until story 3's test.yml; claude-code-review.yml keeps reviewing them, and both Claude workflows keep installing Flutter until story 13
- Decision: 2026-11-06, the required check, dependency-review.yml and dependabot-auto-merge.yml are story 13, after story 3, not part of it: story 3 is one bmad-tea-framework run with framework and CI scope, and one story keeps auto-merge after the required check, since without it a pull request merges untested; story 3 hands one summary job
- Decision: 2026-11-06, story 13 also retargets claude.yml and claude-code-review.yml to app/ and supabase/, moved from epic-app-store-release, because every pull request from story 1 on is app/ and supabase/ code and no Flutter work is planned before epic-app-store-release
- Decision: 2026-11-06, stale docs split by who deletes the thing they describe: README.md's CI/CD items 1 (01_ci) and 3 (Platform Releases) and docs/claude-code-setup.md's ANTHROPIC_API_KEY (Required), CI Pipeline Enhancement and MCP Server Configuration sections go in story 12; README item 2 (02_deploy_web) in story 1; README item 4 and the rest of that page, which story 13 rewrites or deletes, in story 13
- Decision: 2026-11-06, story 12 sits second in build order with no prerequisite so it is built now; this amends the tracer decision's "iOS follows as story 2" to next after story 12, and accepts that stories 1 and 12 each remove different items of README.md's CI/CD list in parallel
- Decision: 2026-11-06, the epic map's row 13 still gives epic-app-store-release "the old workflows" and src/index.js, and the spine's Structural Seed lists only deploy.yml, test.yml, keep-alive.yml, apple-secret.yml and backup.yml, not dependency-review.yml, dependabot-auto-merge.yml or the two Claude workflows; both are the architect's to amend through bmad-architecture
- Decision: 2026-11-06, this epic was sliced before TEA was planned in, so instead of an epic-level test design, a system-level `bmad-tea-test-design` run on the initiative goes before story 3's framework run, which then follows its risk plan; the no-closing-suite decision above stands for this epic
- Decision: 2026-11-06, story 13 records in AGENTS.md, through `bmad-project-context`, that Playwright tests use the `@seontechnologies/playwright-utils` fixtures story 3 sets up and a vanilla Playwright equivalent needs a stated reason, because `bmad-build` and `bmad-build-auto` do not load TEA's Playwright Utils rule (grep 2026-11-06) and every build reads AGENTS.md
