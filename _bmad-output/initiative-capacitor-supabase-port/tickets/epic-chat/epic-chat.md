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

On epic 3's class membership and epic 2's directory and upload pattern, users chat on one chat model (AD-10): one-to-one between a teacher and their own student or the admin and a teacher, in groups only teachers create with their own students, and in class chats that follow the roster; teachers and the admin attach files up to 10 MB, students send text; users see typing and unread counts; only participants read or post; a removed student loses the class chat and that teacher's groups with history, and an archived class's chat takes no new messages; scheduled messages post at their time through the same send check; users see green, yellow and red presence dots and turn do-not-disturb on or off, over epic 2's presence colour and flag (AD-11). Fills epic 2's chat clause of the directory. Hands message recipients to epic 6 and presence to epic 12.

## Outcome

Users message the people they may message on one chat model that only participants can read (initiative R10, K14).

## Done when

- On the deployed site, a teacher chats one-to-one with their student, in a group they made and in a class chat, attaching a file, while the student sends text; both see typing and unread counts
- A scheduled message posts at its time
- Users see green, yellow and red presence dots and turn do-not-disturb on and off
- Automated checks refuse a non-participant reading or posting, a student-to-student or student attachment send, and a removed student reading the class chat or that teacher's groups
- A `bmad-tea-trace` run at closure maps each Requirements line to passing tests, and its gate is PASS or each gap has a waiver in Notes

## Boundaries

- Out: push and the inbox screen (epic-notifications)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R10, R12, R16, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-2, AD-10, AD-11, AD-13, AD-15, AD-19
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 5 Chat, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-classes-rosters because: classes, enrollment and the class checks for class chats and pairing
- Decision: 2026-11-06, `bmad-tea-test-design` runs on this epic at epic level during its refinement, after its Requirements are written and before its stories are planned; its test plan is adopted as a companion, each story names the scenarios it covers, and the plan settles whether the epic closes with an end-to-end suite
