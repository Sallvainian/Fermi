---
type: initiative
title: Capacitor Supabase Port
parent: none
sources: [_bmad-output/initiative-capacitor-supabase-port/research-firebase-backend-auth-rules-collections/research-firebase-backend-auth-rules-collections.md, _bmad-output/initiative-capacitor-supabase-port/brief-port-goals.md, _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md]
companions: [_bmad-output/initiative-capacitor-supabase-port/parity-inventory.md, _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md]
after: []
risk: high
---

# Capacitor Supabase Port

## Description

Fermi is rebuilt as one web app on Supabase, and Flutter and Firebase are retired. It ships only as a website, which iPhone users save to the Home Screen from Safari; there is no iPhone app, because every change to a native shell waits on App Review (owner, 2026-11-07). The port keeps every feature a teacher, student or admin can reach and use today, as the codebase research at 7808a91 traced it, fixes five features that are broken today, and adds due reminders, do-not-disturb, account deletion and an audit log. It drops desktop, Android (for now), Jeopardy, calls, games and dead code, and it starts with no migrated data. The Roselle email domains no longer decide roles, and nobody signs themselves up. The admin keeps a list of teacher emails, and listed teachers sign in with Google. Teachers create their students' accounts by adding them to class rosters, and students sign in with the school email and the password their teacher gives them. Fermi sends no email. The Firebase access model let users edit their own role and read other users' data, so the new backend enforces roles, ownership and membership in the database from the start, as the architecture spine lays out. The site lives on a free workers.dev address and ships from CI the way My-Love does.

## Outcome

Teachers, students and the admin use Fermi on the website and saved to the iPhone Home Screen with today's features, and no Firebase sits behind it (brief G1). Nobody gets in who is not on the admin's teacher list or a teacher's roster, and no user can raise their own access (brief C4, spine AD-7, AD-8).

## Requirements

- R1 (AD-6, AD-7, AD-8, Decision 2026-11-07): the sign-in screen opens with "I'm a teacher" and "I'm a student"; a teacher or the admin signs in with Google and gets in only when their email is on the admin's teacher list (the admin's own email is set up once); a student signs in with the school email and password their teacher's roster gave them; nobody registers themselves
- R2 (research Q1, AD-6, Decision 2026-11-07): a signed-in user lands on their role's dashboard (teacher, student, admin) whichever button they used, and a Google account whose email is not on the teacher list cannot get in
- R3 (research Q4, Q5): a user completes their name and uploads or removes a profile picture
- R4 (research Q3, Q6, AD-9): a teacher creates, edits and deletes their own classes and manages each roster; students cannot leave a class, only its teacher removes them; a removed student loses that class's chat, groups, grades and points, which stay for the teacher
- R5 (research Q5, Q6, Q9, D18, AD-8): a teacher or the admin adds students to a class roster by name and school email, one at a time or by a CSV of up to 1000 rows; a new email gets a student account with a generated password, an existing student is enrolled keeping their password, and a teacher's or the admin's email is refused; each row shows its own result, and the teacher gets a printable sheet of the added students' emails and passwords
- R6 (research Q3, Q6, D10, D12, AD-14): a teacher creates, publishes, edits and deletes assignments for their class, with files attached from the device or Google Drive; enrolled students see them, open their attachments, and submit text with files from the device or Google Drive; the teacher grades submissions; a student sees only their own grades; enrolled students get a notification when an assignment is published and when their work is graded
- R7 (research Q8, Q10): a teacher manages a class's behaviors, awards and undoes points, and sees class totals and filtered history; a student sees only their own points and history
- R8 (research Q3, Q6): a user creates calendar events and sees the events they created or were added to
- R9 (research Q3, Q7, D16): users read and post in discussion boards, threads and replies, and like threads and replies; only teachers create boards; authors delete their own posts
- R10 (research Q4, Q7, Q10, AD-10): users chat one-to-one, in groups and in class chats; one-to-one chats are only between a teacher and a student in one of their classes, or the admin and a teacher; only teachers create groups, with their own students; teachers and the admin send text and attachments, students send text only; users see typing and unread counts, and only participants read or post; a student removed from a class loses its class chat and that teacher's groups, history included, and a one-to-one chat whose pair no longer qualifies stays readable and takes no new messages
- R11 (D9, research Q11, AD-11, AD-14, Decision 2026-11-07): on iPhone, in Fermi saved to the Home Screen from Safari, a user who allowed notifications gets a system notification for a chat message, a new assignment, a grade, an announcement, a due reminder or a removal request while Fermi is not on screen, unless they are in do-not-disturb; it names who and what kind ("New message from <name>", "<assignment> was graded"), never the message text or score; the inbox and unread counts still show what was missed
- R12 (research Q5, AD-11, Decision 2026-11-07): users see a dot for each user they can see: green while that user has Fermi on screen, yellow on screen in do-not-disturb, red otherwise, turning red as soon as they leave Fermi; any user turns do-not-disturb on or off, and it silences their push notifications and pop-ups while their inbox and unread counts still fill
- R13 (research Q5): a user submits a support or bug report, and it is stored for the admin
- R14 (research Q5): a user sees their notifications, marks them read and deletes them
- R15 (research Q5, Q12, D15, AD-7, AD-16): an admin lists users with counts by role and online, keeps the teacher email list (adding a student's email is refused), and deletes any account but their own
- R16 (D10, research Q5): a user schedules a chat message, and it is posted to the chat at the chosen time
- R17 (D10, research Q11, AD-11, AD-14, Decision 2026-11-07): while Fermi is on screen, in a tab or the Home Screen web app, a notification shows as an in-app pop-up and no system notification is sent, unless the user is in do-not-disturb
- R18 (D10, research Q6): a teacher sees a class's grade analytics: per-student performance, per-assignment stats, category performance and grade trends over time
- R19 (D10, research Q6, Q8): dashboard widgets show real data: for a teacher, assignment stats and recent activity; for a student, upcoming assignments, recent grades, assignment stats and GPA
- R20 (D11): a teacher posts an announcement in a class's Announcements board, and the class's members read it and get a notification
- R21 (D13, AD-9): a teacher archives a class at the end of the year; the class and its grades leave the main views and stay viewable under Archived, a teacher's for their classes and a student's for their own grades; an archived class takes no new work, posts or messages
- R22 (D14): a user opens Gmail's compose screen from inside Fermi, with the recipient filled in when they start from a Fermi user
- R23 (D9, AD-24, AD-26, Decision 2026-11-07): after a deploy that changed the app, a Fermi tab or Home Screen web app still running the previous build is replaced by a full-screen page that cannot be dismissed, showing only "A new version of Fermi+ is ready. Refresh to keep using Fermi+." and one Refresh button; Fermi checks when it opens, when it comes back on screen and every 15 minutes while on screen; the page waits up to 2 minutes for an upload or CSV import in progress, and after Refresh what the user was typing is back
- R24 (D9, AD-11, AD-14, Decision 2026-11-07): in desktop Chrome, Edge and Safari, a user who allowed notifications gets a system notification for the same kinds and with the same text as R11 while Fermi is not on screen, unless they are in do-not-disturb; this is best effort, and the inbox and unread counts still show what was missed
- R25 (D9, AD-7, Decision 2026-11-07): the landing page says Fermi is for teachers on the admin's list and the students they add, and shows how to add Fermi to the Home Screen from Safari
- R26 (AD-8, AD-22): every teacher of a student, and the admin, sees that student's current password with Show password on any roster row and replaces it with Reset password; the roster shows whether each student is waiting for their first sign-in or connected; a student cannot change their own password
- R27 (AD-14, AD-15): a student gets a reminder for each assignment they have not submitted, by default 24 hours before it is due; each student sets their own reminder times or turns reminders off; teachers set none, and a submitted assignment sends no reminder
- R28 (AD-16): a teacher deletes their own account from Settings after a warning listing their classes, which are deleted with it
- R29 (AD-14, AD-16): a student asks their teacher to remove their account, and their teachers and the admin get a notification; a teacher of that student can then delete the account, and cannot without an open request
- R30 (AD-22): an audit log nobody can edit records staff list changes, classes created, archived or deleted, students added to or removed from a class, passwords shown or reset, removal requests and account deletions; the admin reads every event, a teacher reads those for their classes and students, and students read none

## Constraints

- K1 (C1, D1, D5, Decision 2026-11-07): one web codebase, with no Capacitor or other native shell, ships the website that iPhone users save to the Home Screen from Safari; there is no iPhone, Android or desktop app; Android comes later
- K2 (C2): Supabase is the only backend (auth, Postgres, edge functions, storage); no Firebase SDK, config or project dependency remains
- K3 (AD-6, AD-7, AD-8, research Q2, Decision 2026-11-07): the role comes from the admin's teacher list, the bootstrap admin email (a secret set by CI, never in the public repo) or a teacher's roster add, and is set on the server when the account is created, never from the sign-in button; no Google sign-in creates an account for an unlisted email, and nobody registers with an email and password; today Google sign-in skips the client's domain check
- K4 (C4, research Q2, Q3): no user can change their own role, and one authoritative role store backs every access check; today the claim and `users.role` diverge, and an owner can edit their role
- K5 (research Q3, Q4, Q9, Q10): every access decision is enforced on the server by membership and ownership, and none of the Firebase defects listed in the parity inventory comes back
- K6 (C5, D8): the site is served by Cloudflare Workers static assets only, from a Worker named `fermi-plus` on a free workers.dev subdomain like My-Love (`fermi-plus.sallvain.workers.dev`, the account My-Love uses, verified 2026-11-06), with no bought domain; the Worker script `src/index.js` that `wrangler.toml` names today goes away
- K7 (C5, D9, D16, AD-21, Decision 2026-11-07): a push to main deploys from CI in order: apply Supabase migrations, push the hosted Auth config and the Realtime private-only setting, deploy edge functions, build and publish `updates/latest.json` naming the build, wrangler deploy, health check (which also asserts that config); nothing is deployed by hand
- K8 (D2): no migration code or Firebase export tooling is built
- K9 (D3, D4, D11): scope is the reachable working features in the parity inventory, plus the five fixed in D10 and the additions R26–R30; Jeopardy, calls, games/scores and the dead code listed there are out
- K10 (D7, AD-8): Fermi sends no email and has no email provider; teachers and the admin have no passwords; students have teacher-generated passwords with no self-service change or email reset
- K12 (D12, D14): Fermi asks Google only for sign-in and for per-file Drive access (`drive.file`, which Google rates non-sensitive, so only its basic app verification applies), requested the first time a user attaches from Drive; it never reads or sends a user's Gmail
- K13 (D16): access policies and edge functions have automated tests that run in CI; today nothing tests rules or functions
- K14 (D16): chat is one model shared by direct, group and class chats; today it is stored two ways
- K16 (D20, AD-12): a user sees another user's email only where allowed: their teachers' and the admin's for a student, their students' and the admin's for a teacher, everyone's for the admin; every other email stays private
- K17 (AD-13): every upload is at most 10 MB, checked by its stored bytes, and is an image, PDF, Word, PowerPoint, Excel or plain-text file; a Google Drive file is copied into Fermi when attached, and Fermi keeps no Drive link or token
- K18 (AD-21): the Supabase project is on the Free plan; CI keeps it from pausing with a twice-daily real query and takes a weekly backup encrypted to the owner's key, never committed because the repo is public; Storage file bytes are not backed up

## Done when

- A walkthrough per role, on the website in Safari and desktop Chrome and on the website saved to an iPhone's Home Screen, against the hosted Supabase project, shows each of R1–R30 working
- Automated checks show that Google sign-in creates no account for an email not on the teacher list, that an email-and-password sign-up is refused, and that a user's attempt to change their own role or a student's own password, or to read another user's private data, is refused
- A push to main runs migrations, the Auth and Realtime config, edge functions, build, wrangler deploy and the health check from CI; the workers.dev site serves the new build, and after a deploy that changed the app a Home Screen web app still on the previous build shows the refresh page and runs the new build after Refresh
- Fermi+ (com.academic-tools.fermi) is removed from sale on the App Store
- No Firebase package, config file or SDK call, and no Capacitor package or native project, is left in the app or CI

## Boundaries

- Out: an iPhone app by any route: the App Store, TestFlight, ad hoc distribution or Apple School Manager custom apps, since each change to a native shell waits on Apple's review (Decision 2026-11-07); with it Capacitor, APNs and native live updates
- Out: Sign in with Apple, which existed only for App Store guideline 4.8 (Decision 2026-11-07)
- Out: Android, until a later initiative (D5)
- Out: macOS, Windows and Linux builds, and the desktop OAuth flows (D1)
- Out: moving any existing Firebase user or data into Supabase (D2)
- Out: Jeopardy, including the stub games screen; calls; games and scores (D4, D11)
- Out: unreachable and always-broken features listed in the parity inventory, other than the five D10 names back in (D3)
- Out: invite codes, class codes and roster name matching (AD-7, AD-8)
- Out: passwords for teachers and the admin, students choosing or changing their own password, any email sent by Fermi, and a bought domain (D7, D8, AD-8)
- Out: per-kind push switches, and purging old data (spine Deferred)
- Out: offline use and any caching of the app; Fermi's one service worker handles push only (AD-25, Decision 2026-11-07)
- Out: signing a user out automatically, on a shared computer or elsewhere; computers stay signed in and signing out is the user's job (AD-27, Decision 2026-11-07)
- Out: an in-app folder file manager (D12)
- Out: reading or sending a user's Gmail from Fermi (D14)
- Out: fixing or hardening the Firebase backend that is being retired
- Touch point: the hosted Supabase project — linked, migrated and configured from CI, kept awake and backed up by scheduled workflows; owner: epic-platform-baseline
- Touch point: the GitHub repo — workflows, repo and environment secrets, Dependabot and the Main ruleset; owner: epic-platform-baseline
- Touch point: the Cloudflare account — the fermi-plus Worker on workers.dev; the old Pages project `fermi` is removed by epic-app-store-release; owner: epic-platform-baseline
- Touch point: App Store Connect — the listing com.academic-tools.fermi (Fermi+), removed from sale by hand; owner: epic-app-store-release
- Touch point: browser push services (Apple's, Mozilla's, and Chrome's on FCM's endpoint, which needs no Firebase project, so K2 holds) and the VAPID keys in Supabase function secrets; owner: epic-notifications
- Touch point: the Google Cloud project Fermi-Plus (`fermi-plus-513902`) — the OAuth client for sign-in and its basic app verification; owner: epic-invite-sign-in; the Drive Picker and `drive.file` on it; owner: epic-assignments-grades
- Touch point: Gmail — its compose screen is opened, never called; owner: epic-contact
- Touch point: My-Love — read as the reference for CI and hosting, never changed; owner: epic-platform-baseline
- Tracer path: the admin adds a teacher's email to the list; the teacher signs in on the website with Google, creates a class and adds a student by name and school email; that student, on an iPhone, signs in to Fermi saved to the Home Screen with the email and password from the printable sheet and is messaged by the teacher; the message arrives as a web push while the Home Screen web app is closed

## References

- research — _bmad-output/initiative-capacitor-supabase-port/research-firebase-backend-auth-rules-collections/research-firebase-backend-auth-rules-collections.md, Q1–Q13 and "Where the answers meet"
- brief — _bmad-output/initiative-capacitor-supabase-port/brief-port-goals.md, Goal, Constraints, Answers to the brackets, Later answers
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-1–AD-27, Consistency Conventions, Stack, Deferred, Open Questions
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership and Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md: requirement-to-Firebase map, out-of-scope lists, defects not to repeat, data-shape conflicts
- deploy reference — /Users/sallvain/Projects/My-Love/.github/workflows/deploy.yml, jobs migrate, functions, build, deploy, health-check

## Notes

- Decision: 2026-11-05, desktop dropped, start fresh, parity means reachable working features, Jeopardy removed (brief D1–D4)
- Decision: 2026-11-05, Android later, invite codes replace the domain gate, Google or Apple sign-in with no passwords or email, workers.dev hosting, Home Screen website plus optional App Store app, five broken features fixed, calls and games removed, Drive for assignments, class archiving, Gmail opened not sent, no admin password reset (brief D5–D16)
- Decision: 2026-11-05, class codes work only for students on the roster, matched by name; rosters filled one at a time or by CSV; the port updates Fermi's existing App Store listing (brief D17–D19)
- Decision: 2026-11-05, email visibility follows D20 (K16)
- Decision: 2026-11-05, sliced into 13 epics in tickets/tickets.toml, one feature area each, deployed on its own; rule: one source capability or a tightly coupled pair per epic; the platform baseline opens
- Decision: 2026-11-05, decisions several epics share (web framework, schema and access-policy pattern, edge-function errors, upload rules, account-delete rule, live update versus App Store build) are settled in an architecture spine through bmad-architecture before epic 1's stories
- Decision: 2026-11-05, the new app lives in `app/` beside the Flutter app until epic-app-store-release removes Flutter; its iOS project takes over bundle com.academic-tools.fermi
- Decision: 2026-11-05, class archiving moved to epic-classes-rosters so other epics' class views do not collide; epic-invite-sign-in owns the upload pattern and the user directory
- Decision: 2026-11-05, sign-in and Drive use a new Google Cloud project just for Fermi, Fermi-Plus (`fermi-plus-513902`), created by the user, as My-Love has its own (my-love-478322); not the Firebase project teacher-dashboard-flutterfire, since K2 allows no Firebase project dependency
- Decision: 2026-11-06, the finalized architecture spine supersedes invite codes, class codes and name matching (D6's codes, D17), gives students teacher-generated passwords (D7 for students), makes chat attachments teacher- and admin-only, adds do-not-disturb, due reminders, pushes for every kind, teacher self-deletion, student removal requests, the audit log and the 10 MB upload rule; the spine and its epic map are adopted as companions and cited by AD id
- Decision: 2026-11-06, epic ownership follows the epic map: the notifications table and `notify` move from epic-notifications to epic-invite-sign-in (the inbox screen stays with epic-notifications), every deletion path is epic-admin-console's, and epic-invite-sign-in also owns the audit log and file cleanup
- Decision: 2026-11-06, teachers see the admin's email too (K16, AD-12)
- Decision: 2026-11-06, the admin opens any class's roster from the admin console to add students and show or reset passwords (R5's and R26's admin part, epic-admin-console)
- Decision: 2026-11-06, App Review gets a demo teacher login and a demo student login plus a note that sign-in is invitation-only; whether a reviewer tries their own Apple ID is only known at submission (epic-app-store-release)
- Decision: 2026-11-06, build-order details: epic-invite-sign-in creates the account-deletion test file and epic-admin-console adds `delete-account` to it; epic-invite-sign-in owns the online heartbeat, epic-chat the dots and the do-not-disturb switch; the epic map is the architect's to amend
- Decision: 2026-11-06, epic-invite-sign-in builds the screen where the admin adds and removes teacher emails, so teachers can sign in from epic 3 on; epic-admin-console shows the same list in the console
- Decision: 2026-11-06, epic-platform-baseline enables pg_cron and pg_net, since its keep-alive reads the cron run log and epics 2, 4 and 5 each schedule jobs
- Decision: 2026-11-06, the tree check's remaining suggestions (audit log screens, Settings owner, epics 9 and 10 waiting on epic 3, GitHub and Firebase-project touch points, shared files) are settled when each epic is refined
- Decision: 2026-11-06, the spine is amended so the admin works on any class's roster (AD-8, AD-9), with its review fixes; the epic map's build-order details now match these Notes
- Decision: 2026-11-06, epic-platform-baseline refined and broken into 11 stories; it checks the iOS app in the Simulator, not TestFlight, and removes src/index.js, so epic-app-store-release no longer lists it
- Decision: 2026-11-06, a .github audit found the old CI dead or broken; removing workflows 01_ci, 03, 04 and 05 and the ten repo secrets only they use moved from epic-app-store-release to epic-platform-baseline (story 1.12, built now), which also rewrites Dependabot, requires test.yml's summary check on the Main ruleset, adds dependency review and Dependabot auto-merge, and retargets the Claude workflows; pull requests run no CI until story 1.3's test.yml; how TestFlight builds reach App Store Connect is settled when epic-app-store-release is refined
- Decision: 2026-11-06, TEA is planned in: a system-level `bmad-tea-test-design` run on the initiative before story 1.3's framework run; an epic-level `bmad-tea-test-design` at each later epic's refinement, before its stories, whose plan also settles a closing end-to-end suite; a `bmad-tea-trace` run in every epic's Done when (epic-app-store-release's over R1–R30); story 1.13 records the Playwright Utils rule in AGENTS.md for the builds
- Decision: 2026-11-06, from spine update 2026-11-06c, epic-platform-baseline's breakdown line adds Dependabot's native group (AD-18) and the two-check merge gate with Dependabot updates live within a day (AD-23), and epic-invite-sign-in's replaces the Apple secret renewal workflow with the never-stored secret minted at each deploy and rerun monthly, plus deploy.yml's edge_function_settings step (AD-21)
- Decision: 2026-11-06, answers to the system-level test design's questions (owner delegated them): Q1 no speed targets and no load tests for a school-sized app, revisited if users report slowness; Q2 assume up to 100 people at once, inside the Free plan's 200 Realtime connections, revisited with the Pro plan trigger; Q3 at least 80% line coverage on app/src/api/ and the stores, no target for screens; Q4 the app may be down up to one day for a restore from the latest weekly backup, losing up to 7 days of data on the Free plan; Q5 student data is treated as FERPA-covered education records, guarded by the access-control tests already planned, with the school's confirmation and the under-13 (COPPA) question owned by epic-app-store-release
- Decision: 2026-11-07, owner: the iPhone app is dropped and Fermi ships only as the website and the Home Screen web app saved from Safari, because any change to the iOS shell (a plugin, Info.plist, capacitor.config) needs an App Store build and waits on App Review; TestFlight (90-day build expiry, beta review per version), ad hoc distribution (100 iPhones a year) and Apple School Manager custom apps (review on every version) were considered and rejected; supersedes C1's Capacitor shell, D9's optional App Store app and D19's listing update, and the earlier Notes lines above on the App Store app, the iOS bundle, App Review's demo logins, TestFlight and the native group; K11 and K15 are retired, and R1, R2, R11, R23, R24, R25, K1, K3 and K7 re-rendered
- Decision: 2026-11-07, owner: the cost accepted is that notifications on iPhone become web push on the Home Screen web app; the web push spike stays first in epic-notifications, and moving it now or adding a renewal requirement now was declined
- Decision: 2026-11-07, owner: Sign in with Apple is dropped with the app, since it existed only for App Store guideline 4.8; teachers and the admin sign in with Google only
- Decision: 2026-11-07, owner: Capacitor is removed entirely; app/ is a Vite React web app, and a later Android initiative may add Capacitor back
- Decision: 2026-11-07, owner: R23 becomes a reload offer for a tab or Home Screen web app still on the previous build, read from `updates/latest.json`, because a Home Screen web app on iPhone can stay suspended on an old build for days
- Decision: 2026-11-07, replan: epic-app-store-release keeps its slug and is retitled "Retire Flutter and Firebase", as epics 2, 3 and 12 kept theirs; it loses TestFlight, App Review, the demo accounts and production APNs, and removes Fermi+ from sale in App Store Connect by hand, since the live 0.9.3 Flutter build stops working once Firebase is removed
- Decision: 2026-11-07, replan: epic-platform-baseline drops story 1.10 (built on loop/integration only, reverted there) and adds stories that remove the iOS project and native-build machinery stories 1.2 and 1.9 built, make Fermi install to the Home Screen as Fermi+, and offer the reload (R23); stories 1.2 and 1.9 stay done
- Decision: 2026-11-07, the initiative keeps its title and folder name, which every ticket and the spine cite, although it no longer ships Capacitor
- Decision: 2026-11-07, the architecture spine is invalidated where it assumes the iPhone app: AD-5 (send-push to APNs), AD-7 (Apple sign-in, Hide My Email), AD-13 (the Drive picker in the iOS NativeAuth sheet), AD-14 (apns rows and push environment), AD-18 (the whole AD), AD-20 (clients on an older App Store build), AD-21 (live-update packaging, the Apple secret step and apple-secret.yml), AD-23 (the MIN_NATIVE_BUILD lane and the native-group exception), the Tests convention (Simulator checks, production APNs), the Stack (@capacitor/*, @capgo/capacitor-updater, @capacitor/push-notifications), the Structural Seed (app/ios, capacitor.config.ts, apple-secret.yml) and the Open Questions (NativeAuth sheet, APNs and App Review spikes); the epic map's rows 1, 2, 6 and 13 and its Native packages seam follow; amending them is the architect's, through bmad-architecture, before story 1.14 builds
- Open question: how does Fermi notice and recover an iPhone web push subscription that iOS dropped without warning (reported by developers, UNVERIFIED)? waits: epic-notifications, after its web push spike
- Decision: 2026-11-07, owner: the COPPA and FERPA confirmation with a school is dropped from the plan, because the owner works at no school now and there is none to confirm with; this supersedes that part of the 2026-11-06 test-design answer Q5, while the access-control tests that guard student data stay
- Decision: 2026-11-07, settled: the architect amended the spine for web only (d98e518), so the invalidation line above is closed and story 1.14's hold is lifted
- Decision: 2026-11-07, ticket sync from that spine update (owner's decisions in its memlog, reviews/review-rubric-update-2026-11-07.md): R23 becomes AD-24's full-screen refresh page, which cannot be dismissed, shows only "A new version of Fermi+ is ready. Refresh to keep using Fermi+." and one Refresh button, is checked on open, on return to the screen and every 15 minutes, and appears only when `app/` changed; this supersedes the 2026-11-07 reload-offer line above; R11, R17 and R24 send no push while Fermi is on screen and name who and what kind, never content (AD-14); R12's dots follow presence per open client with an immediate leave report, and `profiles.last_seen_at` is dropped (AD-11); one service worker, for push only, caching nothing (AD-25), and computers staying signed in (AD-27) become Boundaries
- Decision: 2026-11-07, ticket sync: epic-platform-baseline adds story 1.17 (the AD-26 draft store and AD-24's busy registry, which epic-invite-sign-in's first text field and upload need) and story 1.18 (the hosted `site_url`, `http://localhost:3000` in `supabase/config.toml` today, pinned to the workers.dev origin and asserted by the health check, AD-7), and epic-invite-sign-in waits on both
- Decision: 2026-11-07, ticket sync: the update check reference to My-Love's `nativeUpdates.ts` is dropped, since that is its native updater and AD-24 defines Fermi's check; References cite AD-1–AD-27
