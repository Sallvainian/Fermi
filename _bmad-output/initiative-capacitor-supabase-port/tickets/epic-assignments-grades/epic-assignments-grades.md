---
type: epic
title: "Assignments, submissions and grades"
parent: initiative-capacitor-supabase-port
covers: [R6, R18, R21, R27]
sources: []
companions: []
after: []
refined: false
risk: medium
---

# Assignments, submissions and grades

## Description

On epic 3's classes and checks and epic 2's upload pattern, a teacher publishes assignments with files from the device or copied in from Google Drive (AD-13); enrolled students open them and submit text with files from the device or Drive, frozen at submit; the teacher grades; a student sees only their own grades; students get a notification for a published assignment and a graded submission through epic 2's notify; a teacher sees a class's grade analytics from one grade-summary function; an archived class's grades stay viewable under Archived and it takes no new assignments, submissions or grades (R21's grades part); students get due reminders for unsubmitted work, 24 hours before by default, each setting their own times or turning them off (AD-15). Opens with a spike on the Drive picker page in the iOS sign-in sheet. Hands assignments, submissions, grades and the grade-summary function to epic 11.

## Outcome

Teachers assign and grade work with files and Drive, students see only their own grades and get reminded before work is due (initiative R6, R27).

## Done when

- On the deployed site, a teacher publishes an assignment with a device file and a Drive file copied in, and an enrolled student opens both
- The student submits text with files, the teacher grades it, the student sees only their own grade, and publish and grade each write a notification
- A student who has not submitted gets a due reminder at their own times, or none when they turned reminders off
- The teacher sees the class's analytics, and an archived class's grades stay viewable under Archived
- Automated checks refuse a student submitting to an assignment outside their classes, or editing a submission after submit

## Boundaries

- Out: class archiving itself (epic-classes-rosters)
- Out: dashboard widgets (epic-dashboards)
- Out: push delivery of its notifications (epic-notifications)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R6, R18, R21, R27, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-4, AD-9, AD-13, AD-14, AD-15, Consistency Conventions (grade summary), Open Questions (Drive picker spike)
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 4 Assignments and grades, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-classes-rosters because: classes, enrollment, the class checks and the archived flag
