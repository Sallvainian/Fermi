---
type: initiative
title: Capacitor Supabase Port
parent: none
sources:
  - _bmad-output/initiative-capacitor-supabase-port/research-firebase-backend-auth-rules-collections/research-firebase-backend-auth-rules-collections.md
  - _bmad-output/initiative-capacitor-supabase-port/brief-port-goals.md
companions:
  - _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md
after: []
risk: high
---

# Capacitor Supabase Port

## Description

Fermi is rebuilt as one Capacitor app on Supabase, and Flutter and Firebase are retired. It ships as a website that anyone can save to their iPhone's Home Screen, plus an optional App Store iPhone app for reliable notifications. The port keeps every feature a teacher, student or admin can reach and use today, as the codebase research at 7808a91 traced it, and fixes five features that are broken today. It drops desktop, Android (for now), Jeopardy, calls, games and dead code, and it starts with no migrated data. The Roselle email domains no longer decide roles. Invite codes do: the admin issues teacher codes, and teachers issue student codes. After the code, people sign in with Google or Apple. Fermi has no passwords and sends no email. The Firebase access model let users edit their own role and read other users' data, so the new backend enforces roles, ownership and membership on the server from the start. The site lives on a free workers.dev address and ships from CI the way My-Love does.

## Outcome

Teachers, students and the admin use Fermi on the website and in the iPhone app with today's features, and no Firebase sits behind it (brief G1). Nobody gets in without an invite code, and no user can raise their own access (brief C4, D6).

## Requirements

- R1 (D6, D7, research Q1, Q2): a person gets in only with an invite code: on the landing page they enter it, sign in with Google or Apple, and get the code's role; teacher codes come from the admin and student codes from a teacher; without a valid code no sign-in creates an account
- R2 (research Q1): a signed-in user lands on their role's dashboard (teacher, student, admin), and a Google or Apple account with no Fermi account cannot get in
- R3 (research Q4, Q5): a user completes their name and uploads or removes a profile picture
- R4 (research Q3, Q6, D17): a teacher creates, edits and deletes their own classes and manages each roster; a student joins a class by entering its code and their name, and gets in only when the name matches a student on that class's roster, so a code shared outside the class lets nobody in; each roster entry can be claimed once, an exact name match joins at once, a near match waits for the teacher to approve, and the teacher can undo a claim
- R5 (research Q5, Q6, Q9, D18): a teacher or admin adds students to a class roster by name, one at a time or by a CSV of up to 1000 rows
- R6 (research Q3, Q6, D10, D12): a teacher creates, publishes, edits and deletes assignments for their class, with files attached from the device or Google Drive; enrolled students see them, open their attachments, and submit text with files from the device or Google Drive; the teacher grades submissions; a student sees only their own grades
- R7 (research Q8, Q10): a teacher manages a class's behaviors, awards and undoes points, and sees class totals and filtered history; a student sees only their own points and history
- R8 (research Q3, Q6): a user creates calendar events and sees the events they created or were added to
- R9 (research Q3, Q7, D16): users read and post in discussion boards, threads and replies, and like threads and replies; only teachers create boards; authors delete their own posts
- R10 (research Q4, Q7, Q10): users chat one-to-one, in groups and in class chats, with text and with image or file attachments of allowed types up to 10 MB; they see typing and unread counts, and only participants read or post
- R11 (D9, research Q11): in the App Store iPhone app, a chat message sent to a user whose app is in the background or closed shows a system notification
- R12 (research Q5): users see which other users are online
- R13 (research Q5): a user submits a support or bug report, and it is stored for the admin
- R14 (research Q5): a user sees their notifications, marks them read and deletes them
- R15 (research Q5, Q12, D6, D15): an admin lists users with counts by role and online, creates teacher invite codes, and deletes any account but their own
- R16 (D10, research Q5): a user schedules a chat message, and it is posted to the chat at the chosen time
- R17 (D10, research Q11): on the website, a notification that arrives while Fermi is open shows as a pop-up
- R18 (D10, research Q6): a teacher sees a class's grade analytics: per-student performance, per-assignment stats, category performance and grade trends over time
- R19 (D10, research Q6, Q8): dashboard widgets show real data: for a teacher, assignment stats and recent activity; for a student, upcoming assignments, recent grades, assignment stats and GPA
- R20 (D11): a teacher posts an announcement in a class's Announcements board, and the class's members read it and get a notification
- R21 (D13): a teacher archives a class at the end of the year; the class and its grades leave the main views and stay viewable under Archived, a teacher's for their classes and a student's for their own grades
- R22 (D14): a user opens Gmail's compose screen from inside Fermi, with the recipient filled in when they start from a Fermi user
- R23 (D9): after a deploy, the App Store iPhone app downloads the new build in the background and offers to restart onto it
- R24 (D9): on the website saved to the Home Screen, a user who allowed notifications gets a system notification for a chat message while Fermi is closed; this is best effort, and the inbox and unread counts still show what was missed
- R25 (D6, D9): the landing page says access is by invite only, shows how to add Fermi to the Home Screen, and links the iPhone app

## Constraints

- K1 (C1, D1, D5): one Capacitor codebase ships the website and an iOS app; Android comes later; there is no desktop shell
- K2 (C2): Supabase is the only backend (auth, Postgres, edge functions, storage); no Firebase SDK, config or project dependency remains
- K3 (D6, research Q2): the role comes from the invite code and is set on the server when the account is created; no sign-in method creates an account without a valid code; today Google sign-in skips the client's domain check
- K4 (C4, research Q2, Q3): no user can change their own role, and one authoritative role store backs every access check; today the claim and `users.role` diverge, and an owner can edit their role
- K5 (research Q3, Q4, Q9, Q10): every access decision is enforced on the server by membership and ownership, and none of the Firebase defects listed in the parity inventory comes back
- K6 (C5, D8): the site is served by Cloudflare Workers static assets only, from a Worker named `fermi-plus` on a free workers.dev subdomain like My-Love (fermi-plus.<account>.workers.dev; the account part is UNVERIFIED, My-Love's is sallvain), with no bought domain; the Worker script `src/index.js` that `wrangler.toml` names today goes away
- K7 (C5, D9, D16): a push to main deploys from CI in order: apply Supabase migrations, deploy edge functions, build and package the live update, wrangler deploy, health check; the live update is served from the Workers site, not a Capgo account, as in My-Love; nothing is deployed by hand
- K8 (D2): no migration code or Firebase export tooling is built
- K9 (D3, D4, D11): scope is the reachable working features in the parity inventory, plus the five fixed in D10; Jeopardy, calls, games/scores and the dead code listed there are out
- K10 (D7): Fermi sends no email: no passwords and no email provider
- K11 (D9, D19): the iOS app ships as an update to Fermi's existing App Store listing (bundle `com.academic-tools.fermi`, team W778837A9L) and must pass its review: Sign in with Apple works as fully as Google, and reviewers get a test invite code
- K12 (D12, D14): Fermi asks Google only for sign-in and for per-file Drive access (`drive.file`, which Google rates non-sensitive, so only its basic app verification applies), requested the first time a user attaches from Drive; it never reads or sends a user's Gmail
- K13 (D16): access policies and edge functions have automated tests that run in CI; today nothing tests rules or functions
- K14 (D16): chat is one model shared by direct, group and class chats; today it is stored two ways
- K15 (D9, D19): a live update carries fixes, UI changes and content within the app's purpose; a major new feature ships as a reviewed App Store build (Apple's license terms allow downloaded web code that does not change the app's primary purpose, per Capgo's reading)
- K16 (D20): a user sees another user's email only where D20 allows (their teachers' and the admin's for a student, their students' for a teacher, everyone's for the admin); every other email stays private

## Done when

- A walkthrough per role, on the website in Safari, on the website saved to the Home Screen, and in the iPhone app against the hosted Supabase project, shows each of R1–R25 working
- Automated checks show that neither Google nor Apple sign-in creates an account without a valid invite code, that a class code with a name not on its roster is refused, and that a user's attempt to change their own role, or to read another user's private data, is refused
- A push to main runs migrations, edge functions, build, wrangler deploy and the health check from CI; the workers.dev site serves the new build, and an installed iPhone app offers to restart onto it
- The iPhone app passes App Store review
- No Firebase package, config file or SDK call is left in the app, its native project or CI

## Boundaries

- Out: Android, until a later initiative (D5)
- Out: macOS, Windows and Linux builds, and the desktop OAuth flows (D1)
- Out: moving any existing Firebase user or data into Supabase (D2)
- Out: Jeopardy, including the stub games screen; calls; games and scores (D4, D11)
- Out: unreachable and always-broken features listed in the parity inventory, other than the five D10 names back in (D3)
- Out: passwords, any email sent by Fermi, and a bought domain (D7, D8)
- Out: an in-app folder file manager (D12)
- Out: reading or sending a user's Gmail from Fermi (D14)
- Out: fixing or hardening the Firebase backend that is being retired
- Touch point: the hosted Supabase project — linked and migrated from CI; owner: epic-platform-baseline
- Touch point: the Cloudflare account — the fermi-plus Worker on workers.dev; the old Pages project `fermi` is removed by epic-app-store-release; owner: epic-platform-baseline
- Touch point: Apple Developer and App Store Connect — TestFlight internal builds (epic-platform-baseline), Sign in with Apple (epic-invite-sign-in), the push key (epic-notifications), review of the listing com.academic-tools.fermi; owner: epic-app-store-release
- Touch point: the Google Cloud project Fermi-Plus (`fermi-plus-513902`) — the OAuth client for sign-in and its basic app verification; owner: epic-invite-sign-in; the Drive Picker and `drive.file` on it; owner: epic-assignments-grades
- Touch point: Gmail — its compose screen is opened, never called; owner: epic-contact
- Touch point: the `@capgo/capacitor-updater` plugin — self-hosted live updates, no Capgo account; owner: epic-platform-baseline
- Touch point: My-Love — read as the reference for CI, hosting and live updates, never changed; owner: epic-platform-baseline
- Tracer path: the admin creates a teacher code; a teacher enters it on the website, signs in with Google, creates a class and adds a student to its roster; that student enters the class code and their name in the iPhone app, signs in with Apple and is messaged by the teacher; the message arrives as a push notification while the app is closed

## References

- research — _bmad-output/initiative-capacitor-supabase-port/research-firebase-backend-auth-rules-collections/research-firebase-backend-auth-rules-collections.md, Q1–Q13 and "Where the answers meet"
- brief — _bmad-output/initiative-capacitor-supabase-port/brief-port-goals.md, Goal, Constraints, Answers to the brackets, Later answers
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md: requirement-to-Firebase map, out-of-scope lists, defects not to repeat, data-shape conflicts
- deploy reference — /Users/sallvain/Projects/My-Love/.github/workflows/deploy.yml, jobs migrate, functions, build, deploy, health-check
- live update reference — /Users/sallvain/Projects/My-Love/src/services/nativeUpdates.ts, scripts/package-live-update.sh and the `CapacitorUpdater` block in capacitor.config.ts

## Notes

- Assumption: a teacher code works once
- Assumption: since nobody exists yet to invite the first admin, a migration adds a rule that makes one Google account the admin on its first sign-in; that account's email is kept as a secret (in fnox, set on Supabase by CI), not in the migration, because the repo is public
- Decision: 2026-11-05, desktop dropped, start fresh, parity means reachable working features, Jeopardy removed (brief D1–D4)
- Decision: 2026-11-05, Android later, invite codes replace the domain gate, Google or Apple sign-in with no passwords or email, workers.dev hosting, Home Screen website plus optional App Store app, five broken features fixed, calls and games removed, Drive for assignments, class archiving, Gmail opened not sent, no admin password reset (brief D5–D16)
- Decision: 2026-11-05, class codes work only for students on the roster, matched by name; rosters filled one at a time or by CSV; the port updates Fermi's existing App Store listing (brief D17–D19)
- Decision: 2026-11-05, email visibility follows D20 (K16)
- Decision: 2026-11-05, sliced into 13 epics in tickets/tickets.toml, one feature area each, deployed on its own; rule: one source capability or a tightly coupled pair per epic; the platform baseline opens
- Decision: 2026-11-05, decisions several epics share (web framework, schema and access-policy pattern, edge-function errors, upload rules, account-delete rule, live update versus App Store build) are settled in an architecture spine through bmad-architecture before epic 1's stories
- Decision: 2026-11-05, the new app lives in `app/` beside the Flutter app until epic-app-store-release removes Flutter; its iOS project takes over bundle com.academic-tools.fermi
- Decision: 2026-11-05, class archiving moved to epic-classes-rosters so other epics' class views do not collide; epic-invite-sign-in owns the upload pattern and the user directory
- Decision: 2026-11-05, sign-in and Drive use a new Google Cloud project just for Fermi, Fermi-Plus (`fermi-plus-513902`), created by the user, as My-Love has its own (my-love-478322); not the Firebase project teacher-dashboard-flutterfire, since K2 allows no Firebase project dependency
