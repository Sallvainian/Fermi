---
title: 'A Fermi on an old build is replaced by the refresh page'
type: feature
ticket: '16'
created: '2026-11-07'
status: done
operator_actions:
  - "After this change is live, push a change under app/ to main. Then, in a desktop browser tab and in the Fermi+ Home Screen web app on your iPhone, both opened on the previous build, confirm each shows only the refresh page when it comes back on screen or within 15 minutes, and that Refresh brings up the build showing the new commit id."
  - "On the iPhone Home Screen web app, while it is on the refresh page, set a value under a fermi:draft: key in sessionStorage (Safari Web Inspector console from a Mac). Tap Refresh, then confirm the value is still there after the app returns from suspension."
  - "Push a change that touches only _bmad-output/ to main, then confirm neither the tab nor the Home Screen web app shows the refresh page."
  - "In that deploy's Health check job log, confirm check-site.sh passed, which includes the max-age=0 assertion on / and /updates/latest.json, and that https://fermi-plus.sallvain.workers.dev/updates/latest.json shows that push's commit as version and its app/ tree hash as app."
baseline_revision: '0634580aadd59a681bc0cf42337d4cc5f718b69f'
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

**Problem:** A tab or Home Screen web app left open across a deploy keeps running the old build, past AD-20's one-deploy contract, and nothing tells it to reload; `latest.json` names only the commit, so a docs-only push cannot be told apart from an app change; and the health check never asserts that `/` and `/updates/latest.json` are served with `max-age=0` (R1, R2, R16; AD-21, AD-24).

**Approach:** deploy.yml computes `APP_ID=$(git rev-parse HEAD:app)` once; the build bakes it in as `__APP_ID__` and `write-latest-json.sh` writes `{"version","app"}`. A framework-free update check in `app/src/update/` fetches `/updates/latest.json` on AD-24's triggers; when `app` differs it waits on the busy registry (at most 2 minutes), then a root gate renders the refresh page in place of the router. `check-site.sh` also asserts `max-age=0` on both paths.

## Boundaries & Constraints

**Always:**
- `latest.json` is exactly `{ "version": "<GITHUB_SHA>", "app": "<APP_ID>" }`. `write-latest-json.sh` refuses, writing nothing, on an unset `APP_ID` (exit 2) and on an app id that is not a quoted literal in `dist/assets` (exit 1), as it already does for the build id.
- `vite.config.ts`: `__APP_ID__` = `process.env.APP_ID || 'local'`, declared in `src/vite-env.d.ts`.
- The fetch is `fetch('/updates/latest.json', { cache: 'no-store' })`. A rejected fetch, a non-2xx status, a body that is not JSON (the SPA fallback), not an object, or has no non-empty string `app` shows nothing. A new `version` with the same `app` shows nothing.
- The refresh page shows only "A new version of Fermi+ is ready. Refresh to keep using Fermi+." and one button, "Refresh". It is full screen, has no close control, ignores Escape, needs no session, and renders in place of `<RouterProvider>`, so the router and everything under it unmount.
- Refresh stores `__APP_ID__` under the sessionStorage key `fermi:update:refreshed-from` (never a `fermi:draft:` key), then calls `location.reload()`. At start the key is read and removed. If it equals `__APP_ID__`, every check before start + 30 s is deferred to one check at that time. Every storage call is in try/catch.
- Checks coalesce: a check that starts while one is in flight joins it. Once a different app is found, every trigger, timer and listener stops.
- `check-site.sh` fails unless `/` and `/updates/latest.json` each carry a `Cache-Control` header with a `max-age=0` directive (comma-separated, case-insensitive, whitespace trimmed). Cloudflare serves `public, max-age=0, must-revalidate` on both (checked live 2026-11-07), so there is no `_headers` file.
- Playwright specs import from `tests/support/merged-fixtures.ts` and use `interceptNetworkCall`. There are no hard waits (the tea-enforce hook enforces this). `app/src/api/` stays at or above 80% line coverage.

**Never:**
- No service worker, no plugin, no new npm dependency.
- No change to the busy registry or the draft store beyond importing them.
- No `realtime.ts` (epic-invite-sign-in calls the exported check).
- No OAuth callback route.
- No `app` assertion in the health check.
- No secret in test.yml and no new test.yml job.
- No edits under `_bmad-output/` other than this plan; the spine keeps naming `package-live-update.sh`.
- No Flutter files.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Same app | `{version:'v2', app:__APP_ID__}` | nothing shown | — |
| Different app, idle | `{version:'v2', app:'other'}`, registry free | refresh page | — |
| Bad responses | rejected fetch, 500, HTML body, `[]`, `{version:'v2'}`, `app:''` | nothing shown, no throw | swallowed |
| Triggers | start; `visibilitychange` to visible; `pageshow`; `online`; `vite:preloadError`; `unhandledrejection` with a dynamic-import failure ("Failed to fetch dynamically imported module", "Importing a module script failed", "error loading dynamically imported module") | one fetch each | — |
| Timer | visible, 15 min pass | one fetch; none while hidden; restarts on visible | — |
| Stale client | `fromPostgrestError` with code `PGRST202`, `PGRST204`, `42883` or `42703` | a check runs at once; mapping unchanged | — |
| Busy | different app while `holdBusy()` is held | app stays; refresh page on release, or at 2 min if still held | — |
| Same build back | marker equals `__APP_ID__` at start | no fetch for 30 s, then one | — |
| Site cache | `/` or `latest.json` with no Cache-Control, or `max-age=600` | check-site fails, naming the URL and header | — |

</intent-contract>

## Code Map

- `.github/workflows/deploy.yml` -- build job (`working-directory: app`): new step before "Build application", `app_id="$(git rev-parse HEAD:app)"; echo "APP_ID=$app_id" >> "$GITHUB_ENV"`. The assignment makes `-e` catch a failure. `HEAD:app` is from the tree root and works on the shallow checkout. The Build and Write latest.json steps inherit it. Update the comments at lines 4-8 (story 16 now adds it), 222-224 and 263-265.
- `scripts/write-latest-json.sh` -- add `APP_ID` (required, exit 2). Run the same quoted-literal grep for it (exit 1). Write `jq -n --arg version … --arg app … '{version:$version, app:$app}'`. In the header, replace "Story 16 adds…" with "the app's update check (app/src/update/) compares `app`".
- `scripts/test-write-latest-json.sh` -- `write()` and `fake_dist()` take an app id. The happy case asserts `jq -cS` = `{"app":"tree123","version":"abc123"}`. New cases: unset `APP_ID` (2, 'APP_ID'), and an app id not in the build (1, names it), each with wrote-nothing.
- `scripts/check-site.sh` -- `fetch()` adds `-D "$headers_file"` (a second mktemp, removed in the trap). A helper returns the Cache-Control of the last header block (`tr -d '\r'`, then reset at each `HTTP/` line, `tolower`, and join repeated lines with `, `). Assert it after the `/` content-type check and after the latest.json content-type check. Reasons: `<url> has no Cache-Control header (expected max-age=0)` and `<url> is served with Cache-Control '<v>' (expected max-age=0)`. Update the header bullets and the comment at line 167.
- `scripts/check-site-preview.config.mjs` (new) -- a vite config with no imports beyond `node:fs` and `node:path`. Its plugin's `configurePreviewServer` adds a pre-middleware that answers `/` and `/index.html` from `<root>/<build.outDir>/index.html` (text/html), and `/updates/latest.json` when that file exists (application/json; otherwise `next()`, so the SPA fallback answers). It sets Cache-Control from `CHECK_SITE_ROOT_CACHE` / `CHECK_SITE_LATEST_CACHE`: unset means `public, max-age=0, must-revalidate`, and empty means no header. Reason: vite preview's sirv sends `no-cache` and overrides earlier `setHeader`s.
- `scripts/test-check-site.sh` -- build with `GITHUB_SHA` and `APP_ID="app-$build_id"`, then write with both. `serve` passes `--config "$root/scripts/check-site-preview.config.mjs"` and keeps `--outDir`. Pass the env per case. New fail cases: `/` without Cache-Control, `/` with `public, max-age=600`, and the same two for latest.json. Update the header list and the final count to 15.
- `.github/workflows/test.yml:159-171` -- the Health Check Tests comment adds the max-age cases and the APP_ID refusals.
- `app/vite.config.ts`, `app/src/vite-env.d.ts` -- `__APP_ID__` as `__BUILD_ID__` is done. The comment names deploy.yml's `APP_ID`.
- `app/src/update/updateCheck.ts` (new) -- `UpdateState = 'current' | 'waiting' | 'refresh'`, `updateState()`, `subscribeUpdate()`, `checkForUpdate(): Promise<void>` (exported for realtime.ts), `startUpdateChecks()` (idempotent; reads the marker, registers the triggers, runs the first check), `refresh()` (marker, then `location.reload()`), `isDynamicImportError(reason)`, and `resetUpdateCheckForTests()`. It uses `isBusy`/`subscribeBusy` from `../busy/busy.ts`. Constants: 15 min, 2 min, 30 s.
- `app/src/update/RefreshPage.tsx` (new) -- `fixed inset-0` full-screen, safe-area padding like `App.tsx`, one `<p>` with the text, and one `<button>` calling `refresh()`.
- `app/src/update/UpdateGate.tsx` (new) -- `useSyncExternalStore(subscribeUpdate, updateState)`. It renders `<RefreshPage/>` when `'refresh'`, else `children`.
- `app/src/main.tsx` -- `<StrictMode><UpdateGate><RouterProvider…/></UpdateGate></StrictMode>`; call `startUpdateChecks()` beside `startAuth()`.
- `app/src/api/errors.ts` -- `STALE_CLIENT_CODES = new Set(['PGRST202','PGRST204','42883','42703'])`; `fromPostgrestError` calls `void checkForUpdate()` when `err.code` is in it, before mapping.
- Reuse: `app/src/busy/busy.ts` (`isBusy`, `subscribeBusy`, `holdBusy`); the test patterns in `tests/unit/App.test.tsx` and `tests/unit/stub-storage.ts`; `tests/e2e/shell.spec.ts` (the `build-commit-id` testid). `interceptNetworkCall` with `fulfillResponse` keeps its `page.route` for every later request, reloads included.

## Tasks & Acceptance

**Execution:**
- [ ] `.github/workflows/deploy.yml`, `scripts/write-latest-json.sh`, `scripts/test-write-latest-json.sh` -- APP_ID end to end -- R2.
- [ ] `scripts/check-site.sh`, `scripts/check-site-preview.config.mjs`, `scripts/test-check-site.sh`, `.github/workflows/test.yml` comment -- the max-age assertion and its tests -- R2, AD-21.
- [ ] `app/vite.config.ts`, `app/src/vite-env.d.ts` -- `__APP_ID__`.
- [ ] `app/src/update/updateCheck.ts`, `RefreshPage.tsx`, `UpdateGate.tsx`, `app/src/main.tsx`, `app/src/api/errors.ts` -- the check, the page and the gate -- R1, R16.
- [ ] `app/tests/unit/updateCheck.test.ts` -- every matrix row except Site cache, with fake timers (`vi.advanceTimersByTimeAsync`) and a `fetch` spy. Stale codes go through `fromPostgrestError`. A non-stale code (`42501`) does not fetch.
- [ ] `app/tests/unit/RefreshPage.test.tsx` -- `UpdateGate` around a fake router child (testid). When refresh: the text content is exactly the sentence plus "Refresh", there is one button and no link or other control, Escape keeps it, the child is not rendered, and the click stores the marker and calls a stubbed `location.reload`. Busy: the child stays while held and the page shows at 2 min.
- [ ] `app/tests/e2e/refresh-page.spec.ts` -- see AC 1. It runs on the chromium and webkit projects.
- [ ] `app/tests/README.md` -- the Health Check Tests row adds the missing or nonzero `max-age` on `/` and `latest.json`, and the APP_ID refusals; add a short "Update check" note beside "Drafts and busy work".

**Acceptance Criteria:**
- **Playwright spec:** Given the built site with `**/updates/latest.json` fulfilled as `{version:'another-commit', app:'another-app-id'}`, when `/refresh-check/deep` opens, then only the refresh page shows (the text and one Refresh button, no `build-commit-id`). When a `fermi:draft:e2e:fixture:x:body` value is put in sessionStorage and Refresh is clicked, then an observed request for `/refresh-check/deep` answers 200 HTML (index.html again), the draft value is still in sessionStorage, and the shell shows (same build came back, so the check waits 30 s).
- **Site-check tests:** Given `scripts/test-check-site.sh`, when it runs, then all 15 cases pass, including the four Cache-Control failures.
- **Writer tests:** Given `scripts/test-write-latest-json.sh`, when it runs, then every case passes, including the APP_ID refusals.
- **Real build:** Given a real build with `GITHUB_SHA` and `APP_ID=$(git rev-parse HEAD:app)`, when `write-latest-json.sh` runs, then `app/dist/updates/latest.json` is exactly `{"version":"<HEAD>","app":"<tree hash>"}`.

## Implementation Notes

- A Sonnet subagent implemented the plan. The parent re-read the full diff and re-ran every Verification command.
- The e2e spec runs signed out (`authSessionEnabled: false`), because the refresh page needs no session.
- The spec opens `/refresh-check/deep`. The reload request for that same path answering 200 HTML proves that "Refresh reloads the current URL" and that index.html was fetched again.
- A comment in `updateCheck.ts` first spelled the draft prefix, which tripped story 17's test allowing only one file to contain it. The comment was reworded.
- `checkForUpdate()` called before `startUpdateChecks()` does not honour the 30 s quiet period, since the marker is read at start. `main.tsx` starts the checks at boot, before any API call can run.
- Live check, 2026-11-07: `scripts/check-site.sh https://fermi-plus.sallvain.workers.dev/ <live version>` passes. Cloudflare sends `public, max-age=0, must-revalidate` on `/` and `/updates/latest.json`, so no `_headers` file is needed.

## Plan Change Log

## Review Triage Log

### 2026-11-07 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `updateCheck.ts`: the comment says the `pageshow` trigger is for back/forward cache restore, but it runs on every `pageshow`. On a normal load that can fetch `latest.json` twice. The ticket says "on pageshow", so the trigger stays. The comment now says it checks on every `pageshow`, a back/forward cache restore included.
  - `[low]` `[reject]` `cameBackToSameApp`: when `getItem` succeeds and `removeItem` throws, the shared catch drops the 30 s wait. Storage that reads but refuses a remove is very rare, and the fix adds a second guarded block. If it happens, the cost is one check that runs at once, which may show the page again.
  - `[low]` `[patch]` `updateCheck.test.ts`: the "until they unsubscribe" half was vacuous, because `resetUpdateCheckForTests()` never notifies and also clears listeners. The test now subscribes two listeners and unsubscribes one before a real transition to `refresh`. It asserts the kept listener is called once and the dropped one never.

## Design Notes

The decision logic lives in a framework-free store, so Vitest drives every trigger and timer without React; the gate only reads the store. The store goes `current` → (`waiting` while busy) → `refresh` and never back. `refresh` is final for the page's life, because the page cannot be dismissed.

```ts
// after a different app is found
stop(); // listeners, interval, deferred timer
if (!isBusy()) return set('refresh');
set('waiting');
const off = subscribeBusy(() => { if (!isBusy()) { off(); clearTimeout(t); set('refresh'); } });
const t = setTimeout(() => { off(); set('refresh'); }, 2 * 60_000);
```

The 15-minute timer runs only while `document.visibilityState === 'visible'`. Coming visible checks at once and restarts it; going hidden clears it.

## Verification

**Commands:**
- `cd app && npm ci && npm run lint && npm run typecheck && npm run test:unit:coverage` -- expected: exit 0; `src/api` ≥80% lines.
- `scripts/test-write-latest-json.sh && scripts/test-check-site.sh` -- expected: every case ok; "All 15 health check and deploy gate cases behaved as expected."
- `(cd app && GITHUB_SHA=$(git rev-parse HEAD) APP_ID=$(git rev-parse HEAD:app) npm run build) && GITHUB_SHA=$(git rev-parse HEAD) APP_ID=$(git rev-parse HEAD:app) scripts/write-latest-json.sh && jq -cS . app/dist/updates/latest.json` -- expected: `{"app":"<tree hash>","version":"<HEAD>"}`.
- `cd app && npx playwright install chromium webkit && npx playwright test --project=chromium --project=webkit tests/e2e/` -- expected: all pass. If browsers or the local stack are unavailable, run what can run and record what could not.
- `actionlint .github/workflows/*.yml && shellcheck scripts/write-latest-json.sh scripts/test-write-latest-json.sh scripts/check-site.sh scripts/test-check-site.sh` -- expected: no output.
- `curl -sSI https://fermi-plus.sallvain.workers.dev/ | grep -i cache-control` -- expected: `max-age=0`.

**Manual checks (if no CLI):**
- After merge (owner, ticket note 2026-11-07): once this build is live, push an `app/` change. Then a tab and the Home Screen web app still on this build each show only the refresh page on return or within 15 minutes, and Refresh shows the new commit id. A push that changes only `_bmad-output/` shows no page. The deploy log shows `max-age=0` passing.

## Auto Run Result

Status: awaiting-operator

**Summary:** A Fermi on an old build is now replaced by the refresh page, and the health check asserts `max-age=0`.
- **App id:** deploy.yml computes `APP_ID=$(git rev-parse HEAD:app)` once, in the build job.
  - The build bakes it in as `__APP_ID__` (`local` off CI).
  - `scripts/write-latest-json.sh` writes `{"version","app"}`. It refuses an unset `APP_ID` (exit 2) and an app id missing from `dist/assets` (exit 1).
- **Update check:** `app/src/update/updateCheck.ts` fetches `/updates/latest.json` (`cache: 'no-store'`) at start, on `visibilitychange` to visible, on `pageshow`, `online` and `vite:preloadError`, on a dynamic-import rejection, and every 15 minutes while visible.
  - `fromPostgrestError` also runs it at once on `PGRST202`, `PGRST204`, `42883` and `42703`. `checkForUpdate()` is exported for epic-invite-sign-in's `realtime.ts`.
  - A failed or malformed fetch, or one with no `app`, shows nothing. So does a new version with the same app.
- **Refresh page:** a different `app` waits on the busy registry, for 2 minutes at most. Then `UpdateGate` renders `RefreshPage` in place of `<RouterProvider>`.
  - The page shows only the sentence and one Refresh button, and it cannot be dismissed.
  - Refresh stores `fermi:update:refreshed-from` and reloads the current URL. If the same build comes back, checks wait 30 s.
- **Health check:** `scripts/check-site.sh` now fails unless `/` and `/updates/latest.json` carry `max-age=0`.

**Files changed:**
- `.github/workflows/deploy.yml`: new "Compute the app id" step; comments updated.
- `.github/workflows/test.yml`: the Health Check Tests comment covers the new cases. Comments only.
- `scripts/write-latest-json.sh`: requires `APP_ID`, checks it is in the build, and writes `app`.
- `scripts/test-write-latest-json.sh`: two-field output and the APP_ID refusal cases (16 cases).
- `scripts/check-site.sh`: Cache-Control `max-age=0` assertion on `/` and `latest.json`.
- `scripts/check-site-preview.config.mjs` (new): vite preview config that sets per-path Cache-Control for the tests.
- `scripts/test-check-site.sh`: builds with `APP_ID`; four new Cache-Control failure cases (15 cases).
- `app/vite.config.ts`, `app/src/vite-env.d.ts`: the `__APP_ID__` define and declaration.
- `app/src/update/updateCheck.ts`, `RefreshPage.tsx`, `UpdateGate.tsx` (new): the check, the page and the root gate.
- `app/src/main.tsx`: wraps the router in `UpdateGate` and calls `startUpdateChecks()`.
- `app/src/api/errors.ts`: the stale-client codes trigger the check; the error mapping is unchanged.
- `app/tests/unit/updateCheck.test.ts`, `app/tests/unit/RefreshPage.test.tsx`, `app/tests/e2e/refresh-page.spec.ts` (new): Vitest and Playwright.
- `app/tests/README.md`: the Health Check Tests row and an "Update check" note.

**Review (quick):** 3 findings, all low.
- Patched (2):
  - the `pageshow` comment;
  - the vacuous unsubscribe assertion.
- Deferred: none.
- Rejected (1): a `removeItem` that throws after a good `getItem` skips the 30 s wait. Storage that reads but refuses a remove is very rare, and the fix adds a guarded block.

**Follow-up review recommended: false.** This is a first pass, and the patched counts are high 0, medium 0, low 2.

**Verification:** run after the patches unless noted.
- In `app/`, `npm run lint` and `npm run typecheck` exit 0.
- `npm run test:unit:coverage`: 205/205 pass, with `src/api` at 100% lines and `src/update` at 100% lines.
- `scripts/test-write-latest-json.sh`: 16/16. `scripts/test-check-site.sh`: "All 15 health check and deploy gate cases behaved as expected."
- A real build at HEAD 0634580aadd59a681bc0cf42337d4cc5f718b69f wrote `{"app":"f60847dab9ff7287038781fe2b5a77dbd2525c8a","version":"0634580aadd59a681bc0cf42337d4cc5f718b69f"}`, and `updates/` held only `latest.json`. Run before the patches, which touched no build or script file.
- `actionlint` and `shellcheck` print nothing.
- Playwright `--project=chromium --project=webkit tests/e2e/`: 8/8 pass, including both refresh-page cases.
- The new `check-site.sh` passes against the live `https://fermi-plus.sallvain.workers.dev/`, which sends `public, max-age=0, must-revalidate`. Run before the patches.
- Every I/O matrix row is covered by a test that ran and passed.

**Residual risks:**
- **First deploy:** tabs open on the build before this one have no update check, so the first deploy carrying it refreshes nobody. Only the second deploy that changes `app/` shows the refresh page (operator action 1).
- **Pending CI:** the ticket's verify depends on the deploy log, the live `latest.json` and CI on GitHub after the merge. None of those has run yet.
- **iPhone check:** the Home Screen web app's return from suspension is checked by hand on the owner's iPhone (ticket note 2026-11-07).
- **Stale spine:** the spine's AD-24 and Structural Seed still name `scripts/package-live-update.sh`. That is for the architect to amend.
- **OAuth callback:** AD-24's rule that the OAuth callback clears its code before the page may show has no route to apply to yet. It belongs to epic-invite-sign-in.
- **Rejected edge case:** a `removeItem` that throws after a good `getItem` skips the 30 s wait (the rejected finding).

## Operator Confirmation

Confirmed 2026-11-07: the external actions this story owed were carried out.

- After this change is live, push a change under app/ to main. Then, in a desktop browser tab and in the Fermi+ Home Screen web app on your iPhone, both opened on the previous build, confirm each shows only the refresh page when it comes back on screen or within 15 minutes, and that Refresh brings up the build showing the new commit id.
- On the iPhone Home Screen web app, while it is on the refresh page, set a value under a fermi:draft: key in sessionStorage (Safari Web Inspector console from a Mac). Tap Refresh, then confirm the value is still there after the app returns from suspension.
- Push a change that touches only _bmad-output/ to main, then confirm neither the tab nor the Home Screen web app shows the refresh page.
- In that deploy's Health check job log, confirm check-site.sh passed, which includes the max-age=0 assertion on / and /updates/latest.json, and that https://fermi-plus.sallvain.workers.dev/updates/latest.json shows that push's commit as version and its app/ tree hash as app.

_Appended by the bmad-loop orchestrator (`bmad-loop confirm`, #335): a human confirmed these external actions out of band, and the story was advanced from `awaiting-operator` to `done`._
