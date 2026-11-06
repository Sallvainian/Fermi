---
review: adversarial
target: architecture-capacitor-supabase-port.md, Consistency Conventions "Tests" row (line 312), amendment of 2026-11-06 (second)
lens: two units that each obey every AD to the letter yet build incompatibly
date: 2026-11-06
scope: the Tests-row change and what it touches (AD-13 Drive picker, AD-14 send-push and push_devices, AD-18 live update and MIN_NATIVE_BUILD, the NativeAuth sheet in Open Questions); epic tickets for epic-platform-baseline, epic-invite-sign-in, epic-assignments-grades, epic-notifications, epic-app-store-release; the initiative ticket's Apple Developer touch point
prior: reviews/review-adversarial-update-2026-11-06.md (U1-U7); none repeated here
---

# Adversarial review: the Tests row moves native checks to the Simulator

## Verdict

**The direction is right, but the change does not yet bind on its own.** Moving the native-only checks into the iOS Simulator, each in the epic that builds the path, removes the "who checks it on TestFlight before TestFlight exists" problem. Three things still undo it:

1. AD-18's own wording still sends every native change out as an App Store build, so epics 1, 2 and 6 each need one.
2. The epic-notifications ticket still names TestFlight as its done line.
3. AD-14 does not say where a device row's APNs environment comes from, or what counts as a token that is gone. The Tests row now puts the first production push at epic 13, so epic-notifications and epic-app-store-release can build to different answers and only find out at the first TestFlight build.

**Sources read in full:** the spine (451 lines, `wc -l`); the `git diff` of the spine (the Tests row only); the five epic tickets; epic-platform-baseline's `tickets/tickets.toml` (stories 2, 9 and 10 used); and the initiative ticket's touch points (line 104) and decisions (lines 136 and 142).

**Also read:**
- the epic map rows 1, 4 and 6 and its seams;
- the prior adversarial review;
- the reference code the epics will copy: My-Love's `ios/App/App/PushEnvironment.swift`, `ios/App/App/NativeAuth.swift`, `ios/App/App/App.entitlements`, `supabase/functions/send-push/apns.ts` and the gone-token comment in `handler.ts`;
- Fermi's current Flutter `ios/Runner/Runner.entitlements`.

Apple behaviour I did not confirm on Apple's own pages is marked UNVERIFIED.

---

## High

### N1. AD-18 still requires an App Store build for every native change, so epics 1, 2 and 6 each need one before epic 13

- **Unit A (epic-platform-baseline, story 10):** it adds `@capgo/capacitor-updater`. Its own text says this "is a native change, so it raises MIN_NATIVE_BUILD and needs a new native build (AD-18)". AD-18 says that change "ships as an App Store build". Epic 1's boundary says "Out: TestFlight and App Store builds (epic-app-store-release)". The story obeys the Tests row but cannot obey AD-18 as written.
- **Unit B (epic-invite-sign-in):** it adds the NativeAuth plugin (ASWebAuthenticationSession, native Swift, as in My-Love's `NativeAuth.swift`). That is a native change, so under AD-18 it "ships as an App Store build". A story author who reads AD-18 literally plans a TestFlight/App Store upload in epic 2.
- **Unit C (epic-notifications):** it adds `@capacitor/push-notifications`, a push-environment plugin (N2) and the `aps-environment` entitlement. These are three native changes, so the same AD-18 rule applies.
- **Collision:** the Tests row says the first TestFlight build is epic 13's. AD-18 says each of epics 1, 2 and 6 ships its native change as an App Store build. Both are rules in the spine. An author can satisfy either one, but not both, and the next epic inherits a build history that differs depending on which they picked. This is also the yes answer to "does anything let an epic before 13 need a TestFlight build anyway?"
- **Fix (tighten AD-18):** "Until epic-app-store-release, no native build leaves the Simulator. A native change raises `MIN_NATIVE_BUILD` and the project's build number together (N4), and is checked in the Simulator by its epic. Epic-app-store-release's first TestFlight build carries every native change made before it. From then on, a native change ships as an App Store build."

### N2. Nothing fixes where a device row's APNs environment comes from, so epic 6 and epic 13 can disagree on both the recorder and the entitlement value

AD-14 says `send-push` sends to "`apns` rows (sandbox or production)", and that devices change only through `register_push_device`. It does not say who decides the environment value that call writes.

- **Unit A (epic-notifications):** it builds and checks only the Simulator sandbox path (Tests row). Every rule allows it to take the environment from the web bundle, for example `import.meta.env.DEV ? 'sandbox' : 'production'` or a build-time variable. It could also hard-code `'sandbox'`, the only value it can observe. Its Simulator check passes either way.
- **Unit B (epic-app-store-release):** it archives the first TestFlight build. Following the many guides that say so, it sets the Xcode entitlements file's `aps-environment` to `production` before archiving. Under AD-18 that is an entitlements change, so it is allowed in an App Store build.
- **Collisions:**
  1. **One bundle serves both environments.** Live updates (AD-18) send one web bundle to every native build: Simulator/Xcode installs, which get sandbox tokens, and TestFlight/App Store installs, which get production tokens. All of them register against one hosted project, because the spine has no staging. A value decided in web code is therefore wrong for one of the two populations. The first production push on epic 13's build goes to the sandbox host and is refused with `BadDeviceToken`. If epic 6 hard-coded the value, every row is sandbox.
  2. **The entitlements file.** If epic 13 edits the entitlements file to `production`, development-signed device builds stop signing because the profile does not match (UNVERIFIED for this project; it is standard Xcode behaviour). Epic 6's Simulator workflow is then running on a project another epic changed under it. The usual practice keeps `development` in the file and lets App Store export put the distribution profile's `production` value in (UNVERIFIED on Apple's pages). Nothing in the spine says which practice Fermi follows.
- **The reference already solved this, and the spine does not say so.** My-Love's `PushEnvironment.swift` reads `aps-environment` from the embedded provisioning profile at registration time:
  - `development` maps to sandbox;
  - `production` maps to production;
  - no profile on a device maps to production;
  - no profile on the Simulator maps to sandbox.

  `apns.ts` then picks the host from the row. Its own comment reads: "The environment is read from the device's registration, never from this sender's own signing."
- **Fix (tighten AD-14):** "A device row's APNs environment is reported by the native shell at registration (a `PushEnvironment` plugin reading the embedded profile's `aps-environment`, as in My-Love), passed to `register_push_device`, and never computed in web code or in `send-push`. Epic-notifications owns the plugin and the value. The checked-in entitlements file carries `aps-environment = development`; App Store export supplies `production`, and no epic edits that value."

### N3. The epic-notifications ticket still makes TestFlight its done line (ticket owner: bmad-agent-po)

`tickets/epic-notifications/epic-notifications.md` line 26 reads: "A chat message and an inbox notification reach a closed **TestFlight** iOS app as a push".

That contradicts the new Tests row, which says APNs push to a closed app is checked through the sandbox in the iOS Simulator by this epic, and production first on epic 13's TestFlight build. It also contradicts the initiative ticket (line 104), which keeps TestFlight builds with epic-app-store-release.

As written, epic 6 cannot close without a TestFlight build that epic 13 owns. That is a second yes to "does anything before 13 need TestFlight". The same text is in `tickets/tickets.toml` line 46, which says "reach a closed iOS app as a push".

**Fix (ticket owner):** "reach a closed iOS app in the iOS Simulator as a push through APNs sandbox, sent by hosted `send-push`".

---

## Medium

### N4. `MIN_NATIVE_BUILD` and the app's own build number are two numbers with no single source, and epic 13 numbers its upload

- **Unit A (epic 1, story 2):** it sets the Xcode build number above App Store Connect's last build, and "records that build as MIN_NATIVE_BUILD in one checked-in file". That leaves two copies: the file, and `CURRENT_PROJECT_VERSION` in the `.pbxproj`. In My-Love, `CFBundleVersion` is `$(CURRENT_PROJECT_VERSION)`, which is `1`.
- **Unit B (epic 2 or epic 6):** AD-18 says a native change "raises `MIN_NATIVE_BUILD`". The epic raises the file and leaves `CURRENT_PROJECT_VERSION` alone. The new Simulator build's own build number is now below `min_native_build` in `latest.json`, so it skips every live update. Epic 1's story 10 check ("skips a bundle above its native build") passes. The next epic's live-update restart check in the Simulator then fails for a reason that epic did not cause.
- **Unit C (epic 13):** it numbers its TestFlight upload by its own rule, for example the CI run number or an agvtool bump. Nothing ties that number to `MIN_NATIVE_BUILD`. If the upload number is lower, the first real build skips every live update. If it is much higher, a later native change that "raises" `MIN_NATIVE_BUILD` by one admits bundles the build cannot run.
- **Fix (tighten AD-18):** "The checked-in `MIN_NATIVE_BUILD` file is the one source of the native build number: the Xcode project's `CURRENT_PROJECT_VERSION` and `latest.json`'s `min_native_build` are both read from it. A native change raises it by one, and every App Store upload uses its value."

### N5. "Deletes targets reported gone" is undefined, so a wrong environment deletes rows silently at epic 13

- **Unit A (epic 6):** it implements AD-14's "deletes targets reported gone". Many APNs guides list `400 BadDeviceToken` together with `410 Unregistered` as reasons to remove a token, so epic 6 deletes on both. The sandbox-only Simulator check never produces `BadDeviceToken`, so the choice is never exercised.
- **Unit B (epic 13):** on the first production build, any row whose environment is wrong (N2) gets `BadDeviceToken`. Epic 6's code deletes the row, and push silently stops for that device. A row that is re-registered with the same wrong value is deleted again on the next send. Nothing reaches `job_health`, because the `send-push` call itself returned 2xx.
- **The reference again differs:** My-Love's `handler.ts` says "a 400 `BadDeviceToken` is an environment mismatch, not a dead device", and deletes only on 410 with APNs' timestamp check.
- **Fix (tighten AD-14):** "Gone means APNs 410 `Unregistered` (honouring its timestamp) or web push 404/410. A `BadDeviceToken` deletes nothing and is reported as a failure."

### N6. The Simulator APNs check does not say which path it exercises, and the reference code says the Simulator cannot do it

The Tests row says "APNs push to a closed app through the sandbox" in the iOS Simulator. My-Love's `PushEnvironment.swift`, which epic 6 will copy, says: "The simulator issues no APNs token that Apple would accept in either environment; sandbox is the nearer of the two, and `simctl push` ignores it."

Third-party accounts of Xcode 14's release notes say the opposite: iOS 16+ Simulators on macOS 13+ with Apple silicon or T2 receive remote notifications from the APNs **sandbox only**, with tokens unique to that simulator and Mac. I did not read Apple's page directly, so the exact conditions are UNVERIFIED.

- **Unit A (epic 6):** it trusts the comment it copied. It checks with `xcrun simctl push` and a payload file. A notification appears on a closed app, so the Tests row's words are met. That path bypasses `send-push`, the APNs JWT, the host choice and the device row.
- **Unit B (epic 13):** it finds on the first TestFlight build that hosted `send-push` has never delivered to Apple at all.
- **Fix (tighten the Tests row):** "APNs push to a closed app: hosted `send-push` delivers through `api.sandbox.push.apple.com` to a Simulator registration (Xcode 14+, iOS 16+ Simulator, macOS 13+ on Apple silicon or T2). `simctl push` does not count."

Separately, My-Love's comment is stale. That is an observation for the owner, not a spine change.

### N7. Production APNs failures found at epic 13 have no owner, and epic 13's ticket does not list the check

- **Epic 13's position:**
  - The tickets.toml `after` line for epic 13 needs "push working in the iOS build" from epic 6. Epic 6 can show only the sandbox in the Simulator.
  - Epic 13's boundary is "Out: new features; this epic releases and removes".
  - The production-only branches of N2's plugin (no profile on a device maps to production) and `send-push`'s production host run for the first time there.
- **Collision:** a production failure belongs to epic 6's units, `send-push` and the registration plugin, but surfaces in an epic forbidden to build features, after epic 6 has closed. Each epic can reasonably say the fix belongs to the other.
- **Spine fix (Tests row or AD-14):** "Epic-notifications' `deno test` covers the production host and the production environment value. A production APNs failure on epic-app-store-release's TestFlight build is fixed in epic-app-store-release against epic-notifications' units, as a defect, not a feature."
- **Ticket fix (owner: bmad-agent-po):** epic-app-store-release's Done when has no production APNs line. Add: "A chat message and a notification reach a closed TestFlight install as a production APNs push." Also restate epic 13's `after` reason for epic 6 as "push working in the Simulator through the sandbox".

---

## Low

### N8. The NativeAuth sheet's contract is not fixed between its builder (epic 2) and its second user (epic 4)

The Tests row now gives epic 2 the NativeAuth sheet and epic 4 "the Drive picker page" in it. AD-13 says the picker page is "opened in the NativeAuth sheet".

- **Unit A (epic 2):** it builds a sign-in-shaped plugin, for example one that takes a provider and returns a Supabase session or code. That is compliant.
- **Unit B (epic 4):** it needs the sheet to return a Google `drive.file` token from its own page. To do that it edits epic 2's Swift plugin, which is a native change in another epic's file (AD-18 applies, and so does N1). Or it adds a second sheet plugin, which gives two native paths for the same sheet.
- My-Love's `NativeAuth.swift` is already generic: `start({ url, callbackScheme }) -> { url }`.
- **Fix (add to AD-13 or the Open Questions spike):** "The NativeAuth sheet is one plugin, owned by epic-invite-sign-in, with the generic contract `start({ url, callbackScheme }) -> { url }`. The Drive picker page uses it unchanged."

### N9. Ticket text lags the Tests row (ticket owner: bmad-agent-po)

- **epic-assignments-grades:** its Done when has no iOS line, although the Tests row now assigns it the Drive picker page check in the Simulator. It mentions only the spike.
- **epic-invite-sign-in:** its Done when says "On the deployed site and the iOS build". Under the Tests row that should read "the iOS app in the iOS Simulator", so no one reads it as a TestFlight build.
- **epic-platform-baseline:** line 80 still records "Source conflict: spine Consistency Conventions, Tests ('… checked by hand on TestFlight')". The amendment resolves that conflict, so the note is stale.

### N10. The entitlements a new project inherits, and the Apple Developer setup needed before epic 13

- **Flutter entitlements:** Fermi's current Flutter `ios/Runner/Runner.entitlements` carries `aps-environment = development` and `applesignin`, which suggests the App ID already has Push and Sign in with Apple. It also carries placeholder `applinks:yourdomain.com`, iCloud containers and an app group `group.…com.nianticlabs.pokemongo`. If epic 1's story 2 copies that file into `app/ios`, epic 6's push signing and epic 13's App Review inherit entitlements no AD sanctions. A one-line rule in the Structural Seed or AD-18 would close it: "`app/ios` starts from Capacitor's template entitlements; each entitlement is added by the epic whose path needs it."
- **Apple Developer setup:** the initiative ticket makes epic-app-store-release the owner of the Apple Developer touch point. Epic 6's Simulator push still needs the push key earlier, and epic 2 needs the Sign in with Apple Services ID earlier. Both are already named as sub-owners there, so this holds. One gap: if the APNs key can be scoped to a single environment, a sandbox-only key created for epic 6's check fails production at epic 13 (UNVERIFIED that Apple offers per-environment key scope). The Secrets row could say "the APNs key covers sandbox and production".

---

## Checked and holding

- **No other path before epic 13 needs TestFlight:**
  - The live-update restart check (epic 1, story 10) is fully Simulator-scoped in its verify text.
  - The web-push spike runs on the owner's iPhone as a Home Screen web app, with no native build.
  - Sign in with Apple through the NativeAuth sheet is a web flow, which the Simulator can run.

  N1 and N3 are the only routes that force a TestFlight build.
- **One owner per check:** the Tests row names exactly one epic per native path, and they match the epic map's owners: epic 1 owns the updater, epic 2 the NativeAuth sheet, epic 4 the Drive picker spike, and epic 6 `send-push`.
- **Per-row environment:** AD-14 already keeps the environment per row ("sandbox or production") rather than per function secret. That is what lets one hosted project serve Simulator and TestFlight installs at once. N2 only fixes where the value comes from.
- **Initiative touch point (line 104):** it agrees with the Tests row. TestFlight belongs to epic-app-store-release, and epic-platform-baseline checks in the Simulator.

## Summary of changes proposed

| Hole | Where | Change | Owner |
| --- | --- | --- | --- |
| N1 | AD-18 | no native build leaves the Simulator before epic 13; the first TestFlight build carries all prior native changes | architect |
| N2 | AD-14 | the environment comes from the native shell's embedded `aps-environment` via a plugin; the entitlements file stays `development`; no epic edits it | architect |
| N3 | epic-notifications ticket | done line becomes Simulator plus APNs sandbox via hosted `send-push` | ticket owner |
| N4 | AD-18 | the `MIN_NATIVE_BUILD` file is the one source of the build number | architect |
| N5 | AD-14 | gone means 410 (APNs) or 404/410 (web push); `BadDeviceToken` deletes nothing | architect |
| N6 | Tests row | the Simulator check is a real sandbox delivery from hosted `send-push`; `simctl push` does not count | architect |
| N7 | Tests row or AD-14; epic-app-store-release ticket | production failures are fixed in epic 13 as defects; epic 13 adds a production push done line | architect; ticket owner |
| N8 | AD-13 or Open Questions | one generic NativeAuth plugin contract, owned by epic 2 | architect |
| N9 | three epic tickets | align iOS done lines; drop the stale conflict note | ticket owner |
| N10 | Structural Seed or AD-18; Secrets row | template entitlements only; the APNs key covers both environments (UNVERIFIED) | architect |

Sources for N6's Simulator claim (third-party accounts of the Xcode 14 release notes):
- [Notificare, Testing Push Notifications on iOS Simulator in 2022](https://notificare.com/blog/2022/10/07/testing-push-notifications-ios-simulator-in-2022/)
- [Pushwoosh, iOS Simulator remote push notification support](https://help.pushwoosh.com/hc/en-us/articles/14811143168157-iOS-Simulator-remote-push-notification-support)
- [Xcode 14 summary (davidyoon blog)](https://davidyoon-blog.vercel.app/docs/Posts/DevPosts/Xcode/xcode14)
