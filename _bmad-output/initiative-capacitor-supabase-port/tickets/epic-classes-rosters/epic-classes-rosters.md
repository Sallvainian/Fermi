---
type: epic
title: "Teachers run classes and students join them"
parent: initiative-capacitor-supabase-port
covers: [R1, R2, R4, R5, R21]
sources: []
companions: []
after: []
refined: false
risk: medium
---

# Teachers run classes and students join them

## Description

A teacher creates, edits, archives and deletes classes and fills each roster by name, one at a time or by CSV; an archived class leaves the main class views and stays under Archived (R21's class part); a student joins with the class code and their name, matched to the roster with claim-once, teacher approval for near matches and undo, and lands on the student dashboard. Delivers R1's student half on epic 2's invite model, and hands classes, membership and the archived flag to epics 4, 5, 7 and 8.

## Outcome

Teachers run their classes and only students on a class's roster can join it (initiative R4, D17).

## Done when

- On the deployed site, a teacher creates a class and fills its roster by hand and by CSV
- A rostered student joins with the code and their name and lands on the student dashboard; a name not on the roster is refused, a near match waits for the teacher, and a claimed entry cannot be claimed twice
- An archived class leaves the main class views and stays under Archived
- Automated checks refuse a teacher editing another teacher's class

## Boundaries

- Out: assignments and grades of archived classes (epic-assignments-grades)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R1, R2, R4, R5, R21, Constraints
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-invite-sign-in because: accounts, server-set roles and the invite-code model
