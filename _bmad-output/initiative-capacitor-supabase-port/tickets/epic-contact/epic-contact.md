---
type: epic
title: "Support reports and Gmail"
parent: initiative-capacitor-supabase-port
covers: [R13, R22]
sources: []
companions: []
after: []
refined: false
risk: low
---

# Support reports and Gmail

## Description

A user submits a support or bug report, and the admin reads them in a reports list this epic adds; a user opens Gmail's compose screen from inside Fermi with the recipient filled in from epic 2's app.visible_email when started from a Fermi user (AD-12).

## Outcome

Users reach the admin with reports and email the people they may email (initiative R13, R22, K16).

## Done when

- On the deployed site, a user submits a report and the admin reads it in the reports list
- The Email button opens Gmail's compose screen with the recipient filled in only where K16 allows, and automated checks refuse reading any other email
- A `bmad-tea-trace` run at closure maps each Requirements line to passing tests, and its gate is PASS or each gap has a waiver in Notes

## Boundaries

- Out: sending or reading mail through Gmail (initiative K12)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R13, R22, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-1, AD-3, AD-12
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 10 Contact, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-invite-sign-in because: accounts, the directory, app.visible_email and the admin role
- Decision: 2026-11-06, `bmad-tea-test-design` runs on this epic at epic level during its refinement, after its Requirements are written and before its stories are planned; its test plan is adopted as a companion, each story names the scenarios it covers, and the plan settles whether the epic closes with an end-to-end suite
