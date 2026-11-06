---
type: epic
title: "Admin console"
parent: initiative-capacitor-supabase-port
covers: [R15]
sources: []
companions: []
after: []
refined: false
risk: medium
---

# Admin console

## Description

The admin lists users with counts by role and online (from epic 5's presence) and deletes any account but their own, the delete following the shared account-delete rule. Delivers R15's rest beside epic 2's teacher codes.

## Outcome

The admin sees who uses Fermi and removes accounts (initiative R15).

## Done when

- On the deployed site, the admin lists users with counts by role and online
- The admin deletes another account, its data goes per the account-delete rule, and deleting their own is refused

## Boundaries

- Out: teacher invite codes (epic-invite-sign-in)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R15, Constraints
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-invite-sign-in because: accounts and the admin role
- Waits on epic-chat because: presence for the online count
