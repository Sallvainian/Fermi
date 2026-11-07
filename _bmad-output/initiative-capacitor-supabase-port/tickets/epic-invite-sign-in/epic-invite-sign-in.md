---
type: epic
title: "Teachers and the admin sign in from the admin's list"
parent: initiative-capacitor-supabase-port
covers: [R1, R2, R3, R15, R25, R30]
sources: []
companions: []
after: []
refined: false
risk: high
---

# Teachers and the admin sign in from the admin's list

## Description

On the deployed site and the Home Screen web app, the landing page says Fermi is for teachers on the admin's list and the students they add and shows how to add Fermi to the Home Screen from Safari; the sign-in screen opens with I'm a teacher (Google) and I'm a student (email and password); the bootstrap admin and teachers on the admin's email list, which the admin adds to and removes from (R15's list part), sign in with Google and land on their dashboards, while every other Google account and an email sign-up are refused (AD-7); roles live only in profiles, set by the one profile creator (AD-6), and nobody changes their own; users complete their name and upload or remove a profile picture (R1's and R2's teacher and admin half; R30's staff-list part). Owns the foundations later epics write into: the directory and app.visible_email with stub class and chat clauses (AD-2, AD-12), presence per open tab or Home Screen web app, with a heartbeat while Fermi is on screen and a leave report the moment it goes off screen, the do-not-disturb flag and the presence colour every screen reads (AD-11; no profiles.last_seen_at), the notifications table and internal.notify (AD-14), the audit log (AD-22), the user: Realtime topic (AD-19), the upload pattern with the avatars bucket and file cleanup (AD-13, AD-16), the account-deletion test file that later epics add their cases to, the settings table for functions the database calls with deploy.yml's one step that writes its rows (AD-5, AD-21), and the one sign-out, in AD-27's fixed order; a computer stays signed in until its user signs out. Its text fields and upload use epic 1's draft store and busy registry (AD-24, AD-26). Turns sign-up on and adds the hook to epic 1's health check in the change that creates the hook. Opens with the spine's sign-in spikes, the Apple one dropped, plus one: Google sign-in started from the Home Screen web app on an iPhone comes back to it signed in. Hands profiles, the profile creator, notify and the audit log to epic 3; notify to epics 4, 6 and 7; the upload pattern and file cleanup to epics 4 and 5; presence, the do-not-disturb flag and the user: topic to epics 5 and 6; app.visible_email to epic 10; accounts and the directory to epics 5, 9 and 10; and the admin role, the teacher list and the audit log to epic 12.

## Outcome

The admin and listed teachers get into Fermi with Google, nobody else can make an account, and no user can change their role (initiative R1, K3, K4).

## Done when

- On the deployed site, in a browser tab and in the Home Screen web app on an iPhone, the admin and a listed teacher each sign in with Google from I'm a teacher and land on their dashboard
- Automated checks refuse an unlisted Google account and an email sign-up, and refuse a user changing their own role
- The admin adds and removes teacher emails, a student's email is refused, and each change is in the audit log
- A user completes their name and uploads or removes a profile picture; a file over 10 MB or of the wrong type is refused by its stored bytes, and a removed picture's file is swept
- The landing page shows who Fermi is for and the steps to add it to the Home Screen from Safari
- A `bmad-tea-trace` run at closure maps each Requirements line to passing tests, and its gate is PASS or each gap has a waiver in Notes

## Boundaries

- Out: classes, rosters, student accounts and student passwords (epic-classes-rosters)
- Out: the admin user list, console and account deletion (epic-admin-console)
- Out: the inbox screen and push delivery (epic-notifications)
- Out: Sign in with Apple, the Apple client secret and `apple-secret.yml` (initiative Decision 2026-11-07)
- Touch point: the repo's `.github` files — changed only at AD-21's extension points: the hook health-check assertion, deploy.yml's `internal.edge_function_settings` step with `sweep-storage`'s entry, `test.yml` lanes, and secrets in the Production environment; owner: epic-platform-baseline

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R1, R2, R3, R15, R25, R30, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-1–AD-7, AD-11–AD-14, AD-16, AD-19, AD-21, AD-22, AD-23, AD-24, AD-26, AD-27, Open Questions (sign-in spikes, the leave report on an iPhone)
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 2 Sign-in, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-platform-baseline because: the CI pipeline, the Supabase project, the app shell, the Home Screen manifest, the empty schemas, pg_cron and pg_net, the draft store and busy registry, and the hosted site_url on the workers.dev origin
- Decision: 2026-11-06, when this epic's stories are planned, pin epic 1's entries: 1.1 (pipeline, hosted project, app shell, empty schemas), 1.4 (the health check's sign-up assertion this epic replaces), 1.5 (the API client and error shapes), 1.7 (pg_cron and pg_net) and 1.9 (the live update the shell ships through)
- Decision: 2026-11-06, `bmad-tea-test-design` runs on this epic at epic level during its refinement, after its Requirements are written and before its stories are planned; its test plan is adopted as a companion, each story names the scenarios it covers, and the plan settles whether the epic closes with an end-to-end suite
- Decision: 2026-11-06, from spine update 2026-11-06c: the Apple client secret is never stored; this epic adds the deploy.yml step that mints it from the `.p8` key just before the config push (key id, team id and services id in the Production environment) and `apple-secret.yml`, which reruns that step monthly (AD-21); it also adds deploy.yml's one step that writes `internal.edge_function_settings`, with the table and `sweep-storage`'s entry (AD-21, architect confirmed); its stories change epic 1's `.github` files only at AD-21's extension points; a native sign-in plugin joins `dependabot.yml`'s native group and raises `MIN_NATIVE_BUILD` in the same change (AD-18); its tests are `test.yml` lanes that `Test Summary` waits on and read no secret (AD-23)
- Decision: 2026-11-06, the pin list above also takes 1.3 (`test.yml` and its lanes, which this epic's tests join)
- Decision: 2026-11-07, replan from the initiative's Decision (owner): no iPhone app and no Sign in with Apple; this epic loses the Apple button, the Hide My Email refusal, the Apple secret step, `apple-secret.yml`, the NativeAuth-sheet spike and the App Store link, and the 2026-11-06 lines above on the Apple secret and on a native sign-in plugin no longer apply; the pin on 1.9 now means the deploy's `latest.json`, not a live update, and 1.15 (the manifest the landing page's Home Screen steps rely on) joins the pin list
- Decision: 2026-11-07, the spine's NativeAuth-sheet spike is replaced by one: Google sign-in started from the Home Screen web app on an iPhone comes back to that web app signed in, because iOS gives a Home Screen web app storage apart from Safari's, so a sign-in that finishes in Safari may not reach it (UNVERIFIED)
- Decision: 2026-11-07, ticket sync from the spine update of the same day (owner): presence is per open tab or Home Screen web app (`presence_clients`, `touch_presence`, `leave_presence`), with a keepalive leave report the moment Fermi goes off screen and the 2-minute window only as a fallback, and `profiles.last_seen_at` is dropped (AD-11); the spine adds a spike on that leave report from an iPhone's Home Screen web app; this epic owns `signOut()` in AD-27's order, and computers stay signed in until their user signs out; its text fields (the profile name) and its avatar upload use epic 1's draft store and busy registry (AD-26, AD-24)
- Decision: 2026-11-07, the pin list above also takes 1.17 (the draft store, `draftKey()`, the sign-out wipe and the busy registry) and 1.18 (the hosted `site_url` on the workers.dev origin, without which a hosted Google sign-in returns to localhost)
