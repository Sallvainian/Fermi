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

The iOS app passes App Store review as an update to com.academic-tools.fermi with Sign in with Apple and a reviewer invite code; the Flutter app, functions/, Firebase config, src/index.js, the email worker, workflows 01_ci, 03, 04 and 05 and the Cloudflare Pages project fermi are removed; a per-role walkthrough on the website, the Home Screen web app and the App Store app shows R1 to R25 working.

## Outcome

Fermi's App Store listing runs the new app, and nothing of Flutter or Firebase remains (initiative Done when).

## Done when

- The iOS app passes App Store review as an update to com.academic-tools.fermi
- A per-role walkthrough on the website, the Home Screen web app and the App Store app shows R1 to R25 working
- The Flutter app, functions/, Firebase config, src/index.js, the email worker, workflows 01_ci, 03, 04 and 05 and the Pages project fermi are gone, and no Firebase package, config or SDK call remains

## Boundaries

- Out: new features; this epic releases and removes

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements (none; Done when), Constraints
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-assignments-grades because: R6, R18 and R21 deployed for the walkthrough
- Waits on epic-notifications because: R11, R14, R17 and R24 deployed, push working in the iOS build
- Waits on epic-boards-announcements because: R9 and R20 deployed
- Waits on epic-calendar because: R8 deployed
- Waits on epic-contact because: R13 and R22 deployed
- Waits on epic-dashboards because: R19 deployed
- Waits on epic-admin-console because: R15 complete
