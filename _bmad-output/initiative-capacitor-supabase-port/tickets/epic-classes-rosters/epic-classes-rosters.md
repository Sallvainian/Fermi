---
type: epic
title: "Teachers run classes and add their students"
parent: initiative-capacitor-supabase-port
covers: [R1, R2, R4, R5, R21, R26, R29, R30]
sources: []
companions: []
after: []
refined: false
risk: high
---

# Teachers run classes and add their students

## Description

A teacher creates, edits, archives and deletes classes (an archived class leaves the main views, stays under Archived and takes no new writes; R21's class part) and adds students to each roster by name and school email, one at a time or by CSV, which creates each new student's account with a generated password, enrolls an existing student keeping theirs, refuses staff emails and ends with a printable sheet (AD-8; R5's and R26's teacher part, the admin's is epic 12's); a rostered student signs in with that email and password and lands on the student dashboard (R1's and R2's student half); each roster row shows waiting or connected, Show password and Reset password, and students cannot change their password or leave a class; a teacher removes a student, ending their access to the class (AD-9); every roster function also works for the admin on any class, for epic 12's screen; a student's Ask my teacher to remove my account writes a request and notifies their teachers and the admin. Class, roster, password and removal-request actions go into epic 2's audit log, and teachers read their classes' and students' events in a view this epic adds (R29's request part; R30's class, roster, password and request part). Fills epic 2's class clauses of the directory, hands classes, enrollment, the archived flag and the class checks to epics 4, 5, 7 and 8, and removal requests to epic 12.

## Outcome

Teachers run their classes and create their students' accounts, and only rostered students get in (initiative R1, R4, R5; spine AD-8).

## Done when

- On the deployed site, a teacher creates a class and adds students one at a time and by CSV, gets the printable sheet, and a staff email is refused
- A rostered student signs in with that email and password and lands on the student dashboard; Show password and Reset password work for every teacher of that student, and a student's own password change is refused
- A removed student loses access to the class; an archived class leaves the main views, stays under Archived and refuses new writes
- A student's removal request notifies their teachers and the admin, and class, roster, password and request actions are in the audit log
- Automated checks refuse a teacher editing another teacher's class or seeing a password of a student they do not teach

## Boundaries

- Out: assignments and grades of archived classes (epic-assignments-grades)
- Out: deleting a student's account, even on request (epic-admin-console)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R1, R2, R4, R5, R21, R26, R29, R30, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-2, AD-4, AD-8, AD-9, AD-14, AD-22
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 3 Classes and rosters, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-invite-sign-in because: profiles and the profile creator, the directory, notify and the audit log
