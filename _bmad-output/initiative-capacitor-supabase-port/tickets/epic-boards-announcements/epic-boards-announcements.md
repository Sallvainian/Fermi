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

On epic 3's classes and membership, teachers create boards; users read, post, reply and like; authors delete their own posts; a teacher's announcement in a class's Announcements board notifies the class through epic 6's notification model. Hands posts to epic 11 for recent activity.

## Outcome

Classes discuss on boards and hear teachers' announcements (initiative R9, R20).

## Done when

- On the deployed site, a teacher creates a board, and users post, reply, like, and delete their own posts
- A student cannot create a board
- A teacher's announcement notifies the class's members

## Boundaries

- Out: the notification model itself (epic-notifications)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R9, R20, Constraints
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-classes-rosters because: classes and membership
- Waits on epic-notifications because: the notification model
