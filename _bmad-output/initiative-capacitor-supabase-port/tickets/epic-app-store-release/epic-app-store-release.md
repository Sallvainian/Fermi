---
type: epic
title: "Release on the App Store and retire Flutter"
parent: initiative-capacitor-supabase-port
covers: []
sources: []
companions: []
after: []
refined: false
risk: high
---

# Release on the App Store and retire Flutter

## Description

The iOS app passes App Store review as an update to com.academic-tools.fermi with Sign in with Apple, account deletion and a demo teacher login and a demo student login in the review notes with a note that sign-in is invitation-only; the Flutter app, functions/, Firebase config, the email worker and the Cloudflare Pages project fermi are removed; a per-role walkthrough on the website, the Home Screen web app and the App Store app shows R1 to R30 working.

## Outcome

Fermi's App Store listing runs the new app, and nothing of Flutter or Firebase remains (initiative Done when).

## Done when

- On the first TestFlight build, which carries every native change since epic-platform-baseline, a chat message reaches the closed app as a push through production APNs
- The iOS app passes App Store review as an update to com.academic-tools.fermi, with demo accounts on the lists in the review notes
- A per-role walkthrough on the website, the Home Screen web app and the App Store app shows R1 to R30 working
- The Flutter app, functions/, Firebase config, the email worker and the Pages project fermi are gone, and no Firebase package, config or SDK call remains
- A `bmad-tea-trace` run maps the initiative's R1–R30 to passing tests and the walkthrough, and its gate is PASS or each gap has a waiver in Notes

## Boundaries

- Out: new features; this epic releases and removes

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements (none; Done when), Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-7, AD-14, AD-16, AD-18, Consistency Conventions (Tests), Open Questions (App Review)
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 13 App Store release, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-assignments-grades because: R6, R18, R21 and R27 deployed for the walkthrough
- Waits on epic-notifications because: R11, R14, R17 and R24 deployed, sandbox push working in the iOS Simulator
- Waits on epic-boards-announcements because: R9 and R20 deployed
- Waits on epic-calendar because: R8 deployed
- Waits on epic-contact because: R13 and R22 deployed
- Waits on epic-dashboards because: R19 deployed
- Waits on epic-admin-console because: R15, R28 and R29 complete, account deletion for App Review
- Decision: 2026-11-06, this epic makes the first TestFlight build and is the first to check production APNs; earlier epics check the iOS app in the Simulator (spine Tests, AD-18)
- Decision: 2026-11-06, a .github audit found workflows 01_ci, 03, 04 and 05 failing on every pull request or firing together on a v* tag; their removal and the ten repo secrets only they use moved to epic-platform-baseline story 1.12, built now, and retargeting claude.yml and claude-code-review.yml to app/ and supabase/ to story 1.13; this epic still removes the Pages project fermi
- Open question: how do TestFlight builds reach App Store Connect, Xcode by hand or CI? Settle at refinement and list the secrets it needs. None of the old ones can be reused: the Flutter-era distribution certificate expired 2026-08-18, the App Store Connect API key secrets were already gone, and the signing set was deleted in 01d3424. CI needs an Apple Distribution certificate (.p12) and its password, an App Store provisioning profile for com.academic-tools.fermi or automatic signing through the API key, an App Store Connect API key (key ID, issuer ID, .p8) and a temporary keychain password; by hand needs no GitHub secrets, and My-Love has no CI upload path to copy. waits: epic-app-store-release refinement
- Decision: 2026-11-06, `bmad-tea-test-design` runs on this epic at epic level during its refinement, before its stories are planned, covering the per-role walkthrough, the TestFlight push check and App Review; its test plan is adopted as a companion and each story names the scenarios it covers
