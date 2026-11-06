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

Users see, mark read and delete their notifications in an inbox screen over epic 2's notifications table; on the website a notification arriving while Fermi is open shows as a pop-up; chat messages and every notification kind reach a closed iOS app as a push and, best effort, the Home Screen web app and desktop Chrome, Edge and Safari as a web push; do-not-disturb silences push and pop-ups, and dead device tokens are removed (AD-14). Opens with a spike that proves web push on the owner's iPhone. Consumes epic 2's notify and epic 5's message recipients; notifications written by epics 3 and 4 start reaching devices when this ships, and epic 7's announcements reach people through it.

## Outcome

People learn about messages and notifications without opening Fermi, reliably in the iOS app (initiative R11, R24).

## Done when

- A spike shows whether a chat message reaches the owner's iPhone as a web push on the Home Screen web app while closed
- A spike shows a sandbox push reaching a closed Fermi in the iOS Simulator on the owner's Mac; if it cannot, a development build installed from Xcode on the owner's iPhone takes the Simulator's place
- A chat message and an inbox notification reach a closed iOS app in the Simulator (or the spike's fallback) as a sandbox push, and a desktop browser as a web push
- Users see, mark read and delete notifications, and on the website a notification arriving while Fermi is open shows as a pop-up
- Automated checks show do-not-disturb skips push and the pop-up, a device row records the push environment the app reported at registration, a gone device token (APNs 410, web push 404 or 410) is removed, and an APNs 400 `BadDeviceToken` is logged and the device kept
- All of it deployed from CI

## Boundaries

- Out: the notifications table and notify (epic-invite-sign-in)
- Out: announcements (epic-boards-announcements)
- Out: production APNs, first checked on epic-app-store-release's TestFlight build

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R11, R14, R17, R24, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-11, AD-14, AD-19
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 6 Notifications, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-chat because: the messages table and message recipients to deliver on
- Decision: 2026-11-06, iOS push is checked in the Simulator through Apple's sandbox push server, not on TestFlight; the spine's Tests line, AD-14 and Open Questions were amended to match, and production APNs moves to epic-app-store-release
