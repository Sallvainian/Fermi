---
type: epic
title: "Admin console and account deletion"
parent: initiative-capacitor-supabase-port
covers: [R5, R15, R26, R28, R29, R30]
sources: []
companions: []
after: []
refined: false
risk: medium
---

# Admin console and account deletion

## Description

The admin lists users with counts by role and online (from epic 2's presence colour) manages epic 2's teacher email list in the console, and opens any class's roster to add students and show or reset passwords as its teacher can (R5's and R26's admin part); delete-account is the only way an account is deleted (AD-16): the admin deletes any account but their own, a teacher deletes their own account from Settings after a warning listing their classes, and a teacher of a student completes that student's open removal request from epic 3; deletion removes the person's teacher list entry, stored password, files and rows by the cascade rule, and each deletion is written to epic 2's audit log, which the admin reads in a view this epic adds (R29's completion part; R30's account-deletion part). Delivers R15's rest beside epic 2's teacher list.

## Outcome

The admin sees who uses Fermi, and every account can be deleted the one way the rules allow (initiative R15, R28, R29).

## Done when

- On the deployed site, the admin lists users with counts by role and online, manages the teacher email list, and adds a student to another teacher's class and shows their password
- The admin deletes another account and their own is refused; a teacher deletes their own account after the warning, and their classes go with it
- A teacher completes a student's open removal request, and without one is refused
- Automated checks show each deletion leaves no rows, files or stored password behind except kept authored posts, and is in the audit log

## Boundaries

- Out: adding and removing teacher emails themselves (epic-invite-sign-in)
- Out: the student's removal request (epic-classes-rosters)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R5, R15, R26, R28, R29, R30, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-7, AD-11, AD-16, AD-22
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 12 Admin console, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-invite-sign-in because: accounts, the admin role, the teacher list and the audit log
- Waits on epic-classes-rosters because: removal requests and teacher-student links
