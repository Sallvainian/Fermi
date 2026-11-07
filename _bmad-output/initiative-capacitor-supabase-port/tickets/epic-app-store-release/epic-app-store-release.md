---
type: epic
title: "Retire Flutter and Firebase"
parent: initiative-capacitor-supabase-port
covers: []
sources: []
companions: []
after: []
refined: false
risk: high
---

# Retire Flutter and Firebase

## Description

The Flutter app, functions/, Firebase config, the email worker and the Cloudflare Pages project fermi are removed; Fermi+ (com.academic-tools.fermi) is removed from sale in App Store Connect by hand, since its live 0.9.3 Flutter build stops working without Firebase; the Flutter app's ios/ and scripts/ios_build.sh go with the Flutter app, as epic-platform-baseline story 1.14 leaves them here; a per-role walkthrough on the website and on the Home Screen web app on an iPhone shows R1 to R30 working.

## Outcome

Fermi runs only as the new web app, the old App Store app is off sale, and nothing of Flutter or Firebase remains (initiative Done when).

## Done when

- App Store Connect shows Fermi+ (com.academic-tools.fermi) removed from sale
- A per-role walkthrough on the website in Safari and desktop Chrome and on the Home Screen web app on an iPhone shows R1 to R30 working
- The Flutter app, functions/, Firebase config, the email worker and the Pages project fermi are gone, and no Firebase package, config or SDK call remains
- README.md describes the new web app on Supabase, with nothing left about Flutter, Firebase or an iPhone app
- A `bmad-tea-trace` run maps the initiative's R1–R30 to passing tests and the walkthrough, and its gate is PASS or each gap has a waiver in Notes

## Boundaries

- Out: new features; this epic removes and walks through
- Out: TestFlight, App Review and any iPhone app build (initiative Decision 2026-11-07)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements (none; Done when), Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-16, Consistency Conventions (Tests)
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 13 App Store release, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-assignments-grades because: R6, R18, R21 and R27 deployed for the walkthrough
- Waits on epic-notifications because: R11, R14, R17 and R24 deployed, web push working on the Home Screen web app
- Waits on epic-boards-announcements because: R9 and R20 deployed
- Waits on epic-calendar because: R8 deployed
- Waits on epic-contact because: R13 and R22 deployed
- Waits on epic-dashboards because: R19 deployed
- Waits on epic-admin-console because: R15, R28 and R29 complete
- Decision: 2026-11-06, this epic makes the first TestFlight build and is the first to check production APNs; earlier epics check the iOS app in the Simulator (spine Tests, AD-18)
- Decision: 2026-11-06, a .github audit found workflows 01_ci, 03, 04 and 05 failing on every pull request or firing together on a v* tag; their removal and the ten repo secrets only they use moved to epic-platform-baseline story 1.12, built now, and retargeting claude.yml and claude-code-review.yml to app/ and supabase/ to story 1.13; this epic still removes the Pages project fermi
- Decision: 2026-11-06, TestFlight and App Store builds reach App Store Connect by hand from Xcode (Archive, then Distribute App to App Store Connect, automatic signing on team W778837A9L), as My-Love ships, because App Store builds come only with native changes (K15) and K7 covers push-to-main deploys, not App Store builds; no signing or App Store Connect secrets go into GitHub, none of the old ones being reusable (certificate expired 2026-08-18, API key secrets gone, signing set deleted in 01d3424); each upload, with its raised build number, is a hitl step in this epic's stories, and moving to Xcode Cloud or fastlane is revisited only if releases become frequent
- Decision: 2026-11-06, `bmad-tea-test-design` runs on this epic at epic level during its refinement, before its stories are planned, covering the per-role walkthrough, the TestFlight push check and App Review; its test plan is adopted as a companion and each story names the scenarios it covers
- Decision: 2026-11-06, this epic rewrites README.md for the new app, since it removes the Flutter app the README describes and no other ticket rewrites it; epic-platform-baseline only edits its CI/CD list
- Decision: 2026-11-06, before App Review, confirm with the school whether any students are under 13 (COPPA) and that its student-records policy (FERPA) allows Fermi; the system-level test design treats student data as FERPA-covered education records
- Decision: 2026-11-07, replan from the initiative's Decision (owner): no iPhone app; this epic keeps its slug and is retitled "Retire Flutter and Firebase", as epics 2, 3 and 12 kept theirs; it loses the TestFlight build, production APNs, App Review and the demo accounts, so the 2026-11-06 lines above on the first TestFlight build, on uploads from Xcode, and the test design's TestFlight push check and App Review no longer apply
- Decision: 2026-11-07, this epic removes Fermi+ (com.academic-tools.fermi) from sale in App Store Connect, a hitl step for the owner, because the live 0.9.3 Flutter build stops working once Firebase is removed
- Decision: 2026-11-07, owner: the COPPA and FERPA confirmation with the school is dropped, because the owner works at no school now; the 2026-11-06 line above on it no longer applies (initiative Notes)
