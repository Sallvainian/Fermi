---
type: epic
title: "Notifications reach people"
parent: initiative-capacitor-supabase-port
covers: [R11, R14, R17, R24]
sources: []
companions: []
after: []
refined: false
risk: high
---

# Notifications reach people

## Description

Users see, mark read and delete their notifications; on the website a notification arriving while Fermi is open shows as a pop-up; a chat message reaches a closed iOS app as a push and, best effort, a closed Home Screen web app as a web push. Opens with a spike that proves web push on the owner's iPhone. Consumes epic 5's message event and hands the notification model to epic 7.

## Outcome

People learn about new messages and notifications without opening Fermi, reliably in the iOS app (initiative R11, R24).

## Done when

- A spike shows whether a chat message reaches the owner's iPhone as a web push on the Home Screen web app while closed
- A chat message reaches a closed TestFlight iOS app as a push
- Users see, mark read and delete notifications, and on the website a notification arriving while Fermi is open shows as a pop-up
- All of it deployed from CI

## Boundaries

- Out: announcements (epic-boards-announcements)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R11, R14, R17, R24, Constraints
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-chat because: the chat message event to notify on
