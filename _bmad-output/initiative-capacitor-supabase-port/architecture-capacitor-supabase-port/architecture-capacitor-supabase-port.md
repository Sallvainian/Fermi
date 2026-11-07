---
name: 'Capacitor Supabase Port'
type: architecture-spine
purpose: build-substrate
altitude: initiative
paradigm: 'policy-in-the-database client-server: Postgres row-level security and SQL functions are the only enforcer; the web app is a thin client; edge functions are adapters to outside services'
scope: 'The new Fermi: app/ (the website and the Home Screen web app), supabase/ (schema, policies, functions, tests), CI, hosting, the update check and operations, across the 13 epics in tickets/tickets.toml'
status: final
created: '2026-11-05'
updated: '2026-11-07'
binds: [R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22, R23, R24, R25, R26, R27, R28, R29, R30, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, K12, K13, K14, K16, K17, K18, epic-platform-baseline, epic-invite-sign-in, epic-classes-rosters, epic-assignments-grades, epic-chat, epic-notifications, epic-boards-announcements, epic-behavior-points, epic-calendar, epic-contact, epic-dashboards, epic-admin-console, epic-app-store-release]
sources:
  - _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md
  - _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md
  - _bmad-output/initiative-capacitor-supabase-port/brief-port-goals.md
  - _bmad-output/initiative-capacitor-supabase-port/tickets/tickets.toml
  - _bmad-output/initiative-capacitor-supabase-port/tickets/epic-platform-baseline/tickets/tickets.toml
  - /Users/sallvain/Projects/My-Love/supabase/
  - /Users/sallvain/Projects/My-Love/wrangler.jsonc
---

# Architecture Spine — Capacitor Supabase Port

## Design Paradigm

**Policy-in-the-database client-server.** Supabase Postgres is the application server: every rule about who may read or change what lives in row-level security policies and SQL functions. The web app, in a browser tab or saved to the Home Screen, is a thin client; hiding something in the UI is convenience, never protection. Edge functions are ports to what Postgres cannot reach (web push, the Auth admin API, the Storage API).

```mermaid
flowchart TD
  UI[app/src features] --> ST[hooks and stores]
  ST --> API[app/src/api services]
  API --> SB[supabase-js]
  SB --> RPC[public RPC wrappers]
  SB --> TBL[tables and views under RLS]
  SB --> EF[edge functions]
  SB --> RT[Realtime private channels]
  SB --> STO[Storage private buckets]
  RPC --> INT[schema internal: _as functions, notify, workers]
  TBL --> APP[schema app: shared checks]
  INT --> APP
  STO --> APP
  RT --> APP
  EF --> INT
  EF --> EXT[web push, Auth admin, Storage API]
  CRON[pg_cron] --> INT
  TRG[triggers via pg_net] --> EF
```

Arrows are the only allowed dependency directions. Only `app/src/api/` imports the Supabase client. Schemas `app` and `internal` are not exposed by the Data API. `app/` has no native shell and no `@capacitor/*` or other native-shell package (K1).

## Invariants & Rules

### AD-1 — The database is the only enforcer [ADOPTED]

- **Binds:** all epics; K4, K5
- **Prevents:** access checked in the app or an edge function while another path trusts the database, which is how Firebase's holes formed (parity inventory, defects table)
- **Rule:** every read and write a user can make is decided by an RLS policy, a column grant or a function that checks before it acts. Every table in `public` has RLS on in the migration that creates it. Client-side checks only shape the UI. Recipients, membership and visibility are computed in SQL only; edge functions never re-derive them in TypeScript.

### AD-2 — Each relationship check is written once, in schema `app` [ADOPTED]

- **Binds:** all epics; owners in the Epic Map
- **Prevents:** two epics defining "enrolled", "teaches" or "in chat" differently; recursive policies; hand-joined membership in functions
- **Rule:** relationships are `stable security definer` functions with `set search_path = ''` in schema `app`. Each takes explicit people (`app.teaches_student(teacher_id, student_id)`), with a one-argument form that passes `auth.uid()`. Policies, storage policies, Realtime policies and functions call these and never re-join membership tables. A predicate is owned by the epic that owns the table it reads. Their meaning is fixed here:

| Predicate | True when | Archived class | After removal |
| --- | --- | --- | --- |
| `app.my_role()` | the caller's `profiles.role` | n/a | n/a |
| `app.is_admin(u)` | `u` has role `admin` | n/a | n/a |
| `app.teaches(t, class)` | `t` owns the class | true | n/a |
| `app.enrolled(s, class)` | an enrollment row exists | true | false |
| `app.class_open(class)` | the class is not archived | false | n/a |
| `app.teaches_student(t, s)` | `s` is enrolled in a non-archived class `t` owns | false | false |
| `app.manages_class(u, class)` | `app.teaches(u, class)` or `app.is_admin(u)` | true | n/a |
| `app.manages_student(u, s)` | `app.teaches_student(u, s)` or `app.is_admin(u)` | false for the teacher | false for the teacher |
| `app.shares_class(a, b)` | both are in one non-archived class as teacher or student | false | false |
| `app.in_chat(u, chat)` | AD-10's membership rule | class chat: true, read-only | false |
| `app.can_see_user(a, b)` | `a = b`, either is admin, `app.teaches_student` either way, `app.shares_class`, or co-members of a chat | per clauses | per clauses |

`app.can_see_user` is created by epic-invite-sign-in as this fixed union. Each clause is its own function, which starts as `false` and is replaced only by the epic that owns its table (epic-classes-rosters for class clauses, epic-chat for chat co-membership).

### AD-3 — Locked by default: tables, columns, functions and views [ADOPTED]

- **Binds:** all epics; K4, K5, K13
- **Prevents:** broad default grants; a writable `role`; any user calling an internal function (Postgres grants EXECUTE to PUBLIC by default); a view that skips RLS
- **Rule:** `anon` gets nothing.
  - **Tables:** each table's creating migration revokes all from `anon` and `authenticated`, then grants only what its policies need. `SELECT` and `UPDATE` are column-scoped where a row mixes public and private columns.
  - **Functions:** each function's migration revokes `EXECUTE` from `public`, `anon` and `authenticated`. Only client-callable RPC wrappers in `public` are granted back to `authenticated`. Internal functions, cron workers, trigger functions and the auth hook live in schema `internal`; the hook's `EXECUTE` goes only to `supabase_auth_admin`.
  - **Views:** every view in `public` is `with (security_invoker = true)`. A figure that must span students (a class average) is a checking function, never a definer view.
  - **Test:** a checked-in privilege fixture lists the expected grants for every table, column, function and view. A pgTAP catalog test compares the catalog against it and fails on any object that is missing or differs.

### AD-4 — Changes with rules attached go through one function each [ADOPTED]

- **Binds:** all epics
- **Prevents:** two write paths into one table with different checks; half-applied changes; a scheduler impersonating users
- **Rule:**
  - **Single writer:** when a write touches several rows, must hold an invariant, or is shared by a person and a scheduler, exactly one function performs it. The client gets no direct `INSERT`, `UPDATE` or `DELETE` on the tables that function writes.
  - **Checks:** they live in `internal.<verb_noun>_as(actor uuid, …)`. The client calls `public.<verb_noun>(…)`, a one-line wrapper passing `auth.uid()`. Schedulers and triggers call the `_as` form with the stored actor.
  - **Atomicity and errors:** each call is one transaction and raises a coded error (AD-17) on refusal.
  - **Direct writes:** allowed only on a user's own row with no cross-row rule, such as a calendar event's creator editing its title.

### AD-5 — Edge functions only for the outside world [ADOPTED]

- **Binds:** all epics
- **Prevents:** checks moving into TypeScript, where pgTAP cannot see them; an epic building its API as edge functions
- **Rule:** the edge functions are `send-push` (web push), `add-students` and `reset-student-password` (Auth admin API), `delete-account` (Auth admin API) and `sweep-storage` (Storage API). A new one needs an outside service no existing one reaches.
  - **User-called functions:** `verify_jwt = true`, and the function asks SQL (`internal.*_as`) before acting.
  - **Trigger- or cron-called functions:** `verify_jwt = false`, and the function checks a shared secret. Every such function's URL and secret live in one service-only table, `internal.edge_function_settings (name, url, secret)`, created by epic-invite-sign-in with `sweep-storage`; CI writes one row per function per environment.
  - **Shape:** each function is split into `handler.ts` (pure, tested with `deno test`) and `index.ts` (wiring). A handler queries only the RPCs it names.

### AD-6 — One role store; one profile creator [ADOPTED]

- **Binds:** R1, R2, R3, R15, K3, K4; epic-invite-sign-in owns
- **Prevents:** the role in two places; a user raising their own role; two code paths creating profiles
- **Rule:** `profiles.role` (`admin`, `teacher`, `student`) is the only role and has no update grant.
  - **Creator:** one `AFTER INSERT ON auth.users` trigger, `internal.on_auth_user_created`, is the only writer of new `profiles` rows. It sets the role from `staff_invites` or the bootstrap admin email for a Google user, and from `app_metadata.fermi_role = 'student'` for a user `add-students` created through the admin API. It reads `app_metadata` once, at creation; no authorization reads claims or metadata afterwards.
  - **Identity:** authorization keys on the user id. `profiles.email` is copied at creation, is never updatable, and is readable only through `app.visible_email` (AD-12).
  - **Editable fields:** `display_name` is set at creation and afterwards only by its owner (R3).
  - **Any provider, same role:** a student who later signs in with Google under the same email is linked to their student account by Supabase. The role still comes from `profiles`, so the app routes on the role, never on the button.

### AD-7 — Staff are admitted by the admin's email list [ADOPTED]

- **Binds:** R1, R2, R15, R25, K3; epic-invite-sign-in owns
- **Prevents:** an uninvited Google account getting in; anyone self-registering with a password; a client-only password page
- **Rule:**
  - **The list:** the admin keeps `staff_invites` (email lowercased and trimmed, role `teacher`). Adding an email that already has a student profile is refused (`email_is_student`).
  - **The hook:** `internal.before_user_created` admits a Google sign-up only when its email is on `staff_invites` or equals the bootstrap admin email. It reads both through one `postgres`-owned helper, because `supabase_auth_admin` has no Vault access and does not bypass RLS. It refuses every `email` provider sign-up. It does not fire for admin-API creation, so it never sees `add-students`' users.
  - **Auth config:** `[auth] enable_signup = true` from the change that registers the hook (epic-platform-baseline ships it `false`), `[auth.email] enabled = true` (password sign-in stays on), anonymous sign-ins off, manual linking off. The hosted `site_url` is `https://fermi-plus.sallvain.workers.dev`, and `additional_redirect_urls` holds only that origin's paths; the health check asserts both (AD-21). The client uses `flowType: 'pkce'`. The Google OAuth client lists that origin as its JavaScript origin and Supabase's callback as its only redirect URI.
  - **The list's writers:** `add_staff_invite` and `remove_staff_invite` (admin only, audited) are the only writers of `staff_invites`; the admin console calls the same functions.
  - **Sign-in screen:** "I'm a teacher" shows Google; "I'm a student" shows email and password.
  - **Test:** pgTAP drives the hook with listed, unlisted, email-provider and bootstrap payloads. This is the ticket's "no account without an invitation" check.

### AD-8 — Student accounts are created by their teacher [ADOPTED]

- **Binds:** R1, R2, R4, R5, R26, K10; epic-classes-rosters owns; epic-admin-console owns the admin's roster screen
- **Prevents:** two ways to create a student; a student outside a roster; a teacher turning an invited colleague into a student; a password or name overwritten by a second class; the admin refused by a teaches-only check, or given a second admin-only path
- **Rule:** only `add-students` creates students. A caller who `app.manages_class` (a class's teacher, or the admin for any class) sends name and school email rows for that class. A CSV of up to 1000 rows is sent in chunks of at most 100 rows per call. Before creating any Auth user, `add-students` asks `internal.check_add_students_as(actor, class)`, which checks `app.manages_class` and `app.class_open`. Each row is handled on its own and returns its own result:
  - an email on `staff_invites`, the bootstrap email, or a teacher or admin profile is refused;
  - an existing student is enrolled, keeping their password and `display_name`;
  - a new email gets an Auth user (`email_confirm: true`, `app_metadata.fermi_role = 'student'`) with a generated password, and is enrolled.

  Enrollment is written by `internal.enroll_student_as(actor, class, student)`, and removal by `remove_student`; both check `app.manages_class` and `app.class_open`. Roster status (waiting for first sign-in or connected) is read only through `roster_status(class)`, allowed for `app.manages_class`. The generated password is stored as a Vault secret referenced by `student_credentials`. It is read only through `reveal_student_password(student)`, allowed for `app.manages_student`. It is replaced only by `reset-student-password`, which asks `internal.issue_password_reset_as(actor, student, new_password)` (checks `app.manages_student`). That call writes a short-lived ticket in `internal.password_resets` carrying the actor and the new password's Vault secret, then the function updates the Auth user. A `BEFORE UPDATE ON auth.users` trigger refuses a student's password change unless it consumes such a ticket; consuming it swaps `student_credentials` to the ticket's secret and writes the audit event, so a failed Auth call changes nothing. Students cannot change their own password, even through the raw Auth API, and cannot leave a class. The printable sheet lists the rows that succeeded, each with its current password. Every reveal and reset is in the audit log (AD-22).

### AD-9 — Enrollment is the only class membership; archived classes are read-only [ADOPTED]

- **Binds:** R4, R6, R7, R9, R10, R18, R19, R20, R21; epic-classes-rosters owns
- **Prevents:** the four Firebase enrollment shapes; writes into an archived class; companion rows created two ways
- **Rule:**
  - **Membership:** `enrollments (class_id, student_id)` is the only record of who is in a class. Nothing copies it.
  - **Archived classes:** `classes.archived_at` set means every class-scoped write checks `app.class_open` and is refused. Reads stay: teachers for their classes, students for their own records.
  - **Reads of classes and rosters:** `app.manages_class` reads a class, its enrollments and its roster status, so the admin reads every class.
  - **Removal:** removing a student's enrollment ends their access to everything scoped to that class, their own grades and points included; the rows stay for the teacher.
  - **Deleting a class:** only `delete_class` (through `internal.delete_class_as`), which cascades and is audited, including when a teacher deletes their own account.
  - **Companion rows:** a per-class row another epic needs (the class chat, the Announcements board) is created by an `AFTER INSERT ON classes` trigger in that epic's migration. The same migration backfills existing classes, and `unique (class_id)` holds.

### AD-10 — Chat is one model with fixed pairing rules [ADOPTED]

- **Binds:** R10, R12, R16, K14; epic-chat owns
- **Prevents:** chat stored two ways; pairing enforced in some paths only; removed students keeping groups
- **Rule:** `chats.kind` is `one_to_one`, `group` or `class`.
  - **Who is in a chat:**
    - a class chat: the class's teacher and enrolled students (derived, never copied);
    - a one-to-one or group chat: `chat_members` rows.
  - **One-to-one pairs:** only a teacher with a student they teach (`app.teaches_student`), or the admin with a teacher.
  - **Groups:** only teachers create them, with their own students as members. A group member counts as in the chat only while the creator still teaches them, so removal from a class needs no cleanup write.
  - **When a pair stops qualifying:** a one-to-one chat stays readable to both and takes no new messages.
  - **Read markers:** `chat_reads (chat_id, user_id, last_read_at)`, written only by `mark_chat_read`. Unread counts derive from it, never from counters.
  - **Sending:** every message, typed or scheduled, goes through `internal.send_message_as(sender, …)`, which re-checks membership, pairing and `app.class_open` at send time.
  - **Attachments:** only teachers and the admin send them.

### AD-11 — Presence and do-not-disturb [ADOPTED]

- **Binds:** R10, R11, R12, R15, R17, R24; epic-invite-sign-in owns `presence_clients`, the heartbeat, the leave report and `app.on_screen` and `app.presence`; epic-chat owns the dots, the do-not-disturb switch and typing
- **Prevents:** faked presence; presence beyond the directory; DND enforced in one sender only; dots and the admin's online count disagreeing; a user who just closed Fermi counting as active, so a reply gets neither a push nor a pop-up; one device going off screen silencing another that is still on screen
- **Rule:**
  - **One row per open client:** each tab or Home Screen web app has a random client id in `sessionStorage`. `presence_clients (user_id, client_id, seen_at)` holds one row per client, written only by `touch_presence(client_id)` and `leave_presence(client_id)`, which act on the caller's own rows; clients have no table grants. `touch_presence` also deletes the caller's rows older than 2 minutes.
  - **Heartbeat:** the app shell (epic-invite-sign-in) calls `touch_presence` when Fermi starts, at once when it comes back on screen, and about every 60 seconds while it stays on screen.
  - **Leave report:** when Fermi goes off screen (`visibilitychange` to hidden, which covers switching away and locking the phone, and `pagehide`, which covers closing), it calls `leave_presence`, which deletes that client's row. `app/src/api/` sends it with `fetch(…, { keepalive: true })` so it survives the page closing. AD-27's sign-out also sends it.
  - **On screen:** `app.on_screen(u)` is true while `u` has a row seen within 2 minutes. The 2-minute window is only the fallback for a leave report that never arrives.
  - **Do not disturb:** `profiles.dnd`; epic-invite-sign-in grants `UPDATE (dnd)` on the caller's own row, and epic-chat's switch writes through that grant.
  - **Dots:** `app.presence(u)` returns `green` when `app.on_screen(u)` and DND is off, `yellow` when on screen and DND is on, `red` otherwise. The dots and the admin's online count (green or yellow) both read it. Visible only where `app.can_see_user` allows.
  - **Typing:** Realtime Presence on the chat's channel, never stored.
  - **What DND silences:** every push and the in-app pop-up; inbox rows are still written.

### AD-12 — The directory decides who sees whom [ADOPTED]

- **Binds:** R3, R10, R12, R15, R22, K16; epic-invite-sign-in owns the shape, clause owners per AD-2
- **Prevents:** features exposing names, pictures or emails by their own rule; classmates reading emails through a row-level grant
- **Rule:** `authenticated` gets column-level `SELECT` on `profiles` for `id, display_name, avatar_path, role, dnd`, filtered by `app.can_see_user`, and none on `email`. Email is read only through `app.visible_email(user)`, which applies D20:
  - a user sees their own;
  - a student sees their teachers' and the admin's;
  - a teacher sees their students' and the admin's;
  - the admin sees everyone's.

  Gmail compose (R22) takes its recipient from it. A pgTAP test asserts `authenticated` cannot select `profiles.email`.

### AD-13 — Uploads: fixed buckets, real limits, paths tied to rows [ADOPTED]

- **Binds:** R3, R6, R10, K12; epic-invite-sign-in owns the pattern, bucket owners per the Epic Map
- **Prevents:** a size check that trusts the client; long-lived links; classmates reading each other's submissions; an edited submission; a row pointing at another scope's file
- **Rule:** private buckets with `file_size_limit` 10 MB and exact `allowed_mime_types`:
  - **Avatars:** `image/jpeg`, `image/png`, `image/webp`, resized on the device first.
  - **Attachments:** `image/jpeg`, `image/png`, `image/gif`, `image/webp`, `image/heic`, `application/pdf`, Word, PowerPoint and Excel (current and legacy) and `text/plain`. No SVG.

| Bucket | Path | Insert | Read | Update or delete |
| --- | --- | --- | --- | --- |
| `avatars` | `<user_id>/<uuid>.<ext>` | self | `app.can_see_user` | self |
| `assignment-files` | `<class_id>/<assignment_id>/<uuid>.<ext>` | `app.teaches` and `app.class_open` | teacher; students only once the assignment is published | teacher, before publish |
| `submission-files` | `<class_id>/<student_id>/<uuid>.<ext>` | that student, `app.enrolled` and `app.class_open`, before submit | that student and `app.teaches` | none after submit |
| `chat-files` | `<chat_id>/<uuid>.<ext>` | `app.in_chat` and role teacher or admin | `app.in_chat` | none |

  - **Rows store paths:** a row stores only the path, and a check asserts the path's prefix equals that row's own scope ids.
  - **Links:** signed URLs are minted under the caller's JWT only, and expire within 1 hour.
  - **Drive:** a Drive file is copied at attach time. The client gets a `drive.file` token at first attach from Google's token client, the same in a browser tab and in the Home Screen web app. The client downloads the bytes, exporting Google Docs, Sheets and Slides to PDF or Office formats (capped at 10 MB by Google), and uploads them through the same path. The token is never stored by Fermi.

### AD-14 — One notification pipeline [ADOPTED]

- **Binds:** R11, R14, R17, R20, R24, R27, R29; epic-invite-sign-in owns the inbox, epic-notifications owns delivery
- **Prevents:** each feature sending pushes its own way; recipients re-derived in TypeScript; DND or dead-token handling in one path only
- **Rule:** the kinds are `chat_message`, `assignment_published`, `grade_posted`, `announcement`, `due_reminder` and `removal_request`. Adding a kind amends this AD.
  - **Inbox:** an inbox row is written only by `internal.notify(recipients, kind, ref)`. Epic-invite-sign-in creates `notifications` and `notify`, so epics 3, 4 and 7 can emit before delivery exists. `chat_message` writes no inbox row; chat unread counts cover it.
  - **Delivery (epic-notifications):**
    - `AFTER INSERT` triggers on `notifications` and `messages` post the id through `pg_net` to `send-push`.
    - `send-push` calls one RPC, `internal.push_targets(kind, ref)`. That RPC uses epic-chat's `internal.message_recipients` for messages. It skips recipients in DND and recipients for whom `app.on_screen` is true, since Fermi on screen shows the in-app pop-up instead (AD-11). It returns each device with the `title`, `body` and `url` to show, built in SQL.
    - **Push text:** it names who and what kind, never content: "New message from <name>", "<assignment> was graded". No message text or score is shown.
    - **Click target:** `url` is always `/open/<kind>/<ref>`. Epic-notifications owns that route, which resolves the target under RLS and redirects. Each epic that owns a kind's screen adds that kind's resolver. The inbox (R14) and the pop-up (R17) open the same route.
    - `send-push` sends to `webpush` rows (endpoint, keys, VAPID with a non-localhost subject, `npm:web-push`). It removes a target the push service reports gone (404 or 410) only through `internal.remove_gone_push_target(endpoint)`. Any other failure is logged, never deleted.
    - **Devices:** `push_devices` has `unique (endpoint)`. Rows change only through `register_push_device`, which upserts on the endpoint and moves it to the caller, `unregister_push_device`, and `internal.remove_gone_push_target`. Sign-out calls `PushSubscription.unsubscribe()` in the browser before `unregister_push_device` (AD-27). A subscription is made only from AD-25's service worker registration.
    - A notifications insert also sends a `notification` event on `user:<uuid>`, which drives the in-app pop-up (R17).
    - Web push is offered on the Home Screen web app on iPhone (R11) and in desktop Chrome, Edge and Safari (R24).

### AD-15 — Scheduled work runs in pg_cron through the `_as` functions [ADOPTED]

- **Binds:** R16, R27; epic-chat, epic-assignments-grades and epic-invite-sign-in (`sweep-storage`) own their jobs
- **Prevents:** a scheduler that bypasses checks, impersonates users through a client-callable parameter, or retries forever
- **Rule:** `pg_cron` workers in `internal` call the `_as` functions with the stored actor: the author for scheduled messages, and the system for reminders through `internal.notify`. Each due row runs in its own subtransaction. A refusal marks that row `failed` with its error key, writes `internal.job_failures`, and is never retried.
  - **Due reminders:** default to 24 hours before the due time, for every enrolled student who has not submitted.
  - **Reminder settings:** each student keeps their own offsets, or turns reminders off, in `reminder_preferences`; teachers set none.

### AD-16 — Account deletion follows one rule [ADOPTED]

- **Binds:** R15, R28, R29; epic-admin-console owns every path; epic-classes-rosters owns the student's request
- **Prevents:** orphaned rows, files or secrets; a deleted teacher signing back in; one teacher wiping a student shared with others; two epics removing the same thing
- **Rule:** only `delete-account` deletes accounts. It asks `internal.delete_account_as(actor, target)`, which checks who may delete and records the actor in `internal.pending_deletions`, then deletes the Auth user through the admin API. It removes nothing itself.
  - **Who may delete:**
    - the admin deletes anyone but themselves, with no request needed;
    - a teacher deletes themselves from Settings, after a warning listing their classes; `internal.delete_account_as` first deletes each class through `internal.delete_class_as`, so each is audited;
    - a student cannot delete themselves. "Ask my teacher to remove my account" writes a request and a `removal_request` notification to their teachers and the admin. A teacher of that student can then delete the account, and never without an open request (`no_removal_request`).
  - **The deletion root is `DELETE FROM auth.users`.** `profiles` cascades from it. Every other effect is a cascade or an `AFTER DELETE` trigger in the owning epic's migration: the `staff_invites` row (epic-invite-sign-in, by email), the Vault secret (epic-classes-rosters, on `student_credentials`), and stored files (each bucket owner).
  - **Cascades:** every foreign key to `profiles` is `ON DELETE CASCADE`, except author columns on `messages`, `threads`, `replies` and `support_reports`, which are `SET NULL` and shown as "Deleted user"; `audit_events` has no foreign keys (AD-22).
  - **Files:** each such trigger enqueues the path into `internal.storage_deletions`. `sweep-storage`, called by `pg_cron`, deletes the queued objects through the Storage API. A kept message keeps its attachment.
  - **Tests:** the pgTAP file `supabase/tests/database/NN_account_deletion.sql`, created by epic-invite-sign-in with the `profiles`, `staff_invites` and `avatars` cases. Each case deletes the `auth.users` row directly and asserts every effect. Each later epic that adds a foreign key to `profiles`, a bucket or a secret adds its case; epic-admin-console adds the `internal.delete_account_as` cases there and the handler cases in `delete-account`'s `deno test`.

### AD-17 — Errors carry a code end to end [ADOPTED]

- **Binds:** all epics
- **Prevents:** Firebase's every-error-is-`internal`; each screen parsing errors its own way
- **Rule:** SQL functions raise with a SQLSTATE (`42501` refused, `P0002` not found, `22023` bad input, `23505` duplicate) and a stable snake_case message key. Edge functions answer with the real HTTP status (401, 403, 404, 409, 422, 500) and `{ "error": { "code": "<key>", "message": "<text>" } }`. The client maps keys to text in one place in `app/src/api/`.

### AD-18 — Retired 2026-11-07 (was: Live update or App Store build)

- **Binds:** nothing; R23 moved to AD-24
- **Prevents:** a story still building to the retired native-build rule, or a later AD reusing this ID
- **Rule:** retired with the iPhone app and Capacitor (initiative Decision 2026-11-07); every change ships by deploy. No `MIN_NATIVE_BUILD`, native Dependabot group or plugin guard remains. The ID is never reused; a later Android initiative that brings back a native shell writes a new AD.

### AD-19 — Realtime: private channels, server-sent events, ids only [ADOPTED]

- **Binds:** R10, R12, R16, R17; epic-chat owns `chat:` topics, epic-invite-sign-in owns `user:` topics
- **Prevents:** public topics; forged live messages; two epics naming topics or events differently
- **Rule:** Realtime runs private-only (set by CI, AD-21). There are two kinds of topic:
  - **`chat:<uuid>`:** members read it through `app.in_chat`, and clients may write only Presence (typing).
  - **`user:<uuid>`:** only that user reads it.

  Broadcast events are sent only by database triggers (`realtime.send`) and carry ids only; clients refetch the rows through RLS. The event union lives in `app/src/api/realtime.ts` as zod schemas. Each event type has one emitting trigger, owned by the epic that adds it. Postgres change feeds are not used. Channel authorization is cached until the JWT expires (1 hour); because events carry only ids, a removed member learns nothing in that window.

### AD-20 — Schema changes are expand, then contract

- **Binds:** all epics; K7, R23
- **Prevents:** migrations, which deploy before the build, breaking clients still on the previous build: an open tab or a Home Screen web app suspended since before the deploy, until AD-24's next check refreshes it
- **Rule:** a migration only adds: columns, tables, or new functions under new names. Renaming or removing a column, or changing an RPC's arguments or result, waits until the build that stopped using the old shape has been live for one deploy, and ships as its own migration.
  - **Same for other shapes:** edge-function request and response bodies, Realtime event payloads and push payloads also only add optional fields, and remove one deploy later. `realtime.ts` ignores an unknown event type instead of throwing.
  - **Checked, not trusted:** a contract migration starts with `-- contract: after <commit>`, naming the commit that stopped using the old shape. The migrate job refuses it unless the live `latest.json` `version` has that commit as an ancestor, so a cancelled pending deploy cannot skip the step. `test.yml`'s migration check fails a drop, rename or argument change without that line.
  - **Stale clients:** `app/src/api/` runs AD-24's check at once on a missing function or column error (`PGRST202`, `PGRST204`, `42883`, `42703`) or an unknown Realtime event.

### AD-21 — Operations are deployed and watched from CI [ADOPTED]

- **Binds:** K6, K7, K13; epic-platform-baseline owns
- **Prevents:** hosted settings set by hand or missing; silent failures; the Free project pausing; expired secrets
- **Rule:**
  - **Extensions:** only epic-platform-baseline enables extensions: `pg_cron` (schema `pg_catalog`), `pg_net` (schema `extensions`) and `pgtap` for tests; `supabase_vault` is on by default.
  - **Deploy order:** migrate, then push the hosted Auth config (`supabase config push`, provider secrets through `env()`), then set Realtime private-only through the Management API, then deploy functions, build and write `updates/latest.json` (AD-24), `wrangler deploy`, and the health check.
  - **Health check:** fails unless the site serves `updates/latest.json` as JSON naming the commit just built, not the SPA fallback, and `/` and `/updates/latest.json` carry `max-age=0`. From epic-notifications on, it also fails unless `/sw.js` is served as JavaScript and the manifest as JSON. It asserts the hosted `site_url` and redirect URLs (AD-7). It reads the hosted Auth and Realtime config through the Management API and fails unless email sign-in is on, anonymous sign-ins are off and Realtime is private-only (a missing `private_only` fails). Epic-platform-baseline ships `[auth] enable_signup = false` and asserts it. Epic-invite-sign-in, in the change that creates the hook, turns sign-up on and replaces that assertion with one comparing the registered hook URI exactly.
  - **Per-environment settings:** CI writes each pg_net-called function's row in `internal.edge_function_settings` per environment (AD-5), from one `deploy.yml` step that epic-invite-sign-in adds with the table and `sweep-storage`'s entry.
  - **Extension points:** epic-platform-baseline owns every `.github` file. A later epic changes them only in the change that needs it, and only by adding a health-check assertion, its function's entry to the one `deploy.yml` step that writes `internal.edge_function_settings`, a public value the browser needs (the VAPID public key, the Google client id, the Picker key and app id) as a repo variable passed to the build step as `VITE_<NAME>`, its function secrets' names in the one `supabase secrets set` step after the functions deploy (created by epic-notifications with VAPID), the bootstrap admin email's Vault write (epic-invite-sign-in, in the `edge_function_settings` step), a `test.yml` lane (AD-23), or a deploy or scheduled-workflow secret to the Production environment, never at repo level (R10). A new workflow file is added only for a new schedule or trigger, and it is listed in the Structural Seed with its owner.
  - **Keep-alive:** a twice-daily workflow runs a real query through the API so breaks do not pause the Free project. It calls `public.job_health()`, a `postgres`-owned definer function only `service_role` may execute (epic-platform-baseline), and fails, so GitHub emails the owner, when `internal.job_failures`, `cron.job_run_details` or non-2xx `net._http_response` rows for those functions hold new failures. It re-enables itself monthly through the GitHub API, because GitHub disables scheduled workflows in an inactive public repo after 60 days.
  - **Rollback:** a revert commit on main, never `wrangler rollback`, which the daily deploy would undo.
  - **Backups:** the Free plan has none, so a weekly workflow runs `supabase db dump --remote` (roles, schema, data) through the Session pooler. It encrypts the dump to the owner's age key and keeps it as a 90-day workflow artifact, never committed, because the repo is public. It restores the dump into a throwaway local database to prove it works. Storage file bytes are not backed up, and neither is the Vault root key, so a restore into a new project loses stored student passwords and teachers reset them.

### AD-22 — One audit log for access-changing actions [ADOPTED]

- **Binds:** R4, R5, R15, R21, R26, R29, R30, AD-8, AD-16; epic-invite-sign-in owns the log and the admin's read policy; epic-classes-rosters adds the teacher read policy and the teachers' view; epic-admin-console the admin's view; each epic writes its own actions
- **Prevents:** each epic logging differently or not at all; a change to who is in Fermi with no record; a deletion erasing the events that record it
- **Rule:** `audit_events (actor_id, action, class_id, subject_id, at, detail)` has no foreign keys: the ids are plain uuids, and `detail` snapshots names, email and class name at write time. It is written only by `internal.audit(...)`, has no client write grant, and is never updated or deleted. A change made in SQL calls `internal.audit` in the same transaction. A change made through the Auth admin API is audited by the database trigger that observes it: a password reset by the ticket-consuming trigger (AD-8), an account deletion by an `AFTER DELETE ON auth.users` trigger reading the actor from `internal.pending_deletions` (epic-admin-console). Actions:
  - staff invite added or removed;
  - class created, archived or deleted;
  - student added to or removed from a class;
  - password shown or reset;
  - removal request made;
  - account deleted.

  Adding an action amends this AD. The admin reads every event. A teacher reads the events of classes they teach now and of students they teach now; events of deleted classes and people are the admin's only. Students read none.

### AD-23 — One merge gate [ADOPTED]

- **Binds:** K13, all epics' tests and checks; epic-platform-baseline owns
- **Prevents:** a later epic's tests failing while a pull request still merges; a lane that fails every Dependabot pull request for lack of secrets; a ruleset that blocks Dependabot's own branches; an update with a known security advisory merging unattended; a merged update waiting for the next human push to deploy
- **Rule:**
  - **Required checks:** the Main ruleset applies to the default branch only and requires exactly two checks, under fixed names: `test.yml`'s summary job, and the dependency review, which fails at moderate severity.
  - **Lanes:** every other check that must block a merge is a job in `test.yml` that the summary job waits on, added to it in the same change that adds the job. A check in another workflow blocks nothing.
  - **No secrets:** `test.yml` reads no repo or environment secret and tests against the local stack only, so Dependabot pull requests run every lane.
  - **Self-merge:** `dependabot-auto-merge.yml` merges every Dependabot pull request once both required checks pass. Such a merge starts no deploy, so `deploy.yml` also runs once a day and stops before migrate when `updates/latest.json` already names main's latest commit (AD-24).

### AD-24 — One build id, one update check

- **Binds:** R23, K7; epic-platform-baseline owns
- **Prevents:** the deploy and the app comparing different identifiers; a second update mechanism; a tab or Home Screen web app staying on an old build past AD-20's one-deploy contract; a docs, planning, CI or `supabase/`-only push stopping every user with the refresh page; a refresh that cuts off work in progress
- **Rule:** a build carries two ids, both computed once in `deploy.yml` and passed to the build and to `scripts/package-live-update.sh`:
  - **`version`:** the commit deployed (`__BUILD_ID__`, also the `fermi-build` meta tag; `local` outside CI). Read by `deploy.yml`'s daily skip and the health check (AD-21).
  - **`app`:** the tree hash of `app/` (`git rev-parse HEAD:app`), baked in as `__APP_ID__`. It changes only when something under `app/` changes, and it works on a shallow checkout. Read only by the app's update check.

  `updates/latest.json` is `{ "version": "…", "app": "…" }` and nothing else, written only by `scripts/package-live-update.sh` after the build.
  - **When the app checks:** it fetches `/updates/latest.json` (absolute path, `cache: 'no-store'`) when Fermi starts, on `visibilitychange` to visible, on `pageshow` and `online`, every 15 minutes while on screen, and at once on AD-20's stale-client signals or a failed dynamic import. A failed or malformed fetch, or one without `app`, shows nothing.
  - **What a different build does:** an `app` other than `__APP_ID__` replaces the app with the refresh page: full screen, cannot be dismissed, one Refresh button, needs no session. Its text is "A new version of Fermi+ is ready. Refresh to keep using Fermi+." It renders at the root in place of the router and every provider, so subscriptions, timers and the heartbeat stop; the user's dot turns red meanwhile.
  - **Work in progress:** the page waits while epic-platform-baseline's one busy registry holds work (a CSV import, an upload, a send), at most 2 minutes. Every multi-call or upload flow registers there.
  - **Refresh:** reloads the current URL; AD-26 restores what the user was typing. The OAuth callback route clears its code from the URL before the page may show. If the reload comes back on the same build, the next check waits 30 seconds.
  - **Same in every client:** a browser tab and the Home Screen web app run the same check. No plugin or service worker takes part (AD-25).

### AD-25 — One service worker, which never serves the app

- **Binds:** R11, R17, R23, R24; epic-notifications owns
- **Prevents:** a caching service worker serving the previous build after AD-24's refresh; two service workers or two manifest writers; a subscription the browser revokes because a push showed nothing
- **Rule:** Fermi has one service worker, `/sw.js` at scope `/`, a hand-written file in `app/public/`; no `vite-plugin-pwa` or Workbox. Only epic-notifications' push code registers it.
  - **Never:** a `fetch` handler, Cache Storage or `importScripts`. Fermi has no offline mode. A Vitest fails if `sw.js` adds a `fetch` listener or touches `caches`.
  - **May:** handle `install` and `activate` (`skipWaiting`, `clients.claim`), `push`, `notificationclick` (opens or focuses AD-14's `url`) and `pushsubscriptionchange`.
  - **Every push shows a notification:** `showNotification` inside `waitUntil`, every time. All suppression (DND, on-screen) is decided on the server (AD-14).
  - **iPhone:** push is offered only in the Home Screen web app (`display-mode: standalone`, iOS 16.4 or later), and permission is asked only from a tap.
  - **One manifest:** epic-platform-baseline's `app/public` manifest (`start_url` and `scope` `/`, `display` `standalone`) is the only one.

### AD-26 — One draft store

- **Binds:** R23 and every epic with a content form; epic-platform-baseline owns the store
- **Prevents:** each epic saving typing its own way, so AD-24's refresh restores some screens and loses others; one form's draft landing in another class's form; a cancelled edit coming back over the server's value; drafts left for the next user of a shared school computer
- **Rule:** every field of a form that creates or edits content (a message, post, reply, assignment, submission, grade or feedback, event, class, profile name) goes through the one draft hook in `app/src/` (epic-platform-baseline). It stores any JSON value: text, numbers, dates, selects. Search boxes, filters, confirm fields and signed-out screens are not kept.
  - **Keys:** only `draftKey(feature, ...scopeIds, field)` builds them, as `fermi:draft:<user id>:…`; `feature` is one of the `app/src/features/<area>` folders. A new row's key carries its parent's id (`new:<class id>`). The hook reads and writes only after the session has resolved.
  - **Storage:** `sessionStorage`, written on each change. It lives only in that tab or Home Screen web app, so closing it drops the drafts.
  - **Restore:** every drafted form is reachable by URL (a route or a search parameter), so AD-24's refresh lands on it. A restored form shows a Discard control. Files picked but not sent are not kept: the draft lists their names, and the form asks for them again and blocks sending until each is picked or removed.
  - **Clearing:** on send, save or cancel, and AD-27 wipes every `fermi:draft:` key at sign-out.
  - **Never kept:** passwords and file bytes.

### AD-27 — One sign-out, in a fixed order

- **Binds:** R1, R11, R24, AD-14, AD-26; epic-invite-sign-in owns
- **Prevents:** each epic attaching its sign-out step where it finds one; push unregistered after the session is gone; drafts surviving a sign-out made in another tab
- **Rule:** `signOut()` in `app/src/api/auth.ts` is the only sign-out. It runs, in order:
  1. `leave_presence` (AD-11), then `PushSubscription.unsubscribe()` in the browser, then `unregister_push_device` (epic-notifications adds this step);
  2. `supabase.auth.signOut()`;
  3. the draft wipe (AD-26).

  The draft wipe also runs on every `SIGNED_OUT` auth event in each tab. Shared computers stay signed in until someone signs out; a second user signing in on the same browser takes over its push endpoint (AD-14).

## Consistency Conventions

| Concern | Convention |
| --- | --- |
| Naming | Tables plural snake_case; columns snake_case; functions `verb_noun`, with `_as` for actor-explicit internals; `app.` predicates read as questions; edge functions kebab-case; TypeScript uses the generated `Database` types |
| Ids and time | `uuid` keys (`gen_random_uuid()`); `timestamptz` stored UTC, shown in the device's zone; `*_at` times, `*_id` references |
| Shared data shapes | `display_name`, `avatar_path`; `enrollments` for membership; `chat_reads` for read markers; one `grades` row per (assignment, student); GPA, letter grade and averages come from one grade-summary function owned by epic-assignments-grades, which epic-dashboards calls; `notifications.read_at`; `points_history.awarded_at`; dashboards read `security_invoker` views over source tables, with no `activities` table |
| Calendar | Participants are added only through `add_event_participant`, which requires `app.can_see_user(creator, participant)` |
| Migrations | One concern per timestamped file under `supabase/migrations/`, with a header naming its test; RLS, grants and the privilege fixture updated in the same change |
| Tests | pgTAP `supabase/tests/database/NN_*.sql` for every table, policy, grant, function and view; `deno test` for every `handler.ts`; Vitest for `app/src`; Playwright projects Desktop Chrome and iPhone WebKit, plus api tests; paths only the Home Screen web app has, which Playwright cannot drive, are checked by hand on the owner's iPhone by the epic that builds each: Google sign-in returning to the Home Screen web app (epic-invite-sign-in), the Drive picker there (epic-assignments-grades) and web push to it while closed (epic-notifications), and AD-24's check, refresh page and draft restore after it returns from suspension (epic-platform-baseline) |
| Client layering | Features → hooks and stores (Zustand) → `app/src/api/*` → supabase-js; only `api/` imports the client; text fields go through the draft hook (AD-26) |
| Secrets | fnox locally; GitHub secrets in CI, a later epic's in the Production environment (AD-21), none read by `test.yml` (AD-23); Supabase function secrets for VAPID; the bootstrap admin email in Vault, set by CI; nothing in source |
| Email | Fermi sends none: no custom SMTP; recovery, OTP and email change are never offered in the UI |

## Stack

| Name | Version |
| --- | --- |
| @supabase/supabase-js | 2.119.0 |
| React, react-dom | 19.3.1 |
| React Router | 8.5.1 |
| Vite | 8.3.6 |
| @vitejs/plugin-react | 6.2.1 |
| TypeScript | 6.0.3 |
| typescript-eslint | 8.72.1 |
| Tailwind CSS | 4.3.4 |
| Zustand | 5.0.16 |
| zod | 4.6.7 |
| Vitest | 5.1.0 |
| wrangler | 4.158.0 |
| web-push (in send-push) | 3.6.7 |
| Supabase CLI | 2.122.0 |
| Supabase edge runtime | Deno 2 |
| Supabase plan | Free |

## Structural Seed

```text
Fermi/
  app/                      # Vite + React: the website and the Home Screen web app
    src/api/                # the only Supabase callers, error map, realtime.ts
    src/features/<area>/    # screens, hooks and stores per feature area
    public/                 # manifest, icons, sw.js (AD-25)
  supabase/
    config.toml
    migrations/
    functions/              # send-push, add-students, reset-student-password, delete-account, sweep-storage, _shared
    tests/database/         # pgTAP, privilege fixture
  wrangler.jsonc            # Worker fermi-plus, assets only
  scripts/package-live-update.sh  # writes updates/latest.json (AD-24)
  .github/
    dependabot.yml          # app/ npm and GitHub Actions only
    workflows/              # deploy.yml, test.yml, keep-alive.yml, backup.yml,
                            # dependency-review.yml, dependabot-auto-merge.yml,
                            # claude.yml, claude-code-review.yml (owners in the Epic Map)
```

```mermaid
flowchart TD
  GH[push to main] --> MIG[migrate]
  MIG --> CFG[push Auth config, Realtime private]
  CFG --> FN[deploy functions]
  FN --> BLD[build + latest.json]
  BLD --> WR[wrangler deploy fermi-plus]
  WR --> HC[health check incl. config]
  WR --> CF[fermi-plus.workers.dev]
  CF --> WEB[website, Home Screen app]
  CF --> UPD[updates/latest.json]
  UPD --> WEB
  KA[keep-alive twice daily] --> SBP[hosted Supabase, Free]
  WEB --> SBP
  SBP --> WP[web push services]
  WP --> WEB
```

There are three environments: local (`supabase start`, with Google mocked), CI (a local stack per run) and hosted (one Supabase project on the Free plan, plus the `fermi-plus` Worker). There is no staging.

```mermaid
erDiagram
  profiles ||--o{ enrollments : "student in"
  classes ||--o{ enrollments : has
  profiles ||--o{ classes : teaches
  profiles ||--o| student_credentials : "password in Vault"
  classes ||--o{ assignments : has
  assignments ||--o{ submissions : receives
  assignments ||--o{ grades : has
  profiles ||--o{ grades : earns
  chats ||--o{ chat_members : has
  chats ||--o{ chat_reads : tracks
  chats ||--o{ messages : holds
  classes ||--o| chats : "class chat"
  profiles ||--o{ notifications : receives
  profiles ||--o{ push_devices : registers
  classes ||--o| boards : "announcements"
  boards ||--o{ threads : has
  threads ||--o{ replies : has
  classes ||--o{ behaviors : defines
  profiles ||--o{ points_history : "awarded to"
```

## Capability → Architecture Map

| Capability | Lives in | Governed by |
| --- | --- | --- |
| R1, R2, R25 sign-in, sign-out and landing | `staff_invites`, hook, `on_auth_user_created`, `profiles`, `signOut()`, the manifest and icons | AD-6, AD-7, AD-8, AD-25, AD-27 |
| R26 student passwords | `student_credentials`, `reveal_student_password`, `reset-student-password`, password-change trigger | AD-8, AD-22 |
| R3 name and picture | `profiles`, `avatars` | AD-3, AD-12, AD-13 |
| R4, R5, R21 classes, rosters, archive | `classes`, `enrollments`, `add-students`, `student_credentials` | AD-2, AD-8, AD-9 |
| R6, R18, R21 assignments, grades, analytics | `assignments`, `submissions`, `grades`, grade-summary function, file buckets | AD-4, AD-9, AD-13 |
| R7 behavior points | `behaviors`, `points_history`, award and undo functions | AD-2, AD-4, AD-9 |
| R8 calendar | `calendar_events`, `calendar_event_participants` | AD-3, conventions |
| R9, R20 boards and announcements | `boards`, `threads`, `replies`, `likes`, `notify` | AD-4, AD-9, AD-14 |
| R10, R12, R16 chat, presence, scheduled | `chats`, `chat_members`, `chat_reads`, `messages`, `send_message`, pg_cron | AD-10, AD-11, AD-15, AD-19 |
| R11, R14, R17, R24 notifications | `notifications`, `push_devices`, `send-push`, `sw.js`, `user:` events | AD-11, AD-14, AD-19, AD-25 |
| R13 support reports | `support_reports` (insert own, admin reads) | AD-1, AD-3 |
| R15 admin console | `app.presence` counts, `staff_invites` writers, admin roster screen, `delete-account` | AD-7, AD-8, AD-11, AD-16 |
| R19 dashboards | `security_invoker` views and the grade-summary function | AD-3, conventions |
| R22 Gmail compose | `app.visible_email` | AD-12 |
| R23 refresh onto a new build | `latest.json`, the update check, the refresh page, the busy registry, the draft hook | AD-20, AD-24, AD-25, AD-26 |
| R27 due reminders | `reminder_preferences`, pg_cron, `notify` | AD-14, AD-15 |
| R28, R29 self-deletion and removal requests | `delete-account`, removal-request rows, `removal_request` kind | AD-14, AD-16 |
| R30 audit log | `audit_events`, `internal.audit` | AD-22 |
| K17 uploads | buckets, Drive copy-in | AD-13 |
| K18 Free plan | keep-alive, backup workflows | AD-21 |
| K7, K13 deploy and tests | workflows, privilege fixture, Main ruleset, Dependabot | AD-3, AD-21, AD-23, AD-24 |

## Deferred

- **Per-epic columns and indexes:** owned by each epic's stories within AD-2 to AD-4; the ERD names entities only.
- **Grade scales and the GPA formula:** epic-assignments-grades decides, inside its one grade-summary function.
- **Board rules beyond R9** (pinning, editing): epic-boards-announcements, inside AD-4.
- **Per-kind push switches:** none in scope. Revisit if users ask, as a column `internal.push_targets` reads.
- **Retention and purging:** nothing is purged in scope. Revisit before the Free plan's 500 MB database, 1 GB storage or 200 concurrent Realtime connections near their limits.
- **The Pro plan:** revisit when real classes depend on Fermi, or when the pause email arrives despite the keep-alive.
- **Supabase CLI 3:** pinned to 2.x for parity with My-Love's workflows. Adopting v3 means `db push --remote --yes` and `functions deploy --yes`.
- **Android:** a later initiative, which may bring back a native shell under a new AD (AD-18 is retired, not reusable); `push_devices.kind` is extensible.
- **Offline use:** none (AD-25). Revisit only together with AD-24's refresh, since caching the shell brings back stale builds.
- **web-push 4.x:** 4.0.0 was published 2026-11-06; `send-push` stays on 3.6.7 until epic-notifications' spike checks 4.x on Deno.

## Open Questions

- **Spikes opening epic-invite-sign-in:**
  - confirm on the hosted project that the hook ignores admin-API creation;
  - confirm Supabase links a later Google sign-in to an existing student account with the same confirmed email (AD-6);
  - confirm Google sign-in started from the Home Screen web app on an iPhone comes back to it signed in. Developer reports from 2026 say the callback lands in Safari instead (UNVERIFIED on this project). The spike tries, in order, the PKCE redirect, then Google's ID-token sign-in passed to `signInWithIdToken`; if neither works, teachers sign in on the website and the Home Screen web app stays student-only for sign-in, a ticket change for the owner;
  - confirm a `BEFORE UPDATE ON auth.users` trigger refuses a student's own password change cleanly (AD-8).
  - confirm AD-11's keepalive leave report reaches the server when the Home Screen web app on an iPhone is closed, switched away from or locked (UNVERIFIED); if it does not, the 2-minute window still ends the silence.
- **Spike opening epic-assignments-grades:** Google's token client, which has only a popup mode, and the Drive picker in the Home Screen web app on an iPhone (AD-13). Drive attach ships only where the spike passes; elsewhere attach is from the device.
- **Google Workspace for Education:** a school blocks unconfigured third-party apps for students it designates under 18, which would stop students' Drive attach (R6) until its admin allows Fermi. Whether Fermi's students' school does so is UNVERIFIED; it waits on epic-assignments-grades' refinement.
- **Spikes opening epic-notifications:**
  - a real web push reaches the closed Home Screen web app on the owner's iPhone (AD-14, AD-25), and whether Declarative Web Push (iOS 18.4, Safari 18.5) should replace the `push` handler's work;
  - how Fermi notices and recovers a subscription iOS dropped without warning (developer reports, UNVERIFIED; initiative Open question).
