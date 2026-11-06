# Review: Currency of the Simulator Amendment to the Tests Convention

- **Artifact:** `architecture-capacitor-supabase-port.md`, uncommitted diff to the Consistency Conventions "Tests" row (line 312), read alongside AD-14 (`send-push`, `apns` sandbox/production rows), AD-18 (live-update restart through `@capgo/capacitor-updater`), the NativeAuth sheet (AD-13 Drive picker, Open Questions), and `.memlog.md` lines 108-110
- **Lens:** was each committed decision web-researched or reality-checked, or asserted from training data? Does each named technology still exist and fit?
- **Reviewed:** 2026-11-06
- **Verdict:** The row holds. Every path it moves to the Simulator is supported there, and a TestFlight build does use production APNs, per Apple's own docs. Two gaps remain. No source confirms remote push works on this Mac's iOS 27.2 Simulator runtime, and earlier runtimes have broken it. AD-14 does not say how an `apns` row gets its environment, or that an environment mismatch is not a "gone" token.

## What was checked, and how

| Claim in the row or the ADs it leans on | Source checked | Result |
| --- | --- | --- |
| A Simulator gets a real APNs token and receives remote pushes through the sandbox | Xcode 14 release notes, item 93914533 (Apple JSON, fetched 2026-11-06): "Simulator now supports remote notifications in iOS 16 when running in macOS 13 on Mac computers with Apple silicon or T2 processors. Simulator supports the Apple Push Notification Service Sandbox environment." | Confirmed as supported. Holding on iOS 27.2 is unconfirmed (F1) |
| This Mac meets the requirement | `uname -m` arm64; `sw_vers` macOS 27.3 (build 26C5035r); `xcodebuild -version` Xcode 27.2 (27B52); `simctl list runtimes`: iOS 27.1, iOS 27.2 (24B8117), iOS 27.2 iPhone19-4 (24B91016s) | Confirmed |
| A production APNs check cannot happen in the Simulator | Same Xcode 14 note (sandbox only). Apple's APNs response table: 400 `BadDeviceToken` "Verify ... that the token matches the environment" | Confirmed |
| A TestFlight build uses production APNs | Apple, `aps-environment` entitlement doc: "Production provisioning profile and [Prerelease versions and beta testers] use `production`." Corroborated by Apple Developer Forums 751440 (May 2024, no Apple staff reply) | Confirmed. The row's "production APNs is checked first on ... TestFlight" is correct and forced |
| ASWebAuthenticationSession OAuth works in the Simulator | Apple Developer Forums 763621 (Xcode 15.4 / iOS 17.5: HTTPS callbacks fail in the Simulator only); 801879 (Xcode 26 / iOS 26: the Simulator does not share Safari cookies, a device does) | Works with a custom-scheme callback, with caveats (F3) |
| Google allows OAuth in ASWebAuthenticationSession | Auth0 community thread on `disallowed_useragent` (Google blocks embedded WKWebView; ASWebAuthenticationSession is the accepted path); supabase/auth#317 | Confirmed. No Simulator-specific limit found |
| Sign in with Apple's web flow works in the NativeAuth sheet in the Simulator | No source found either way. Simulator reports are about the native `ASAuthorizationController` sheet (forums 837902, error 1000), not the web flow | UNVERIFIED. The Open Questions spike stays the reality check (F3) |
| Capgo downloads in the background and reloads in the Simulator | `Cap-go/capacitor-updater` README on `main` (package.json 8.54.2); capgo.app onboarding ("run on a device or simulator"; background, then foreground, to apply) | Confirmed. Nothing in the README or docs is Simulator-specific |
| Stack pins in scope are current | `npm view`: `@capgo/capacitor-updater` 8.54.2 (registry modified 2026-11-04), `@capacitor/push-notifications` 8.1.3 | Confirmed, matching the Stack table |
| Xcode 27.x has no push or auth regressions in the Simulator | Xcode 27, 27.1 and 27.2 release notes (Apple JSON): zero mentions of notification, push, APNs, authentication or Associated Domains | Nothing listed. That is not proof it works (F1) |

The memlog's `(version)` entry at line 109 states the Simulator push facts with no source attached. The Xcode 14 note above is the primary source for it.

## Findings

### F1: MEDIUM. No source confirms Simulator remote push on iOS 27.2, and this feature has broken between runtimes before

- **Where:** Tests row, "APNs push to a closed app through the sandbox (epic-notifications)".
- **Evidence:**
  - Remote push in the iOS 26.0 Simulator stopped returning a device token. `didRegisterForRemoteNotificationsWithDeviceToken` never fired, while the same app on an iOS 18.x runtime worked. Sources: Apple Developer Forums 795433 (Xcode 26 beta 4, Aug 2025) and 797507; firebase-ios-sdk#15315, opened Sep 11 2025.
  - Reporters on firebase-ios-sdk#15315 said it was fixed in iOS 26.1 (Nov 5 2025). On forum 797507, later posts say it came back on 26.2, and a separate report calls it resolved at 26.4. Apple asked for Feedback reports (FB19400926 cited) and gave no root cause.
  - I found no report either way for iOS 27.x. The Xcode 27, 27.1 and 27.2 release notes say nothing about Simulator notifications.
- **Impact:** epic-notifications' hand check, and its Done-when, now depend on a Simulator feature that has regressed before and that no one has run on this Mac's runtime. If it fails, the spine names no fallback short of epic-app-store-release's TestFlight build. That pushes the first real push check to the last epic, which is the outcome the amendment was meant to avoid.
- **Fix:**
  - Run a one-off smoke check on this Mac's iOS 27.2 runtime before epic-notifications relies on it: register, take the token, then curl `api.sandbox.push.apple.com` with the team's `.p8` key.
  - Name a fallback in the row that still avoids TestFlight. A development-signed build installed from Xcode onto a physical iPhone also uses the sandbox, so it keeps production APNs at epic-app-store-release. An older installed Simulator runtime is a second option.

### F2: MEDIUM. AD-14 does not say how a row's sandbox or production value is set, or that `BadDeviceToken` is not a gone token

- **Where:** AD-14, "`send-push` sends to `apns` rows (sandbox or production) ... and deletes targets reported gone". The row now has the Simulator use sandbox and TestFlight use production.
- **Evidence:**
  - `@capacitor/push-notifications`' `Token` has one field, `value` ("On iOS it contains the APNS token"). It reports no environment (plugin README on `main`). Something else must decide the environment, and the spine does not say what.
  - Apple's APNs response table: 400 `BadDeviceToken` means the token is invalid or "does not match the environment"; 410 `Unregistered` means "no longer active for the topic". Only 410 means gone.
- **Impact:** a row labelled with the wrong environment gets 400 `BadDeviceToken` on its first send. If `send-push` counts that as "reported gone", it deletes the row. The Simulator hand check then shows no push and leaves no trace. A build-config guess such as `#if DEBUG` mislabels a Release-configuration build run in the Simulator, so the check fails without any visible error.
- **Fix:** a decision for the architect.
  - **The environment:** have the native shell report it, from the `aps-environment` entitlement in the embedded provisioning profile, with `targetEnvironment(simulator)` meaning sandbox. Pass it to `register_push_device`.
  - **Deletion:** limit "reported gone" to 410 `Unregistered`. Treat 400 `BadDeviceToken` as a mislabel to log, not to delete.

### F3: LOW. The NativeAuth sheet works in the Simulator only with a custom-scheme callback, and a Simulator pass covers a fresh sign-in only

- **Where:** Tests row, "the NativeAuth sheet (epic-invite-sign-in; the Drive picker page, epic-assignments-grades)". Open Questions, "confirm Sign in with Apple through the NativeAuth sheet works end to end".
- **Evidence:**
  - **HTTPS callbacks:** in the Simulator, an HTTPS callback (`ASWebAuthenticationSession.Callback.https`) fails with "Using HTTPS callbacks requires Associated Domains using the `webcredentials` service type". The same build works on a device (forums 763621). My-Love's sheet uses a custom callback scheme (memlog line 15), which does not depend on Associated Domains. The spine does not pin the callback type.
  - **Cookies:** the Simulator's session does not share Safari's cookies, and a device's does (forums 801879, iOS 26). The Simulator also has no on-device Apple Account context.
  - **Sign in with Apple:** I found no source on Apple's web flow in this sheet in the Simulator, so it is UNVERIFIED.
- **Impact:**
  - If Fermi switches to an HTTPS callback, the Simulator check fails for a reason that has nothing to do with Fermi.
  - Device-only behavior, such as reusing a Google session from Safari or Apple's page on a device signed into an Apple Account, is first seen on epic-app-store-release's TestFlight build. That is the same epic where App Review judges web-flow Sign in with Apple.
- **Fix:**
  - State in the row or in the NativeAuth convention that the sheet uses a custom-scheme callback.
  - Optionally, have the Open Questions spike run once on a development-signed physical device as well. That is the same fallback as F1.

### F4: Confirmed, no change. The Capgo live-update restart works in the Simulator

- **Where:** Tests row, "the live-update restart (epic-platform-baseline)"; AD-18. The ticket for this is in `tickets/epic-platform-baseline/tickets/tickets.toml` and uses manual mode, no Capgo account, `latest.json`.
- **Evidence:**
  - The plugin's README (8.54.2) documents manual mode (`autoUpdate: false`, `download()`, `set()`/`next()` to apply on reload or backgrounding) with no device-only caveat.
  - Capgo's onboarding tells you to run on "a device or simulator" and to background and then foreground the app to apply an update.
  - The self-hosted dev guide requires HTTPS, which the `workers.dev` host provides.
- **Note:** `set()` reloads the WebView and does not end the process. A "restart" check that kills the app instead exercises `resetWhenUpdate` and the launch path, which is also fine in the Simulator.

### F5: Confirmed, no change. TestFlight uses production APNs

- The row's sequencing is correct. The Simulator can reach only the sandbox (Xcode 14 note). TestFlight builds get `aps-environment` `production` (Apple's `aps-environment` doc). So production APNs cannot be checked before the first TestFlight build, and putting that check in epic-app-store-release is forced, not chosen.

## Outside this lens (observations, not findings)

- `tickets/epic-notifications/epic-notifications.md` line 26 still says "a closed TestFlight iOS app". The memlog (line 110) already records this conflict as Sofia's to fix.
- The host reports macOS 27.3 with build `26C5035r`. The `r` suffix suggests a pre-release seed. Simulator push behavior on a pre-release host is a further unknown under F1.

## Sources

- Xcode 14 release notes, item 93914533: https://developer.apple.com/documentation/xcode-release-notes/xcode-14-release-notes
- Xcode 27, 27.1, 27.2 release notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes (also `xcode-27_1-`, `xcode-27_2-`)
- `aps-environment` entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment
- Handling notification responses from APNs: https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns
- Sending notification requests to APNs: https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns
- Apple Developer Forums 795433, 797507 (iOS 26 Simulator token): https://developer.apple.com/forums/thread/795433, https://developer.apple.com/forums/thread/797507
- firebase-ios-sdk#15315: https://github.com/firebase/firebase-ios-sdk/issues/15315
- Apple Developer Forums 751440 (TestFlight production): https://developer.apple.com/forums/thread/751440
- Apple Developer Forums 763621 (HTTPS callback in Simulator): https://developer.apple.com/forums/thread/763621
- Apple Developer Forums 801879 (cookie sharing, Simulator vs device): https://developer.apple.com/forums/thread/801879
- Apple Developer Forums 837902 (native Sign in with Apple in Simulator): https://developer.apple.com/forums/thread/837902
- Auth0 community, `disallowed_useragent`: https://community.auth0.com/t/pkce-google-login-error-disallowed-useragent/23584
- supabase/auth#317: https://github.com/supabase/auth/issues/317
- nilcoalescing, Testing remote push on iOS Simulator (May 2023): https://nilcoalescing.com/blog/TestingRemotePushOniOSSimulator
- Capgo updater README: https://github.com/Cap-go/capacitor-updater (README.md, package.json on `main`)
- Capgo onboarding: https://capgo.app/docs/getting-started/onboarding
- Capgo manual update: https://capgo.app/docs/plugin/self-hosted/manual-update
- `@capacitor/push-notifications` README: https://github.com/ionic-team/capacitor-plugins/tree/main/push-notifications
