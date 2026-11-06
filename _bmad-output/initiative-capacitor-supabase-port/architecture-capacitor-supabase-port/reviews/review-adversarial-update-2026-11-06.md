---
review: adversarial
target: architecture-capacitor-supabase-port.md (+ epic-map), amendment of 2026-11-06
lens: two units that each obey every AD to the letter yet build incompatibly
date: 2026-11-06
prior: reviews/review-adversarial.md (2026-11-05); its findings that the spine has since fixed are not repeated
---

# Adversarial review: amendment of 2026-11-06

## Verdict

**The amendment is not ready to bind stories.** Most of it holds: the pg_cron/pg_net move, the split of the health-check hook assertion, and the admin's write path through `enroll_student_as` all close the ordering gaps they target. But the two newest pieces collide with older rules. AD-22's audit log, bound this time to R26, R29 and R30, cannot hold the very events it lists, because AD-16's cascade and AD-22's own cascade clause erase them. AD-8's admin roster has write paths but no read path. A further gap is new in kind: the deletion test file, now created by epic 2, has no defined deletion root, so epic 3's Vault-secret case can pass while the secret leaks.

Sources read in full: the spine (447 lines), the epic map (74), the git diff of both files and the folder's `.memlog.md`, the prior review `reviews/review-adversarial.md` (206), and `tickets/tickets.toml`. I also read My-Love's `20261031000000_push_devices.sql` header for the pattern AD-5 cites. Supabase behaviour I did not check against current docs is marked UNVERIFIED.

---

## Critical

### U1. AD-22 and AD-16 cascades delete the audit events R30 exists to keep

- **Unit A (epic 2, audit log story):** creates `audit_events (actor_id, action, class_id, subject_id, at, detail)`. `actor_id` and `subject_id` reference `profiles`. AD-16 says "every foreign key to `profiles` is `ON DELETE CASCADE`, except author columns on `messages`, `threads`, `replies` and `support_reports`", and `audit_events` is not on that list, so both columns cascade. `class_id` references `classes` on delete cascade, which matches AD-22's own words: "never updated or deleted, except by cascade when its class is deleted." Epic 2's deletion test case for `profiles` (AD-16 Tests) asserts the cascade. The unit is compliant.
- **Unit B (epic 3, `delete_class`):** AD-9 says "Deleting a class: only `delete_class`, which cascades", and AD-22 says the "class … deleted" event is written "inside the same function and transaction". The unit is compliant.
- **Unit C (epic 12, `delete-account`):** writes the "account deleted" event with `subject_id` set to the deleted person. The unit is compliant.
- **Collisions:**
  1. **Class deleted.** If `delete_class` writes the event before the delete, the cascade removes it in the same transaction. If it writes it after, the insert fails the foreign key. Either way, the "class deleted" event can never be stored.
  2. **Account deleted.** The same thing happens through `subject_id`. The "account deleted" event and the student's "removal request made" event (R29) disappear in the deletion they record.
  3. **Erasing a trail.** A teacher who deletes themselves (R28) cascades their classes (AD-16), which cascades every audit event for those classes. The cascade through `actor_id` also takes every event they acted in, such as passwords they revealed. So a teacher can wipe their own audit trail by deleting their account. That defeats R30's "an audit log nobody can edit".
  4. **A second deletion path for classes.** Teacher self-deletion also deletes classes without going through `delete_class`, so no "class deleted" event is written, even though AD-9 says `delete_class` is the only deletion path.
- **Fix: tighten AD-22 and AD-16.**
  - AD-22: "`audit_events` has no foreign keys. `actor_id`, `class_id` and `subject_id` are plain uuids, and `detail` snapshots the display name, email and class name at write time. Rows are never updated or deleted."
  - AD-22 read rule: "A teacher reads the events of classes they teach now and of students they teach now. Events of deleted classes and deleted people are visible only to the admin."
  - AD-16: add `audit_events` to the cascade exceptions ("no foreign key; kept").
  - AD-16: "a teacher's self-deletion runs `delete_class` for each of their classes before the Auth user is deleted, so each class deletion is audited."

## High

### U2. AD-22's "same function and transaction" cannot hold for actions that go through the Auth admin API

- **Unit A (epic 3, `reset-student-password`) and Unit B (epic 12, `delete-account`):** under AD-5 both are edge functions, and the change itself is an Auth admin API call (update the password; delete the user). That call commits on its own, outside any SQL transaction the function opens.
- **Unit C (epic 2, `internal.audit`):** AD-22 says it is "called inside the same function and transaction as the change it records".
- **Collision:** the two edge-function epics can satisfy that rule in incompatible ways. Epic 3 may write the audit row in the SQL call that issues the `password_resets` ticket. If the Auth call then fails, the log records a reset that never happened. Epic 12 may write the row after the Auth delete returns. If that write fails, an account is gone with no record. Each reading is defensible, and the two epics will pick differently. The same gap exists for the Vault copy of a reset password: if the Auth update fails after Vault was written, Show password displays a password that does not work.
- **Fix: add to AD-22.** "An action carried out through the Auth admin API is audited by the database trigger that observes it: the password reset by the `BEFORE UPDATE ON auth.users` trigger that consumes the `password_resets` ticket, and the account deletion by an `AFTER DELETE ON auth.users` trigger (epic 12). The actor is read from the ticket, or from an `internal.pending_deletions` row the edge function writes first." For the same reason, AD-8 should say "the Vault secret is replaced in the same trigger that consumes the ticket", with the ticket carrying the new secret's id.

### U3. AD-8 gives the admin roster writes but no reads

- **Unit A (epic 3):** writes `classes` and `enrollments` read policies per AD-9: "Reads stay: teachers for their classes, students for their own records". It builds roster status ("waiting or connected") as a check that uses `app.teaches`. AD-8's amendment widens only `add-students`, `enroll_student_as`, `reveal_student_password` and `reset-student-password`. The unit is compliant.
- **Unit B (epic 12):** under the epic map seam "Admin roster 3 → 12 … epic 12 adds only the screen", it builds a class picker and roster screen for the admin. The unit is compliant.
- **Collision:** the admin can call the write functions, but RLS returns no rows when the admin lists classes, a class's enrollments or roster status. The epic map says the owner writes the policies, so epic 12 may not add an admin `SELECT` policy to epic 3's tables. Either the screen is empty, or epic 12 builds an admin-only definer function that lists rosters, which is a second read path. AD-2 has no `app.is_admin` clause for class data, so nothing in the spine tells epic 3 to include the admin. Removal is a related gap. AD-8 says "only the teacher removes them", so an admin who adds the wrong student cannot undo it except by deleting the account. Deleting the account is then blocked for teachers by `no_removal_request`.
- **Fix: tighten AD-8 and AD-9.**
  - AD-9 reads: "Reads stay: teachers for their classes, students for their own records, and the admin for every class, its roster and roster status."
  - AD-8: "Every roster read and write that accepts `app.teaches` also accepts `app.is_admin`, including remove student (decide yes or no explicitly)."
  - Epic map seam: "epic 3's read policies and roster-status function include the admin from epic 3 on."

### U4. AD-16's deletion test file has no deletion root, so epic 3's secret case passes while the secret leaks

- **Unit A (epic 2):** creates the deletion test file with the `profiles` and `avatars` cases (AD-16, amended). `delete-account` does not exist until epic 12, so the only root epic 2 can test is `delete from auth.users` in pgTAP. `staff_invites` has no foreign key to `profiles`, so its removal is not a cascade. AD-16 lists it under "What deletion removes", a sentence about `delete-account`, so epic 2 leaves it to epic 12. The unit is compliant.
- **Unit B (epic 3):** "each later epic that adds … a secret adds its case". The `student_credentials` row cascades, but the `vault.secrets` row it references does not. Epic 3 can either:
  - add a case asserting only that `student_credentials` is gone, which is green while the decryptable password stays in Vault; or
  - add an `AFTER DELETE` trigger on `student_credentials` that deletes the Vault secret. In that case epic 12's `delete-account`, following "What deletion removes: … their Vault secret" literally, deletes it a second time or fails on a missing secret.
- **Unit C (epic 12):** "adds the `delete-account` cases" to the same file. `delete-account` is an edge function, and the conventions put edge-function tests in `deno test` of `handler.ts`, not pgTAP. The file's runner and path are not named.
- **Collision:** the Vault secret and the `staff_invites` row each have two possible removers in two epics, and the tests written before epic 12 cannot detect the leak.
- **Fix: rewrite AD-16's removal and test bullets.**
  - "The deletion root is `DELETE FROM auth.users`. Every side effect hangs off it as a cascade or as an `AFTER DELETE` trigger in the owning epic's migration: the `staff_invites` row (epic 2, keyed by email), the Vault secret (epic 3), and file paths (bucket owners). `delete-account` only checks through `internal.delete_account_as(actor, target)`, records the pending deletion (U2), and calls the Auth admin API. It removes nothing itself."
  - "The deletion test file is the pgTAP file `supabase/tests/database/NN_account_deletion.sql`. Each case deletes the `auth.users` row directly and asserts every side effect, the Vault row included. Epic 12 adds the `internal.delete_account_as` cases there and the handler cases in `delete-account/handler.test.ts`."

## Medium

### U5. Functions called through pg_net have no single config owner and no failure surface (AD-5, AD-21)

- **Unit A (epic 2):** `sweep-storage` is "called by `pg_cron`" (AD-16), so AD-5 makes it `verify_jwt = false` with "a shared secret held in a service-only table". Following My-Love's pattern (`push_sender_settings`, one row holding the URL and secret), epic 2 creates its own settings table and adds a deploy step for it. The unit is compliant.
- **Unit B (epic 6):** builds `send-push` with My-Love's `push_sender_settings`. AD-21 says "CI writes `send-push`'s URL and shared secret per environment", which names only that function. The unit is compliant.
- **Unit C (epic 1):** owns `deploy.yml`. It is told to write settings for `send-push`, which does not exist until epic 6, and nothing for `sweep-storage`.
- **Collision:**
  - The result is two service-only secret tables with different shapes, and two CI steps written into epic 1's file by two epics.
  - `net.http_post` only queues the request, so a cron job that calls `sweep-storage` succeeds in `cron.job_run_details` whatever the function returns. A wrong secret or URL means storage is never swept, and AD-21's keep-alive, which watches only `cron.job_run_details` and `internal.job_failures`, stays green. That is the "silent failures" AD-21 says it prevents, on the 1 GB Free storage limit.
- **Fix: tighten AD-21 and AD-5.**
  - "Epic 2 creates `internal.edge_function_settings (name, url, secret)` with the first pg_net-called function (`sweep-storage`). Every trigger- or cron-called function reads its row, and CI writes one row per such function per environment."
  - "The keep-alive also fails on new non-2xx rows in `net._http_response` for those URLs." UNVERIFIED: whether `net._http_response` keeps rows long enough for a twice-daily check.

### U6. The AD-11 ownership split leaves the DND write path, the heartbeat caller and "online" without a single owner

- **Unit A (epic 2):** owns `profiles` and "its column grants", plus `profiles.dnd`. AD-3 grants "only what its policies need", and epic 2 has no DND switch, so it grants `UPDATE (display_name, avatar_path)` only. The unit is compliant.
- **Unit B (epic 5):** owns "the do-not-disturb switch". AD-11 says `profiles.dnd` "is user-settable". Epic 5 cannot change epic 2's grants (the owner writes the grants and fixture entries), so it adds `public.set_dnd(bool)`, which AD-4 allows. If a different epic 2 author had granted `UPDATE (dnd)`, there would now be two write paths.
- **Unit C (epic 12):** counts "online" as `last_seen_at > now() - interval '2 minutes'` in SQL. Epic 5 computes dot colours in TypeScript. If one counts a DND user as online and the other does not, or the threshold drifts, the admin's count disagrees with the dots.
- **Heartbeat:** the spine gives epic 2 `touch_presence` but does not say which epic's client code calls it every 60 seconds. If epic 5 only reads and epic 2 only defines, everyone shows red. If both call it, the heartbeat runs twice.
- **Fix: tighten AD-11.**
  - "Epic 2 grants `UPDATE (dnd)` on the caller's own row and ships the app-wide heartbeat that calls `touch_presence`. Epic 5 builds only the switch UI over that grant."
  - "`app.presence(u)` (epic 2) returns `green`, `yellow` or `red`, and the dots and the admin's online count both read it."

## Low

### U7. AD-16: whether the admin needs a removal request is ambiguous

"The admin deletes anyone but themselves" conflicts with "A teacher of that student, or the admin, can then delete the account, and never without an open request". Epic 12 builds both paths and must guess whether the admin needs a request to delete a student. **Fix:** "never without an open request" applies to teachers only; the admin needs none.

---

## Checked and holding

- **pg_cron and pg_net in epic 1 (AD-21):** this removes the "two epics enable an extension" problem and the 4/5 ordering problem. Copying My-Love's `create extension if not exists pg_net` is harmless.
- **Hook assertion moved to epic 2 (AD-21):** the deploy order is migrate, then config push, then health check, and the hook function exists before it is registered. The seam matches the ticket text of epics 1 and 2.
- **Admin writes (AD-8):** `enroll_student_as` checking `app.teaches or app.is_admin`, and `app.class_open`, keeps one write path for the admin, and archived classes still refuse. Reveal and reset "for `app.teaches_student` or the admin" are consistent with R26.
- **Ordering:** epic 12 now depends on epics 2, 3 and 5 in tickets.toml, so the admin roster functions exist before the screen.

## Summary of AD changes proposed

| Hole | AD | Change |
| --- | --- | --- |
| U1 | AD-22, AD-16, AD-9 | no foreign keys on `audit_events`, which is never deleted; cascade exception; self-deletion goes through `delete_class` |
| U2 | AD-22, AD-8 | Auth-API actions audited by `auth.users` triggers; Vault replaced in the ticket-consuming trigger |
| U3 | AD-9, AD-8, epic map | admin reads classes, rosters and status; decide whether the admin can remove a student |
| U4 | AD-16 | deletion root is `auth.users` delete; side effects are owner triggers; the test file is named |
| U5 | AD-21, AD-5 | one `internal.edge_function_settings` (epic 2); keep-alive watches pg_net responses |
| U6 | AD-11 | epic 2 grants `dnd` and owns the heartbeat; `app.presence` |
| U7 | AD-16 | the open-request rule applies to teachers only |
