---
type: review
lens: rubric
target: architecture-capacitor-supabase-port.md (update 2026-11-07) and epic-map-capacitor-supabase-port.md
date: 2026-11-07
inputs:
  - initiative-capacitor-supabase-port.md (Requirements, Constraints, Boundaries, Notes 2026-11-07)
  - tickets/tickets.toml
  - tickets/epic-platform-baseline/tickets/tickets.toml (stories 14, 15, 16) and epic-platform-baseline.md
  - .memlog.md (entries from "update run (2026-11-07)" on)
  - app/ (vite.config.ts, index.html, src/, playwright.config.ts, package.json), wrangler.jsonc, scripts/ (package-live-update.sh, check-site.sh, deploy-gate.sh, check-migrations.ts, migration-lint.ts), .github/ (deploy.yml, test.yml, dependabot.yml, dependabot-auto-merge.yml) at c61bed9 plus the working-tree spine
---

# Rubric review: spine update 2026-11-07 (web only)

## Verdict

The update applies every item on the initiative's 2026-11-07 invalidation line. The spine and epic map have no leftover that assumes the iPhone app. AD-24, AD-25 and AD-26 match the code that exists today, apart from the parts story 1.14 removes. No finding is critical. Two high findings and several medium ones come from the move to web only and need a short amendment pass before epic-invite-sign-in (epic 2) and epic-notifications (epic 6) are refined:

- AD-21's closed list of extension points has no way to get public config into the build, or VAPID keys into function secrets.
- Push subscriptions on a shared browser can deliver one user's pushes to another.
- The push payload and the routing of notification clicks are not decided.
- AD-26's scope can be read more than one way.
- A build id taken from the commit fires the full-screen refresh on every push to main.

Story 1.14 can start: its hitl setup (AD-18, AD-21's live-update packaging, AD-23, Tests, Stack, Seed) has landed.

## Checklist summary

| Check | Result |
| --- | --- |
| Fixes the real divergence points for the 13 epics and misses none | Partly. Missed: build-time public config and function secrets (H1), push device ownership (H2), push payload and click routing (M2), cross-deploy contracts beyond SQL (M3), service worker lifecycle (M4) |
| Every Rule is enforceable and prevents its stated divergence | Mostly. AD-26 has no enforcement and an unclear scope (M5). AD-24 prevents a stale build but fires on changes that do not touch the client (M1) |
| Nothing under Deferred lets two units diverge | Holds. "Offline use" and "web-push 4.x" are safe deferrals |
| Ratifies, not contradicts, existing code | Holds, except for items story 1.14 removes. Small gaps in what is ratified: the `fermi-build` meta tag and the `local` id (L3), the expand-only lane (L4) |
| Covers every requirement in the ticket | R1 to R30 all mapped. K1 has no enforcing rule left (L1) |
| Every dimension the altitude owns is decided, deferred or open | Not yet: shared-computer sessions (M6), and the update check, refresh page and draft hook on the Home Screen web app as a path checked by hand (L2) |
| iPhone-app leftovers | None of substance. Naming leftovers only (L6, L7) |
| Invalidation line landed | Every item landed (table below) |
| Quiet requirements dropped | One: the hand check of the update path on the device (L2) |

## Critical

None.

## High

### H1 — AD-21's extension points cannot carry public build config or function secrets

- **Location:** AD-21 Extension points (spine line 285); Consistency Conventions, Secrets row (line 348); AD-14 (lines 221–222); AD-13 Drive (line 210); epic map row 1 and the `.github` files seam.
- **Problem:** the list is closed: "only by adding a health-check assertion, its function's entry to the one `deploy.yml` step that writes `internal.edge_function_settings`, a `test.yml` lane, or a deploy or scheduled-workflow secret to the Production environment". The web-only move adds needs the list does not cover:
  - **VAPID public key:** epic 6's client needs it as the `applicationServerKey` at `pushManager.subscribe`. It has to reach the browser, but the build job has no environment and reads no secret (deploy.yml `build` job; AD-23's posture). Passing it as a repo variable into `npm run build` is a new line in epic 1's build step, which the list does not allow.
  - **Google settings:** epic 4's Drive token client and Picker need the OAuth client id and a Picker developer key in the browser. This is the same problem.
  - **VAPID private key:** the Secrets row says "Supabase function secrets for VAPID", but no rule says what puts them there. K7 says nothing is deployed by hand, so it would need a `supabase secrets set` step, which is not an extension point.
  - **Bootstrap admin email:** the Secrets row says it is in Vault and "set by CI", but no extension point lets epic 2 add the step that writes it.
- **Divergence:** epic 4 and epic 6 each pick a path: a `VITE_*` repo variable in the build step, a runtime RPC, or a hard-coded key. Or they edit `deploy.yml` outside AD-21, or set secrets by hand against K7.
- **Proposed fix:** add to AD-21's Extension points:
  - "a public value the client needs (VAPID public key, Google OAuth client id, Picker key) as a repo variable passed to the `build` step's env as `VITE_<NAME>` and declared in `src/vite-env.d.ts`";
  - "its function secrets, through one `deploy.yml` step after `functions` that runs `supabase secrets set` from Production-environment secrets (created by epic 6 with VAPID; later epics add only their names)";
  - "the bootstrap admin email's Vault write, in the `edge_function_settings` step (epic 2)".

  Mirror these in the epic map's `.github` files seam (1 → 2, 4, 6).

### H2 — A push subscription on a shared browser keeps delivering the previous user's pushes

- **Location:** AD-14 Delivery, "Devices change only through `register_push_device` and `unregister_push_device` (at sign-out)" (line 222); epic map row 6. AD-26 itself names the "shared school computer" (line 331).
- **Problem:** a web push subscription belongs to the browser profile, not the user. Suppose user A never signs out: the tab is closed or the session lapses. User B then signs in on the same browser and registers, and `pushManager.getSubscription()` returns the same endpoint. Now `push_devices` has A's row and B's row on one endpoint, so B's screen shows A's chat messages and grades as system notifications. With APNs this did not happen because iPhones are personal. Desktop browsers and school computers (R24) are where it happens now.
- **Divergence:** a unique key is a data-shape decision that epic 6 may or may not make. `unregister` at sign-out alone does not close the leak.
- **Proposed fix:** add to AD-14:
  - `push_devices` has `unique (endpoint)`;
  - `register_push_device` upserts on the endpoint and moves an existing row to the caller;
  - sign-out also calls `pushManager.unsubscribe()` before `unregister_push_device`;
  - pgTAP covers the case where B registers A's endpoint and A's row is gone.

## Medium

### M1 — A build id taken from the commit fires the forced refresh on every push, including ticket-only commits

- **Location:** AD-24 Rule (line 317); code: `app/vite.config.ts` (`GITHUB_SHA || 'local'`), `deploy.yml` (every push to main deploys; its comment says "a docs-only push redeploys the same build").
- **Problem:** every push to main produces a new id. That includes commits that touch only `_bmad-output/` or `.github/`, and every Dependabot merge picked up by the daily run. Every open tab and Home Screen web app then gets the full-screen page that cannot be dismissed, and it comes from content that did not change. During active development that is several interruptions a day, in class. The `deploy.yml` comment is also wrong now: the build is not "the same build" to the client.
- **Proposed fix:** choose one and record it in AD-24:
  - (a) **Make the id the app tree:** the id is `git rev-parse HEAD:app`, the tree hash of `app/`. It changes only when the client changes. `deploy-gate.sh` and `check-site.sh` compute the same value, so "three readers, one identifier" still holds.
  - (b) **Keep the commit id and record the trade-off:** keep it, state the trade-off as accepted in AD-24, and correct the `deploy.yml` comment (story 1.14 already edits that file's comments).

### M2 — Push payload, display duty and click routing are not decided

- **Location:** AD-14 (lines 216–224), AD-19 ("ids only", line 268), AD-25 (line 326), R17.
- **Problem:** several decisions are missing:
  - **Payload:** the service worker cannot read supabase-js's session, which lives in `localStorage`, an API workers do not have. It therefore cannot fetch the row an ids-only payload names. The payload must carry the text to show, and the spine does not say whether `send-push` or SQL builds that text, or whether lock-screen text may include message content (K16 privacy).
  - **Display duty:** Safari requires every push to show a notification and revokes subscriptions whose pushes show nothing (user-visible-only). The service worker therefore cannot quietly drop a push while Fermi is in front, so R17's in-app pop-up and the system notification appear together.
  - **Click routing:** `notificationclick` needs one URL per kind, and those URLs are routes owned by epics 3, 4, 5 and 7.
- **Divergence:** emitter epics, epic 6's `send-push` and `sw.js`, and each feature's routes will each guess the shape.
- **Proposed fix:** add to AD-14:
  - "`internal.push_targets` also returns `title`, `body` and `url` per kind, built in SQL; message bodies are shown in full or as 'New message' (decide)";
  - "`sw.js` always calls `showNotification`; the in-app pop-up is skipped for a notification whose push the device received while it was in front, or the duplicate is accepted (decide)";
  - "each kind's `url` is a route the owning epic registers in one route map in `app/src/`".

### M3 — AD-20 covers SQL shapes only, but edge functions, Realtime events and push payloads cross deploys too

- **Location:** AD-20 Rule (line 274); deploy order in AD-21 (functions deploy before the build).
- **Problem:** before the forced refresh fires, an open tab still runs the previous build against:
  - edge functions that are already redeployed (`add-students`, `reset-student-password`, `delete-account` request and response shapes);
  - new `user:` and `chat:` event types its zod union (`realtime.ts`) does not know.

  `sw.js` also updates on its own schedule, so an old worker can receive a new payload. `scripts/migration-lint.ts` enforces only the SQL half.
- **Proposed fix:** extend AD-20's Rule: "Edge function request and response bodies, Realtime event payloads and push payloads change the same way: add optional fields only, and remove one deploy later. `realtime.ts` ignores unknown event types instead of throwing."

### M4 — AD-25 forbids `pushsubscriptionchange` and leaves the worker's update lifecycle open

- **Location:** AD-25 Rule (line 326); Open Questions, epic-notifications second spike (line 486).
- **Problem:** the Rule says the worker "handles `push` and `notificationclick` only". The open question about subscriptions iOS drops will most likely be answered with a `pushsubscriptionchange` handler and a re-subscribe on start, so the spike's answer would break the AD. Separately, without `skipWaiting()` and `clients.claim()`, a new `sw.js` waits until every client closes. A Home Screen web app is rarely closed fully, so the old push handler can keep running after AD-24's refresh, which links to M3.
- **Proposed fix:** amend AD-25: "handles `push`, `notificationclick` and `pushsubscriptionchange`; calls `skipWaiting()` and `clients.claim()`, which is safe because it has no `fetch` handler". Add a Vitest that fails if `sw.js` registers a `fetch` listener or touches `caches`, so the "caches nothing" rule is tested.

### M5 — AD-26's scope can be read several ways and nothing enforces it

- **Location:** AD-26 Rule (lines 332–335).
- **Problems:**
  - **Scope:** "every text input and text area" leaves open the number input for a grade, the date and time pickers for scheduled messages and calendar events, selects, and reminder offsets. Epics 4, 5, 9 and 8 will draw the line differently, and AD-24's refresh restores some forms and not others, which is the divergence AD-26 is meant to prevent.
  - **Keys:**
    - signed-out screens have no `<user id>`. The sign-in email field is a text input under the Rule;
    - a new, unsaved row has no row id, and the only example given is `chat:<chat id>:composer`.
  - **Clearing:** a cancelled or discarded edit is never cleared and comes back the next time that editor opens.
  - **Enforcement:** none is named.
- **Proposed fix:**
  - "every user-entered form value except passwords and files: text, number, date, time, select and checkbox";
  - "signed-out screens are not kept";
  - "a new row's key uses `new:<parent id>`";
  - "cleared on send, save or cancel";
  - "fields come from the draft hook's components in `app/src/`; an ESLint rule (epic 1) bans a raw `<input>` or `<textarea>` under `src/features/`".

### M6 — Shared-computer sign-in persistence is not decided

- **Location:** AD-26's Prevents names shared school computers, but no AD or Open Question covers the session; supabase-js persists the session in `localStorage` by default (`app/src/api/client.ts`).
- **Problem:** a student who closes the tab on a school computer without signing out leaves the next person signed in as them. Drafts were scoped to the tab for exactly this case, but the whole session outlives the tab. This dimension is new with web only: on iPhone the app was personal.
- **Proposed fix:** decide it or log it as an Open Question owned by epic 2. For example: "students' sessions use `sessionStorage` (`auth.storage`), so closing the tab signs out; staff keep `localStorage`", or "accepted: sign-out is the user's job".

## Low

### L1 — K1 no longer has an enforcing rule

- **Location:** frontmatter binds K1; retired AD-18 (line 258) only states that nothing native remains.
- **Fix:** add one line to the paradigm or to AD-24: "`app/` has no native shell; no `@capacitor/*` or other native-shell package; a later Android initiative writes a new AD." Optionally, story 1.14's grep could become a `test.yml` lane.

### L2 — Quiet drop: the hand check of the update path on the device

- **Location:** Consistency Conventions, Tests row (line 346).
- **Problem:** the old row had epic-platform-baseline check "the live-update restart" by hand. The new row lists only sign-in, the Drive picker and web push. Playwright cannot drive iOS suspension, so these are not checked by hand anywhere:
  - AD-24's check after a suspended Home Screen web app returns;
  - whether `sessionStorage` survives `location.reload()` there (AD-26, UNVERIFIED).

  Story 16's verify does it, but the spine no longer requires it.
- **Fix:** add "the update check, refresh page and draft restore after the Home Screen web app returns from suspension (epic-platform-baseline)" to the Tests row.

### L3 — AD-24 leaves part of the existing build-id code unratified

- **Location:** AD-24 (line 317); code: `vite.config.ts` also writes the id as `<meta name="fermi-build">`, `check-site.sh` checks that tag and the first JS asset, and the id is `local` outside CI.
- **Fix:** add: "The id is also written as the `fermi-build` meta tag, which the health check reads. Outside CI it is `local`, and `package-live-update.sh` refuses to run without `GITHUB_SHA`."

### L4 — AD-20 does not name its existing test

- **Location:** AD-20 (line 274); code: `test.yml` `migration-check` → `scripts/check-migrations.ts` and `migration-lint.ts`, with the `-- contract: <reason>` marker.
- **Fix:** add a Test line: "`test.yml`'s Migration Check fails a drop, rename or argument change unless the file starts with `-- contract: <reason>`."

### L5 — Gaps around the manifest

- **Location:** Capability map row "R1, R2, R25" (line 441); epic map Seams.
- **Problem:**
  - the manifest is not in the Capability map;
  - there is no seam for the manifest that epic 1 hands to epic 2 (R25's Home Screen steps, and the OAuth return staying inside the manifest's `scope`) and to epic 6 (iOS web push needs `display: standalone`);
  - the manifest's `scope` and AD-25's worker scope should both stay `/`.
- **Fix:** add the manifest and its icons to R25's row. Add a "Home Screen manifest" seam (1 → 2, 6): `start_url` and `scope` `/`, `display` `standalone`, the same as `sw.js`'s scope.

### L6 — Leftover name: `scripts/package-live-update.sh`

- **Location:** AD-24 (line 317), Structural Seed (line 386).
- **Problem:** the script no longer packages a live update.
- **Fix:** optionally rename it to `write-latest-json.sh` in story 1.14 and update the spine. Otherwise keep the name and note that it is historical.

### L7 — Leftover reference: "My-Love's update check"

- **Location:** epic map row 1, Uses ("My-Love's deploy, update check and test layout").
- **Problem:** My-Love's update check (`src/services/nativeUpdates.ts`) is the Capgo native updater, which this initiative no longer copies.
- **Fix:** reword to "My-Love's deploy and test layout; its `latest.json` comparison only".

### L8 — Refresh loop while a deploy propagates

- **Location:** AD-24 "What a different version does" (line 319).
- **Problem:** if Refresh lands on an edge that still serves the previous `index.html`, the start check shows the page again. It clears in seconds, but the page cannot be dismissed.
- **Fix (optional):** "after a Refresh that comes back on the same build, the next check waits 30 seconds."

## Leftovers that assume the iPhone app, Capacitor, APNs, Apple sign-in, App Review or live updates

A grep of the spine and epic map for `capacitor|apns|apple|app store|app review|testflight|simulator|native|live update|bundle|ios|xcode|plugin|nativeauth|hide my email|min_native|capgo|restart|launch` finds only these:

- the spine's name and title "Capacitor Supabase Port", and the slug `epic-app-store-release`, both kept by the initiative Decision of 2026-11-07, so not defects;
- the retired AD-18 and the Android deferral, both intended;
- `scripts/package-live-update.sh` (L6);
- the epic map row 1 Uses "My-Love's … update check" (L7);
- epic map row 13's "Fermi+ removed from sale in App Store Connect" and the Flutter `ios/`, both intended.

Nothing else remains.

## Invalidation line (initiative Notes, 2026-11-07): what landed

| Item | Landed |
| --- | --- |
| AD-5 send-push to APNs | Yes: web push only |
| AD-7 Apple sign-in, Hide My Email | Yes: Google only; the relay payload is gone from the test |
| AD-13 Drive picker in NativeAuth | Yes: Google's token client in both clients |
| AD-14 apns rows and push environment | Yes: `webpush` rows; gone means 404 or 410 |
| AD-18 the whole AD | Retired, ID kept |
| AD-20 clients on an older App Store build | Yes: open tabs and suspended Home Screen web apps |
| AD-21 live-update packaging, Apple secret step, apple-secret.yml | Yes |
| AD-23 MIN_NATIVE_BUILD lane, native-group exception | Yes |
| Tests convention (Simulator, production APNs) | Yes, but the update-path hand check was dropped (L2) |
| Stack (@capacitor/*, @capgo, push-notifications) | Yes |
| Structural Seed (app/ios, capacitor.config.ts, apple-secret.yml) | Yes; `public/` and `sw.js` added |
| Open Questions (NativeAuth, APNs, App Review) | Yes; replaced with spikes in the Home Screen web app |
| Epic map rows 1, 2, 6, 13 and the Native packages seam | Yes |
| AD-16's App Store 5.1.1(v) bind (memlog) | Yes |

## Ticket-sync items (for the PO, not spine defects)

1. **R23, epic-platform-baseline R1 and Done when, epic 1's description in `tickets.toml`, story 16:** "offers to reload … can be dismissed … Not now" against AD-24's full-screen page that cannot be dismissed. This conflict is known and goes to the PO. Story 16 also lacks:
   - the 15-minute check;
   - the AD-26 restore;
   - AD-24's wording, "A new version of Fermi is ready. Refresh to keep using Fermi." Story 16 says "Fermi+", and the product is named Fermi+ everywhere else: `index.html` title, App heading, manifest. Confirm the owner meant "Fermi".
2. **No story builds AD-26's draft hook,** which epic-platform-baseline owns per the spine and epic map row 1. Epic 1's Boundaries ("Out: any user-facing feature other than the reload offer (R1) and the Home Screen manifest (R14)") need to admit it. Story 16 or a new story 1.17 should build it before epic 2's first text field. **This is the highest-priority sync item.**
3. **References:**
   - epic-platform-baseline.md References lists AD-18; it should list AD-24, AD-25 and AD-26;
   - epic-notifications.md References lacks AD-25, which that epic owns;
   - the initiative References say "AD-1–AD-22", which should be AD-1–AD-26;
   - the initiative's "update check reference — My-Love nativeUpdates.ts … restart offer" points at the native updater.
4. **Every later epic's refinement** should cite AD-26 for its text fields. Epics 4 and 6 should also cite H1's extension points once they are amended.
5. **Story 14** may rename `package-live-update.sh` (L6) and should correct `deploy.yml`'s "same build" comment (M1).
