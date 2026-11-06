---
type: epic
title: "Discussion boards and announcements"
parent: initiative-capacitor-supabase-port
covers: [R9, R20]
sources: []
companions: []
after: []
refined: false
risk: low
---

# Discussion boards and announcements

## Description

On epic 3's classes and checks, teachers create boards; users read, post, reply and like; authors delete their own posts; each class gets an Announcements board (AD-9), and a teacher's announcement notifies the class's members through epic 2's notify, which they see in epic 6's inbox and as a push; an archived class's boards take no new posts. Hands posts to epic 11 for recent activity.

## Outcome

Classes discuss on boards and hear teachers' announcements (initiative R9, R20).

## Done when

- On the deployed site, a teacher creates a board, and users post, reply, like, and delete their own posts
- A student cannot create a board, and an archived class's boards refuse new posts
- A teacher's announcement reaches the class's members in the inbox and as a push

## Boundaries

- Out: notify and the inbox (epic-invite-sign-in, epic-notifications)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R9, R20, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-4, AD-9, AD-14
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 7 Boards and announcements, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-classes-rosters because: classes and membership
- Waits on epic-notifications because: the inbox screen and push delivery, so members see the announcement
