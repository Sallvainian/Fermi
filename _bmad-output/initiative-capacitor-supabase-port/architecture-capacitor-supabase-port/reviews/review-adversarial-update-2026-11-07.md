---
review: adversarial
target: architecture-capacitor-supabase-port.md and epic-map-capacitor-supabase-port.md, update 2026-11-07 (iPhone app dropped; AD-18 retired; AD-5, AD-7, AD-13, AD-14, AD-16, AD-20, AD-21, AD-23 amended; AD-24, AD-25, AD-26 added)
lens: two units one level down that each obey every AD to the letter yet build incompatibly (clashing shapes, two owners of one thing, conflicting state paths, ordering contradictions)
reviewed: 2026-11-07
scope: the refresh page, drafts, sign-in and sign-out, the service worker and push, latest.json's writers and readers, AD-20 against the check moments, draft screen keys, push_devices, epic map drift
prior: reviews/review-adversarial-update-2026-11-06c.md (F1-F8) and earlier; none repeated here
---

# Adversarial review: the web-only update

## Verdict

**Needs amendment before epic 1's remaining stories are built.** The three new ADs are the right shape, but:

- Two of them have no correct builder in the tickets. No story builds AD-26's draft hook. Story 1.16 builds the dismissable banner that AD-24 replaced.
- Making the refresh mandatory turns several ordinary seams into data loss or privacy holes: in-flight work, sign-out, shared computers and stale code paths. No AD covers them yet.

Counts: 2 CRITICAL, 6 HIGH, 10 MEDIUM, 7 LOW, plus 4 over-specification notes.

**Sources read:**

| Source | Lines |
| --- | --- |
| Spine | 486 |
| Epic map | 80 |
| `tickets/tickets.toml` | 104 |
| `tickets/epic-platform-baseline/tickets/tickets.toml` | 182 |
| `scripts/deploy-gate.sh` | 31 |
| `scripts/check-site.sh` | 210 |
| `scripts/package-live-update.sh` | 87 |
| `.github/workflows/deploy.yml` | 349 |

Line counts are from `wc -l`. Also read:

- `wrangler.jsonc`;
- the header of `scripts/migration-lint.ts`;
- the spine memlog, lines 125-145;
- epic-platform-baseline.md, grepped for references and decisions;
- epic-notifications.md, grepped;
- initiative R11, R14, R17, R23, R24 and R25, and the 2026-11-07 Decisions;
- My-Love's `vite.config.ts`, `src/main.tsx`, `public/_headers` and `src/sw.ts`, grepped;
- `git log origin/main --first-parent` for 2026-11-06.

## CRITICAL

### W1. No story builds AD-26's draft hook, and epic 2's text fields come first

- **Unit A (epic 1):** the epic map row 1 and AD-26 give the draft hook to epic-platform-baseline. None of stories 1-16 in `epic-platform-baseline/tickets/tickets.toml` builds it, and story 11 is a cleanup sweep that says "scope pushed out of another story is a new story".
- **Unit B (epic 2):** this is the first epic with text fields: the admin's staff-email field, `display_name`, and the student email on the sign-in screen. Per AD-26, each must go through a hook that does not exist.
- **Outcome:** epic 2 has two options, and both break the spine:
  - It builds the hook itself, which makes it a second owner.
  - It skips the hook, which breaks AD-26. AD-24's promise that "AD-26 restores what the user was typing" is then false for every screen built before someone notices.
- **Rule:** add a story to epic-platform-baseline (hook, key builder, sign-out wipe, Vitest), with `after = [16]` or merged into 16. Epic 2's `after` names it in `needs`.

### W2. Story 1.16 and initiative R23 build the AD-24 that was replaced

- **Unit A (story 1.16, hitl = false, so bmad-loop builds it unattended):**
  - a top banner, 'A new version of Fermi+ is ready', with Reload and Not now;
  - checks on start and on `visibilitychange` only;
  - "Fermi stays usable either way";
  - tests for Not now.
- **Unit B (AD-24):**
  - a non-dismissable full-screen page reading "A new version of Fermi is ready. Refresh to keep using Fermi.";
  - one Refresh button;
  - a check every 15 minutes while on screen.
- **Also stale:** initiative R23 still says "offers to reload", and epic 1's description says "offers to reload onto each new deploy". The memlog (line 136) records this as "Ticket change for Sofia", but the tickets are unchanged.
- **Outcome:** story 1.16 can follow its ticket or AD-24, but not both. Its Playwright spec asserts the opposite of the spine. If it merges, AD-20's one-deploy contract rests on a banner that can be dismissed indefinitely.
- **Rule:** no spine change. Re-render R23, epic 1's description and story 1.16 (copy, no Not now, the 15-minute check, tests) before story 1.16 leaves `after = [14]`. Story 1.14 is hitl = true, so it holds 1.16 until then.

## HIGH

### W3. Build id = commit forces a full-screen refresh for pushes that change nothing in the bundle

- **Unit A (AD-24, AD-21):** the build id is the commit. `deploy.yml` deploys on every push ("a docs-only push redeploys the same build"), and the daily run ships Dependabot merges, including dev-only bumps.
- **Unit B (AD-24's refresh page):** any different `version` blocks the screen.
- **Evidence:** main took 35 first-parent commits on 2026-11-06. Only 8 changed `app/` or `supabase/` (`git log` and `git diff`). Planning-doc commits (`chore(tickets)`, `chore(operator)`) land on main through bmad-loop all day.
- **Outcome:** every open tab and Home Screen web app is blocked, one class at a time, during school hours, for an identical bundle. This multiplies W5's in-flight losses.
- **Rule (amends AD-24's "nothing else"):** `latest.json` becomes `{ "version": <sha256 of dist minus updates/, id stripped>, "commit": <sha> }`. The app compares `version` with a baked `__BUNDLE_HASH__`. The deploy gate and the health check compare `commit`. A second option was considered and rejected: keeping one id but skipping wrangler when `app/` is unchanged would leave `latest.json` behind main, so the daily gate would redeploy every day.

### W4. AD-20 counts deploys, but clients refresh only at check moments, and deploys can be skipped

- **Unit A (`deploy.yml`):** it uses `concurrency: deploy` with `cancel-in-progress: false`. GitHub keeps one running and one pending run per group and cancels the older pending run.
  - Push B ("stop using column x") goes pending behind A. Push C (`-- contract: B is live`, dropping x) arrives and cancels B. C migrates while every client is still on A.
  - `migration-lint.ts` accepts any free-text `-- contract:` reason and verifies nothing.
- **Unit B (AD-24):** a hidden tab does no 15-minute check ("while it stays on screen"). It still holds its Realtime channels, and AD-19 events make it refetch with the old shape. A resumed Home Screen app sends its first queries before the check answers.
- **Outcome:** both units follow the letter: "live for one deploy", plus the checks. Old clients still call shapes that have been dropped, and the calls fail outright.
- **Rule (AD-20):**
  - The contract line names a commit: `-- contract: after <sha>`. The migrate job refuses unless the live `latest.json` commit has `<sha>` as an ancestor, and that commit's Production deployment is at least 24 hours old (GitHub deployments API).
  - Separately, `app/src/api/` treats a missing function or column (`PGRST202`, `PGRST204`, `42883`, `42703`) and an unknown Realtime event as a cue to run the update check at once.

### W5. A forced refresh during multi-step work loses data or doubles a write

- **Unit A (epic 1, AD-24):** the refresh page can appear at any moment, from the 15-minute timer or on return to the screen.
- **Unit B:** several later epics run work that spans many calls:
  - epic 3's CSV import is 10 calls of 100 rows (AD-8), and its printable sheet is built from the per-row results on the client;
  - uploads of up to 10 MB (epics 4 and 5);
  - sends in epics 5 and 7.
- **AD-26:** a draft is cleared "when its content is sent". The reading most epics will build is "after the server acknowledges".
- **Outcome:**
  - Refresh during an import leaves an unknown number of chunks done, and the sheet's results are lost.
  - Refresh between a committed send and its acknowledgement restores the draft, so the user sends again: a duplicate message, post or submission text.
- **Rule (AD-24 and AD-26):**
  - Epic 1 owns one busy registry (`app/src/` `useBlockingWork`). While it is non-empty, the refresh page shows with Refresh disabled and "Finishing…", up to a 60-second cap.
  - A send clears the draft before the call and restores it on failure, or the draft carries a client uuid that the `_as` function deduplicates on.

### W6. Push subscriptions follow the browser, not the user, on shared school computers

- **Unit A (epic 6):** `push_devices` has no uniqueness rule in AD-14. Two schemas are natural: `unique (user_id, endpoint)`, or a plain insert.
- **Unit B (epic 2, AD-14):** `unregister_push_device` runs "at sign-out" and needs a JWT. A session that expired, an account the admin deleted, or a sign-out while offline never unregisters. The browser's `PushSubscription` survives all of these.
- **Outcome:** user B signs in on the same lab computer and registers the same endpoint. With `(user_id, endpoint)`, both rows exist, so user A's notifications appear on user B's screen, including chat text. This is the exact risk AD-26 names ("the next user of a shared school computer").
- **Rule (AD-14):**
  - `push_devices` has `unique (endpoint)`. `register_push_device` upserts on it and reassigns `user_id`.
  - Sign-out calls `PushSubscription.unsubscribe()` locally first, whatever the network does, so the push service reports 410 and `send-push` removes the row.

### W7. Sign-out has three participants, no owner and no order

- **Units:**
  - epic 2 owns the session and the screens, and builds the sign-out action;
  - epic 6 must call `unregister_push_device` before `auth.signOut()`, while the JWT is still valid;
  - epic 1's hook must wipe `fermi:draft:*` after sign-out.
- **Gap:** no AD or epic-map row owns `signOut()`. Each epic will attach its step where it finds one: a button handler, a Zustand action, or an `onAuthStateChange`.
- **Outcome:**
  - If the wipe sits in the button handler, an expired session, an admin deletion (AD-16) or a sign-out in another tab never wipes. supabase-js signs out other tabs, but `sessionStorage` is per tab.
  - If unregister sits after `signOut()`, it always fails.
- **Rule:**
  - Epic 2 owns `app/src/api/auth.ts` `signOut()` with ordered steps: (1) push unregister and local unsubscribe, (2) `auth.signOut()`, (3) draft wipe.
  - The draft wipe also runs on every `SIGNED_OUT` event in each tab.
  - Add a "Sign-out" seam (2 ↔ 1, 6) to the epic map.

### W8. Where a notification click goes is defined nowhere, and epic 6 ships before the screens it opens

- **Unit A (epic 6):** it builds `sw.js` `notificationclick`, the R17 pop-up and the R14 inbox. That is three entry points that each map a kind to a screen. AD-14 gives `notify(recipients, kind, ref)`, but not what `ref` is per kind or which route each kind opens.
- **Unit B (epics 4, 7, 12):**
  - epic 4 will route `/classes/:classId/assignments/:id`, while `ref` is likely just an assignment id;
  - epic 7's announcement screens and epic 12's removal-request screen do not exist when epic 6 ships (epic 7 needs 6; epic 12 comes later).
- **Outcome:** `send-push` cannot build a URL without a second query that AD-5 does not name. The three entry points pick different targets, and the kinds whose epics come later get no target.
- **Rule (AD-14):**
  - Add a table of each kind, its `ref` type and the epic that owns its screen.
  - One in-app route, `/open/<kind>/<ref>`, owned by epic 6, resolves under RLS and redirects. Each screen-owning epic adds its kind's resolver.
  - The push payload carries that URL. The service worker opens or focuses it as is, and the inbox and the pop-up use the same route.

## MEDIUM

### W9. AD-20 covers SQL shapes only, but stale code also reads functions, events, push payloads and routes

- **Functions:** edge functions deploy before the build (AD-21), so an old tab calls the new `add-students` with the old body.
- **Realtime:** an AD-19 zod union in an old tab strictly parses a new event and throws.
- **Service worker:** an old `sw.js` waiting to update (W10) reads a new push payload.
- **Routes:** "Refresh reloads the current URL" lands on a route the new build removed. Bookmarks, the Home Screen `start_url` and push URLs (W8) carry old routes too.
- **Rule (AD-20):** expand-then-contract also covers:
  - edge-function request and response bodies;
  - Realtime event payloads (old clients ignore unknown types);
  - push payloads;
  - app route paths (a removed route redirects for one deploy cycle, per W4).

### W10. AD-25's handler whitelist rules out what epic 6 needs

- **Unit A (AD-25):** the service worker "handles `push` and `notificationclick` only".
- **Unit B (epic 6):**
  - Its open question (iOS drops subscriptions silently) points to a `pushsubscriptionchange` handler, or to re-registering on every start.
  - Without `skipWaiting()` and `clients.claim()` in `install` or `activate`, a Home Screen app that is suspended but never closed keeps the old `sw.js`, with old click routing, indefinitely.
- **Rule:** restate AD-25 as an invariant. The service worker has no `fetch` handler and no Cache Storage, and imports no scripts. It may handle `install` and `activate` (`skipWaiting`, `clients.claim`), `push`, `notificationclick` and `pushsubscriptionchange`. This also belongs in the over-specification section (O1).

### W11. The My-Love reference that epics 1 and 6 copy breaks AD-24 and AD-25

- **What My-Love does:**
  - `vite-plugin-pwa` with `injectManifest`, `precacheAndRoute(self.__WB_MANIFEST)`, `registerType: 'autoUpdate'` and `injectRegister: 'auto'`, so it registers on load, not from push code;
  - a `manifest` block, so the plugin writes a second manifest beside story 1.15's;
  - `public/_headers` for `/updates/*`;
  - `src/services/nativeUpdates.ts`, a Capgo live update.
- **Fermi's references to it:** epic map row 1 "Uses" still says "My-Love's deploy, update check and test layout". epic-platform-baseline.md line 82 cites `nativeUpdates.ts`.
- **Outcome:** an epic-6 agent working "on My-Love's model" builds a caching, auto-registered service worker and a second manifest writer.
- **Rule:**
  - Epic map row 1 drops "update check" from Uses.
  - AD-25 adds: `sw.js` is a hand-written file in `app/public/`; no `vite-plugin-pwa` or Workbox; the manifest has one writer, story 1.15's file.

### W12. Draft screen keys have no namespace and no rule for new rows or several fields

- **Units:** epics 3, 4, 7 and 8 each have per-class forms ("new assignment", "new board", "new behavior", "edit class"). Nothing stops two of them choosing `class:<id>:new`. One "new assignment" key without the class id carries a draft from class A into class B's form, where it is published to the wrong class.
- **Several fields:** AD-26 keys by "screen and its row". An assignment form has a title, instructions, a due date and points. One key per screen cannot hold them, and the hook covers text only, so the date and selects are lost. The form comes back half restored, and the user may publish it without a due date.
- **Rule (AD-26):**
  - Keys come only from `draftKey(feature, …scopeIds, field)` in one module. `feature` is a closed union of the `app/src/features/<area>` folders, each owned by one epic.
  - A new-row key includes the parent scope's id.
  - The hook stores any JSON-serializable field value, not only text.

### W13. Drafts have no defined behavior when signed out or while the session is loading

- **Unit A (AD-26):** the key needs `<user id>`.
- **Unit B (epic 2):**
  - The student sign-in email field has no user.
  - After a reload, the session is resolved asynchronously (`INITIAL_SESSION`), so a field mounted first reads or writes `fermi:draft:undefined:…`.
  - On the Google OAuth callback route, the refresh page can appear after the code exchange, and Refresh reloads a URL whose code has already been used. The Home Screen return path is already UNVERIFIED in the Open Questions.
- **Rule:**
  - The hook reads and writes only after the auth state resolves.
  - Signed-out screens are exempt, or use `anon` keys that are wiped at sign-in.
  - The callback route clears its query (`history.replaceState`) before the update check may show the page, and the refresh page on auth routes reloads `/`.

### W14. A refresh cannot restore drafts in forms that have no URL

- **Unit A (AD-24):** "Refresh reloads the current URL."
- **Unit B (any epic):** a composer in a modal, a dialog or a wizard step whose open state is not in the URL.
- **Outcome:** after the refresh, the field is not mounted, so the draft is orphaned. It comes back stale the next time the dialog opens.
  - Edit forms: AD-26 clears only on send or save, so a cancelled edit's draft later overrides the server's value without any sign.
- **Rule (AD-26):**
  - Every form with a draft can be reached by URL, for example `?compose=`.
  - The hook clears on cancel or discard.
  - A restored draft shows a "Restored" marker with Discard.

### W15. Files picked before a refresh are lost, and submissions are then frozen without them

- **Unit A (AD-26):** "files picked but not yet sent" are never kept.
- **Unit B (epic 4, AD-13):** `submission-files` allows "none after submit".
- **Outcome:** after a refresh, a student's submission text comes back without its files. The student submits, and can no longer attach them.
- **Rule (AD-26):** the draft records the picked file names. The restored form lists them as "not attached, pick again" and blocks submit until each is re-picked or removed.

### W16. The refresh page as an overlay versus as a replacement of the app

- **AD-24 says** the page "replaces the whole screen". That reads two ways:
  - As an overlay above a mounted tree: epic 2's heartbeat, Realtime and timers keep calling with the old build (feeds W4).
  - As a replacement: presence turns red after 2 minutes on the refresh page.
- **Rule (AD-24):**
  - The page renders at the root in place of the router and every provider, and tears down subscriptions and timers.
  - The red presence dot is accepted.
  - The page needs no session.

### W17. Old hashed chunks are answered with the SPA fallback after a deploy

- **Unit A (`wrangler.jsonc`):** `not_found_handling: "single-page-application"`. Cloudflare Workers assets serve only the deployed version's files. That is UNVERIFIED in this review against the Cloudflare docs; it rests on Workers' per-version asset manifest.
- **Unit B (any epic):** an epic that adds route-level `lazy()` imports. None exist today; `grep` over `app/src` finds only test imports.
- **Outcome:** a tab that is minutes stale loads `/assets/old-chunk.js`, receives `index.html` with status 200, fails with a module MIME error and shows a white screen until the next check.
- **Rule (AD-24):** a failed dynamic import runs the update check at once.

### W18. Rolling back by hand is undone by the daily deploy

- `wrangler rollback` serves the previous `latest.json`. Clients refresh onto the old build, which works because AD-24 compares "different", not "newer".
- The daily gate (`deploy-gate.sh`) then sees that the live commit is not main's and redeploys main within a day. Migrations are never rolled back.
- **Rule (AD-21):** a rollback is a revert commit on main, never `wrangler rollback`.

## LOW

### W19. A relative path to latest.json fails silently on deep routes

- Every AD writes `updates/latest.json` without a leading slash. A relative fetch from `/classes/x/` hits the SPA fallback, which returns HTML. That is "malformed", so the app "shows nothing", and AD-24 makes this failure invisible.
- **Rule:** fetch `/updates/latest.json` as an absolute path. Story 1.16's Playwright spec runs the check from a deep route.

### W20. The health check does not prove AD-25

- **Rule (AD-21 extension):**
  - assert `Cache-Control` has `max-age=0` on `/` and `/updates/latest.json`;
  - once epic 6 ships, assert `/sw.js` answers as JavaScript, not HTML, and has no `fetch` listener.

### W21. A push and the pop-up both fire while Fermi is in front

- Safari expects a shown notification for every push. Not showing one risks the subscription being revoked (UNVERIFIED). As a result, a focused user also gets the R17 pop-up.
- This sits inside epic 6, but AD-14 should decide it, for example: the pop-up yields to the push notification for kinds that are delivered by push.

### W22. send-push is a third writer of push_devices

- AD-14 says devices change only through register and unregister, but `send-push` deletes subscriptions that report 404 or 410.
- **Rule:** name `internal.remove_gone_push_target(endpoint)` as the one RPC the handler uses (AD-5, "queries only the RPCs it names").

### W23. Names and coverage drift

- Stories 1.15 and 1.16 say "Fermi+", while AD-24's copy says "Fermi". The manifest name is "Fermi+" by design, so the refresh copy should be decided in one place.
- Epic 1 `covers` R11 (iPhone web push, epic 6's) and R25 (the landing page, epic 2's), presumably for the manifest part. Say so in the epic.

### W24. The scripts still have the native shape

- `check-site.sh` still requires `min_native_build`, `url` and `checksum` and exits 2 when `app/MIN_NATIVE_BUILD` is absent.
- `package-live-update.sh` still zips and calls `check-native-build.sh`.
- `deploy.yml`'s comments still describe the iOS shell.
- Story 1.14 covers all of this. Its hitl precondition (the spine amended first) is now met, so its hitl can go off. This is an observation, not a spine change.

### W25. The check moments may miss a page restored from the back-forward cache

- A page restored from the back-forward cache fires `pageshow` (`persisted`). Whether `visibilitychange` also fires in Safari's Home Screen mode is UNVERIFIED.
- **Rule:** also check on `pageshow` and `online`.

## Over-specified: move to Deferred or loosen

- **O1. AD-25's handler list:** keep the invariant (no `fetch`, no caches) and drop the whitelist (W10).
- **O2. AD-26's "every text input and text area":**
  - Search boxes, filters and a "type DELETE to confirm" field (epic 12) should not be restored.
  - Scope the rule to content fields: messages, posts, replies, assignment and submission text, `display_name`, and event fields. Defer the per-epic list to each epic.
- **O3. AD-24's exact copy and button count:**
  - The architectural rule is "full screen, cannot be dismissed, one action, no session needed".
  - The wording belongs in story 1.16 and R23, which disagree today (W2, W23).
- **O4. AD-25's sentence about Cloudflare's default `Cache-Control`:** prose cannot fail. Make it a health-check assertion (W20) and remove it from the rule text.
