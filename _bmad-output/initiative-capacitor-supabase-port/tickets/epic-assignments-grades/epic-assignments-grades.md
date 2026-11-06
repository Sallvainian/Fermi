---
type: epic
title: "Assignments, submissions and grades"
parent: initiative-capacitor-supabase-port
covers: [R6, R18, R21]
sources: []
companions: []
after: []
refined: false
risk: medium
---

# Assignments, submissions and grades

## Description

On epic 3's classes and membership and epic 2's upload pattern, a teacher publishes assignments with files from the device or Google Drive; enrolled students open them and submit text with files from the device or Drive; the teacher grades; a student sees only their own grades; a teacher sees a class's grade analytics; an archived class's grades stay viewable under Archived (R21's grades part). Hands assignments, submissions and grades to epic 11.

## Outcome

Teachers assign and grade work with files and Drive, and students see only their own grades (initiative R6).

## Done when

- On the deployed site, a teacher publishes an assignment with a device file and a Drive file, and an enrolled student opens both
- The student submits text with files, the teacher grades it, and the student sees only their own grade
- The teacher sees the class's analytics, and an archived class's grades stay viewable under Archived
- Automated checks refuse a student submitting to an assignment outside their classes

## Boundaries

- Out: class archiving itself (epic-classes-rosters); dashboard widgets (epic-dashboards)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R6, R18, R21, Constraints
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-classes-rosters because: classes, enrollment and the archived flag
