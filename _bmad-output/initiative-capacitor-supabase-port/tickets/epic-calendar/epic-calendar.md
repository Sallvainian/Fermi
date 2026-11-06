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

## Boundaries

- Out: notifications for events

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R8, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-3, Consistency Conventions (Calendar)
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 9 Calendar, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-invite-sign-in because: accounts and the directory
