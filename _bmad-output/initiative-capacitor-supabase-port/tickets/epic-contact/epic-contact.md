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

A user submits a support or bug report, and the admin reads them in a reports list this epic adds; a user opens Gmail's compose screen from inside Fermi with the recipient filled in from epic 2's user directory when started from a Fermi user.

## Outcome

Users reach the admin with reports and email the people they may email (initiative R13, R22, K16).

## Done when

- On the deployed site, a user submits a report and the admin reads it in the reports list
- The Email button opens Gmail's compose screen with the recipient filled in only where K16 allows, and automated checks refuse reading any other email

## Boundaries

- Out: sending or reading mail through Gmail (initiative K12)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R13, R22, Constraints
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-invite-sign-in because: accounts, the user directory and the admin role
