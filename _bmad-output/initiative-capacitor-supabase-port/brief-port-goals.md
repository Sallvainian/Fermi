---
title: Port goals and constraints
type: brief
author: user
created: 2026-11-05
---

# Port goals and constraints

The user's own words from 2026-11-05, with the answers they gave to its open brackets the same day. Ids are cited by the initiative.

## Goal

- **G1** Port Fermi from Flutter + Firebase to a Capacitor app on Supabase, keeping what users can do today.

## Constraints

- **C1** Capacitor app shell, platforms iOS, Android and web.
- **C2** Supabase for auth, Postgres database, edge functions and storage; Firebase removed entirely.
- **C3** Keep the domain gate: `@roselleschools.org` teacher, `@rosellestudent.org` student, `@fermi-plus.com` admin.
- **C4** A user can never change their own role.
- **C5** Hosted on Cloudflare Workers (assets only) at fermi-plus.com, deployed from CI like My-Love: build, apply Supabase migrations, wrangler deploy, health check.

## Answers to the brackets

- **D1** macOS and Windows: dropped. Desktop users use the web app in a browser; no Electron shell.
- **D2** Existing users and data: start fresh. No Firebase Auth or Firestore migration.
- **D3** "What users can do today" means features a user can reach and that work today. Dead or always-broken code is out unless the user names it back in.
- **D4** Jeopardy is removed completely, including the stub games screen.

## Later answers (2026-11-05)

Given the same day while the initiative was written. Where one replaces a constraint above, it says so.

- **D5** Android is dropped for now; it ships later. Replaces C1's Android.
- **D6** The user no longer works at Roselle, so roles come from invite codes instead of email domains. The admin (the user) creates teacher codes, teachers create student codes, and the code decides the role. The landing page says access is by invite only; nobody signs up without a code. Replaces C3.
- **D7** After entering the code, a person signs in with Google or Apple. There are no passwords and no "Forgot password", so Fermi sends no email.
- **D8** The site is hosted free on a workers.dev subdomain like My-Love; no domain is bought. Replaces C5's fermi-plus.com.
- **D9** Everyone can use the website saved to the Home Screen, with best-effort notifications. An optional App Store iPhone app gives reliable notifications and updates itself like My-Love: it downloads a new build after each deploy and offers to restart onto it. The App Store needs Sign in with Apple, and it works for real.
- **D10** Kept and fixed: file attachments on submissions, scheduled chat messages, the web notification pop-up, grade analytics and dashboard widgets.
- **D11** Removed: calls and games/scores. Kept: announcements, files and archived grades.
- **D12** Files means attachments on assignments, submissions and chat, plus attaching from Google Drive, which is used only for viewing, attaching and submitting assignments. No folder file manager.
- **D13** A teacher archives a whole class at the end of the year; its grades leave the main views and stay viewable under Archived.
- **D14** Fermi opens Gmail's compose screen from inside the app; it never sends mail itself.
- **D15** No admin password reset; the admin can still delete accounts.
- **D16** Confirmed: edge functions deploy in CI after migrations and before the build, as My-Love does; access rules and edge functions get automated tests in CI; the Flutter app, Firebase config, `src/index.js` and the email worker are removed when the port ships; chat becomes one system; only teachers create discussion boards.
- **D17** A class's code is the student invite code, and it works only for students on that class's roster. At sign-up the student enters their name, which is fuzzy-matched against the roster, so a code shared outside the class lets nobody in.
- **D18** Teachers add students to a roster both ways: one at a time and by CSV.
- **D19** Fermi is already on the App Store, and the user already has the paid Apple developer membership. The port ships as an update to that listing.
