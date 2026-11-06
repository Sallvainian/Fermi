---
type: epic
title: "Calendar"
parent: initiative-capacitor-supabase-port
covers: [R8]
sources: []
companions: []
after: []
refined: false
risk: low
---

# Calendar

## Description

A user creates calendar events and sees the events they created or were added to; a creator adds only people epic 2's directory lets them see.

## Outcome

Users keep their events on a shared calendar (initiative R8).

## Done when

- On the deployed site, a user creates an event and sees the events they created or were added to, and no others
- Automated checks refuse adding a participant the creator cannot see
- A `bmad-tea-trace` run at closure maps each Requirements line to passing tests, and its gate is PASS or each gap has a waiver in Notes

## Boundaries

- Out: notifications for events

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R8, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-3, Consistency Conventions (Calendar)
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 9 Calendar, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-invite-sign-in because: accounts and the directory
- Decision: 2026-11-06, `bmad-tea-test-design` runs on this epic at epic level during its refinement, after its Requirements are written and before its stories are planned; its test plan is adopted as a companion, each story names the scenarios it covers, and the plan settles whether the epic closes with an end-to-end suite
