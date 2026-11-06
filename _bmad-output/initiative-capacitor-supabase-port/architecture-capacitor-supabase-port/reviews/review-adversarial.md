---
review: adversarial
target: architecture-capacitor-supabase-port.md (+ epic-map, tickets/tickets.toml)
lens: two units that each obey every AD to the letter yet build incompatibly
date: 2026-11-05
---

# Adversarial review — Capacitor Supabase Port spine

## Verdict

**Not ready to bind stories.** The paradigm holds up: one enforcer, shared `app.*` checks, single writers. But the ADs govern only *tables* and only *caller-relative* checks. That leaves five unguarded surfaces where two compliant units can open a hole between them: function EXECUTE grants, views, column-level reads, storage path scope per bucket, and actor identity in scheduled or service-role code. On top of that, three ownership and ordering contradictions in the epic map force one epic to rewrite another's object or call something that does not exist yet.

The holes below are listed by severity. Each has the two units, what each builds while staying compliant, how they collide, and the AD text that closes the hole.

Sources read in full: the spine (295 lines), the epic map (59), tickets.toml (104) and .memlog.md (80). Supabase behaviour that I have not checked against current docs is marked UNVERIFIED.

---

## Critical

### H1 — Every `security definer` function is a public RPC endpoint (no AD covers EXECUTE grants)

- **Unit A (epic 6, notifications):** builds `public.notify(recipients uuid[], kind, ref)` as the only inbox writer (AD-14). It is `security definer` so that emitters can call it, and it does no caller check because callers are trusted SQL.
- **Unit B (epic 4, publish assignment story):** under AD-4 the teacher publishes through `publish_assignment()`, which calls `notify`. This is compliant.
- **Collision:** Postgres grants EXECUTE on new functions to PUBLIC, and Supabase's default privileges also grant EXECUTE to `anon` and `authenticated` on `public` (UNVERIFIED for the CLI version pinned here, but this is the long-standing default). AD-3 only revokes *table* grants, and its pgTAP catalog test checks only tables. So any signed-in student, or `anon`, can call `rpc('notify', {recipients: <every user>, kind: 'grade_posted', ...})`. That spams every inbox and every phone, and ignores the directory and DND. The same reasoning applies to:
  - The pg_cron workers (`fire_scheduled_messages`, `fire_due_reminders`), which anyone can trigger.
  - The `before_user_created` hook function, if it sits in `public`. Anyone can then call it with a crafted payload and learn whether an email is on `staff_invites` or is the bootstrap admin email. That is an enumeration oracle for the admin's address.
- **Fix — new AD-3b "Function grants":** every migration that creates a function first runs `revoke execute ... from public, anon, authenticated`. It then grants EXECUTE to `authenticated` only on functions listed as client-callable in the owning epic. Internal functions live in a non-exposed schema (`app` for predicates, a new `internal` schema for `notify`, cron workers and trigger functions). The auth hook lives in `internal` and has EXECUTE granted only to `supabase_auth_admin`. The AD-3 catalog test is extended so it fails when any function in an exposed schema is executable by `anon`, or by `authenticated` without being on an allowlist.

### H2 — Scheduled work has no actor: `send_message` cannot be both "the same function" and safe

- **Unit A (epic 5, send story):** `send_message(chat_id, body, attachment_path)` derives the sender from `auth.uid()` and checks `app.in_chat(chat_id)`. This follows AD-2, AD-4 and AD-10.
- **Unit B (epic 5, scheduled-messages story):** AD-15 says the pg_cron job "calls the same function". Under pg_cron, `auth.uid()` is NULL. So either:
  - every scheduled message is refused, or
  - the developer adds a `p_sender` parameter so cron can name the author. That parameter is now client-callable (see H1), and any member can post as the teacher.
- The same collision hits a due-reminder job if its recipient filter reuses `app.enrolled()`, which is caller-relative.
- **Second collision:** AD-4 says "one transaction" and AD-15 says "cron calls `send_message`". A job that loops over 50 due rows and gets one `42501` refusal (for example an archived class) rolls back all 50 and retries forever.
- **Fix — tighten AD-15:** every person-facing write function has an internal twin, `internal.<fn>_as(actor uuid, ...)`. The twin holds all the checks and is called with an explicit actor. The client-callable `public.<fn>(...)` is a one-line wrapper that passes `auth.uid()`, and only the wrapper is granted to `authenticated`. Cron jobs call `_as()` with the stored author id. Each due row runs in its own subtransaction (`begin ... exception ... end` per row), and a refusal marks that row `failed` with its error key and is never retried. The `app.*` predicates also get actor-explicit forms (see H11).

---

## High

### H3 — Views bypass RLS; dashboards and analytics read everything

- **Unit A (epic 4):** `grades` has RLS so that a student sees only their own rows (AD-1). Compliant.
- **Unit B (epic 11):** builds `student_dashboard` and `teacher_recent_activity` as "read-only views over source tables", exactly as the conventions say. Epic 4's "grade analytics views" and epic 8's "totals views" are built the same way.
- **Collision:** a Postgres view runs with its *owner's* privileges unless it is created `with (security_invoker = true)`. The owner is `postgres`, so RLS is skipped and a student selecting from the view gets every student's grades and points. AD-1 and the AD-3 catalog test only look at tables, so CI stays green.
- **Secondary:** epic 4 owns the GPA formula (Deferred), but epic 11 shows GPA. Nothing stops epic 11 from computing it a second time.
- **Fix — extend AD-1/AD-3:** every view in an exposed schema is `security_invoker = true`, and the catalog test fails on any view that is not. Aggregates that must cross RLS (class averages) are `security definer` functions that check through `app.*`, never definer views. Add a rule that a derived figure (GPA, letter grade) has one SQL function owned by epic 4 and epic 11 calls it.

### H4 — Row-level `profiles` SELECT exposes email (and role, dnd) to anyone the directory admits

- **Unit A (epic 2):** `profiles` SELECT policy `using (app.can_see_user(id))`. AD-12 calls the directory "built on `app.can_see_user`", so this is compliant. The D20 email rule is coded in the directory function or view.
- **Unit B (epic 5, member list story):** the story calls `from('profiles').select('*').in('id', memberIds)`, which RLS allows row by row. It receives every classmate's `email`, which breaks D20 and AD-12's "classmates seeing each other's emails" prevention.
- **Collision:** RLS filters rows, not columns, and AD-3 makes only UPDATE column-scoped.
- **Fix — tighten AD-12:** `authenticated` gets column-level SELECT on `profiles` limited to the directory-safe columns (`id, display_name, avatar_path, last_seen_at, dnd, role`). `email` gets no SELECT grant. It is either moved to a separate table or readable only through `app.visible_email(user_id)` / `directory_email(user_id)`, which applies D20. A pgTAP test asserts that `authenticated` cannot select `profiles.email`.

### H5 — AD-13 lets each epic pick a storage scope; the natural pick leaks submissions

- **Unit A (epic 4, submission upload):** paths `submission-files/<class_id>/<uuid>.pdf`. The rule says "scope is the user, class or chat", and the read policy `app.teaches(scope) or app.enrolled(scope)` matches. Compliant.
- **Unit B (epic 4, teacher grading view):** reads submissions by path. Compliant.
- **Collision 1:** every enrolled student can list `<class_id>/` and mint signed URLs for every classmate's submission. That is a student reading another student's data.
- **Collision 2:** `assignment-files/<class_id>/` is readable by every enrolled student, including files on *draft* (unpublished) assignments. The storage policy can only call `app.*` on the path, so it cannot see `published_at`.
- **Collision 3:** if epic 4 copies epic 2's avatar pattern (owner may update and delete own objects), the student overwrites or deletes the file after submitting. That breaks "a submission is frozen at submit" (memlog).
- **Collision 4:** the database "stores only the path". Nothing ties a row's path to that row's scope, so a submission row can name another user's object. That is harmless while the client mints URLs under its own RLS. It becomes a read-anything primitive the day any function mints URLs with the service role.
- **Fix — rewrite AD-13 as a per-bucket table owned by the spine:**

  | Bucket | Path | Insert | Read | Update/Delete |
  | --- | --- | --- | --- | --- |
  | avatars | `<user_id>/<uuid>` | self | `app.can_see_user(user_id)` | self |
  | assignment-files | `<class_id>/<assignment_id>/<uuid>` | `app.teaches(class)` and `app.class_open` | teacher; student only if `app.assignment_visible(assignment_id)` | teacher, none after publish |
  | submission-files | `<class_id>/<student_id>/<uuid>` | `student_id = auth.uid()` and `app.enrolled` and `app.class_open` | `app.teaches(class)` or `student_id = auth.uid()` | none after submit |
  | chat-files | `<chat_id>/<uuid>` | `app.in_chat` and role in (teacher, admin) | `app.in_chat` | none |

  Every row that stores a path has a CHECK or trigger asserting that the path's prefix equals the row's own scope ids. Signed URLs are minted only under the caller's JWT, never with the service role.

### H6 — `send-push` re-implements chat membership in TypeScript with the service role

- **Unit A (epic 5):** `app.in_chat(chat_id)` derives class chat members from enrollments, drops removed students from groups, and freezes one-to-one chats (AD-10).
- **Unit B (epic 6):** AD-14 tells `send-push` to "read the source row with the service role" and fan out. For a `messages` row there is no `recipients` column. So the Deno handler queries `chat_members` and `enrollments` itself and bypasses RLS.
- **Collision:** a second definition of "in chat" that pgTAP cannot see, which is exactly what AD-2 and AD-5 forbid, and nothing in the ADs stops it. If it drifts (it forgets that removed students lose groups), lock-screen pushes carry message text to people who can no longer read the chat.
- **Fix — tighten AD-14:** recipients are computed only in SQL. Epic 5 owns `internal.message_recipients(message_id) returns setof uuid`, epic 6 owns `internal.push_targets(kind, ref) returns (user_id, device rows)`, and the DND filter lives in that SQL. `send-push` calls one RPC and does transport only. A `deno test` asserts that the handler makes no table queries apart from that RPC and the gone-token delete.

### H7 — Two profile creators, an unowned staging table, and invite pre-emption through identity linking

- **Unit A (epic 2):** the `before_user_created` hook "creates the profile with the listed role in the same flow" (AD-7).
- **Unit B (epic 3):** `add-students` "stages that email", calls the admin API, then writes the student profile (AD-8).
- **Collision 1 — creator:** a *before* hook runs before the `auth.users` row exists, so a `profiles.id → auth.users` FK insert from inside it fails. The FK detail is UNVERIFIED, but it is a structural consequence of "before". The real creator must be an AFTER INSERT trigger on `auth.users`. If epic 2 writes that trigger for staff only, it either raises or defaults the role for `add-students`' user. If epic 3 also inserts a profile, the two collide with `23505`. AD-6 says "written only when the profile is created (AD-7, AD-8)", which names two writers.
- **Collision 2 — staging owner:** the hook is epic 2's object. The staging table it must read appears in neither epic's "Owns" column, and epic 3's "Uses" says "hook staging (epic 2)". So epic 2 must create a table for a feature it does not build, or epic 3 must rewrite epic 2's hook. "In the same request" is undefined across an edge function that makes separate SQL and Auth-API calls.
- **Collision 3 — pre-emption (role fixed to the wrong value):** the admin lists `newteacher@school` in `staff_invites`, and the teacher has not signed in yet. Teacher B then adds that email in `add-students`. AD-8 refuses only "an email owned by a teacher or admin", meaning an existing profile, so a student account is created and teacher B holds its password. When the new teacher first signs in with Google, Supabase's automatic identity linking (on by default; "manual linking off" does not disable it; UNVERIFIED for this CLI version) attaches the Google identity to the existing verified-email user. No user is created, the hook never fires, and the invited teacher is permanently a `student` (AD-6 forbids changing the role), on an account another teacher can reveal and reset.
- **Fix — rewrite AD-6/7/8 as one creation rule:**
  - Epic 2 creates `internal.pending_accounts (email, role, display_name, staged_by, class_id, expires_at)` empty.
  - Epic 2 owns the hook and one `internal.on_auth_user_created` AFTER INSERT trigger. That trigger is the only `INSERT` into `profiles`, taking the role from `staff_invites`, the bootstrap email or `pending_accounts`, and it consumes the pending row.
  - `add-students` refuses any email on `staff_invites` or equal to the bootstrap email.
  - Inserting into `staff_invites` refuses an email that already has a student profile, with error `email_is_student`.
  - The epic 2 spike also checks automatic identity linking for an admin-created, email-confirmed user.

### H8 — Deletion is incomplete across epics, and a deleted teacher walks back in

- **Unit A (epic 12):** `delete-account` removes "the person's Storage objects", deletes the Auth user, and rows cascade from `profiles` (AD-16).
- **Unit B (epic 2):** `staff_invites` is an email list with no FK to `profiles` (AD-7).
- **Collision 1:** the admin deletes a teacher (or the teacher deletes themselves). Their email is still on `staff_invites`, so the next Google sign-in passes the hook and creates a fresh teacher account. Admin deletion cannot remove anyone.
- **Collision 2:** epic 3's Vault secrets (AD-8) are not rows in `public` and do not cascade, so the deleted student's password stays decryptable.
- **Collision 3:** "the person's objects" is ambiguous when paths are scoped by class or chat. A teacher's deleted classes leave students' submission files under `submission-files/<class_id>/`, owned by the students, as orphans counting against the 1 GB Free storage. A deleted teacher's chat files are removed while AD-16 keeps "chat messages others rely on" pointing at those paths, so the remaining messages show broken attachments.
- **Collision 4 (ordering):** epic 12 depends only on 2 and 5 in tickets.toml, so it can ship before epics 4, 7, 8, 9 and 10. Its tests "cover every table that exists when it ships". The later buckets, tables and Vault secrets never join its sweep or its warning list.
- **Collision 5:** AD-16 lets "a teacher of that student" complete a deletion but never requires a pending request. Teacher A can delete any student they teach, wiping that student's work in teacher B's classes.
- **Fix — tighten AD-16:**
  1. `delete-account` deletes or marks consumed the person's `staff_invites` row and their Vault secret in the same flow.
  2. A teacher may delete a student only when an open removal request from that student exists, error `no_removal_request`.
  3. The storage sweep is driven by one SQL function `internal.objects_to_delete(user_id)`. Each bucket-owning epic adds its own branch, covering class-scoped prefixes for teacher deletes. Chat files are kept when their message is kept.
  4. Each epic that adds a `profiles` FK, a bucket or a secret adds its case to the epic 12 deletion test file. Alternatively, move epic 12 after 4, 7, 8, 9 and 10.
  5. Define "others rely on" per table in the spine (messages, replies, threads: SET NULL; everything else: CASCADE) rather than leaving it to each epic. Calendar events with other participants and `support_reports` are currently undecided.

---

## Medium

### H9 — `app.can_see_user` is owned by epic 2 but needs epic 3's tables, and it contradicts AD-10's chat pairings

- **Unit A (epic 2):** owns `app.can_see_user` ("people who share a class, a student's teachers, everyone for the admin"). Epic 2 runs before `enrollments` exists, so it cannot write or test the class clause. Epic 3 must `create or replace` epic 2's function, which leaves the function with two owners.
- **Unit B (epic 5):** builds a group whose members are the teacher's students from *different* classes (allowed by AD-10), and an admin–teacher one-to-one chat (allowed by AD-10).
- **Collision:** students in a cross-class group do not share a class, so `can_see_user` hides their names and avatars from each other. A teacher is not in "everyone for the admin" from the teacher's side, so the teacher cannot see the admin's name or presence in their own one-to-one chat. AD-12 also gives students the admin's *email* (D20) while `can_see_user` hides the admin's *name*. Epic 10 (after epic 2 only) builds D20 email and has the same dependency on epic 3.
- **Fix:** move `app.can_see_user` and the D20 email function to epic 3, or have epic 2 ship an admin-only stub that epic 3 explicitly owns extending. Add a spine rule: "a predicate that reads a table is owned by the epic that owns the table". Redefine `can_see_user` as the union of: shares a class; teacher–student pairing; co-members of a chat; the admin (everyone sees the admin, the admin sees everyone).

### H10 — Class-chat unread counts need per-member rows that AD-9 forbids

- **Unit A (epic 5, class chat story):** class members are derived from enrollments with no `chat_members` rows (AD-9 "nothing copies it", AD-10).
- **Unit B (epic 5, unread story):** "unread counts come from each member's `last_read_at`", which by the conventions lives on the member row.
- **Collision:** class chats have no member row to hold `last_read_at`. Unit B either breaks for class chats or inserts `chat_members` rows for class chats, copying the enrollment list against AD-9.
- **Fix — tighten AD-10:** read markers live in `chat_reads (chat_id, user_id, last_read_at)`, which is separate from membership, written only by `mark_chat_read(chat_id)` (which checks `app.in_chat`). `chat_members` holds only group and one-to-one membership.

### H11 — Removal from a class does not reach group memberships, and caller-relative `app.*` cannot express the checks

- **Unit A (epic 3):** `remove_student(class_id, student_id)` deletes the enrollment (AD-4, AD-9). It ships before chat exists.
- **Unit B (epic 5):** groups are `chat_members` rows (AD-10), and "removed from a class loses that teacher's groups".
- **Collision:** epic 3 cannot delete rows in a table that does not exist yet, and epic 5 has no instruction to react. A removed student keeps the group because the row is still there. Separately, every listed predicate is relative to the caller (`app.teaches_student(student_id)` means "does *auth.uid()* teach them"). Several checks need two named people:
  - `send_message` by a student must ask "does the *other* member teach me?"
  - group validity asks "does the group's *creator* still teach this member?"
  - `delete-account` asks "who are this student's teachers?"
  - the due-reminder job runs with no caller at all.

  Each epic will hand-join `classes` and `enrollments` to get these, which is what AD-2 forbids.
- **Fix:** add actor-explicit predicates `app.teaches_student(teacher_id, student_id)` and `app.enrolled(student_id, class_id)`, with the one-argument forms wrapping them with `auth.uid()`. `app.in_chat` for groups requires both the row and `app.teaches_student(chat.created_by, member)`, so removal takes effect without any cleanup write. Optionally, epic 5 adds an `enrollments` AFTER DELETE trigger to prune stale group rows.

### H12 — Ordering: epics 3 and 4 call `notify` before epic 6 exists, and the kind list is closed

- **Unit A (epic 4, after epic 3 only in tickets.toml):** emits `assignment_published`, `grade_posted` and `due_reminder` through `notify` (epic map "Uses").
- **Unit B (epic 6, after epic 5):** creates `notify` and `notifications`.
- **Collision:** epics 4 and 5 can run in parallel after epic 3, so epic 4's stories can be built before `notify` exists. Epic 3's "ask my teacher to remove my account" request "goes to their teachers' inboxes and the admin's" (memlog). Epic 3 runs before epic 6, and AD-14's closed kind list has no `removal_request`, while "a new kind is added in epic-notifications' code".
- **Fix:** either move `notifications` and `notify` (inbox only, no push) into epic 3, or add `after = epic 6` to epic 4's notification stories and give epic 3's request an explicit "inbox delivery lands in epic 6" seam. Add `removal_request` to AD-14's kinds now. Restate in AD-14 that the kind enum is the contract and is owned by epic 6, but is seeded in the spine.

### H13 — Realtime: members can forge live "messages", and two epics define `user:` events

- **Unit A (epic 5):** the `realtime.messages` INSERT policy is `app.in_chat(topic chat id)`, needed so that clients can broadcast typing (AD-11, AD-19).
- **Unit B (epic 5, Deferred choice "client-side broadcast of new messages"):** the sender's client broadcasts `{event: 'message', sender_id, body}` after `send_message`.
- **Collision:** the same INSERT policy lets any member broadcast a fake `message` event with the teacher's `sender_id`. zod validates shape, not authenticity, so other clients render text that was never stored. Separately, epic 6's web pop-up (R17) needs per-user events, but the epic map gives `user:` topics to epic 5 and lists no emitter or event schema for epic 6.
- **Also:** Realtime authorization is evaluated at join time and cached, reportedly until reconnect or token refresh (UNVERIFIED). A removed student may keep receiving `chat:` broadcasts for up to the JWT lifetime.
- **Fix — tighten AD-19:** clients may broadcast only `typing`, and the INSERT policy checks the event name (if `realtime.messages` exposes it; UNVERIFIED) or typing moves to Presence. Message and notification events are sent only by server triggers (`realtime.send`) and carry ids only, and the client refetches rows through RLS. `user:<uuid>` read access is `auth.uid()` only. Its event union lives in one `app/src/api/realtime.ts` with one owner listed in the epic map (epic 6 emitting, epic 5 defining the topic).

### H14 — `app.*` semantics under archive and removal are unspecified

- **Unit A (epic 4):** student grade read policy `student_id = auth.uid() and app.enrolled(class_id)`, which is what AD-9 needs ("removal ends access to own grades").
- **Unit B (epic 3):** defines `app.enrolled` as "enrollment row exists *and class not archived*", a natural reading of "active student".
- **Collision:** with that definition, archived grades become invisible, which breaks R21. If epic 3 picks the opposite definition, epic 5's one-to-one pairing ("a student enrolled in one of that teacher's classes") stays live through archived classes, which AD-10 does not decide either way.
- **Fix:** add a truth table to AD-2 giving, for each predicate, whether it is true for an archived class and after removal. Example: `enrolled` = row exists, regardless of archive; `class_open` = not archived; pairing = enrolled in a *non-archived* class of that teacher, or state otherwise.

### H15 — `add-students` cannot meet AD-4, and a second teacher's CSV can overwrite a student's name

- **Unit A (epic 3):** `add-students` loops over up to 1000 rows, making admin-API `createUser` calls and writing enrollments with the service role (AD-5, AD-8).
- **Unit B (AD-4):** "does all of its work in one transaction".
- **Collision:** Auth-API creations commit one by one, so a failure at row 400 leaves 399 accounts and 399 enrollments, and the printable sheet has nothing defined to show. The service-role enrollment insert also skips `app.class_open` unless the TypeScript re-checks it, which is a race with an archive happening at the same moment. Teacher B's CSV gives an existing student a different `display_name`. AD-8 says the password is kept and says nothing about the name. Meanwhile epic 2 lets the student edit their own name (R3), so `profiles.display_name` has two writers.
- **Fix:** AD-8 states that `add-students` is per-row idempotent (keyed by `pending_accounts`), returns a per-row result, and the sheet lists only rows that succeeded. Enrollment is written by `internal.enroll_student_as(actor, class_id, student_id)`, which checks `teaches` and `class_open`. For an existing student, `display_name` is never overwritten. Name a single owner for it: the student after creation, or the teacher only.

---

## Low

### H16 — Calendar participants are unbounded and bypass the directory

Epic 9 (after epic 2 only) lets a creator write `calendar_event_participants`. This is compliant: it is the creator's own event, and AD-1 and AD-3 are its only governing ADs. Any student can add any user id, and every participant then sees the other participants' names, which goes around AD-12. **Fix:** participants are added only through `add_event_participant`, which requires `app.can_see_user(creator, participant)`. Participant names are rendered through the directory.

### H17 — Per-class companion rows created by later epics

Classes created in epic 3 need a class chat (epic 5, `classes ||--o| chats`) and an Announcements board (epic 7). Each epic will pick a creation path on its own: a trigger on `classes`, lazy creation in `send_message`, or a backfill. A lazy path and a trigger together produce two class chats. **Fix:** a spine rule that a per-class companion row is created by an AFTER INSERT trigger on `classes` in the owning epic's migration, plus a backfill in the same migration, and has a unique `(class_id)` constraint.

---

## Set aside (settled in .memlog.md, not counted)

- **Taking over another teacher's student:** any teacher can attach an existing student by email and then Show or Reset their password. This follows from the user's decisions ("an existing student is enrolled", "Show password shows the existing one", "every teacher of a student can see that student's password"). It is noted only so the user knows that attaching gives full account access. An optional reveal/reset audit log would be in scope for epic 3 if the user wants accountability.
- **Students changing their own password:** a student can change it through `auth.updateUser`, which makes the Vault copy stale. The memlog records this as accepted, with teacher Reset as the remedy. The spine does not say so, so a line in AD-8 would stop epic 2 from trying to block it differently.
- **Stale epic descriptions:** tickets.toml descriptions for epics 2, 3 and 13 still describe invite codes and class-code name matching. The spine's warning already requires Sofia to update them. Until then, any story refined from those descriptions builds the superseded gate.

## Ordering contradictions found (summary)

| From | Needs | Problem |
| --- | --- | --- |
| Epic 2 `can_see_user`, directory email | `enrollments` (epic 3) | Owner runs before the table exists (H9) |
| Epic 10 Gmail compose email | D20 teacher↔student email (epic 3) | Epic 10 is only after epic 2 (H9) |
| Epic 2 hook | Staging table | Not owned by any epic (H7) |
| Epic 3 removal request to inboxes | `notify` (epic 6) | Epic 3 runs before epic 6, and the kind is missing (H12) |
| Epic 4 emitters | `notify` (epic 6) | Epic 4 is not ordered after epic 6 (H12) |
| Epic 3 `remove_student` | Group `chat_members` (epic 5) | Cleanup has no owner (H11) |
| Epic 12 `delete-account` | Buckets, tables and secrets from epics 4, 7, 8, 9, 10 | Can ship first; its sweep and tests miss them (H8) |
