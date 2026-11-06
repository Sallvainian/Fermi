---
type: epic
title: "Chat on one model"
parent: initiative-capacitor-supabase-port
covers: [R10, R12, R16]
sources: []
companions: []
after: []
refined: false
risk: medium
---

# Chat on one model

## Description

On epic 3's class membership, epic 2's user directory and upload pattern, users chat one-to-one, in groups and in class chats on one chat model, with text and checked attachments up to 10 MB, typing and unread counts; only participants read or post; scheduled messages post at their time; users see who is online. Hands the message event to epic 6 and presence to epic 12.

## Outcome

Users message each other on one chat model that only participants can read (initiative R10, K14).

## Done when

- On the deployed site, users chat one-to-one, in a group and in a class chat with text and attachments, seeing typing and unread counts
- A scheduled message posts at its time
- Users see who is online
- Automated checks refuse a non-participant reading or posting, and an attachment over 10 MB by its real bytes

## Boundaries

- Out: push and the notification inbox (epic-notifications)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R10, R12, R16, Constraints
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-classes-rosters because: classes and enrollment for class chats
