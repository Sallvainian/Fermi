---
title: Rubric review — Capacitor Supabase Port architecture spine
reviews: architecture-capacitor-supabase-port.md, epic-map-capacitor-supabase-port.md
against: initiative-capacitor-supabase-port.md (R1-R25, K1-K16), tickets/tickets.toml, .memlog.md
date: 2026-11-05
---

# Rubric review

**Verdict: not ready to bind epics.** The paradigm and most ADs are sound, and the user's decisions in the memlog are carried over faithfully. But two security gaps sit in the enforcement layer itself (hosted auth config is outside the pipeline; AD-3 says nothing about function EXECUTE or views). The epic map has two build-order violations. The operational envelope is thin on backups, monitoring and recurring operations. All of these can be fixed in the spine. None needs a user decision to be reopened.

Inputs read in full: the spine (295 lines), the epic map (59), the ticket (119), tickets.toml (104) and the memlog (80). The parity inventory's defects and data-shape tables were also read. Checked against Supabase docs on 2026-11-05: the `before_user_created` hook is available on the Free plan; its docs do not say whether it fires for admin-API user creation, so the spine's open question stands; the hook function needs `grant execute ... to supabase_auth_admin` and a revoke from `authenticated, anon, public`; Apple's OAuth (web) secret must be regenerated every 6 months, but native-only ID-token sign-in needs no secret.

## Critical

### C1. Hosted auth config is not deployed by the pipeline, so AD-7's gate can be missing in production

AD-7's whole admission rule depends on three things in the hosted project's Auth config: the `before_user_created` hook being registered, `[auth.email] enable_signup = false`, and anonymous sign-ins being off. The Consistency Conventions "Auth config" row also covers Google and Apple provider settings, redirect URLs and manual linking.

`supabase db push` applies migrations only. It does not apply `config.toml` auth settings to a hosted project. The spine's deploy flow and K7's order (migrate, functions, build, wrangler, health check) have no config step. So the hook and flags would either be set by hand in the dashboard, which breaks K7's "nothing is deployed by hand", or not set at all. If the hook isn't registered, any Google or Apple account gets an Auth user, which is the R2/K3 failure the ticket's "Done when" tests for. Local runs and CI use `config.toml` and would pass, so nothing catches the drift.

**Fix:** add a step to the deploy flow and the Structural Seed: `supabase config push` (with provider secrets passed through `env()`) after migrate and before functions. Add a post-deploy check that reads the hosted auth config through the Management API and fails unless the hook is enabled and both signup flags match. Record this in AD-7's Rule.

### C2. AD-3 locks tables but leaves functions and views open

- **Functions:** Postgres grants `EXECUTE` to `PUBLIC` on every new function, and Supabase's default privileges extend it to `anon` and `authenticated`. Any `public` function is therefore an RPC endpoint. Several functions in the spine must never be client-callable:
  - `notify(recipients, kind, ref)`: any user could write inbox rows and trigger pushes to anyone.
  - the cron-only paths in AD-15.
  - the `before_user_created` hook function.
  - any internal helper.

  AD-3 and its catalog test cover tables only.
- **Views:** the spine relies on views in several places:
  - grade analytics (R18)
  - archived grades
  - behavior totals
  - every dashboard (R19)
  - possibly the directory

  A view in `public` runs with its owner's rights and bypasses RLS unless it is created `with (security_invoker = true)`. One epic forgetting this exposes every student's grades or points. That brings back the parity defect "an enrolled student can read every classmate's points and history".

**Fix:** extend AD-3's Rule:
1. Every function's creating migration revokes `EXECUTE` from `public, anon, authenticated` and grants it to `authenticated` only for the named client RPCs.
2. Internal functions (`notify`, cron targets, the hook) live in a non-exposed schema, or are granted only to `postgres`/`service_role`/`supabase_auth_admin`.
3. Every view in `public` sets `security_invoker = true`, unless it is a named `security definer` exception such as the directory.
4. The catalog test fails on any public function with a PUBLIC/anon execute grant, and on any public view without `security_invoker`, unless it is on an explicit allowlist.

## High

### H1. Build-order violations in the epic map

1. **Epic 4 uses `notify`, which epic 6 owns.** In tickets.toml, epic 4 has `after = [3]` and epic 6 comes later (it depends on 5). The epic map still has epic 4 owning the due-reminder pg_cron job, which calls `notify`, and emitting `assignment_published` and `grade_posted`.
   **Fix (pick one):**
   - add `{ epic = 6 }` to epic 4's `after` and reorder;
   - or move the emit wiring (triggers on `assignments`/`grades`, the due-reminder job) into epic 6, which then lists epic 4's tables under "Uses";
   - or split the reminder and emit stories out of epic 4 and run them after epic 6. Note that `reminder_preferences` would move with them.
2. **Epic 2 owns `app.can_see_user` and the directory**, but the rule AD-12 states ("people who share a class, a student's teachers") is defined over `enrollments`, which epic 3 creates later. Epic 2 can only ship a self-plus-admin version, so epic 3 would have to rewrite a function owned by another epic. That is exactly the two-definitions divergence AD-2 forbids.
   **Fix:** epic 2 owns the directory's interface (its name, columns, D20 email masking) with a body covering self and admin only. Epic 3 owns the body that reads enrollments and its pgTAP tests. State this hand-off in the epic map and the seams table, or move `app.can_see_user` to epic 3 outright.
3. **Epic 3's "ask my teacher to remove my account" request.** The memlog (line 72) says it goes to the teachers' and the admin's inboxes. The inbox is epic 6's `notifications`, and AD-14's closed kind list has no removal-request kind.
   **Fix:** add a `removal_request` kind to AD-14. Then either make epic 3 show pending requests on the roster and in the admin's view without `notify`, with epic 6 adding the inbox emit, or move the request's notification story after epic 6.

### H2. Deleting a row leaves its file in Storage; class deletion has no rule

R4 lets a teacher delete classes, but no AD covers what a class delete does. AD-16 covers accounts only: "removes the person's Storage objects". Under AD-13 paths are `<scope_id>/<uuid>`, where the scope is the class or chat, so objects cannot be traced to a person by path. Files a teacher's students uploaded into the teacher's classes are not "the person's" either.

A SQL cascade does not remove the bytes. Supabase routes file deletion through the Storage API; whether a direct SQL delete on `storage.objects` is blocked on new projects is UNVERIFIED. As a result, these leave orphaned files that count against the Free plan's 1 GB, with nothing purging them (the Deferred "retention" item assumes nothing grows by accident):
- deleting an assignment, a submission or a message
- deleting a class
- a teacher deleting their own account, which cascades their classes

AD-8 also stores each student's password in Vault, and `vault.secrets` rows are not FK-linked to `profiles`, so deleting a student would leave their secret behind.

**Fix:** add an AD:
1. Every table that stores a storage path gets an `AFTER DELETE` trigger that queues the path into one `storage_deletions` table.
2. One pg_cron job and one edge function drain that queue through the Storage API.
3. Class deletion goes through one `delete_class` function.
4. `delete-account` also deletes the student's Vault secret.

Owners: epic 1 or 2 owns the queue; every epic that owns a bucket adds its trigger.

### H3. Sign in with Apple can't reliably get past AD-7 (K11, App Review)

The memlog (line 26) records that Apple lets users hide their email behind a private relay address. Such an address will never match `staff_invites`, so a teacher or the admin who picks "Hide My Email" is refused, and the spine gives no rule or message for this case. App Review is also at risk: reviewers usually test Sign in with Apple with their own Apple ID, which will not be on the list. Guideline 2.1(a) needs a working demo path, and 4.8 needs Apple to work "as fully as Google" (K11). The epic map's "reviewer demo accounts on the lists" does not say which Apple or Google identity a reviewer would use.

**Fix:**
- Add a rule to AD-7: when a relay address (`@privaterelay.appleid.com`) is refused, the user sees a message telling them to share their real email. Alternatively, record refused sign-ins so the admin can add the relay address.
- Add an Open Question for epic 13: the reviewer demo path. For example, a demo teacher Google account whose credentials go in the review notes, plus a demo student email-and-password account, plus a note on Apple behaviour.

### H4. The operational envelope is thin beyond deploy and keep-alive

Environments and secret locations are decided. These are not:

- **Backups and restore:** there is no staging, and migrations run forward on live data from every push to main. The spine says nothing on backups. Whether the Free plan gives any restorable backup is UNVERIFIED. The spine should decide: accept no backups, or run a scheduled `supabase db dump` in CI to a private artifact (with a note on Vault-encrypted secrets and Storage files). It should also state a migration-failure policy: forward-only, fix by a new migration, and no destructive change in the same deploy as the code that stops using it.
- **Monitoring:** the only checks are the health check and Supabase's pause email. Nothing reports failures of `send-push`, `pg_cron` jobs (scheduled messages, due reminders) or the `add-students`/`delete-account` edge functions. At minimum, decide where failures surface. Examples: a `cron.job_run_details` check in the keep-alive job, or `send-push` writing failures to a table the admin console shows.
- **Keep-alive can stop itself:** GitHub disables scheduled workflows in a public repository after 60 days with no repository activity. A summer break with no commits would disable `keep-alive.yml`, and the Free project would then pause. Decide how the job stays enabled (for example, a re-enable step through the API, or periodic activity on the repo), or state that the pause email is the only backstop.
- **Recurring secret rotation:** the Apple OAuth secret used by the web sign-in flow expires every 6 months (Supabase docs). Native ID-token sign-in is unaffected. Name who regenerates it and where it is stored (fnox, then pushed by CI per C1). The same goes for APNs and VAPID keys.
- **Per-environment values inside the database:** AD-14's `pg_net` trigger needs the `send-push` URL, and AD-5 needs the shared secret "held in a service-only table". Only the bootstrap admin email is said to be "set by CI". Say that CI seeds all three per environment (local, CI, hosted), so epic 6 does not invent its own mechanism and K7's "nothing by hand" holds.

## Medium

### M1. No compatibility rule between the schema and older clients

The iOS updater only offers to restart. A Home Screen web app can run a cached bundle, and an App Store build can lag behind `MIN_NATIVE_BUILD`. Migrations deploy first, so clients still running the previous bundle hit the new schema. Without a rule, one epic renaming a column or changing an RPC signature breaks every lagging client.

**Fix:** a Consistency Convention of expand-then-contract. Column renames, removals and RPC signature changes ship only after the bundle that stops using the old shape has been live for one deploy. Changing a function's arguments means adding a new function name.

### M2. AD-15's "same functions" clashes with `auth.uid()`

`send_message` "re-checks membership and pairing at send time", but under `pg_cron` `auth.uid()` is null.

**Fix:** state the split. A client RPC passes `auth.uid()` into an internal `send_message_as(sender_id, …)`. That internal function is not client-executable (C2) and is the one the cron job calls. Do the same for `notify`.

### M3. AD-13 does not fix the path scope for each bucket

"The scope is the user, class or chat" leaves `submission-files` ambiguous. If it is scoped by class, a policy using `app.enrolled(class_id)` lets classmates read each other's submissions.

**Fix:** add a table to AD-13:

| Bucket | Path | Who reads |
| --- | --- | --- |
| `avatars` | `<user_id>/…` | directory-visible users |
| `assignment-files` | `<class_id>/…` | teacher and enrolled students |
| `submission-files` | `<class_id>/<student_id>/…` | that student and `app.teaches` only |
| `chat-files` | `<chat_id>/…` | chat members |

Also state each bucket's MIME list: avatars take images only.

### M4. `user:` Realtime topics have several emitters but no event contract

AD-19 gives the topic names to epic 5. But `user:` carries "per-user events" from both epic 5 (unread changes) and epic 6 (the R17 web pop-up, which the spine never wires to a transport).

**Fix:** epic 5 owns one zod discriminated union of `user:` event types in `app/src/api/`, which other epics extend. State that epic 6's pop-up arrives as a `notification` event on `user:<uuid>`, and say who sends it (a trigger with `realtime.send`, or `send-push`).

### M5. The GPA deferral lets two epics compute it differently

Deferred says "epic-assignments-grades decides" the GPA formula. But epic 11 shows GPA (R19), and dashboards "read views over source tables". Epic 4's analytics (R18) and epic 11's widget could each compute it.

**Fix:** epic 4 owns one grade-summary view or function, which includes GPA. Epic 11 reads only that.

### M6. How the Drive token is obtained is undecided (K12, R6)

Students now sign in with email and password, so they have no Google identity. Teachers who sign in with Apple don't either. AD-13 assumes "the user's `drive.file` token". The flow is open: a separate Google consent requested at first attach, which on iOS has to run outside WKWebView (the NativeAuth sheet). If left open, epic 2 (Google OAuth wiring) and epic 4 (Drive) could build different flows.

**Fix:** add one line to AD-13. Request the `drive.file` token through Google's token client on web and through the NativeAuth sheet on iOS, at first attach, kept on the client only and never stored by Fermi.

### M7. How profiles and staging are created is unspecified (AD-6, AD-7, AD-8)

- A `before_user_created` hook runs before the `auth.users` row exists, so it cannot insert `profiles` (the FK). The spine's "the profile is created with the listed role in the same flow" therefore needs a named mechanism: one `AFTER INSERT ON auth.users` trigger that reads `staff_invites` or the staging row. Otherwise epic 2 (staff) and epic 3 (students) may create profiles two different ways.
- The staging table is unnamed. The epic map calls it "hook staging (epic 2)".
- "Staged ... in the same request" cannot be one transaction. `add-students` must commit the staging row before calling the Auth admin API, so stale staging rows need cleanup.

**Fix:** name the trigger, the `student_staging` table and its owner (epic 2), and add a TTL cleanup.

### M8. K10 ("Fermi sends no email") is not closed in the Auth config

`[auth.email] enable_signup = false` does not stop password-recovery, magic-link or email-change mail. AD-6 implies a user can change their email through the Auth API. Whether default SMTP delivers to non-team addresses is UNVERIFIED for this project.

**Fix:**
- Extend the Auth config row: no custom SMTP; recovery, OTP and email change are never offered in the UI; admin-created users get `email_confirm: true`.
- Add a pgTAP or API test that asserts calling these endpoints changes nothing about access.
- Optionally set the email-sent rate limit to its minimum.

### M9. AD-3's "lacks a grants test" cannot be enforced as written

A catalog query cannot tell whether a test exists.

**Fix:** one checked-in fixture holds the expected privilege matrix for each object (tables, columns, functions, views). The catalog test compares `information_schema` and `pg_proc` ACLs against it, and fails on any object missing from the fixture.

## Low

- **L1.** AD-9, AD-15, AD-17, AD-18 and AD-19 lack `[ADOPTED]`. Three memlog items marked "flag for user at close" are not in Open Questions:
  - AD-9's "removal ends access to own grades" (line 79)
  - the reset-password addition (line 76)
  - the assumption that DND also silences the in-app pop-up (line 48)

  Either tag the ADs or list these items for confirmation.
- **L2.** The epic map's mermaid is missing E13's dependencies on 4, 6, 7, 9 and 10, which tickets.toml lists. E9 and E10 have no outgoing edge.
- **L3.** If clients update `profiles.last_seen_at` through a column grant, they can fake being online. Use a `touch_presence()` function that sets `now()`.
- **L4.** R8 has no rule on who can be added to `calendar_event_participants`. Limit it to `app.can_see_user`.
- **L5.** Processing 1000 CSV rows in one `add-students` call may exceed edge-function time limits (UNVERIFIED). State that the client sends chunks, for example 100 rows each.
- **L6.** Pin the Supabase CLI to the stack's 2.122.0 in CI (the memlog notes npm `supabase` 3.0.0). Whether TypeScript 7.0.2 works with the lint toolchain is UNVERIFIED.
- **L7.** Class chats for classes created before epic 5 ships need a backfill and an insert trigger on `classes`. Name epic 5 as the owner.
- **L8.** The frontmatter `binds` lists R1-R25 and the epics but none of K1-K16, which the ADs bind.

## Checklist results

| Check | Result |
| --- | --- |
| Real divergence points fixed, none missed | Mostly. Missed: function/view grants (C2), storage cleanup and class delete (H2), the path scope for each bucket (M3), the `user:` event contract (M4), schema compatibility with lagging clients (M1), the profile-creation path (M7) |
| Each AD's Rule is enforceable and prevents its divergence | AD-3 is not enforceable as worded (M9) and incomplete (C2). AD-7 depends on config outside the pipeline (C1). AD-15 conflicts with `auth.uid()` (M2). The rest are fine |
| Nothing deferred can let epics diverge | The GPA deferral can (M5). The retention deferral relies on H2. The others are safe |
| Covers R1-R25 and K1-K16, except where superseded | See the table below. Gaps: R4 class delete, R17 transport, R8 participant scope, K7 (C1, H4), K10 (M8), K11 (H3), K12 (M6) |
| Operational envelope decided, deferred or open | Deployment and environments are decided. Backups, monitoring, keep-alive survival, secret rotation and per-environment DB values are missing (H4) |
| Epic map vs tickets.toml build order | Two violations (epic 4 uses epic 6's `notify`; epic 2's `can_see_user` needs epic 3's tables) plus epic 3's removal request needing epic 6 (H1) |

## Requirement and constraint coverage

| Item | Status | Where / gap |
| --- | --- | --- |
| R1, R2 | Covered (superseded to email lists per memlog 35-40) | AD-6, AD-7, AD-8; C1, H3, M7 affect it |
| R3 | Covered | AD-12, AD-13 |
| R4 | Partial | Create/edit/archive covered (AD-9); **class delete has no rule** (H2). The name match is superseded |
| R5 | Covered (superseded to name + email) | AD-8 |
| R6 | Covered | AD-4, AD-9, AD-13; Drive token flow open (M6) |
| R7 | Covered | AD-2, AD-4; totals views need C2 |
| R8 | Partial | No participant-scope rule (L4) |
| R9 | Covered | AD-9; details deferred to epic 7 (safe) |
| R10 | Covered (students text-only per memlog 43) | AD-10, AD-13, AD-19 |
| R11 | Covered | AD-14 |
| R12 | Covered (+DND) | AD-11 |
| R13 | Covered | Capability map |
| R14 | Covered | AD-14 |
| R15 | Covered (codes superseded by the list) | AD-7, AD-16 |
| R16 | Covered | AD-15; M2 |
| R17 | Partial | Owner named; transport unspecified (M4) |
| R18 | Covered | Epic 4 views; C2 |
| R19 | Covered | Views; C2, M5 |
| R20 | Covered | AD-14 |
| R21 | Covered | AD-9 |
| R22 | Covered | AD-12 |
| R23 | Covered | AD-18; M1 |
| R24 | Covered | AD-14 |
| R25 | Covered (wording changes with the gate) | Capability map |
| K1 | Covered | Paradigm, seed |
| K2 | Covered | Epic 13 removal |
| K3 | Superseded (email lists) | AD-7 |
| K4 | Covered | AD-6 |
| K5 | Mostly | Parity defects mapped; the classmates-read-points defect can recur through views (C2) |
| K6 | Covered | `wrangler.jsonc`; the workers.dev account subdomain is still UNVERIFIED in the ticket |
| K7 | Partial | Auth config and secrets fall outside the pipeline (C1, H4) |
| K8, K9 | Covered | Scope |
| K10 | Partially superseded (student passwords) | "No email" not closed (M8) |
| K11 | Partial | Apple relay and reviewer path (H3) |
| K12 | Partial | Token flow (M6) |
| K13 | Covered | Tests convention, AD-3 |
| K14 | Covered | AD-10 |
| K15 | Covered | AD-18 |
| K16 | Covered | AD-12 (needs email masking: profiles not row-readable by others, M7/H1) |
