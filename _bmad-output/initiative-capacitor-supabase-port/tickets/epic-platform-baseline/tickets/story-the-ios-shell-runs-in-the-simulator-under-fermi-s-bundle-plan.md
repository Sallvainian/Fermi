---
title: 'The iOS shell runs in the Simulator under Fermi''s bundle'
type: feature
ticket: '2'
created: '2026-11-06'
status: done
baseline_revision: 'bf9b233abe25df857689f37b90903c2ad2a61d89'
route: full
route_source: auto
risk: high
review: thorough
review_source: pinned
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred:
  - summary: >-
      The Capacitor template's Info.plist adds UIRequiredDeviceCapabilities = armv7, which the live Flutter build's Info.plist does not have.
    evidence: |-
      grep -c UIRequiredDeviceCapabilities ios/Runner/Info.plist is 0. Whether App Store Connect refuses an update that adds this key (it excludes no device that runs iOS 15) is UNVERIFIED; Capacitor apps ship with it routinely. Settled at epic-app-store-release's first TestFlight upload, or by removing the key in a native build before then.
    location: >-
      app/ios/App/App/Info.plist
    severity: medium (unverified)
  - summary: >-
      The iOS project ships Capacitor's placeholder app icon and splash images, which would replace Fermi's icon on the listing if uploaded as is.
    evidence: |-
      AppIcon-512@2x.png and the three identical splash-2732x2732 PNGs are the template defaults. This epic builds for the Simulator only; App Store builds are epic-app-store-release's (epic Boundaries), which needs real icon and splash assets before its first upload.
    location: >-
      app/ios/App/App/Assets.xcassets
    severity: low
---

<intent-contract>

## Intent

**Problem:** `app/` has the web shell and the Capacitor packages but no iOS project, so nothing proves the new app can ship as an update to Fermi's App Store listing (bundle `com.academic-tools.fermi`, team W778837A9L, highest uploaded build 7, live version 0.9.3), and no file records the minimum native build that story 9's live updates will carry (AD-18).

**Approach:** Add `app/capacitor.config.ts` and the Capacitor iOS project in `app/ios` set to version 1.0.0, build 8, team W778837A9L; record `8` in a checked-in `app/MIN_NATIVE_BUILD`; add a script that builds the web app with the current commit id, syncs it into the iOS project, builds for the iOS Simulator with `xcodebuild` (no signing), installs and launches it with `simctl`, and passes only when a screenshot's recognised text contains that commit id.

## Boundaries & Constraints

**Always:** Capacitor 8.6.0 as pinned in `app/package.json`; Swift Package Manager (as My-Love), not CocoaPods. iPhone and iPad stay supported (`TARGETED_DEVICE_FAMILY = "1,2"`, as the live Flutter build), since an App Store update cannot drop iPad. `MIN_NATIVE_BUILD` is its own file, never derived from `CURRENT_PROJECT_VERSION`. The script needs only Xcode, Node and git (no jq, Homebrew or Python). Leave the Flutter `ios/`, `lib/`, `pubspec.yaml` and every workflow untouched.

**Never:** No plugins (`@capgo/capacitor-updater`, push, `@capacitor/app` are stories 9, 10 and later), no Info.plist or entitlement additions beyond the template, no signing, provisioning, archive, TestFlight or App Store Connect call, no CI job or `.github` change (CI lanes are story 3's, the MIN_NATIVE_BUILD check story 9's). No `server.url` or live-reload config.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Check at HEAD | clean checkout, deps installed | app launches in a Simulator; screenshot text contains `git rev-parse HEAD`; exit 0, prints screenshot path, bundle id, version, build | — |
| Id override | `GITHUB_SHA=<id>` set | builds and checks that id instead | — |
| Device choice | `SIM_DEVICE` (UDID or exact name) unset | first available iPhone; boots it if shut down | no iPhone simulator → exit 1 naming the problem |
| Wrong id shown | screen lacks the id after all attempts | exit 1, prints expected id and the last recognised text | — |
| Failure branch | `CHECK_SCREENSHOT=<png>` | recognise that file only, no build or Simulator | exit 1 on mismatch |
| Build failure | xcodebuild fails | exit non-zero with xcodebuild's error | `set -euo pipefail` |

</intent-contract>

## Code Map

- `app/package.json` -- already has `@capacitor/core`, `@capacitor/ios`, `@capacitor/cli` 8.6.0; no script change required (a `cap:sync` script is optional, not needed).
- `app/index.html` -- already `viewport-fit=cover`, so `env(safe-area-inset-top)` works in WKWebView.
- `app/src/App.tsx` -- `<main className="mx-auto max-w-xl p-8">`; on an iPhone with a Dynamic Island the heading sits under the status bar. Give the top padding `max(2rem, env(safe-area-inset-top))` (Tailwind arbitrary value); nothing else.
- `app/vite.config.ts` -- build id from `GITHUB_SHA || 'local'`; reuse, do not change.
- `app/.gitignore` (`dist/`) and root `.gitignore` -- root ignores `**/build/`, `*.xcscheme`, `xcuserdata/`, `**/Pods/`; Capacitor writes its own `app/ios/.gitignore` (`App/App/public`, `capacitor.config.json`, `config.xml`, `DerivedData`, ...). Keep the generated one; confirm `git status` shows no build output after a check run.
- Model: `/Users/sallvain/Projects/My-Love/capacitor.config.ts` (comment on appId permanence) and `/Users/sallvain/Projects/My-Love/ios/` (tracked files: `App/App.xcodeproj/project.pbxproj`, `project.xcworkspace/.../Package.resolved`, `App/App/*`, `App/CapApp-SPM/*`, `debug.xcconfig`). Read only.
- Flutter `ios/Runner.xcodeproj/project.pbxproj` -- source of the listing identity (bundle, team, device family "1,2"); read only.
- `scripts/check-site.sh` -- style model for the new script (header comment, `set -euo pipefail`, env knobs `ATTEMPTS`/`RETRY_DELAY`).
- Tooling here: Xcode 27.2, iOS 27.x runtimes, iPhone simulators available, Node 24, `swiftc`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/capacitor.config.ts` -- `appId: 'com.academic-tools.fermi'` (comment: permanent, it is the App Store listing's bundle id and on-device storage is keyed to it), `appName: 'Fermi+'`, `webDir: 'dist'`; comment that changing this file is a native change that raises `MIN_NATIVE_BUILD` (AD-18).
- [ ] `app/ios/` -- `npx cap add ios` (SPM; pass `--packagemanager SPM` if 8.6.0 offers it) from `app/` after a build; then in `App.xcodeproj/project.pbxproj` set, for the App target's Debug and Release: `DEVELOPMENT_TEAM = W778837A9L`, `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 8`, keep `PRODUCT_BUNDLE_IDENTIFIER = "com.academic-tools.fermi"` and `TARGETED_DEVICE_FAMILY = "1,2"`. Commit the generated sources, `Package.resolved` once resolved, and the generated `.gitignore`; no `public/` copy.
- [ ] `app/MIN_NATIVE_BUILD` -- one line, `8`. Nothing else in the file, so `$(cat app/MIN_NATIVE_BUILD)` reads it.
- [ ] `app/src/App.tsx` -- safe-area top padding as in Code Map.
- [ ] `scripts/ocr-text.swift` -- Vision `VNRecognizeTextRequest` (accurate level, language correction off) on the image path argument; prints each recognised line to stdout; exit 1 on unreadable image.
- [ ] `scripts/ios-sim-check.sh` (executable, `set -euo pipefail`, runs from any cwd) -- header comment stating purpose, env knobs and that it needs no signing. Steps: id = `GITHUB_SHA` or `git rev-parse HEAD`; `npm run build` in app/ with that `GITHUB_SHA`; `npx cap sync ios`; pick device (`SIM_DEVICE`, else first available iPhone from `xcrun simctl list devices available`); `xcodebuild -project app/ios/App/App.xcodeproj -scheme App -configuration Debug -destination "id=<udid>" -derivedDataPath app/ios/DerivedData CODE_SIGNING_ALLOWED=NO build`; print the built app's `CFBundleIdentifier`, `CFBundleShortVersionString`, `CFBundleVersion` (plutil); boot if needed, `simctl bootstatus -b`, install, terminate (ignore failure), launch `com.academic-tools.fermi`; compile the OCR helper once into DerivedData; up to `ATTEMPTS` (default 10) × `RETRY_DELAY` (default 2 s): screenshot to `app/ios/DerivedData/sim-check-<id>.png`, recognise, pass when the text with all whitespace removed contains the id. Leave the Simulator booted. When `CHECK_SCREENSHOT=<png>` is set, skip every step but recognition and match that file once against the id.

**Acceptance Criteria:**
- Given a clean checkout of this branch with `npm ci` done in app/, when `scripts/ios-sim-check.sh` runs, then it exits 0, the app is on screen in an iOS Simulator showing "Fermi+" and "Build <HEAD commit id>", and the saved screenshot shows the same.
- Given that run, when the built app's Info.plist is read, then bundle id is `com.academic-tools.fermi`, version `1.0.0`, build `8`; and `app/MIN_NATIVE_BUILD` reads `8`.
- Given the screenshot a passing run saved, when `CHECK_SCREENSHOT=<that png> GITHUB_SHA=deadbeef scripts/ios-sim-check.sh` runs, then it exits 1 without building or touching a Simulator, printing the expected id and the recognised text; with `GITHUB_SHA` set to the HEAD id instead, it exits 0.
- Given the run finished, when `git status --porcelain` runs, then it shows nothing (build output, synced web assets and screenshots are ignored).
- Given the repo, when listed, then the Flutter `ios/` and `lib/` are unchanged from the baseline.

## Implementation Notes

- Implemented by a Sonnet subagent from this plan; verified again in the main session. No commit, signing or App Store Connect call.
- `cap add ios` (8.6.0) rejects `com.academic-tools.fermi` because of the dash and has no skip flag, so the project was generated with a temporary `com.academictools.fermi` and the real id restored in `capacitor.config.ts` and set in `project.pbxproj` by hand; `cap sync` accepts it. Regenerating `app/ios` needs the same workaround. No trace of the temporary id remains (grep).
- `app/eslint.config.js` now ignores `ios/**`: after `cap sync` the synced web bundle in `ios/App/App/public` (gitignored) made `npm run lint` fail with 1,421 errors.
- Recognition misread one `b` as `6` at native scale every time, a case the planned `o`/`l` normalisation does not cover; `scripts/ocr-text.swift` instead recognises at 1x, 2x, 3x and 0.5x and prints every distinct line, and the script still requires the exact id.
- The first available iPhone here is an "iPhone Duo" (two displays): `simctl io screenshot` cannot pick a display on it, so the default pick skips `iPhone Duo`; `SIM_DEVICE` overrides.
- Verified in the main session: lint and typecheck exit 0; full run on iPhone 18 Pro exits 0 printing `com.academic-tools.fermi`, `1.0.0`, `8`; the screenshot shows "Fermi+" and "Build bf9b233abe25df857689f37b90903c2ad2a61d89"; `CHECK_SCREENSHOT` exits 1 for `deadbeef` and 0 for HEAD; a stand-in `xcrun` listing no iPhone exits 1 with the no-iPhone message; a stand-in failing `xcodebuild` exits 65; `git status` shows only source files; Flutter `ios/`, `lib/`, `pubspec.yaml`, `.github` unchanged.

## Plan Change Log

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 33 findings — high 0, medium 7, low 19, false 6, maybe-false 1
- findings:
  - `medium` `patch` [blind] a screenshot left by an earlier run at the same id passes when this run's screenshot fails — `rm -f "$shot"` before each attempt in scripts/ios-sim-check.sh.
  - `low` `patch` [blind] cross-scale dedupe in ocr-text.swift can split a wrapped id so its correct halves are never contiguous — dedupe moved inside each scale.
  - `low` `patch` [blind] SIM_DEVICE names with parentheses never match (ERE groups) — name now matched literally with `grep -F`; "iPhone 17" and "iPad Pro 13-inch (M5)" resolved.
  - `medium` `patch` [blind] bundle id, version and build are printed, never checked — script now fails unless CFBundleIdentifier is com.academic-tools.fermi and CFBundleVersion is an integer ≥ app/MIN_NATIVE_BUILD; proved by MIN_NATIVE_BUILD=9 → exit 1.
  - `false` `reject` [blind] screen check does not look for "Fermi+" — the id is rendered only by App.tsx beside the heading, so the id cannot appear without the shell.
  - `low` `patch` [blind] capacitor.config.ts is not type-checked — added to app/tsconfig.node.json include; typecheck exits 0.
  - `low` `patch` [blind] "no build id" message unreachable when git rev-parse fails under set -e — substitution made non-fatal.
  - `low` `patch` [blind] safe area handled only at the top; landscape iPhone puts text under the island — left/right safe-area padding added to App.tsx.
  - `maybe-false` `defer` [blind] template Info.plist adds UIRequiredDeviceCapabilities armv7, absent from the live build — whether App Store Connect refuses it is settled at the first upload; deferred (medium, unverified).
  - `low` `patch` [blind] regeneration workaround and CURRENT_PROJECT_VERSION ≥ MIN_NATIVE_BUILD rule live only in the plan — both added as comments in app/capacitor.config.ts.
  - `low` `defer` [blind] placeholder icon and splash would replace the listing's icon — App Store builds are outside this epic (Boundaries); deferred to epic-app-store-release.
  - `false` `reject` [blind] Debug-only `-D COCOAPODS` flag makes Capacitor compile differently — OTHER_SWIFT_FLAGS of the App target apply only to AppDelegate/SceneDelegate, which have no `#if COCOAPODS`; SPM packages build with their own settings; same as My-Love's template.
  - `low` `patch` [blind] one Vision perform error at any scale aborts the whole run — failed scales are skipped; exit 1 only when none recognised.
  - `medium` `patch` [edge] stale screenshot passes — same root cause and fix as the blind finding.
  - `low` `patch` [edge] SIM_DEVICE with parentheses never matches — same root cause and fix as the blind finding.
  - `low` `patch` [edge] `.` in SIM_DEVICE matches any character — same root cause (regex match of a name); literal match fixes it.
  - `low` `reject` [edge] ATTEMPTS 0 or non-numeric gives a misleading mismatch — only a caller misusing the knob meets it, the script still exits 1, and the fix adds a guard.
  - `low` `reject` [edge] non-numeric RETRY_DELAY aborts via set -e without a FAIL line — same reasoning: misuse only, still fails, fix adds a guard.
  - `low` `patch` [edge] a dirty tree is labelled with HEAD's id — met in this very run; script now warns on stderr when app/ has uncommitted changes and GITHUB_SHA is unset (seen in the verification run).
  - `low` `patch` [edge] unreachable "no build id" message — same fix as the blind finding.
  - `low` `patch` [edge] cross-scale dedupe interleaves id fragments — same fix as the blind finding.
  - `medium` `patch` [edge] nothing checks the build number against MIN_NATIVE_BUILD — same root cause and fix as the blind identity finding.
  - `medium` `patch` [verification-gap] built app's bundle id, version and build printed but never checked — same fix; the build-number branch proven, the wrong-bundle-id branch not exercised.
  - `medium` `patch` [verification-gap] stale screenshot can pass — same fix as the blind finding.
  - `low` `patch` [verification-gap] SIM_DEVICE names with parentheses break — same fix as the blind finding.
  - `false` `reject` [intent] the Simulator check is not run on every build in CI — the spine's Tests convention checks native-only paths by hand in the Simulator, and the epic gives CI lanes to story 3.
  - `false` `reject` [intent] an Xcode build from a fresh clone has no web files or shows "local" — that is Capacitor's normal flow (`cap sync` copies the web build); the ticket's check is the script, and story 9's live updates carry the web id.
  - `low` `patch` [intent] uncommitted code shows HEAD's id — same fix as the edge dirty-tree finding.
  - `medium` `patch` [intent] version, build and MIN_NATIVE_BUILD are set but not checked — same fix as the blind identity finding.
  - `low` `reject` [intent] only Debug is built and the team setting is unused without signing — the ticket asks for an unsigned Simulator run; signing and Release builds are epic-app-store-release's.
  - `low` `reject` [intent] the "MIN_NATIVE_BUILD goes up only with a native change" rule is written only in capacitor.config.ts — the epic gives recording the native rules in AGENTS.md to story 13; the config comment now also states the build-number rule.
  - `false` `reject` [intent] screenshot proves only that the id is drawn — same refutation as the blind "Fermi+" finding.
  - `false` `reject` [intent] the app is named "Fermi+" though the ticket says "Fermi" — the epic settles the name: listing title Fermi+ and the App Store message "A new version of Fermi+".

### 2026-11-06 — Review pass (follow-up)
- verdicts: 28 findings — high 0, medium 2, low 18, false 7, maybe-false 1
- findings:
  - `low` `patch` [blind] the build-floor check passes silently when app/MIN_NATIVE_BUILD is empty: the joined `case "$min_build$built_build"` accepts "8", and `[ 8 -lt "" ]` errors inside `if`, so FAIL never runs — each value is now checked on its own; an emptied file now exits 1 "app/MIN_NATIVE_BUILD '' is not an integer" (run this pass, file restored to 8).
  - `medium` `patch` [blind] CFBundleShortVersionString is printed but never compared — carried: the earlier pass's [intent] "version, build and MIN_NATIVE_BUILD are set but not checked" row; the code still checks bundle id and build only, as that row's fix described.
  - `low` `reject` [blind] the deferred list records only armv7 among Info.plist gaps; the live ios/Runner/Info.plist also has ITSAppUsesNonExemptEncryption, UIBackgroundModes, BGTaskSchedulerPermittedIdentifiers and CFBundleURLTypes — confirmed by grep; nobody meets it in this epic (Simulator builds never reach App Store Connect, which asks the export-compliance question on screen at upload), the background and URL keys belong to features later stories port, and adding them breaks the plan's no-Info.plist-additions rule.
  - `low` `reject` [blind] `SIM_DEVICE=Booted` matches the `(Booted)` state word and is taken as a UDID — real, but only a misuse of the knob meets it, xcodebuild still fails non-zero, and the fix adds a UDID-shape guard.
  - `low` `reject` [blind] the default device pick ignores an already-booted iPhone and may boot a second one — real; costs Simulator memory only, and preferring a booted device adds a branch.
  - `low` `reject` [blind] OCR runs all four scales on every attempt, slow on a 3x upscale — real cost; a passing run stops at the first matching attempt, and short-circuiting needs a new parameter for the helper.
  - `low` `patch` [blind] the regeneration steps in capacitor.config.ts omit that `cap add` needs dist/ (`npm run build` first) — confirmed in @capacitor/cli (`Could not find the web assets directory`); comment now says to run `npm run build` first. The "regeneration restores template defaults" half needs no text: DW-4/DW-5 are still open.
  - `false` `reject` [blind] vite.config.ts's buildId comment was not updated for ios-sim-check.sh — the comment states where the id comes from and that App.tsx shows it, both still true; it is not a list of every reader, and ios-sim-check.sh documents its own GITHUB_SHA use.
  - `false` `reject` [blind] `simctl boot ... 2>/dev/null || true` hides boot errors — the next line, `simctl bootstatus -b`, boots the device if it is not booted (`simctl help bootstatus`), so a real boot failure surfaces there.
  - `maybe-false` `defer` [blind] remove the armv7 UIRequiredDeviceCapabilities key now instead of deferring — carried: the earlier pass's armv7 row (maybe-false, deferred); not deferred again.
  - `low` `patch` [edge] empty MIN_NATIVE_BUILD or CFBundleVersion passes the build-floor check — same root cause and fix as the first [blind] row.
  - `low` `reject` [edge] SIM_DEVICE set to a state word or other parenthesised token becomes the UDID — same reasoning as the [blind] SIM_DEVICE=Booted row.
  - `low` `reject` [edge] ATTEMPTS 0/non-numeric or non-numeric RETRY_DELAY gives a misleading or missing message — carried: the earlier pass's two ATTEMPTS/RETRY_DELAY rows (rejected).
  - `low` `patch` [edge] screenshot errors are discarded, so a run whose every screenshot fails reports a misleading "screen does not show build id" — `2>&1` dropped from the screenshot line, so simctl's stderr reaches the terminal; side effect: simctl's two informational notes ("Detected file type", "No display specified") now print on each attempt.
  - `low` `reject` [edge] a GITHUB_SHA with `/`, whitespace or uppercase hex can never match — misuse only (GitHub's GITHUB_SHA is 40 lowercase hex), the run still exits 1, and the fix adds a guard.
  - `false` `reject` [edge] Vision may read lowercase `c` as `C`, failing a correct screen — the saved bf9b233 screenshot, re-recognised this pass, reads its `c` lowercase at all four scales, and this pass's 4e3ac8ab… id (six `c`s) matched on a real run.
  - `false` `reject` [edge] the 40-character id has no break point and overflows or is clipped on a narrow iPhone — on iPhone 18 Pro the id renders about 321 pt wide on its own line; on the narrowest current iPhone (375 pt) it would run at most about 10 pt into the 32 pt right padding, and nothing clips it.
  - `false` `reject` [edge] only the id is matched, not "Fermi+" or the "Build" label — carried: the earlier pass's [blind] "Fermi+" row (false).
  - `low` `reject` [verification-gap] the build-floor check reads only the Debug CURRENT_PROJECT_VERSION; Release could drift below MIN_NATIVE_BUILD — real gap; both are 8 today, it needs a later hand edit of one config only, and App Store Connect refuses a reused build number at upload (Release builds are epic-app-store-release's); the fix adds a check.
  - `low` `reject` [verification-gap] TARGETED_DEVICE_FAMILY and MARKETING_VERSION in the built app are printed or ignored, never checked — the version half is the carried earlier-pass row; the device-family half: "1,2" is the Capacitor template default and nothing in this story changes it, so meeting it needs a later deliberate change, and the fix adds a new check.
  - `low` `reject` [verification-gap] plan notes say ocr-text.swift dedupes lines, but the code prints every line at every scale — true; the fix is editing this build's plan.
  - `false` `reject` [intent] the Simulator check is not run in CI — carried: the earlier pass's CI row (false).
  - `medium` `patch` [intent] build is checked only as ≥ MIN_NATIVE_BUILD, not = 8, and the version is never compared — carried: the earlier pass's version/build row.
  - `low` `reject` [intent] DEVELOPMENT_TEAM is never checked — carried: the earlier pass's Debug-only/team row (rejected).
  - `low` `reject` [intent] "MIN_NATIVE_BUILD goes up only with a native change" is a comment only — carried: the earlier pass's AD-18 rule-location row (rejected).
  - `false` `reject` [intent] nothing in the diff proves the script ran (screenshot gitignored) — runs are recorded in Implementation Notes, and this pass ran it again at 4e3ac8ab3ab72137226241c7ccb283df99d08ccd (exit 0, screenshot viewed).
  - `low` `patch` [intent] with app/ dirty, the id shown may not be the exact commit — carried: the earlier pass's dirty-tree row (patched with the stderr warning, seen again this pass).
  - `low` `defer` [intent] template armv7 key and placeholder icon/splash ship unchanged — carried: the earlier pass's two deferred rows; not deferred again.

## Design Notes

The screenshot check proves what a person would see, not a file on disk: the id is read off the rendered screen. Recognition can misread a 40-character hex string; the matcher strips whitespace (the id may wrap) and compares exactly, and if real runs show misreads, normalise only lowercase `o`→`0` and `l`/`I`→`1` before comparing, noted in Implementation Notes. `appName` is "Fermi+" to match the listing title and the web shell; the Flutter build shows "Fermi" under the icon, so the Home Screen label changes with this build. `MIN_NATIVE_BUILD` is a bare number file so story 9's packaging and CI check read it with no parser.

## Verification

**Commands:**
- `cd app && npm ci && npm run lint && npm run typecheck` -- expected: exit 0.
- `scripts/ios-sim-check.sh` -- expected: exit 0; prints bundle `com.academic-tools.fermi`, version `1.0.0`, build `8`, and the screenshot path; open the screenshot and confirm "Build <git rev-parse HEAD>".
- `CHECK_SCREENSHOT=app/ios/DerivedData/sim-check-<HEAD id>.png GITHUB_SHA=deadbeef scripts/ios-sim-check.sh` -- expected: exit 1 naming `deadbeef`; same with `GITHUB_SHA=<HEAD id>` -- expected: exit 0.
- `cat app/MIN_NATIVE_BUILD` -- expected: `8`.
- `git status --porcelain` -- expected: empty after the run.
- `git diff --stat bf9b233abe25df857689f37b90903c2ad2a61d89 -- ios lib pubspec.yaml .github` -- expected: empty.

## Auto Run Result

Status: built

**Summary:** Follow-up review pass on the iOS shell. `app/` has `capacitor.config.ts` (bundle `com.academic-tools.fermi`, name Fermi+) and a Capacitor 8.6.0 Swift Package Manager iOS project in `app/ios`: team W778837A9L, version 1.0.0, build 8, iPhone and iPad. `app/MIN_NATIVE_BUILD` holds `8`, kept separate from the Xcode build number. `scripts/ios-sim-check.sh` builds the web app with the commit id, syncs it, and builds for the Simulator unsigned. It then checks the built bundle id and that the build number is not below MIN_NATIVE_BUILD, launches the app with simctl, and passes only when text recognised in a screenshot contains the id. This pass tightened three details of that script and its comments (commit 4e3ac8ab3ab72137226241c7ccb283df99d08ccd).

**Files changed (whole story, since bf9b233abe25df857689f37b90903c2ad2a61d89):**
- `app/capacitor.config.ts`: app id, name and web dir, with comments on permanence, AD-18 and regenerating `ios/` (this pass: run `npm run build` before `cap add`).
- `app/ios/**`: generated Xcode project (pbxproj with team, 1.0.0, build 8), Swift sources, storyboards, Info.plist, template assets, CapApp-SPM package and Package.resolved, generated .gitignore.
- `app/MIN_NATIVE_BUILD`: `8`.
- `app/src/App.tsx`: safe-area padding on the top, left and right.
- `app/eslint.config.js`: ignores `ios/**`, the synced web bundle.
- `app/tsconfig.node.json`: type-checks capacitor.config.ts.
- `scripts/ios-sim-check.sh`: the Simulator check and the `CHECK_SCREENSHOT` mode. This pass: each build number is validated on its own, and simctl screenshot errors are shown.
- `scripts/ocr-text.swift`: Vision text recognition at several scales.

**Review (follow-up pass):** 28 findings: high 0, medium 2, low 18, false 7, maybe-false 1.
- **Patched (3 entries, all low):**
  - An empty MIN_NATIVE_BUILD (or CFBundleVersion) let the build check pass silently.
  - Screenshot errors were hidden behind a misleading mismatch message.
  - The regeneration comment left out the web build step.
- **Carried from the first pass (11 rows):** all keep their earlier route; none was patched or deferred again. The two medium rows (version and build number checked only as ≥ MIN_NATIVE_BUILD) are among them.
- **No new deferrals.** The two existing deferred items (the armv7 key and the placeholder icon/splash) are unchanged.
- **Rejected this pass, with reasons:**
  - Other live Info.plist keys missing (low): not met before the first upload; feature keys belong to later stories; adding them breaks the plan's no-additions rule.
  - `SIM_DEVICE=Booted` and other state words (low, twice): misuse only; still fails non-zero; the fix adds a guard.
  - Already-booted device ignored (low): only extra memory use; the fix adds a branch.
  - OCR runs all scales (low): only a speed cost; the fix needs a new parameter.
  - vite comment not updated (false): the comment is still accurate.
  - `simctl boot` hiding errors (false): `bootstatus -b` boots the device and surfaces the error.
  - GITHUB_SHA format (low): misuse only; the fix adds a guard.
  - `c`/`C` misread (false): disproved on real screenshots.
  - id overflowing on a narrow iPhone (false): nothing clips it, and it fits within the padding.
  - Release build number not checked (low): needs a later one-sided hand edit, and App Store Connect refuses a reused build number; the fix adds a check.
  - Device family not checked (low): it is the template default and nothing here changes it; the fix adds a check.
  - Plan notes vs ocr-text.swift dedupe (low): the fix is editing the plan.
  - No proof of a run (false): the script was run again this pass.

**Follow-up review recommended: false.** This is a follow-up pass and it patched no high entry (patched counts: high 0, medium 0, low 3).

**Verification (this pass):**
- `npm ci`, `npm run lint` and `npm run typecheck` in app/ exit 0.
- `SIM_DEVICE="iPhone 18 Pro" scripts/ios-sim-check.sh` at 4e3ac8ab3ab72137226241c7ccb283df99d08ccd exits 0. It printed `com.academic-tools.fermi`, `1.0.0`, `8` and matched on attempt 4 (attempts 1–3 ran while the web view was loading). The screenshot, viewed, shows "Fermi+" and "Build 4e3ac8ab3ab72137226241c7ccb283df99d08ccd".
- `CHECK_SCREENSHOT` on that screenshot exits 1 for `deadbeef` and 0 for the HEAD id.
- With `app/MIN_NATIVE_BUILD` temporarily emptied, the run exits 1: "app/MIN_NATIVE_BUILD '' is not an integer". The file was restored to `8`.
- `cat app/MIN_NATIVE_BUILD` reads `8`.
- After the runs, `git status --porcelain` shows only this plan file.
- `git diff --stat bf9b233… -- ios lib pubspec.yaml .github` is empty.

**Residual risks:**
- Regenerating `app/ios` needs the temporary-id workaround.
- App Store acceptance of the template Info.plist and assets is untested until epic-app-store-release; the live plist's export-compliance key is not carried over.
- Only the Debug build number is checked against MIN_NATIVE_BUILD.
- The wrong-bundle-id failure branch is still not exercised.
- The Home Screen label becomes "Fermi+".
- simctl's informational notes now print on each screenshot attempt.
- The iPhone 18 Pro Simulator is left booted on this Mac.
