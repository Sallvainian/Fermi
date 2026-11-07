---
workflowStatus: 'completed'
totalSteps: 5
stepsCompleted: ['step-01-detect-mode', 'step-02-load-context', 'step-03-risk-and-testability', 'step-04-coverage-plan', 'step-05-generate-output']
lastStep: 'step-05-generate-output'
nextStep: ''
lastSaved: '2026-11-06'
workflowType: 'testarch-test-design'
inputDocuments:
  - _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md
  - _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md
  - _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md
  - _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md
  - _bmad-output/initiative-capacitor-supabase-port/brief-port-goals.md
  - _bmad-output/initiative-capacitor-supabase-port/tickets/tickets.toml
  - _bmad-output/initiative-capacitor-supabase-port/tickets/epic-platform-baseline/tickets/tickets.toml
---

# Test Design for Architecture: Capacitor Supabase Port

**Purpose:** Architectural concerns, testability gaps and NFR requirements for the owner and the builds to settle. This is the contract between test design and engineering on what must exist before tests are written. The test recipe is in the companion `test-design-qa.md`.

**Date:** 2026-11-06
**Author:** Murat (TEA Master Test Architect), for Sallvainian
**Status:** Architecture Review Pending
**Project:** Fermi
**PRD Reference:** `_bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md` (R1–R30, K1–K18; no separate PRD exists)
**ADR Reference:** `_bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md` (AD-1–AD-23)

---

## Executive Summary

**Scope:** The whole initiative. Fermi is rebuilt as one Capacitor app (`app/`: web plus an iOS shell) on Supabase (`supabase/`: schema, RLS, edge functions, Storage, Realtime). It is deployed from CI to the `fermi-plus` Worker on workers.dev, across 13 epics.

**Business Context** (from the initiative):

- **Impact:** Teachers, students (minors) and one admin. The Firebase app has no live users today, so the risk is in what the new app does when it ships, not in a migration.
- **Problem:** Firebase let users edit their own role and read other users' data (initiative Description). The port moves every access decision into Postgres.
- **GA Launch:** The App Store update in epic 13, which waits on epics 4, 6, 7, 9, 10, 11 and 12. No date is set.

**Architecture** (from the spine):

- **AD-1 to AD-4:** RLS and SQL functions are the only enforcer. Objects are locked by default, with a privilege fixture and a catalog test. There is one writer per rule-bearing change.
- **AD-6 to AD-8:** One role store. Staff are admitted only from the admin's email list. Students are created only by `add-students`.
- **AD-18, AD-21, AD-23:** Self-hosted live updates gated by `MIN_NATIVE_BUILD`. A fixed CI deploy order with a config health check. One merge gate (`test.yml`'s summary plus Dependency Review).

**Expected Scale:** UNKNOWN. The only figures are the Free plan's ceilings: a 500 MB database, 1 GB storage and 200 concurrent Realtime connections (spine, Deferred).

**Risk Summary:**

- **Total risks:** 46
- **High-priority (≥6):** 14 risks requiring mitigation, two of them critical at 9 (R-002, R-012)
- **Test effort:** ~341 planned tests, ~2.5–4.5 weeks of one person's full-time effort, spread across the 13 epics (details in the QA doc)

---

## Quick Guide

### 🚨 BLOCKERS - Team Must Decide (Can't Proceed Without)

**Pre-Implementation Critical Path.** Story 1.3's framework run must settle these before epic 2's tests can be written:

1. **TC-1: Staff sessions on the local stack (decided, a rule).** Staff sign in only with Google or Apple, and the spine says only "Google mocked" for local, with no mechanism. Decided 2026-11-06: any helper that signs in a teacher or the admin lives only in test code and runs only against the local Supabase stack. It creates the user and gets a session with that stack's own `service_role` key, and it refuses to run when the Supabase URL is not local (`127.0.0.1` or `localhost`). Nothing in `app/`, `supabase/functions/` or the hosted Supabase config adds a test-only way to sign in; the hosted project keeps Google and Apple as the only staff sign-in. Real Google and Apple sign-in is checked by hand in the Simulator in epic-invite-sign-in, not by automated tests. Because the helper creates users through the admin API, which bypasses `before_user_created`, browser tests signed in this way never exercise admission; admission is covered by P0-003 (R-003) and those hand checks. (Owner: story 1.3 builds the helper)
2. **TC-3: One persona cast for every policy test.** Admin, teacher A, teacher B, a student only in A, a student in A and B, a removed student and an archived class, as a pgTAP helper and as matching TypeScript factories. (Recommended owner: story 1.3, extended by each epic)
3. **TC-2: Control of time in scheduled and time-window rules.** Cron workers take the run time as a parameter (default `now()`), so reminders, scheduled messages, presence and reset tickets are tested without waiting. (Recommended owner: epic 2 for the first job; the rule applies to epics 4 and 5)

**What we need:** TC-1 is decided. Story 1.3 builds it as stated, and decides TC-3 and TC-2's pattern, or every later epic invents its own.

---

### ⚠️ HIGH PRIORITY - Team Should Validate (We Provide Recommendation, You Approve)

1. **R-012 and R-002: Make the catalog test and the persona × table matrix the first P0 gate.** Story 1.6 ships the catalog test. Every epic then adds its tables to both before they reach hosted. (Owner approves; implementation phase)
2. **TC-4 and R-031: Add a migration lint** that fails `DROP`, `RENAME` or a changed function signature without an explicit contract marker. AD-20 has no automated check today. (Owner approves; story 1.3 or 1.11)
3. **R-032: Keep the health check strict.** It fails on any Auth or Realtime drift, and epic 2 swaps the sign-up assertion for the hook URI in the same change. (Already in stories 1.4 and epic 2; confirm)
4. **R-036 and R-029: Make the merge gate and `MIN_NATIVE_BUILD` check `test.yml` jobs** that the summary waits on, per AD-23. (Already in stories 1.3, 1.9 and 1.13; confirm)
5. **Clarifications Q1–Q5** (performance targets, user counts, coverage threshold, recovery time objective, student-privacy law). Each stays UNKNOWN until the owner answers. See Assumptions.

---

### 📋 INFO ONLY - Solutions Provided (Review, No Decisions Needed)

1. **Test strategy:** pgTAP for every rule (Integration), `deno test` on each `handler.ts` (Unit), Vitest for `app/src` (Unit), Playwright UI and api projects (Component, API, E2E), and dated hand checks for native-only paths. The rules live in SQL, so most tests are pgTAP.
2. **Tooling:** Supabase CLI 2.122.0 local stack, pgTAP, Deno 2, Vitest 5.1.0, Playwright with `@seontechnologies/playwright-utils` fixtures (AGENTS.md rule, story 1.13).
3. **Tiered CI/CD:** every lane runs on every PR in `test.yml`, target under 15 minutes. Scheduled workflows cover keep-alive, backup and the Apple secret. The health check runs after each deploy.
4. **Coverage:** ~341 scenarios, P0–P3 (P0 12 risks, P1 20, P2 10, P3 4).
5. **Quality gates:** P0 100%, P1 ≥ 95%, high-risk mitigations before App Store submission. Coverage proposed at 80% for `app/src/api/` and stores, pending Q3. Details in the QA doc's Exit Criteria.

---

## For Architects and Devs - Open Topics 👷

### Risk Assessment

**Total risks identified:** 46 (14 high-priority score ≥6, 26 medium, 6 low). Each row cites the source statement it comes from. Owner means the epic or story that owns the control, per the epic map.

#### High-Priority Risks (Score ≥6) - IMMEDIATE ATTENTION

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner | Timeline |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ---------- | ----- | -------- |
| R-002 | SEC | Users "read other users' data" (initiative Description). Merged with K5 "every access decision is enforced on the server", AD-1 "access checked in the app or an edge function while another path trusts the database", AD-5 "checks moving into TypeScript", and parity "any student can read every `users` document; any signed-in user can read every class", "read every classmate's points", "`chatRooms` read by any signed-in user". Consequence: a student or teacher reads grades, points, chats or profiles outside their classes. About 30 tables, 4 buckets and 2 topic kinds are written over 13 epics. | 3 | 3 | 9 | pgTAP persona × table read matrix per owning epic (TC-3 personas); handlers query only named RPCs; a negative api test per table from Playwright's api project | Each table's owning epic; the matrix pattern starts in story 1.3 | Every epic, before its tables ship |
| R-003 | SEC | "No Google or Apple sign-in creates an account for an unlisted email … today Google sign-in skips the client's domain check" (K3). Merged with AD-7 "an uninvited Google or Apple account getting in; anyone self-registering with a password" and parity "Google sign-in skips the client's role gate". Consequence: a stranger gets an account and sees the directory. | 2 | 3 | 6 | pgTAP drives `before_user_created` with listed, unlisted, relay, email-provider and bootstrap payloads (AD-7); an api test of an email sign-up refused on the local stack; the health check asserts sign-up is off until the hook exists, then the hook URI | Epic 2; story 1.4 | Epic 2's hook change |
| R-004 | SEC | "Every access decision is enforced on the server by membership and ownership" (K5). Merged with parity "a student can rewrite a class's `studentIds`", "`teacherId` ownership checks … non-binding", "a student can create a submission for any assignment", "15 rule conditions are a placeholder `true`", "reply `likeCount` update passes with any other keys changed", "messages deletable by any signed-in user". Consequence: a user writes into another class's roster, assignments, submissions or posts. | 2 | 3 | 6 | pgTAP write matrix (insert, update, delete per persona) per table; `_as` functions tested for each refusal key; no direct write grant where AD-4 names a single writer | Each table's owning epic | Every epic |
| R-005 | TECH | "Today nothing tests rules or functions" (K13). Merged with initiative Notes "pull requests run no CI until story 1.3's test.yml", story 1.12 and parity "nothing tests rules, functions or auth; CI runs no tests". Consequence: stories 1.1, 1.2 and 1.12 merge with no automated test; regressions land unseen. | 3 | 2 | 6 | Story 1.3 delivers every lane and the summary job next; stories 1.1, 1.2 and 1.12 are verified by their `verify` steps by hand; story 1.13 makes the gate required | Story 1.3, story 1.13 | Epic 1 |
| R-010 | BUS | "Whether a reviewer tries their own Apple ID is only known at submission" (initiative Notes). Merged with spine Open Questions "whether App Review accepts web-flow Sign in with Apple that refuses unlisted reviewers" and "whether App Review accepts the student removal request under 5.1.1(v)", and AD-18 "a major feature shipped around App Review". Consequence: the iOS update is rejected, and R11 and R23 don't reach users through the App Store. | 2 | 3 | 6 | Demo accounts on the lists in the review notes (initiative Notes); TestFlight walkthrough per role before submission; Apple sign-in parity with Google checked on the TestFlight build | Epic 13 | At submission |
| R-012 | SEC | "Broad default grants; a writable `role`; any user calling an internal function (Postgres grants EXECUTE to PUBLIC by default); a view that skips RLS" (AD-3). Consequence: any signed-in user, or `anon`, calls an `internal.*_as` function with any actor, which is full impersonation, or reads through a definer view. | 3 | 3 | 9 | Privilege fixture plus pgTAP catalog test that fails on any missing or differing grant (story 1.6); every migration updates the fixture in the same change (conventions) | Story 1.6, then every epic | Story 1.6, then every migration |
| R-018 | SEC | "Removed students keeping groups" (AD-10). Merged with AD-9 "removing a student's enrollment ends their access to everything scoped to that class" and AD-19's 1-hour channel cache. Consequence: a removed student keeps reading the class chat, groups, boards, or their own grades and points in that class. | 2 | 3 | 6 | Per-epic pgTAP case "after `remove_student`, every class-scoped read is refused" (epics 4, 5, 7, 8); a realtime test that a removed member gets ids only; seam row "Removal from a class" | Epic 3 (removal), epics 4, 5, 7 and 8 (their tables) | Each of those epics |
| R-020 | SEC | "Features exposing names, pictures or emails by their own rule; classmates reading emails through a row-level grant" (AD-12; K16). Consequence: students' school emails are exposed to classmates or unrelated users. | 2 | 3 | 6 | pgTAP: `authenticated` cannot select `profiles.email` (AD-12); `app.visible_email` truth table per D20 for each persona pair; `app.can_see_user` clause tests | Epic 2 (shape), epics 3 and 5 (clauses) | Epics 2, 3, 5 |
| R-023 | SEC | "Classmates reading each other's submissions; an edited submission; a row pointing at another scope's file" (AD-13). Consequence: a student downloads a classmate's submitted work or swaps a file after submitting. | 2 | 3 | 6 | Storage policy pgTAP per bucket and persona (insert, read, update, delete); path-prefix check tests; an api test uploading to another scope's path | Epic 2 (avatars), epic 4 (assignment and submission files), epic 5 (chat files) | Those epics |
| R-029 | TECH | "A bundle reaching an app without the native code it needs; a student on an old App Store build silently missing every later fix; … a Dependabot update shipping plugin code by live update" (AD-18). Consequence: iOS users get a broken app that a later live update can't repair, or a native update slips out without an App Store build. | 2 | 3 | 6 | `test.yml` check: a plugin added without raising `MIN_NATIVE_BUILD`, or `MIN_NATIVE_BUILD` above the Xcode build, fails (story 1.9); `latest.json` carries `min_native_build`; Simulator check of skip, banner and restart (story 1.10); the native group never auto-merges (story 1.13) | Stories 1.9, 1.10, 1.13 | Epic 1 |
| R-032 | OPS | "Hosted settings set by hand or missing" (AD-21). Consequence: sign-up left on without the hook, anonymous sign-ins on, or Realtime public, which reopens R-003 and R-030 on the live project. | 2 | 3 | 6 | Deploy pushes the Auth config and sets Realtime private-only; the health check reads both back and fails on any drift, a missing `private_only` included; manual-dispatch health check (story 1.4) | Story 1.4; epic 2 (hook assertion) | Story 1.4 |
| R-033 | OPS | "Silent failures" (AD-21). Consequence: due reminders, scheduled messages, storage sweeps or push delivery fail on the hosted project and nobody learns of it. | 3 | 2 | 6 | `public.job_health()` reads `internal.job_failures`, `cron.job_run_details` and non-2xx `net._http_response`; keep-alive fails, and GitHub emails the owner (story 1.7); each job's refusal path writes `job_failures` (AD-15) | Story 1.7; epics 2, 4, 5, 6 (their jobs) | Story 1.7 |
| R-036 | OPS | "A later epic's tests failing while a pull request still merges; a lane that fails every Dependabot pull request for lack of secrets; a ruleset that blocks Dependabot's own branches; an update with a known security advisory merging unattended" (AD-23). Merged with story 1.13 "today it targets every branch, ~ALL" and "without them a pull request merges untested". Consequence: untested or vulnerable code reaches main and deploys within a day. | 2 | 3 | 6 | Ruleset requires exactly Test Summary and Dependency Review; every lane is a `test.yml` job the summary waits on; `test.yml` names no secret (story 1.3's verify); auto-merge only after both pass, never for the native group (story 1.13) | Stories 1.3, 1.13 | Epic 1 |
| R-042 | SEC | "Confirm Sign in with Apple through the NativeAuth sheet works end to end" (spine Open Questions). Consequence: Apple sign-in fails on iOS, which breaks K11 "Sign in with Apple works as fully as Google" and fails App Review. | 2 | 3 | 6 | The spike that opens epic 2; a hand check in the Simulator per conventions; recheck on the TestFlight build | Epic 2 spike; epic 13 | Start of epic 2 |

#### Medium-Priority Risks (Score 3-4)

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ---------- | ----- |
| R-001 | SEC | Users "edit their own role" (initiative Description). Merged with K4 "the claim and `users.role` diverge, and an owner can edit their role", AD-3 "a writable `role`", AD-6 "the role in two places; a user raising their own role; two code paths creating profiles", and parity rows 1 to 3. Consequence: a student makes themselves a teacher or the admin. The design has no update grant and a single creator, which lowers probability. | 1 | 3 | 3 | pgTAP: `UPDATE profiles SET role` refused for every persona; `on_auth_user_created` is the only insert path; no authorization reads `app_metadata` after creation; catalog fixture lists no `role` update grant | Epic 2 |
| R-007 | OPS | "CI keeps it from pausing" (K18). Merged with AD-21 "the Free project pausing" and "GitHub disables scheduled workflows in an inactive public repo after 60 days". Consequence: the hosted project pauses and the site stops working for everyone. | 2 | 2 | 4 | Twice-daily keep-alive with a real query; monthly self re-enable through the GitHub API; verified by a manual run (story 1.7) | Story 1.7 |
| R-008 | SEC | Backups are "never committed because the repo is public" (K18). Merged with K3's bootstrap admin email "never in the public repo" and AD-21's backup rule. Consequence: student data or secrets are published in a public repo. | 1 | 3 | 3 | Backup artifact encrypted to the owner's age key and kept as a 90-day artifact (story 1.8); secrets in fnox and the Production environment only; `test.yml` names no secret | Stories 1.1, 1.8 |
| R-009 | DATA | "Storage file bytes are not backed up" (K18). Merged with AD-21 "neither is the Vault root key, so a restore into a new project loses stored student passwords" and the weekly cadence. Consequence: a project loss loses every uploaded file, every stored student password, and up to 7 days of rows. | 2 | 2 | 4 | Accepted by design. Restore-into-throwaway-database proves the dump restores (story 1.8); teachers reset passwords after a restore | Story 1.8 (owner accepts the residual) |
| R-011 | TECH | "Two epics defining 'enrolled', 'teaches' or 'in chat' differently; recursive policies; hand-joined membership in functions" (AD-2). Consequence: the same question answers differently in different features, so one path leaks or wrongly refuses. | 2 | 2 | 4 | One pgTAP truth-table file per predicate, asserting AD-2's table (archived and removed columns included); review rule: no policy joins `enrollments` directly | Epics 2, 3, 5 |
| R-013 | DATA | "Two write paths into one table with different checks; half-applied changes; a scheduler impersonating users" (AD-4). Merged with AD-15 "impersonates users through a client-callable parameter". Consequence: inconsistent rows, or a check skipped on one path. | 2 | 2 | 4 | Catalog fixture shows no direct `INSERT`, `UPDATE` or `DELETE` grant on single-writer tables; pgTAP asserts a refused call leaves no partial rows; `_as` never granted to `authenticated` (R-012's test) | Every epic |
| R-014 | DATA | "Two ways to create a student; a student outside a roster; a teacher turning an invited colleague into a student; a password or name overwritten by a second class; the admin refused by a teaches-only check" (AD-8). Merged with parity "bulk import writes `users` for every row, not only accounts that were created". Consequence: staff locked into student accounts, or students' passwords silently changed. | 2 | 2 | 4 | `add-students` deno tests per row outcome (staff, bootstrap, existing student, new); pgTAP `check_add_students_as` and `enroll_student_as` for teacher, admin and other teacher; api test of a 1000-row CSV in chunks of 100 | Epic 3 |
| R-015 | BUS | "Writes into an archived class" (AD-9). Consequence: work, posts, points or messages land in a class that is meant to be read-only. | 2 | 2 | 4 | Every class-scoped `_as` function and policy has a pgTAP "archived class refuses" case; seam row "Archived classes" | Epics 3, 4, 5, 7, 8 |
| R-017 | SEC | "Pairing enforced in some paths only" (AD-10). Consequence: two students get a private one-to-one chat, or a teacher messages a student they don't teach. | 1 | 3 | 3 | All sends go through `internal.send_message_as`; pgTAP pairing matrix covering the typed and scheduled paths | Epic 5 |
| R-021 | SEC | "A size check that trusts the client" (AD-13). Merged with parity "chat file size checked against the client's declared `fileSize`, not the bytes; `image/jpg` rejected for `.jpg`". Consequence: oversize or disallowed files are stored, and the 1 GB Free storage fills. | 2 | 2 | 4 | Bucket `file_size_limit` and `allowed_mime_types` asserted in pgTAP from `storage.buckets`; an api test uploading 10 MB + 1 byte and an SVG, both refused | Epic 2 (pattern), bucket owners |
| R-022 | SEC | "Long-lived links" (AD-13). Merged with parity "chat attachment URLs are signed until year 2500". Consequence: a forwarded link keeps exposing a student's file indefinitely. | 2 | 2 | 4 | Vitest on the `api/` signed-URL helper asserting expiry ≤ 3600 s; review rule that nothing else mints URLs | Epic 2 |
| R-024 | OPS | "Each feature sending pushes its own way; recipients re-derived in TypeScript; DND or dead-token handling in one path only" (AD-14). Merged with AD-11 "DND enforced in one sender only" and parity "push token kept on the user row, one per user, never removed at logout". Consequence: pushes reach non-members, users in do-not-disturb, or a signed-out device. | 2 | 2 | 4 | pgTAP `internal.push_targets` per kind (DND skip, membership); `send-push` deno tests for 410, 404 and 400 handling; `unregister_push_device` at sign-out tested | Epic 6 |
| R-025 | OPS | "A scheduler that bypasses checks … or retries forever" (AD-15). Consequence: a scheduled message posts after the sender lost access, or a failing job loops. | 2 | 2 | 4 | pgTAP: due row refused → marked `failed`, `job_failures` written, never retried; worker takes run time as a parameter (TC-2) | Epics 2, 4, 5 |
| R-026 | DATA | "Orphaned rows, files or secrets; a deleted teacher signing back in" (AD-16). Consequence: a deleted account's data, files or Vault password remain, or a deleted teacher gets back in through a leftover `staff_invites` row. | 2 | 2 | 4 | The shared `NN_account_deletion.sql` file: each epic adds its case, deletes the `auth.users` row and asserts every effect (AD-16) | Epic 2 (file), every epic with a foreign key, bucket or secret |
| R-027 | SEC | "One teacher wiping a student shared with others" (AD-16). Consequence: an account is deleted without an open removal request, or by the wrong person. | 1 | 3 | 3 | pgTAP `internal.delete_account_as` matrix (admin, self-teacher, teacher with and without request, student self); `delete-account` deno tests | Epic 12 |
| R-030 | SEC | "Public topics; forged live messages; two epics naming topics or events differently" (AD-19). Consequence: live events reach non-members, or clients forge them. | 2 | 2 | 4 | Health check asserts `private_only` (story 1.4); pgTAP on `realtime.messages` policies per topic kind; zod event union in `realtime.ts` with Vitest | Story 1.4; epics 2, 5 |
| R-031 | TECH | "Migrations, which deploy before the bundle, breaking clients still on the previous bundle or an older App Store build" (AD-20). Consequence: the iOS app on an older build breaks until users restart onto the new bundle or update. | 2 | 2 | 4 | Migration lint for drop, rename or changed signature (TC-4); contract migrations ship as their own change | Epic 1 (lint), every epic |
| R-034 | OPS | "Expired secrets" (AD-21), meaning the Apple sign-in client secret against "Apple's 6-month limit". Consequence: Apple sign-in stops working for every teacher who uses it, until the secret is minted again. | 2 | 2 | 4 | The secret is never stored. A `deploy.yml` step mints it at each deploy, and `apple-secret.yml` reruns that step monthly | Epic 2 |
| R-035 | OPS | "Each epic logging differently or not at all; a change to who is in Fermi with no record; a deletion erasing the events that record it" (AD-22). Consequence: R30's audit trail has holes. | 2 | 2 | 4 | pgTAP per audited action asserting one `audit_events` row in the same transaction; grants show no update or delete; deletion-trigger case writes the event | Epics 2, 3, 12 |
| R-037 | TECH | "Native-only paths checked by hand in the iOS Simulator" (spine conventions). Consequence: the live-update restart, NativeAuth, the Drive picker or APNs regress after a later change, and no test notices. | 2 | 2 | 4 | Dated hand-check notes per story; full rerun on the TestFlight build (epic 13); `Capacitor.isPluginAvailable` guards covered by Vitest | Epics 1, 2, 4, 6, 13 |
| R-038 | OPS | "There is no staging" (spine Structural Seed). Consequence: a bad migration runs straight on the only hosted project, with no automated rollback. | 1 | 3 | 3 | Migrations run on CI's local stack with every pgTAP test before merge; expand-only rule (R-031); weekly restore-proven backup (R-009) | Epic 1 |
| R-040 | TECH | "Confirm on the hosted project that the hook ignores admin-API creation" (spine Open Questions). Consequence: `add-students` is refused by the email-provider rule, and no student can be created. | 2 | 2 | 4 | Epic 2's opening spike on the hosted project; pgTAP hook test includes an admin-API-shaped payload | Epic 2 spike |
| R-043 | SEC | "Confirm a `BEFORE UPDATE ON auth.users` trigger refuses a student's own password change cleanly" (spine Open Questions; AD-8). Consequence: a student changes their password through the raw Auth API, and the teacher's stored copy goes stale. | 2 | 2 | 4 | Epic 2 spike; an api test with a student JWT calling Auth's update-user, refused; pgTAP ticket-consumption case | Epic 2 spike, epic 3 |
| R-044 | TECH | "A Fermi-hosted Drive picker page in the NativeAuth sheet on iOS" (spine Open Questions). Consequence: iOS users can't attach from Drive. | 2 | 2 | 4 | Epic 4's opening spike; hand check in the Simulator | Epic 4 spike |
| R-045 | TECH | "A real sandbox APNs push reaches a closed app in the iOS Simulator on the build Mac … If it does not, a development-signed build … takes its place" (spine Open Questions). Consequence: R11 can't be verified before TestFlight. | 2 | 2 | 4 | Epic 6's opening spike, with the stated fallback | Epic 6 spike |
| R-046 | BUS | "`awardBehaviorPoints` has no type or range check on `points`" (parity inventory). Consequence: wrong or extreme point values corrupt totals. | 2 | 2 | 4 | pgTAP: award function refuses non-integer and out-of-range values with `22023` | Epic 8 |

#### Low-Priority Risks (Score 1-2)

| Risk ID | Category | Description | Probability | Impact | Score | Action |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ------ |
| R-006 | DATA | "Today it is stored two ways" (K14). Merged with the parity data-shape conflicts table (photo, enrollment, display name, student record, grade, chat, notification read flag, history time, push token, activity owner), AD-9 "the four Firebase enrollment shapes" and AD-10 "chat stored two ways". Consequence: two features disagree about one fact. | 1 | 2 | 2 | Generated `Database` types in Vitest typecheck; the conventions' shared shapes are the only names; review at each epic's test design |
| R-016 | DATA | "Companion rows created two ways" (AD-9). Consequence: a class without a class chat or Announcements board, or with two. | 1 | 2 | 2 | pgTAP: inserting a class creates exactly one of each; the backfill covers existing classes; `unique (class_id)` holds |
| R-019 | SEC | "Faked presence; presence beyond the directory; … dots and the admin's online count disagreeing" (AD-11). Consequence: wrong online dots, or presence visible to strangers. | 1 | 2 | 2 | pgTAP: no update grant on `last_seen_at`; `app.presence` thresholds at 2 min; visibility through `app.can_see_user` |
| R-028 | TECH | "Firebase's every-error-is-`internal`; each screen parsing errors its own way" (AD-17). Merged with parity "callables rethrow every error as `internal`". Consequence: users see generic errors, and tests can't assert refusals. | 1 | 2 | 2 | Story 1.5's Vitest map and deno helper tests; ESLint rule against Supabase imports outside `api/` |
| R-039 | PERF | Free-plan limits named but unmeasured: "Revisit before the Free plan's 500 MB database, 1 GB storage or 200 concurrent Realtime connections near their limits" (spine Deferred). Consequence: Realtime or uploads fail once usage grows. | 1 | 2 | 2 | Add database size, storage size and peak Realtime connections to `job_health()` or the keep-alive output, as a later improvement (clarification Q2) |
| R-041 | TECH | "Confirm Supabase links a later Google sign-in to an existing student account with the same confirmed email" (spine Open Questions; AD-6). Consequence: a student who taps Google is refused or gets a second account. | 2 | 1 | 2 | Epic 2 spike; api test on the local stack if linking can be simulated, otherwise a hand check |

#### Risk Category Legend

- **TECH**: Technical/Architecture (flaws, integration, scalability)
- **SEC**: Security (access controls, auth, data exposure)
- **PERF**: Performance (SLA violations, degradation, resource limits)
- **DATA**: Data Integrity (loss, corruption, inconsistency)
- **BUS**: Business Impact (UX harm, logic errors, revenue)
- **OPS**: Operations (deployment, config, monitoring)

---

### NFR Testability Requirements

| NFR Category | Threshold / Requirement | Current Design Support | Gap / Decision Needed | Planned Evidence |
| --- | --- | --- | --- | --- |
| Security | No `anon` grants; RLS on every `public` table; uploads ≤ 10 MB with an exact MIME list; signed URLs ≤ 1 h; Dependency Review fails at moderate (AD-3, AD-13, AD-23) | Supported | TC-1 staff sessions; TC-3 personas | pgTAP matrices, catalog test, Playwright api runs, health check |
| Performance | UNKNOWN | Unknown | Q1: no latency or throughput target exists | None until Q1 |
| Reliability | Keep-alive twice daily; weekly backup with restore; Apple secret monthly; job refusals recorded and never retried (AD-15, AD-21) | Supported | Recovery time objective UNKNOWN (Q4); data-loss limit implied at 7 days | keep-alive and backup run history, `job_health()` |
| Maintainability | pgTAP for every table, policy, grant, function and view; `deno test` for every `handler.ts` (spine conventions) | Supported | Coverage threshold UNKNOWN (Q3); migration lint missing (TC-4) | `test.yml` lanes, coverage report |

**Unknown thresholds:** performance (Q1), user and concurrency counts (Q2), coverage (Q3), recovery time (Q4). These are clarification items, and no value is guessed.

**Assessment boundary:** final PASS, CONCERNS or FAIL belongs to `bmad-tea-nfr` once implementation evidence exists.

---

### Testability Concerns and Architectural Gaps

**🚨 ACTIONABLE CONCERNS**

#### 1. Blockers to Fast Feedback (WHAT WE NEED FROM ARCHITECTURE)

| Concern | Impact | What Architecture Must Provide | Owner | Timeline |
| --- | --- | --- | --- | --- |
| **TC-1 Staff sessions locally (decided)** | No Playwright test can act as a teacher or the admin | A test-code-only helper using the local stack's `service_role` key, refusing any non-local URL; no test sign-in path in the app, functions or hosted config | Story 1.3 | Before epic 2 |
| **TC-2 Time control** | Reminder, schedule, presence and expiry tests would wait in real time or be skipped | Cron workers take the run time as a parameter | Epic 2 (pattern) | First cron job |
| **TC-3 Persona cast** | Each epic seeds differently, and policy tests miss cases | A shared SQL persona helper plus TypeScript factories | Story 1.3 | Before epic 2 |
| **TC-4 Expand-only check** | A breaking migration passes every lane (R-031) | A migration lint in `test.yml` | Story 1.3 or 1.11 | Epic 1 |

#### 2. Architectural Improvements Needed (WHAT SHOULD BE CHANGED)

1. **Native-only paths have no rerun (TC-5, R-037)**
   - **Current problem:** the live-update restart, the NativeAuth sheet, the Drive picker and APNs are checked by hand once, in the story that builds them.
   - **Required change:** record each hand check as a dated note in its story, and rerun all of them on epic 13's TestFlight build.
   - **Impact if not fixed:** a later change breaks iOS-only behaviour unseen until App Review.
   - **Owner:** epics 1, 2, 4, 6 and 13. **Timeline:** each native story; TestFlight.
2. **Free-plan usage is not reported (R-039)**
   - **Current problem:** the spine names the 500 MB, 1 GB and 200-connection ceilings but nothing measures them.
   - **Required change:** `job_health()` or the keep-alive output reports database size, storage size and peak Realtime connections.
   - **Impact if not fixed:** uploads or Realtime fail at the limit with no warning.
   - **Owner:** story 1.7 or later. **Timeline:** after Q2 is answered.

---

### Risk Mitigation Plans (High-Priority Risks ≥6)

These are the 14 high-priority risks. Each must be mitigated before epic 13's App Store submission, and R-002 and R-012 before any epic's tables reach hosted. Test scenarios for each are in the QA doc.

#### R-002: Cross-user private reads (Score: 9) - CRITICAL

1. Every `public` table has RLS on in its creating migration, and reads go only through AD-2's predicates (AD-1, AD-2).
2. Edge-function handlers query only the RPCs they name; no membership is re-derived in TypeScript (AD-5).
3. Each owning epic adds its tables to the persona × table read matrix before they reach hosted.

**Owner:** each table's owning epic · **Timeline:** every epic · **Status:** Planned · **Verification:** QA doc P0-002 green in `test.yml`

#### R-012: Default grants and EXECUTE to PUBLIC (Score: 9) - CRITICAL

1. Each migration revokes EXECUTE from `public`, `anon` and `authenticated`, and grants back only `public` RPC wrappers (AD-3).
2. Every view in `public` is `security_invoker` (AD-3).
3. The privilege fixture changes in the same migration (conventions).

**Owner:** story 1.6, then every migration · **Timeline:** story 1.6 · **Status:** Planned · **Verification:** the catalog test fails on a missing fixture entry and on EXECUTE to `anon` (story 1.6 verify)

#### R-003: Unlisted Google or Apple account, or email sign-up, admitted (Score: 6) - HIGH

1. `internal.before_user_created` admits only `staff_invites` or bootstrap emails; it refuses `email` provider sign-ups and Apple relay addresses (AD-7).
2. Sign-up stays off until the change that registers the hook (AD-21).

**Owner:** epic 2; story 1.4 · **Timeline:** epic 2's hook change · **Status:** Planned · **Verification:** QA doc P0-003; the health check's hook-URI assertion

#### R-004: Cross-scope writes (Score: 6) - HIGH

1. Rule-bearing writes go through one `internal.*_as` function with no direct client write grant (AD-4).
2. Every class-scoped write checks membership, ownership and `app.class_open` (AD-9).

**Owner:** each table's owning epic · **Timeline:** every epic · **Status:** Planned · **Verification:** QA doc P0-004

#### R-005: No tests or CI on pull requests yet (Score: 6) - HIGH

1. Story 1.3 delivers every lane and Test Summary immediately after story 1.1.
2. Until then, stories 1.1, 1.2 and 1.12 are accepted on their `verify` steps by hand.

**Owner:** story 1.3, story 1.13 · **Timeline:** epic 1 · **Status:** Planned · **Verification:** story 1.3 verify: four deliberate failures turn the run red

#### R-010: App Review rejects the iOS update (Score: 6) - HIGH

1. Review notes carry a demo teacher and a demo student on the lists, plus a note that sign-in is invitation-only (initiative Notes).
2. Apple sign-in reaches parity with Google before submission (K11). Major features ship in reviewed builds (AD-18).

**Owner:** epic 13 · **Timeline:** at submission · **Status:** Planned · **Verification:** a TestFlight walkthrough per role

#### R-018: Removed student keeps access (Score: 6) - HIGH

1. Access derives from `enrollments` through the predicates; removal needs no cleanup write (AD-9, AD-10).
2. Realtime events carry ids only, so the 1-hour channel cache leaks nothing (AD-19).

**Owner:** epic 3, plus epics 4, 5, 7 and 8 · **Timeline:** each of those epics · **Status:** Planned · **Verification:** QA doc P0-007

#### R-020: Emails exposed beyond D20 (Score: 6) - HIGH

1. `authenticated` has no `SELECT` on `profiles.email`; email is read only through `app.visible_email` (AD-12).

**Owner:** epic 2 (shape), epics 3 and 5 (clauses) · **Timeline:** epics 2, 3, 5 · **Status:** Planned · **Verification:** QA doc P0-008

#### R-023: Storage scope (submissions, paths) (Score: 6) - HIGH

1. Private buckets with AD-13's policy table. A row stores only a path, and its prefix must equal the row's scope ids.

**Owner:** epics 2, 4, 5 · **Timeline:** those epics · **Status:** Planned · **Verification:** QA doc P0-009

#### R-029: Live update reaches an incompatible native shell (Score: 6) - HIGH

1. `latest.json` carries `min_native_build`, and the shell skips a newer bundle and shows the App Store banner (AD-18).
2. A `test.yml` job fails a plugin added without raising `MIN_NATIVE_BUILD` (story 1.9). The native Dependabot group never merges itself (story 1.13).

**Owner:** stories 1.9, 1.10, 1.13 · **Timeline:** epic 1 · **Status:** Planned · **Verification:** story 1.10's Simulator check; QA doc P1-012

#### R-032: Hosted Auth or Realtime config drift (Score: 6) - HIGH

1. Deploy pushes the Auth config and sets Realtime private-only; the health check reads both back (AD-21).

**Owner:** story 1.4; epic 2 · **Timeline:** story 1.4 · **Status:** Planned · **Verification:** story 1.4 verify (anonymous sign-ins turned on makes the check fail)

#### R-033: Silent job failures (Score: 6) - HIGH

1. `public.job_health()` reads `internal.job_failures`, `cron.job_run_details` and non-2xx `net._http_response`; keep-alive fails, and GitHub emails the owner (AD-21).

**Owner:** story 1.7; epics 2, 4, 5, 6 · **Timeline:** story 1.7 · **Status:** Planned · **Verification:** story 1.7 verify (an inserted failure row turns the next run red)

#### R-036: Merge gate bypassed (Score: 6) - HIGH

1. The Main ruleset targets the default branch only and requires exactly Test Summary and Dependency Review (AD-23).
2. `test.yml` reads no secret. Auto-merge runs only after both checks pass, and never for the native group.

**Owner:** stories 1.3, 1.13 · **Timeline:** epic 1 · **Status:** Planned · **Verification:** story 1.13 verify

#### R-042: Apple sign-in through the NativeAuth sheet fails (Score: 6) - HIGH

1. The spike that opens epic 2 proves Sign in with Apple through the NativeAuth sheet end to end (spine Open Questions).

**Owner:** epic 2 spike; epic 13 · **Timeline:** start of epic 2 · **Status:** Planned · **Verification:** a dated hand check in the Simulator, repeated on TestFlight

---

### Testability Assessment Summary

#### What Works Well

- ✅ All business rules are reachable without a UI: `internal.*_as(actor, …)` takes the actor explicitly (AD-4).
- ✅ Edge functions split into a pure `handler.ts` and the wiring in `index.ts` (AD-5).
- ✅ Coded errors (AD-17) make refusals assertable by key.
- ✅ The privilege fixture turns "locked by default" into a failing test (AD-3).
- ✅ CI uses a fresh local stack and `test.yml` uses no secrets, so runs are reproducible and Dependabot pull requests run every lane (AD-23).
- ✅ `audit_events` and `internal.job_failures` give assertable trails (AD-15, AD-22).

#### Accepted Trade-offs (No Action Required)

- **Storage file bytes and the Vault root key are not backed up** (K18, AD-21). Teachers reset passwords after a restore. This is accepted for the Free plan.
- **No client error reporting (TC-6).** Revisit with the Pro plan (spine Deferred).
- **Playwright "iPhone WebKit" is not iOS Safari or the Capacitor shell (TC-8).** The per-role walkthrough in the initiative's "Done when" covers the real platforms.
- **Web push is best effort** (R24). The inbox and unread counts carry what was missed.

These are acceptable for the port and revisited with the Pro plan.

---

### Assumptions and Dependencies

#### Assumptions

1. The spine's design is built as written. Scores assume its controls are planned, not yet present.
2. `before_user_created` does not fire for admin-API user creation. UNVERIFIED until epic 2's spike (R-040).
3. A `BEFORE UPDATE ON auth.users` trigger can refuse a student's own password change. UNVERIFIED until epic 2's spike (R-043).
4. Staff signed in by the TC-1 helper bypass `before_user_created`, so automated browser tests never exercise admission. Admission rests on P0-003's hook tests (R-003) and the epic-invite-sign-in hand checks.
5. Expected scale fits the Free plan. UNKNOWN (Q2).
6. Clarifications open: Q1 performance targets; Q2 users and peak concurrency; Q3 coverage threshold; Q4 recovery time objective; Q5 whether a student-privacy law or school data policy applies (no source names one).

#### Dependencies

1. Story 1.3's framework run settles TC-1 and TC-3. Required before epic 2's stories.
2. Epic 2's spikes (R-040 to R-043) settle the Auth assumptions. Required before epic 2's sign-in stories.
3. Epic 4's Drive picker spike (R-044) and epic 6's APNs spike (R-045). Required before those epics' feature stories.

#### Risks to Plan

- **Risk:** the persona × table matrices (P0-002, P0-004) grow with every epic and slow `test.yml` past 15 minutes.
  - **Impact:** slower feedback on every PR.
  - **Contingency:** pgTAP files run in parallel by file; Playwright shards. Neither moves out of the PR run.
- **Risk:** spikes fail (R-040, R-042, R-043).
  - **Impact:** the matching tests change shape.
  - **Contingency:** each spike's outcome feeds that epic's own `bmad-tea-test-design` run.

---

**End of Architecture Document.**

**Next steps for the owner:** decide TC-1 to TC-4 in story 1.3's framework run; answer Q1–Q5 when convenient. Scenarios are in `test-design-qa.md`.
