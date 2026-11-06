---
type: epic
title: "Teachers and the admin sign in from the admin's list"
parent: initiative-capacitor-supabase-port
covers: [R1, R2, R3, R15, R25, R30]
sources: []
companions: []
after: []
refined: false
risk: high
---

# Teachers and the admin sign in from the admin's list

## Description

On the deployed site and the iOS build, the landing page says Fermi is for teachers on the admin's list and the students they add, shows how to add Fermi to the Home Screen and links the App Store listing; the sign-in screen opens with I'm a teacher (Google, Apple) and I'm a student (email and password); the bootstrap admin and teachers on the admin's email list, which the admin adds to and removes from (R15's list part), sign in with Google or Apple and land on their dashboards, while every other Google or Apple account, a hidden Apple email and an email sign-up are refused (AD-7); roles live only in profiles, set by the one profile creator (AD-6), and nobody changes their own; users complete their name and upload or remove a profile picture (R1's and R2's teacher and admin half; R30's staff-list part). Owns the foundations later epics write into: the directory and app.visible_email with stub class and chat clauses (AD-2, AD-12), the online heartbeat, the do-not-disturb flag and the presence colour every screen reads (AD-11), the notifications table and internal.notify (AD-14), the audit log (AD-22), the user: Realtime topic (AD-19), the upload pattern with the avatars bucket and file cleanup (AD-13, AD-16), the account-deletion test file that later epics add their cases to, the settings table for functions the database calls, and the Apple secret renewal workflow. Turns sign-up on and adds the hook to epic 1's health check in the change that creates the hook. Opens with the spine's sign-in spikes. Hands profiles, the profile creator, notify and the audit log to epic 3; notify to epics 4, 6 and 7; the upload pattern and file cleanup to epics 4 and 5; presence, the do-not-disturb flag and the user: topic to epics 5 and 6; app.visible_email to epic 10; accounts and the directory to epics 5, 9 and 10; and the admin role, the teacher list and the audit log to epic 12.

## Outcome

The admin and listed teachers get into Fermi with Google or Apple, nobody else can make an account, and no user can change their role (initiative R1, K3, K4).

## Done when

- On the deployed site and the iOS build, the admin and a listed teacher each sign in with Google or Apple from I'm a teacher and land on their dashboard
- Automated checks refuse an unlisted Google or Apple account, a hidden Apple email and an email sign-up, and refuse a user changing their own role
- The admin adds and removes teacher emails, a student's email is refused, and each change is in the audit log
- A user completes their name and uploads or removes a profile picture; a file over 10 MB or of the wrong type is refused by its stored bytes, and a removed picture's file is swept
- The landing page shows who Fermi is for, the Home Screen steps and the App Store link

## Boundaries

- Out: classes, rosters, student accounts and student passwords (epic-classes-rosters)
- Out: the admin user list, console and account deletion (epic-admin-console)
- Out: the inbox screen and push delivery (epic-notifications)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R1, R2, R3, R15, R25, R30, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-1–AD-7, AD-11–AD-14, AD-16, AD-19, AD-22, Open Questions (sign-in spikes)
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 2 Sign-in, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-platform-baseline because: the CI pipeline, the Supabase project, the app shell, the empty schemas, pg_cron and pg_net
