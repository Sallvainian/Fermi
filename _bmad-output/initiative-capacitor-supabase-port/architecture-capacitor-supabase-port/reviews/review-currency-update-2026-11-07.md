# Currency review: spine update 2026-11-07 (website and Home Screen web app)

- **Reviewer lens:** each committed decision was checked against current docs, the npm registry, the live site and the repo, not taken from training data.
- **Spine read:** `architecture-capacitor-supabase-port.md`, the working-tree version as of 02:03 on 2026-11-07. It includes the AD-24 `app` / `__APP_ID__` amendment, which landed while this review was running.
- **In scope:** AD-7, AD-13, AD-14, AD-21, AD-23, AD-24, AD-25, AD-26, the Stack table, Deferred and Open Questions.
- **Repo files read:** `app/package.json`, `supabase/config.toml`, `wrangler.jsonc`, `scripts/package-live-update.sh`, `scripts/check-site.sh`, `.github/workflows/*.yml` (CLI pins), `.github/dependabot.yml`, and `app/node_modules/@supabase/auth-js` (2.119.0).
- **Live probe:** `https://fermi-plus.sallvain.workers.dev` with `curl -I`, run 2026-11-07.

**Verdict:** the hosting, caching, service-worker and version facts are correct and current. The update does not handle four platform constraints it now depends on, and each one breaks a requirement if the implementer misses it:
- the hosted Auth redirect allow list;
- what happens when OAuth or the Google token-client popup is used from an iOS standalone web app;
- iOS and Safari revoking the push subscription after silent pushes;
- the default block that Google Workspace for Education puts on third-party apps for students designated under 18.

No critical findings.

---

## High

### H1: The hosted Auth config still sends OAuth to `http://localhost:3000`

- **Where:** AD-7 "Auth config"; AD-21 "Health check".
- **Evidence (repo):** `supabase/config.toml` `[remotes.production.auth]` contains `site_url = "http://localhost:3000"` and `additional_redirect_urls = []`. The comment above it says these are the hosted project's own values as of 2026-11-06. AD-21's deploy runs `supabase config push`, which pushes exactly these values. AD-7's Auth config list (signup, email, anonymous, manual linking) names neither setting, and the health check does not assert either.
- **Evidence (docs):** a `redirectTo` must match the Redirect URLs allow list, and the Site URL is the default destination: https://supabase.com/docs/guides/auth/concepts/redirect-urls. Field reports say a `redirect_to` that is not on the list falls back silently to `site_url`. This is UNVERIFIED in official docs: https://claudskills.com/skills/supabase-oauth-redirect-trap/SKILL.md and https://vibe-eval.com/guides/lovable-forgot-password/.
- **Impact:** with these values, a teacher's Google sign-in on the hosted site comes back to `localhost:3000` (R1, R2). Before 2026-11-07 a native deep link may have hidden this. On the web it is the main path.
- **Fix:**
  - Add to AD-7 Auth config: `site_url = "https://fermi-plus.sallvain.workers.dev"` and `additional_redirect_urls = ["https://fermi-plus.sallvain.workers.dev/**"]`, or an exact callback path, in `[remotes.production.auth]`. Keep local values in `[auth]`.
  - In AD-21, add a health-check assertion that the Management API's `site_url` and `uri_allow_list` equal those values.
  - In the same AD-7 line, name the Google Cloud OAuth client's settings that are fixed by the domain: the Supabase callback `https://<ref>.supabase.co/auth/v1/callback` as a redirect URI, and `https://fermi-plus.sallvain.workers.dev` as an Authorized JavaScript origin. The second one is needed by the Google token client in AD-13.

### H2: Google sign-in from the iOS Home Screen web app has no committed fallback, and the flow type is not pinned

- **Where:** AD-7 "Sign-in screen"; Open Questions (epic-invite-sign-in spike 3); Tests convention.
- **Evidence:**
  - A Home Screen web app keeps storage separate from Safari: https://bugs.webkit.org/show_bug.cgi?id=181849 (open).
  - Developer reports from September and October 2026 say an OAuth navigation out of an installed iOS web app is handed to Safari or a Safari sheet. The callback then lands there, not in the app, and the app stays signed out:
    - https://github.com/bulwarkmail/webmail/issues/1267 (opened 2026-10-17, still open);
    - https://github.com/rachittnh-sys-the-neighbourhood/the-neighbourhood-mobile/pull/51 (2026-09-29; it detects `document.referrer` from Supabase auth combined with not standalone);
    - https://github.com/RobertM05/hex-catan-multiplayer/issues/228 (PKCE `code_verifier` lost on redirect).
  - None of these were tested on a device by this reviewer, so the exact routing is still UNVERIFIED, as the spine says.
  - `app/node_modules/@supabase/auth-js` 2.119.0 defaults to `flowType: 'implicit'` (`GoTrueClient.js:21`), and `app/src/api/client.ts` sets no `flowType`.
    - With PKCE, the verifier sits in the app's localStorage, so a callback in Safari fails.
    - With implicit, Safari, not the app, ends up signed in.
- **Impact:** R1 for a teacher or the admin on the iPhone Home Screen app may be impossible with the plain redirect flow. Students are not affected, because they use a password. The spine lists the spike but does not decide what happens if it fails. Epic-invite-sign-in would then need an architecture decision in the middle of the epic.
- **Fix:**
  - Pin `flowType: 'pkce'` in AD-7. The OAuth security BCP discourages the implicit grant (https://www.rfc-editor.org/rfc/rfc9700). It also makes a callback in the wrong context fail loudly instead of signing in the wrong one.
  - Commit the fallback now, as an AD-7 sub-rule. Proposed text: "If the spike shows the callback leaves the Home Screen web app, the teacher button in standalone mode tells the teacher to sign in once in Safari at fermi-plus.sallvain.workers.dev, then add Fermi to the Home Screen again. A callback page that detects it is not standalone after an OAuth return shows that instruction. No session hand-off between contexts is built."
  - Alternatively, name a one-time-code hand-off as a deferred option with its owner. Either way, record that the hand-off needs no new edge function, or say which existing one (AD-5) it would use.

### H3: The Drive token client is popup-only, and students may be blocked from it outright

- **Where:** AD-13 "Drive"; Open Questions (epic-assignments-grades spike); R6 (students submit files from Google Drive).
- **Evidence:**
  - The Google Identity Services token model supports "only the dialog UX", which means a popup: https://developers.google.com/identity/oauth2/web/guides/use-token-model.
  - `TokenClientConfig` has no `ux_mode` or `redirect_uri`. Only `CodeClientConfig` has `ux_mode: popup | redirect`, and that needs a server-side code exchange: https://developers.google.com/identity/oauth2/web/reference/js-reference.
  - Reports say that iOS standalone popups open where the app cannot reach them, so the callback never fires: https://github.com/SaharAga/SpotLi/pull/231 and https://developer.apple.com/forums/thread/759487 (`window.opener` null from iOS 17.5, reported for WKWebView). Whether this happens in a Home Screen web app is UNVERIFIED.
  - Google Workspace blocks unconfigured third-party apps by default for users designated under 18. An admin must configure the app before students can grant it Drive access: https://support.google.com/a/answer/13288950. Vendor notices from the 2023-10-23 rollout say students "would be blocked from binding to their Google Drive". Whether Fermi's school designates its students as under 18 is UNVERIFIED.
  - The Picker needs a browser API key, restricted to the app's origin and `https://docs.google.com/*`. It also needs `setAppId(<project number>)`, from the same project as the OAuth client, so that `drive.file` covers the picked file: https://developers.google.com/workspace/drive/picker/guides/web-picker and https://developers.google.com/drive/picker/guides/sample.
- **Impact:**
  - "The same in a browser tab and in the Home Screen web app" is asserted, not checked, and the token model offers no redirect to fall back on.
  - Separately, student Drive submissions (R6) could fail in every client unless the school's Workspace admin configures Fermi-Plus as Trusted, or as Limited with Drive unrestricted.
- **Fix:**
  - Amend AD-13: "Drive attach is offered only where the token client completes. In the Home Screen web app it is shown only after epic-assignments-grades' spike passes, and otherwise is hidden there (device files remain)."
  - Add an Open Question with an owner (epic-assignments-grades): "Does the school's Workspace allow students designated under 18 to grant `drive.file` to Fermi-Plus (`fermi-plus-513902`)? If not, the school admin configures the app, or student Drive attach is dropped and R6 is re-rendered."
  - Add the Picker's API key and App ID to the Secrets convention as public client configuration (`VITE_*`), restricted by referrer, not secrets.
  - Note that on iOS, `<input type="file">` opens the Files picker. It can include Google Drive through the Drive app's file provider, which makes it a no-OAuth fallback for device uploads. Whether it exports native Docs is UNVERIFIED.

### H4: A push that shows no notification gets the subscription revoked, and AD-25 does not forbid it

- **Where:** AD-25 rule; AD-14 delivery; Open Questions ("a subscription iOS dropped without warning").
- **Evidence:**
  - WebKit enforces `userVisibleOnly` with a quota of three. A push event that does not post a notification in time, or whose promise rejects, counts against it, and at three the subscription is removed: https://webkit.googlesource.com/WebKit/+/108ccb442e40e9705d212e74c1f213e3b5a0ea05.
  - Field write-ups describe the same: https://dev.to/progressier/how-to-fix-ios-push-subscriptions-being-terminated-after-3-notifications-39a7 and https://meta.discourse.org/t/ios-notifications-can-lose-permission-to-push-if-the-user-is-currently-active/290225. Discourse lost subscriptions by skipping notifications while the user was active.
  - Chrome requires every push to cause a notification, per an older MDN-derived reference (https://reference.codeproject.com/dom/Push_API). The generic "site updated in the background" notice Chrome shows instead is from memory and UNVERIFIED here.
- **Impact:** a natural implementation suppresses the OS notification when the app is focused, because R17's in-app pop-up already shows. That revokes iOS and Safari subscriptions after three messages. This is a known, documented cause of the "dropped without warning" symptom the spine leaves open.
- **Fix:**
  - Add to AD-25: "The `push` handler calls `self.registration.showNotification` inside `event.waitUntil` for every push, whether or not a Fermi window is focused. Nothing filters on focus or kind in the service worker, and every suppression (DND) happens in `internal.push_targets` before sending. A `deno test` or Vitest test on the handler asserts that every push path shows a notification."
  - In Open Questions, tell the epic-notifications spike to rule out this cause first.

---

## Medium

### M1: AD-25 and AD-14 leave out the iOS preconditions for web push

- **Where:** AD-25, AD-14 "Web push is offered…", Structural Seed (`public/` manifest).
- **Evidence:**
  - WebKit's requirements are iOS or iPadOS 16.4 or later, an app added to the Home Screen, a manifest with `display` set to `standalone` or `fullscreen`, and a permission request "in response to direct user interaction": https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/.
  - The Push API is not exposed in an iOS Safari tab: https://pushpad.xyz/blog/ios-special-requirements-for-web-push-notifications.
  - iOS 26 opens every Home Screen bookmark as a web app by default ("Open as Web App"): https://heise.de/-10749652 and https://www.macrumors.com/2025/06/18/safari-changes-on-ios-26/. Whether iOS 26 also drops the manifest requirement for push is UNVERIFIED.
  - A push-only service worker with no `fetch` handler is enough for push in Chrome, Edge and Safari. Push needs only an active registration. Chrome dropped the fetch-handler requirement for menu installs in Chrome 108 (mobile) and 112 (desktop), though its automatic install prompt still needs one: https://developer.chrome.com/blog/update-install-criteria. R25 is iPhone-only, so AD-25's choice holds.
- **Fix:**
  - Add to AD-25: "The manifest (story 1.15) has `display: standalone`, `scope: /`, `start_url: /` and a stable `id`. Fermi asks for notification permission only from a tap on a Fermi button, never on load. On iPhone the button appears only when `navigator.standalone` or `matchMedia('(display-mode: standalone)')` is true and `'PushManager' in window`. Otherwise the R25 'add to Home Screen' guidance shows."
  - State a supported iOS floor, either 16.4 for push or 18.4 if M2 is adopted.

### M2: Declarative Web Push is not considered

- **Where:** AD-25; AD-14 payload.
- **Evidence:** Declarative Web Push shipped in iOS and iPadOS 18.4 for Home Screen web apps and in Safari 18.5 on macOS. A payload with `"web_push": 8030` and `notification.title` / `navigate` is shown by the system even if the service worker fails. An installed service worker still receives the `push` event, and older browsers handle the same JSON imperatively: https://webkit.org/blog/16535/meet-declarative-web-push/ and https://www.mactech.com/2025/05/12/with-safari-18-5-included-in-macos-15-5-apple-added-declarative-web-push.
- **Fix:** add to AD-14: "`send-push` encodes every payload in the declarative format (`web_push: 8030`, title, body, `navigate` to the deep link). `sw.js` reads the same JSON." This keeps AD-25's single service worker. It also gives iOS 18.4+ a system fallback that cannot trip H4's quota. Chrome and Edge support for the declarative path is UNVERIFIED, but they receive it as a normal push event.

### M3: The health check would accept a missing `sw.js` or manifest

- **Where:** AD-21 "Health check"; AD-25.
- **Evidence (live, 2026-11-07):**
  - `GET /sw.js` (not deployed yet) returned `200 content-type: text/html`, the SPA fallback (`wrangler.jsonc` `not_found_handling: single-page-application`). It did the same with `Service-Worker: script` headers. `/manifest.webmanifest` also returned `200 text/html`.
  - Real assets are correct: `/assets/index-*.js` is served as `text/javascript`, and `/updates/latest.json` as `application/json`. Both carry `cache-control: public, max-age=0, must-revalidate` and an ETag.
  - Wrangler sets Content-Type from the file extension: https://developers.cloudflare.com/workers/static-assets/headers/.
- **Impact:**
  - A build that drops `sw.js` deploys green, and every push registration then fails with a MIME error.
  - Deleting `sw.js` never removes an installed worker, because the update fetch gets HTML.
- **Fix:**
  - In AD-21, say that epic-notifications adds a health-check assertion that `/sw.js` answers 200 with a JavaScript content type. Story 1.15 adds one that `/manifest.webmanifest` answers 200 with `application/manifest+json` (UNVERIFIED that wrangler maps `.webmanifest` to that type; check it on first deploy).
  - Add to AD-25: "`sw.js` is never deleted. Retiring it means shipping a `sw.js` that unregisters itself."

### M4: web-push, 3.6.7 versus 4.0.0, on Deno

- **Where:** Stack "web-push (in send-push) 3.6.7"; Deferred "web-push 4.x".
- **Evidence (npm registry, GitHub):**
  - 3.6.7 was published 2024-01-16 with deps `jws ^4.0.0`, `asn1.js ^5.3.0`, `http_ece 1.2.0`, `https-proxy-agent ^7.0.0` and `minimist`.
  - 4.0.0 was published 2026-11-06T11:44Z and is `latest`. It is `"type": "module"` (ESM-only, #961), refactored to classes (#966), uses `parseArgs` in place of `minimist` for the CLI, and moves to `https-proxy-agent ^9.1.0` and `http_ece 1.2.1`.
  - The 4.0.0 lockfile refresh (#999) addressed `bn.js` GHSA-378v-28hj-76wf through `asn1.js`. Its author found no reachable path through web-push, and the published ranges already let 3.6.7 resolve the fixed `bn.js`.
  - The compare `v3.6.7...v4.0.0` lists no protocol change: https://github.com/web-push-libs/web-push/compare/v3.6.7...v4.0.0 and https://github.com/web-push-libs/web-push/pull/999.
  - Deno: payloads sent with `npm:web-push` failed to decrypt until Deno's fix of 2024-08-28 (https://github.com/denoland/deno/issues/23693 and https://github.com/web-push-libs/web-push/issues/904). Hosted edge functions run Deno 2.1 (https://supabase.com/changelog?tags=edge+functions), and `supabase/config.toml` sets `deno_version = 2`. That 3.6.7 encrypts correctly on today's hosted runtime is UNVERIFIED end to end.
  - Apple's push service rejects VAPID subjects such as `mailto:user@localhost` with `403 BadJwtToken`: https://github.com/web-push-libs/web-push/pull/988.
- **Assessment:** holding 3.6.7 is reasonable, and ESM-only is no obstacle on Deno.
- **Fix:**
  - The epic-notifications spike sends an encrypted payload, not an empty push, with whichever version it adopts, to Chrome and to iOS.
  - Pin it as `npm:web-push@<exact>` with a committed `deno.lock` under `supabase/functions`.
  - Add to AD-14 or the Secrets row: "VAPID subject is `mailto:<owner address>` or `https://fermi-plus.sallvain.workers.dev`, never a localhost address."
  - Note that Dependabot is configured only for `app/` npm and Actions (`.github/dependabot.yml`), so nothing will report an advisory against the edge function's pin. Add a reminder to the Deferred line, or have `dependency-review` cover `supabase/functions`. Whether Dependabot supports Deno is UNVERIFIED.

---

## Low

### L1: sessionStorage behaves as AD-26 assumes, with two caveats

- **Evidence:** "A page session lasts as long as the tab or the browser is open, and survives over page reloads and restores". A page with an `opener` starts with a copy of the opener's sessionStorage, and closing the tab clears it: https://developer.mozilla.org/en-US/docs/Web/API/Window/sessionStorage. Desktop behavior on `location.reload()` is therefore guaranteed by the spec and the per-tab isolation holds.
- **Caveats:**
  - Same-origin windows opened with an opener copy the drafts. Duplicating a tab also copies them in Chrome, which is reported but UNVERIFIED here. Two tabs can then each hold a copy of the same draft key, and AD-26 does not say which one wins.
  - Whether iOS keeps sessionStorage when it evicts a suspended Home Screen web app and relaunches it is UNVERIFIED. If iOS drops it, a user does not see that as "closing".
- **Fix:** amend AD-26 Restore: "…closing it, or iOS ending a suspended Home Screen web app, drops the drafts". Open same-origin windows with `noopener`. Accept last-write-wins for duplicated tabs.

### L2: Safari tab storage and Home Screen storage

- **Evidence:** Home Screen web apps keep storage separate from Safari: https://bugs.webkit.org/show_bug.cgi?id=181849. WebKit caps script-writable storage for websites at 7 days without use and exempts Home Screen web apps: https://webkit.org/blog/10218/full-third-party-cookie-blocking-and-more/.
- **Impact:**
  - The supabase-js session lives in localStorage. A Safari-tab user who stays away for 7 days is signed out.
  - A user who signs in in Safari and then adds Fermi to the Home Screen must sign in again there.
- **Fix:** in R25's landing copy (epic-invite-sign-in), say "add to the Home Screen first, then sign in there". No change to the spine is needed beyond a Tests-row mention.

### L3: Stack table against `app/package.json` and the registry (checked 2026-11-07)

- **Matches `app/package.json` exactly:** supabase-js 2.119.0, React and react-dom 19.3.1, react-router 8.5.1, Vite 8.3.6, plugin-react 6.2.1, TypeScript 6.0.3, typescript-eslint 8.72.1, Tailwind 4.3.4, Zustand 5.0.16, zod 4.6.7, Vitest 5.1.0, wrangler 4.158.0.
- **Supabase CLI:** 2.122.0 matches `deploy.yml` (three jobs) and `backup.yml`.
- **Newer since:**
  - Tailwind 4.3.5 and Zustand 5.1.0, both published 2026-11-06. Dependabot's weekly groups cover them.
  - npm `supabase` `v2.stable` is 2.122.1. Its release notes say "The CLI is unchanged from v2.122.0", so 2.122.0 is fine (https://github.com/supabase/cli/releases/tag/v2.122.1).
  - TypeScript 7.0.2 is `latest`, but typescript-eslint 8.72.1 still peers `typescript >=4.8.4 <6.1.0`, so 6.0.3 is still right.
- **Expected leftovers:** `@capacitor/core`, `@capacitor/ios` and `@capacitor/cli` 8.6.0 are still in `app/package.json`, along with the `native` Dependabot group and `scripts/package-live-update.sh`'s zip and `min_native_build`. These are expected until story 1.14, and the Stack correctly omits them.
- **Not versioned:** Google Identity Services (`accounts.google.com/gsi/client`) and the Picker (`apis.google.com/js/api.js`) are loaded unversioned from Google.
- **Fix:** add a Stack row "Google Identity Services, Picker: Google-hosted, unversioned". Optionally add Node 24 (`app/.node-version`).

### L4: The AD-24 `app` id refreshes users for changes that do not alter the bundle, and misses some that do

- **Evidence:** `app` is `git log -1 -- app/`.
  - Dependabot merges that touch only `app/package.json` dev dependencies, such as eslint or vitest, change `app` and show every user the refresh page after the next daily deploy. `app/tests/**` edits do the same.
  - `VITE_*` values set in `deploy.yml` (for example `VITE_SUPABASE_URL`, and a future Google client ID or Picker key) change the bundle without changing `app/`.
- **Fix:** either exclude paths that cannot reach the bundle (`git log -1 -- app/ ':!app/tests' ':!app/eslint.config.*'`), or accept the noise and say so. In AD-24, state that a change to a `VITE_*` value in `deploy.yml` goes with an `app/` change.

### L5: Things checked and found accurate

- **Cloudflare cache header:** the default `Cache-Control: public, max-age=0, must-revalidate` (sent when the request has no `Authorization` or `Range` header), with an ETag, is confirmed by the docs (https://developers.cloudflare.com/workers/static-assets/headers/) and by live headers on `/`, `/assets/*.js` and `/updates/latest.json`. AD-25's claim holds.
- **JavaScript content type:** Workers serve `.js` as `text/javascript`, a valid service-worker script type (live probe).
- **Drive export cap:** "the exported content is limited to 10 MB": https://developers.google.com/workspace/drive/api/reference/rest/v3/files/export.
- **Deno runtime:** the edge runtime is Deno 2.1 hosted (changelog above), with `deno_version = 2` locally.
- **Declarative Web Push:** iOS 18.4 and macOS Safari 18.5 (see M2).
- **iOS web push floor:** iOS 16.4 (see M1).
