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

Users see, mark read and delete their notifications in an inbox screen over epic 2's notifications table; a notification arriving while Fermi is on screen shows as a pop-up and sends no push (epic 2's on-screen presence); chat messages and every notification kind reach the Home Screen web app on an iPhone while Fermi is not on screen and, best effort, desktop Chrome, Edge and Safari as a web push whose text names who and what kind, never the message text or score; do-not-disturb silences push and pop-ups, and gone push subscriptions are removed (AD-14). Push runs through one service worker, which handles push only and caches nothing (AD-25), and sign-out unsubscribes the browser before the session ends (AD-27). Opens with a spike that proves web push on the owner's iPhone. Consumes epic 2's notify and epic 5's message recipients; notifications written by epics 3 and 4 start reaching devices when this ships, and epic 7's announcements reach people through it.

## Outcome

People learn about messages and notifications without opening Fermi: on an iPhone through Fermi saved to the Home Screen, and best effort in desktop browsers (initiative R11, R24).

## Done when

- A spike shows whether a chat message reaches the owner's iPhone as a web push on the Home Screen web app while closed
- A chat message and an inbox notification reach the closed Home Screen web app on the owner's iPhone, and a desktop browser, as a web push
- Users see, mark read and delete notifications, and a notification arriving while Fermi is on screen shows as a pop-up with no push
- Automated checks show do-not-disturb skips push and the pop-up, a recipient with Fermi on screen gets no push, push text carries no message text or score, and a gone push subscription (web push 404 or 410) is removed
- All of it deployed from CI
- A `bmad-tea-trace` run at closure maps each Requirements line to passing tests, and its gate is PASS or each gap has a waiver in Notes

## Boundaries

- Out: the notifications table and notify (epic-invite-sign-in)
- Out: announcements (epic-boards-announcements)
- Out: APNs and any native push (initiative Decision 2026-11-07)
- Out: offline use, caching, and any second service worker; `sw.js` has no `fetch` handler (AD-25)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R11, R14, R17, R24, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-11, AD-14, AD-19, AD-25, AD-27
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 6 Notifications, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-chat because: the messages table and message recipients to deliver on
- Decision: 2026-11-06, iOS push is checked in the Simulator through Apple's sandbox push server, not on TestFlight; the spine's Tests line, AD-14 and Open Questions were amended to match, and production APNs moves to epic-app-store-release
- Decision: 2026-11-06, `bmad-tea-test-design` runs on this epic at epic level during its refinement, after its Requirements are written and before its stories are planned; its test plan is adopted as a companion, each story names the scenarios it covers, and the plan settles whether the epic closes with an end-to-end suite
- Decision: 2026-11-07, replan from the initiative's Decision (owner): no iPhone app, so iPhone notifications are web push to the Home Screen web app (R11), and this epic loses APNs, the sandbox Simulator spike, push environments and APNs token handling; the 2026-11-06 Simulator decision above no longer applies; the web push spike stays this epic's opening ticket (owner declined moving it earlier)
- Decision: 2026-11-07, the web push service worker this epic adds must not serve a stale build after epic-platform-baseline story 1.16's reload offer; iPhone web push relies on story 1.15's manifest, which makes Fermi a standalone Home Screen web app
- Decision: 2026-11-07, ticket sync from the spine update of the same day (owner): one service worker, `/sw.js`, for push only, with no caching and no offline mode, which settles the stale-build line above (AD-25); no push to a recipient with Fermi on screen, who gets the pop-up instead, read from epic 2's per-client presence (`app.on_screen`), with no `profiles.last_seen_at` (AD-11, AD-14); push text names who and what kind, never the message text or score (AD-14); this epic adds the browser unsubscribe and `unregister_push_device` step to epic 2's `signOut()` (AD-27)
- Open question: how does Fermi notice and recover an iPhone web push subscription that iOS dropped without warning (reported by developers, UNVERIFIED)? waits: this epic's web push spike, settled at refinement
