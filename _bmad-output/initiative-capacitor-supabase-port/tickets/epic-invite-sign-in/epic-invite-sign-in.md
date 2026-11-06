---
type: epic
title: "Teachers and the admin get in by invite"
parent: initiative-capacitor-supabase-port
covers: [R1, R2, R3, R15, R25]
sources: []
companions: []
after: []
refined: false
risk: high
---

# Teachers and the admin get in by invite

## Description

On the deployed site and the iOS build, the landing page says access is by invite only, shows how to add Fermi to the Home Screen and links Fermi's existing App Store listing; the admin is made by migration on first Google sign-in and creates teacher codes (R15's teacher-code part); a teacher signs in with a code and Google or Apple; roles are set on the server, nobody changes their own, the admin and teachers land on their dashboards, and users complete their name and upload or remove a profile picture. Owns the upload pattern (type and real byte-size checks, short-lived links) that epics 4 and 5 reuse, and the user directory (who sees whose name, picture and email). Hands accounts, roles and the invite-code model to epic 3, and accounts, the directory and the admin role to epics 5, 9, 10 and 12.

## Outcome

The admin and teachers get into Fermi only with an invite code and Google or Apple, with roles no user can change (initiative R1, K3, K4).

## Done when

- On the deployed site and the iOS build, the admin and a teacher each get in with a code and Google or Apple and land on their dashboard
- Automated checks refuse an account with no valid code by either sign-in, and refuse a user changing their own role
- A user completes their name and uploads or removes a profile picture, and an oversized or wrong-type file is refused by its real bytes
- The landing page shows the invite-only notice, the Home Screen steps and the App Store link

## Boundaries

- Out: classes, rosters and student joining (epic-classes-rosters)
- Out: the admin user list and account deletion (epic-admin-console)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R1, R2, R3, R15, R25, Constraints
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-platform-baseline because: the CI pipeline, the Supabase project and the app shell
