---
runScope: 'system'
runKey: 'system'
workflowStatus: 'completed'
totalSteps: 5
stepsCompleted: ['step-01-detect-mode', 'step-02-load-context', 'step-03-risk-and-testability', 'step-04-coverage-plan', 'step-05-generate-output']
lastStep: 'step-05-generate-output'
nextStep: ''
inputDocuments:
  - _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md
  - _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md
  - _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md
  - _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md
  - _bmad-output/initiative-capacitor-supabase-port/brief-port-goals.md
  - _bmad-output/initiative-capacitor-supabase-port/tickets/tickets.toml
  - _bmad-output/initiative-capacitor-supabase-port/tickets/epic-platform-baseline/tickets/tickets.toml
  - .claude/skills/bmod-tea/knowledge/adr-quality-readiness-checklist.md
  - .claude/skills/bmod-tea/knowledge/nfr-criteria.md
  - .claude/skills/bmod-tea/knowledge/test-levels-framework.md
  - .claude/skills/bmod-tea/knowledge/risk-governance.md
  - .claude/skills/bmod-tea/knowledge/test-quality.md
  - .claude/skills/bmod-tea/knowledge/playwright-cli.md
lastSaved: '2026-11-06'
---

# Test Design Progress — System Level

## Step 1: Mode Detection

- **Mode:** System-Level. Chosen by the owner (option A) on 2026-11-06.
- **Why:** story 1.3 (epic-platform-baseline) requires a system-level test design on the initiative before its TEA framework session. File-based detection alone would have chosen epic-level, because the initiative's ticket tree holds 13 epics.
- **Inputs standing in for PRD + ADR:** the initiative's requirements R1–R30 (`initiative-capacitor-supabase-port.md`) serve as the PRD. The architecture spine's decisions AD-1–AD-23 (`architecture-capacitor-supabase-port.md`) serve as the ADRs and architecture. Supporting documents: the epic map, the parity inventory, the brief and the Firebase backend research.
- **Run identity:** run_scope=system, run_key=system.
- **Prior checkpoint:** none. This is a fresh run.

## Step 2: Context Loaded

**Config:** tea_use_playwright_utils=true; tea_use_pactjs_utils=true (but no Pact dependency or artifacts exist, so contract testing is not relevant and no Pact fragments load); tea_pact_mcp=mcp (not relevant, same reason); tea_browser_automation=auto; test_stack_type=auto.

**Detected stack:** the repo on main today is the Flutter app (pubspec.yaml, ios/, macos/ Podfiles). `app/` and `supabase/` do not exist yet; story 1.1 creates them. The test design targets the stack the spine pins: **fullstack** (Vite + React 19 + TypeScript in `app/`, with Supabase Postgres, RLS, Deno edge functions, Realtime and Storage as the backend), plus a Capacitor 8 iOS shell whose native-only paths are checked by hand in the Simulator.

**Extracted from inputs:**
- Tech stack: see the spine's Stack table (Capacitor 8.6.0, supabase-js 2.119.0, React 19.3.1, Vite 8.3.6, Vitest 5.1.0, Supabase CLI 2.122.0, Deno 2 edge runtime, wrangler 4.158.0).
- Integration points: Supabase Auth (Google, Apple and email providers; before_user_created hook; admin API), Postgres RLS and `app.*` predicates, pg_cron and pg_net to edge functions, Realtime private channels, Storage buckets, APNs, web push (VAPID), Google Drive Picker (`drive.file`), Gmail compose (URL only), Cloudflare Workers static assets, the Capgo self-hosted live updater, GitHub Actions (deploy, test, keep-alive, backup, apple-secret, Dependabot, ruleset), App Store Connect.
- NFRs present: security (K3–K5, K16, K17; AD-1 to AD-3, AD-7, AD-8, AD-12, AD-13, AD-19), reliability and operations (K7, K18; AD-14, AD-15, AD-21), deployability and compatibility (AD-18, AD-20, AD-23), maintainability (K13; AD-3's privilege fixture, AD-5's handler split, AD-17).
- **NFR thresholds missing:** no latency or performance targets anywhere; no availability target; no recovery time or data-loss limit beyond "weekly backup" (implies up to 7 days of data loss); Free-plan ceilings (500 MB DB, 1 GB storage, 200 concurrent Realtime connections) named as limits to revisit, not as test thresholds.

**Knowledge fragments loaded (closed set):** adr-quality-readiness-checklist, nfr-criteria, test-levels-framework, risk-governance, test-quality (system-level required); playwright-cli (tea_browser_automation=auto). No Pact or contract-testing fragments.

## Step 3: Testability and Risk Assessment

### 3.1 Testability Review (system level)

#### 🚨 Testability Concerns (actionable first)

| # | Area | Concern | Source | What is needed |
| --- | --- | --- | --- | --- |
| TC-1 | Controllability | Staff sign-in is Google or Apple only, and locally "Google is mocked" with no stated mechanism. Playwright cannot sign in a teacher or the admin without one. | Spine, Structural Seed ("local (`supabase start`, with Google mocked)"); AD-7 | Decided 2026-11-06 (owner): Decided 2026-11-06: any helper that signs in a teacher or the admin lives only in test code and runs only against the local Supabase stack. It creates the user and gets a session with that stack's own `service_role` key, and it refuses to run when the Supabase URL is not local (`127.0.0.1` or `localhost`). Nothing in `app/`, `supabase/functions/` or the hosted Supabase config adds a test-only way to sign in; the hosted project keeps Google and Apple as the only staff sign-in. Real Google and Apple sign-in is checked by hand in the Simulator in epic-invite-sign-in, not by automated tests. Because the helper creates users through the admin API, which bypasses `before_user_created`, browser tests signed in this way never exercise admission; admission is covered by P0-003 (R-003) and those hand checks. |
| TC-2 | Controllability | Time-driven rules have no stated way to control time in tests: due reminders 24 h before, scheduled messages, presence's 2-minute window, signed URLs under 1 h, short-lived password-reset tickets, the 1 h Realtime auth cache. | AD-8, AD-11, AD-13, AD-15, AD-19 | Cron worker functions take the run time as a parameter (default `now()`), or tests insert rows with past times and call the worker directly. Presence tests set `last_seen_at` through `service_role` and never wait. |
| TC-3 | Controllability | No shared persona or seed strategy is named. Almost every policy test needs the same cast: admin, teacher A, teacher B, a student only in A, a student in A and B, a removed student, and an archived class. | AD-2's truth table; AD-9 | One SQL persona helper for pgTAP (users in `auth.users`, JWT claims set per test) and matching TypeScript factories for Playwright and api tests, created once in story 1.3 and extended by each epic. |
| TC-4 | Controllability | Expand-then-contract (AD-20) has no automated check. A migration that renames or drops passes every lane. | AD-20 | A `test.yml` lane, or a step in the pgTAP lane, that fails a new migration containing `DROP`, `RENAME` or a changed function signature unless the file carries an explicit contract marker. |
| TC-5 | Observability | Native-only paths are checked by hand in the Simulator: the live-update restart, the NativeAuth sheet, the Drive picker page and APNs to a closed app. Nothing reruns them after later changes. | Spine, Consistency Conventions (Tests row) | Accept for now. Record each hand check as a dated note in the story, and rerun all of them on epic 13's TestFlight build. |
| TC-6 | Observability | No client-side error reporting is named. A crash or failed live-update apply on a user's device leaves no trace. | Spine, AD-21 (operations watch cron, pg_net and job failures only) | FYI on the Free plan. Revisit with the Pro plan (spine, Deferred). |
| TC-7 | Reliability | Playwright workers share one local database per CI run. Tests that create Auth users and classes collide without unique data and cleanup. | test-quality.md (parallel-safe, unique data); story 1.3 | Factories make unique emails per test and clean up through `service_role`. pgTAP files run inside `begin … rollback`. |
| TC-8 | Reliability | Playwright's "iPhone WebKit" project is WebKit with an iPhone viewport, not iOS Safari or the Capacitor shell. A pass there does not show the Home Screen web app or the native app working. | Story 1.3; spine conventions | State this in the test plan. Home Screen and native behaviour stay in the per-role walkthrough the initiative's "Done when" requires. |

#### ✅ Testability Assessment Summary (already strong)

- **Business logic is headless.** Every rule lives in SQL (AD-1). `internal.*_as(actor, …)` functions take the actor explicitly (AD-4), so pgTAP tests every rule without a UI.
- **Edge functions are split into a pure `handler.ts` and the wiring in `index.ts`** (AD-5). `deno test` covers handlers with APNs, web push, the Auth admin API and Storage stubbed.
- **Errors are deterministic.** SQLSTATE plus a snake_case key (AD-17), so tests assert exact refusal codes, not message text.
- **Grants are checked against a fixture.** The privilege fixture and catalog test (AD-3) turn "locked by default" into one failing test per wrong grant.
- **Each environment is disposable.** CI runs its own local stack and `test.yml` reads no secrets (AD-23), so runs are reproducible and Dependabot pull requests run every lane.
- **The audit log and `internal.job_failures` give assertable trails** for access changes and scheduled-job refusals (AD-15, AD-22).
- **Hosted config is verified after each deploy.** The health check reads back Auth and Realtime settings (AD-21).
- **The account-deletion test file has one shape**, which every epic adds its cases to (AD-16).

#### Architecturally Significant Requirements (ASRs)

| ASR | Requirement | Source | Status |
| --- | --- | --- | --- |
| ASR-1 | The database is the only enforcer, and every object is locked by default | AD-1, AD-3, K5 | ACTIONABLE: persona × object access matrix in pgTAP; catalog test (story 1.6) |
| ASR-2 | Only listed staff and the bootstrap admin are admitted; no self-registration | AD-7, K3, R1, R2 | ACTIONABLE: hook payload tests (epic 2); health-check hook assertion |
| ASR-3 | One role store, written once, never updatable | AD-6, K4 | ACTIONABLE: grant and trigger tests (epic 2) |
| ASR-4 | Students are created only by `add-students`; passwords are revealed and reset only by managers | AD-8, R5, R26, K10 | ACTIONABLE: pgTAP, deno and api tests (epic 3) |
| ASR-5 | One merge gate; `test.yml` reads no secret | AD-23 | ACTIONABLE: stories 1.3 and 1.13 |
| ASR-6 | Fixed deploy order, and a health check that asserts the hosted config | AD-21, K7 | ACTIONABLE: stories 1.1 and 1.4 |
| ASR-7 | A live update never reaches a shell older than its `min_native_build` | AD-18, R23 | ACTIONABLE: stories 1.9 and 1.10 |
| ASR-8 | Migrations only expand until the old bundle is gone | AD-20 | ACTIONABLE: no check exists yet (TC-4) |
| ASR-9 | Uploads are capped at 10 MB with an exact MIME list, and paths are tied to rows | AD-13, K17 | ACTIONABLE: storage policy tests per bucket owner |
| ASR-10 | Realtime is private-only and carries ids only | AD-19 | ACTIONABLE: health check (story 1.4) and realtime policy tests (epics 2 and 5) |
| ASR-11 | One notification pipeline that honours do-not-disturb and removes dead tokens | AD-14, AD-11 | ACTIONABLE: `push_targets` pgTAP and `send-push` deno tests (epic 6) |
| ASR-12 | The audit log is append-only and complete | AD-22, R30 | ACTIONABLE: grant tests and per-action tests (epics 2, 3, 12) |
| ASR-13 | Account deletion has one root, and every effect is a cascade or a trigger | AD-16 | ACTIONABLE: the shared deletion test file (epic 2 onward) |
| ASR-14 | Errors carry a code from database to screen | AD-17 | FYI: built into story 1.5 and used by every later test |
| ASR-15 | The Free plan stays awake and is backed up weekly | K18, AD-21 | FYI: stories 1.7 and 1.8 verify by workflow run |

### 3.2 Risk Register

Derived by the step-3 procedure: one scored risk per merged gap statement, numbered by first appearance across the sources in step 2's order (initiative → spine → epic map → parity inventory → brief → tickets). The epic map, brief and ticket files add no new gap statements. Their gap statements merge into earlier rows: story 1.12's "Pull requests then run no CI" into R-005, and story 1.13's "targets every branch, ~ALL, which blocks Dependabot's own branches" into R-036. Owner means the epic or story that owns the control per the epic map. The project has one human owner, and builds run through bmad-loop.

#### High-Priority Risks (Score ≥6)

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner | Timeline |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
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
| --- | --- | --- | --- | --- | --- | --- | --- |
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
| --- | --- | --- | --- | --- | --- | --- |
| R-006 | DATA | "Today it is stored two ways" (K14). Merged with the parity data-shape conflicts table (photo, enrollment, display name, student record, grade, chat, notification read flag, history time, push token, activity owner), AD-9 "the four Firebase enrollment shapes" and AD-10 "chat stored two ways". Consequence: two features disagree about one fact. | 1 | 2 | 2 | Generated `Database` types in Vitest typecheck; the conventions' shared shapes are the only names; review at each epic's test design |
| R-016 | DATA | "Companion rows created two ways" (AD-9). Consequence: a class without a class chat or Announcements board, or with two. | 1 | 2 | 2 | pgTAP: inserting a class creates exactly one of each; the backfill covers existing classes; `unique (class_id)` holds |
| R-019 | SEC | "Faked presence; presence beyond the directory; … dots and the admin's online count disagreeing" (AD-11). Consequence: wrong online dots, or presence visible to strangers. | 1 | 2 | 2 | pgTAP: no update grant on `last_seen_at`; `app.presence` thresholds at 2 min; visibility through `app.can_see_user` |
| R-028 | TECH | "Firebase's every-error-is-`internal`; each screen parsing errors its own way" (AD-17). Merged with parity "callables rethrow every error as `internal`". Consequence: users see generic errors, and tests can't assert refusals. | 1 | 2 | 2 | Story 1.5's Vitest map and deno helper tests; ESLint rule against Supabase imports outside `api/` |
| R-039 | PERF | Free-plan limits named but unmeasured: "Revisit before the Free plan's 500 MB database, 1 GB storage or 200 concurrent Realtime connections near their limits" (spine Deferred). Consequence: Realtime or uploads fail once usage grows. | 1 | 2 | 2 | Add database size, storage size and peak Realtime connections to `job_health()` or the keep-alive output, as a later improvement (clarification Q2) |
| R-041 | TECH | "Confirm Supabase links a later Google sign-in to an existing student account with the same confirmed email" (spine Open Questions; AD-6). Consequence: a student who taps Google is refused or gets a second account. | 2 | 1 | 2 | Epic 2 spike; api test on the local stack if linking can be simulated, otherwise a hand check |

### 3.3 NFR Planning

| Category | In scope | Thresholds found in sources | Missing (UNKNOWN) | Planned evidence |
| --- | --- | --- | --- | --- |
| Security | Yes, the core of the port (K3–K5, K16, K17) | Uploads ≤ 10 MB with an exact MIME list (AD-13); signed URLs ≤ 1 h; Realtime auth cache 1 h; Dependency Review fails at moderate (AD-23); no `anon` grants (AD-3) | None | pgTAP matrices, catalog test, deno handler tests, Playwright api tests, Dependency Review, health check |
| Reliability and operations | Yes (K7, K18, AD-15, AD-21) | Keep-alive twice daily; monthly self re-enable; backup weekly with a 90-day artifact; Apple secret rerun monthly against a 6-month limit; presence heartbeat 60 s and online window 2 min; Dependabot updates live within a day | Recovery time objective; acceptable push-delivery delay | Workflow run results (stories 1.7, 1.8), `job_health()`, health check |
| Disaster recovery | Partly | Data-loss limit is implicitly 7 days (weekly backup); Storage bytes and the Vault key are excluded (accepted) | Recovery time objective | Story 1.8's restore step |
| Deployability | Yes (AD-18, AD-20, AD-21) | Fixed deploy order; `min_native_build` rule | None numeric | Deploy run, `latest.json` checks (story 1.9), migration lint (TC-4) |
| Performance | Not stated anywhere | None | Page-load and API latency targets; CSV import time for 1000 rows; send-to-push time | None planned; no k6 lane proposed without a target |
| Scalability | Free plan | 500 MB database, 1 GB storage, 200 concurrent Realtime connections (spine Deferred, as revisit points) | Expected users and peak concurrent users | Possible `job_health()` usage readout (R-039) |
| Maintainability | Yes (K13, AD-3, AD-5, AD-17) | Every table, policy, grant, function and view has pgTAP; every `handler.ts` has deno tests | Vitest coverage threshold (story 1.3 says "with coverage", no %) | `test.yml` lanes, coverage report |
| Compliance | App Store guidelines 4.8 (Sign in with Apple) and 5.1.1(v) (account deletion) | App Review must pass (initiative Done when) | Whether any student-privacy law or school policy applies (not mentioned in any source) | TestFlight walkthrough, review notes |

**Clarification items (not scored; no source gap statement):**
- Q1: Latency or performance targets. None exist. Without one, no performance lane is planned and performance stays UNKNOWN.
- Q2: Expected number of users and peak concurrent users, for judging the 200 Realtime connection ceiling.
- Q3: Vitest coverage threshold for `app/src`. Story 1.3 says "with coverage" with no number.
- Q4: Recovery time objective. How long may Fermi be down after a hosted-project loss?
- Q5: Whether a student-privacy law or school data policy applies. No source mentions one.
- Assumption: R24's web push is "best effort" by decision. It is a scope constraint, not a risk.
- Assumption: Dependabot security-update runs on `functions/` stay red until epic 13 (story 1.1). That is the out-of-scope Firebase backend, not a risk.

### 3.4 Summary

46 risks: 14 high (two at 9), 26 medium, 6 low. Categories: SEC 17, TECH 10, OPS 9, DATA 6, BUS 3, PERF 1.

- **Critical (9):** R-002 (cross-user reads) and R-012 (default grants and EXECUTE to PUBLIC). Both are mitigated by the same two tools: the privilege fixture and catalog test (story 1.6), and a persona × object pgTAP matrix that every epic extends. These become P0 in the coverage plan.
- **Epic 1 itself owns** R-005, R-029, R-032, R-033 and R-036, with stories 1.3, 1.4, 1.7, 1.9, 1.10 and 1.13 as their mitigations.
- **Spikes carry** R-040 to R-045. The tests for these wait on each spike's outcome.
- **Testability asks for story 1.3's framework run:** TC-1 (staff session on the local stack), TC-2 (time control), TC-3 (personas) and TC-4 (migration lint).

## Step 4: Coverage Plan and Execution Strategy

### Priority criteria (kept verbatim for the published plan)

- **P0:** Critical business, security, data-integrity, or compliance impact with no safe workaround
- **P1:** Core, frequent, or complex behavior with material user reach and a limited workaround
- **P2:** Secondary behavior with narrower user reach and an acceptable workaround
- **P3:** Rare, cosmetic, or experimental behavior with minimal impact and an easy workaround

**Level key for this system.** pgTAP against the local stack is **Integration**: it crosses one owned store, Postgres, through RLS, grants, triggers and `storage.objects` and `realtime.messages` policies. A call to one Supabase HTTP service (an edge function, Auth, Storage, the Management API) from Playwright's api project or a workflow step is **API**. `deno test` on a pure `handler.ts` and Vitest on `app/src` are **Unit**. Anything spanning GitHub, the hosted project, Apple, Google or a real device is **E2E**.

Test IDs follow `{EPIC}.{STORY}-{LEVEL}-{SEQ}` once each epic's design assigns stories. At system level, rows carry the risk ID only.

### 4.1 Coverage Matrix

#### P0 (Critical)

| Risk Link | Scenario | Test Level | Test Count | Owner | Notes |
| --- | --- | --- | --- | --- | --- |
| R-001 | No persona can change their own or anyone's `profiles.role`; profiles are created only by `on_auth_user_created` | Integration | 6 | Epic 2 | Mechanism: a role write grant or a second profile writer, at the Postgres boundary, so Integration. Scenarios: `UPDATE role` refused for student, teacher and admin; direct `INSERT profiles` refused; role set from `staff_invites`, bootstrap and `fermi_role` only; no policy reads `app_metadata`. Consequence: self-elevation to teacher or admin (Done when). Workaround: none. |
| R-002 | Persona × table read matrix: each persona reads exactly what AD-2's predicates allow, and nothing outside its classes | Integration | 30–60 (≈2 per table, grows per epic) | Each table's owning epic | Mechanism: an RLS read policy at the Postgres boundary, so Integration. Scenarios per table: an outsider student and an outsider teacher get 0 rows; the owner or member gets theirs; the admin's view matches AD-9. Consequence: student data leak. Workaround: none. |
| R-003 | `before_user_created` admits only listed or bootstrap Google or Apple emails | Integration | 6 | Epic 2 | Mechanism: the hook function in Postgres, so Integration. Scenarios: listed admitted; unlisted refused; Apple relay refused with its message; `email` provider refused; bootstrap admitted; email case and whitespace normalised. Consequence: a stranger gets in (Done when). Workaround: none. |
| R-004 | Persona × table write matrix: insert, update and delete refused outside ownership or membership; single-writer tables have no direct write | Integration | 30–60 (grows per epic) | Each table's owning epic | Mechanism: RLS write policies and `_as` checks at Postgres, so Integration. Parity regressions: student rewriting a roster, cross-teacher assignment, submission without enrollment, like with extra columns, deleting another's message. Consequence: data written into other classes. Workaround: none. |
| R-008 | The backup artifact holds only the age-encrypted dump; no workflow writes a secret or plaintext dump | Integration | 2 | Story 1.8 | Mechanism: the backup workflow's artifact file, one file boundary, so Integration. Scenarios: the artifact list has only the `.age` file; decrypting with the wrong key fails. Consequence: student data published in a public repo; irreversible. Workaround: none. |
| R-012 | Catalog test: every table, column, function and view grant matches the privilege fixture; `anon` has nothing; `internal.*` has no `authenticated` EXECUTE | Integration | 1 catalog test + 1 negative case per object kind (≈4) | Story 1.6, then every migration | Mechanism: Postgres default grants, so Integration. Scenarios: a function without a fixture entry fails; EXECUTE granted to `anon` fails; a definer view in `public` fails (story 1.6 verify). Consequence: full impersonation through `_as`. Workaround: none. |
| R-018 | After `remove_student`, every class-scoped read and write by that student is refused (chat, groups, boards, grades, points) | Integration | 8 (2 per epic 4, 5, 7, 8) | Epic 3, plus epics 4, 5, 7, 8 | Mechanism: predicate results after the enrollment row goes, so Integration. Rows stay visible to the teacher. A Realtime case asserts payloads carry ids only. Consequence: a removed student keeps class data. Workaround: none. |
| R-020 | `authenticated` cannot select `profiles.email`; `app.visible_email` follows D20 for every persona pair; `app.can_see_user` clauses | Integration | 10 | Epic 2 (shape), epics 3, 5 (clauses) | Mechanism: column grants and a definer function, so Integration. Scenarios: classmate gets null; student sees their teachers and the admin; teacher sees their students and the admin; admin sees all. Consequence: minors' emails exposed. Workaround: none. |
| R-023 | Storage policies per bucket and persona: insert, read, update and delete as AD-13's table; path prefix matches the row's scope | Integration | 16 (4 buckets × 4 operations) | Epics 2, 4, 5 | Mechanism: `storage.objects` RLS, so Integration. Scenarios: classmate reads a submission (refused); student updates after submit (refused); a row path pointing at another class (refused). Consequence: work copied or swapped. Workaround: none. |
| R-026 | `NN_account_deletion.sql`: deleting the `auth.users` row removes or nulls every dependent row, queues files, deletes the Vault secret and the `staff_invites` row | Integration | 1 case per foreign key, bucket and secret (≈12 by epic 12) | Epic 2 (file), every epic adding a foreign key | Mechanism: cascades and `AFTER DELETE` triggers, so Integration. Consequence: data kept after deletion (App Store 5.1.1(v)); a deleted teacher signs back in. Workaround: none. |
| R-027 | `internal.delete_account_as` permits exactly AD-16's matrix | Integration | 6 | Epic 12 | Scenarios: admin deletes others but not self; teacher deletes self after cascade; teacher with an open request deletes the student; without a request refused (`no_removal_request`); student self refused. Consequence: irreversible wrong deletion. Workaround: none (backup is up to 7 days old). |
| R-032 | The health check fails on hosted Auth or Realtime drift | API | 5 | Story 1.4; epic 2 | Mechanism: Management API read-back, one HTTP service, so API. Scenarios: anonymous sign-ins on (fail, story 1.4 verify); sign-up on before the hook (fail); `private_only` missing (fail); email sign-in off (fail); after epic 2, hook URI mismatch (fail). Consequence: anonymous or unlisted users authenticated; K7 and AD-21 mandate the control. Workaround: none. |

#### P1 (High)

| Risk Link | Scenario | Test Level | Test Count | Owner | Notes |
| --- | --- | --- | --- | --- | --- |
| R-005 | A pull request with one failing ESLint rule, Vitest test, pgTAP test and Playwright test turns each job and Test Summary red; reverting turns it green | E2E | 1 (4 deliberate failures) | Story 1.3 | Mechanism: CI on pull requests spans GitHub Actions and every lane, so E2E. Consequence: regressions merge unseen; other risks' harm lasts longer. Workaround: stories' hand `verify` steps until 1.3. |
| R-007 | A manual keep-alive run is green, runs a real query, and the monthly re-enable call succeeds | API | 2 | Story 1.7 | Mechanism: a workflow calling the hosted Supabase API, so API. Consequence: the whole app is down while paused. Recovery path: not stated in sources (unresolved). |
| R-010 | TestFlight build per-role walkthrough with demo accounts; Apple sign-in parity with Google | E2E | 3 roles | Epic 13 | Mechanism: a shipped build plus App Review, so E2E. Consequence: the iOS update is rejected. Workaround: the website and Home Screen web app (D9). |
| R-011 | One truth-table file per `app.*` predicate asserting AD-2's table, archived and removed columns included | Integration | ≈11 predicates × 3 cases | Epics 2, 3, 5 | Consequence: R-002 and R-004's harm, which carry the P0 cases. |
| R-013 | Single-writer tables have no direct write grant; a refused `_as` call leaves no partial rows | Integration | 1 per single-writer function | Every epic | Consequence: inconsistent rows. Workaround: a corrective call by the owner. |
| R-014 | `add-students` per-row outcomes: staff, bootstrap, teacher or admin email refused; existing student enrolled keeping password and name; new student created; admin works on any class; 1000-row CSV in 10 chunks | API | 7 | Epic 3 | Mechanism: an edge function plus the Auth admin API, one HTTP service, so API. Handler branches are also covered by `deno test`. Consequence: wrong accounts or changed passwords. Workaround: Show or Reset password (R26), admin delete (R15). |
| R-017 | `internal.send_message_as` pairing matrix for typed and scheduled sends: student–student refused, teacher–untaught student refused, admin–teacher allowed | Integration | 6 | Epic 5 | Consequence: unsupervised pairs chat. Workaround: limited; users already share the directory. |
| R-021 | Storage upload of 10 MB + 1 byte refused; SVG refused; `.jpg` as `image/jpeg` accepted | API | 3 per bucket kind | Epic 2 (pattern), bucket owners | Mechanism: Storage HTTP enforcing bucket config, so API. Consequence: storage fills; scriptable files stored. |
| R-022 | The signed-URL helper in `app/src/api/` never asks for more than 3600 s | Unit | 2 | Epic 2 | Mechanism: an expiry parameter in client code, no boundary, so Unit. Consequence: a forwarded link exposes a file long after. |
| R-024 | `internal.push_targets` per kind skips DND and non-members; `send-push` deletes on 410, 404 and web-push 410, keeps 400; sign-out unregisters | Integration | 10 | Epic 6 | Mechanism: recipient and target selection in Postgres, so Integration. Handler status cases run in `deno test`. Consequence: pushes to the wrong device or person. Workaround: the inbox stays correct. |
| R-025 | A due row that is refused is marked `failed` with its key, writes `job_failures`, and is not retried; the worker takes the run time as a parameter | Integration | 4 per job (≈3 jobs) | Epics 2, 4, 5 | Consequence: posts after access is lost, or jobs loop. |
| R-029 | `latest.json` skip when `min_native_build` > installed; App Store banner; the `MIN_NATIVE_BUILD` check fails a plugin added without a raise | E2E | 4 | Stories 1.9, 1.10 | Mechanism: a release control for an installed build (shipped shell + Workers site), so E2E. Simulator hand check for the shell part. Consequence: broken iOS app. Workaround: the website (D9). |
| R-030 | `realtime.messages` policies: `chat:` read only for members, client writes only Presence; `user:` only self | Integration | 6 | Epics 2, 5 | Consequence: ids leak to non-members. |
| R-031 | The previous bundle's api tests pass against the new migrations | E2E | 1 job | Epic 1 (TC-4), every epic | Mechanism: a migration and an older client are two deployables, so E2E. Consequence: older iOS builds break. Workaround: restart onto the live update. |
| R-033 | `job_health()` returns failure when a `job_failures` row, a failed `cron.job_run_details` row or a non-2xx `net._http_response` exists; keep-alive then fails | Integration | 4 | Story 1.7 | Consequence: reminders, messages and sweeps silently stop. |
| R-035 | Each AD-22 action writes exactly one `audit_events` row in the same transaction; no update or delete grant; reads by role | Integration | ≈12 (one per action) + 3 read cases | Epics 2, 3, 12 | Consequence: R30's trail has holes that can't be rebuilt. |
| R-036 | Ruleset targets main only and requires exactly Test Summary and Dependency Review; a Dependabot PR outside the native group auto-merges after both pass; a native-group PR does not; a moderate advisory blocks | E2E | 4 | Story 1.13 | Mechanism: GitHub ruleset, workflows and Dependabot, so E2E. Consequence: untested or vulnerable code deploys within a day. Workaround: manual PR review. |
| R-038 | Every migration applies on CI's fresh local stack and every pgTAP test passes before merge | Integration | 1 job | Story 1.3 | Consequence: a broken migration on the only hosted project. Recovery: weekly backup (AD-21). |
| R-040 | On the hosted project, an admin-API-created user is not refused by `before_user_created` | API | 1 | Epic 2 spike | Consequence: no student can be created (R5 blocked). Recovery: unresolved until the spike. |
| R-042 | Sign in with Apple through the NativeAuth sheet completes and lands a listed teacher on the dashboard | E2E | 1 (hand check) | Epic 2 spike | Consequence: Apple sign-in broken on iOS (K11). Workaround: Google. |
| - | Tracer path: admin lists a teacher → teacher creates class and adds a student → student signs in with the sheet's password → teacher messages → push to a closed app | E2E | 1 | Epic 13 closing suite | Initiative "Tracer path". Playwright for the web part; the push leg is a hand check. |
| - | The deployed shell shows the commit id of the push | E2E | 1 | Story 1.1 | Story 1.1 verify; becomes the post-deploy smoke. |

#### P2 (Medium)

| Risk Link | Scenario | Test Level | Test Count | Owner | Notes |
| --- | --- | --- | --- | --- | --- |
| R-009 | The weekly dump restores into a throwaway database, and row counts match | Integration | 1 | Story 1.8 | Consequence: rare project loss. Workaround for passwords: teachers reset (AD-21). Files: unresolved (accepted). |
| R-015 | Each class-scoped `_as` function and write policy refuses an archived class | Integration | 1 per writer (≈10) | Epics 3, 4, 5, 7, 8 | Workaround: the teacher removes the stray item. |
| R-016 | Inserting a class creates exactly one class chat and one Announcements board; backfill covers existing classes | Integration | 2 per companion | Epics 5, 7 | Workaround: rerun the backfill. |
| R-028 | The error map turns each SQLSTATE and key into text; the edge helper returns real status and `{error:{code,message}}` | Unit | 6 | Story 1.5 | Consequence: generic error text. |
| R-034 | Apple sign-in on hosted works after the monthly `apple-secret.yml` run | E2E | 1 | Epic 2 | Workaround: Google sign-in (R1). |
| R-037 | Hand-check notes for each native-only path, rerun on TestFlight | E2E | 4 paths | Epics 1, 2, 4, 6, 13 | Workaround: the website. |
| R-043 | A student JWT calling Auth's update-user to change the password is refused | API | 1 | Epic 2 spike, epic 3 | Workaround: the teacher resets the password (R26). |
| R-044 | The Drive picker page in the NativeAuth sheet returns a file that uploads | E2E | 1 (hand check) | Epic 4 spike | Workaround: attach from the device. |
| R-045 | A sandbox APNs push reaches a closed app in the Simulator, or on a development build | E2E | 1 (hand check) | Epic 6 spike | Fallback stated in the spine. |
| R-046 | The award function refuses non-integer and out-of-range points with `22023` | Integration | 3 | Epic 8 | Workaround: undo (R7). |
| - | Landing page says who Fermi is for, shows Home Screen steps and links the App Store (R25) | Component | 2 | Epic 2 | |

#### P3 (Low)

| Risk Link | Scenario | Test Level | Test Count | Owner | Notes |
| --- | --- | --- | --- | --- | --- |
| R-006 | Typecheck against the generated `Database` types; shared shape names only | Unit | (typecheck lane) | Every epic | Workaround: a code fix. |
| R-019 | No update grant on `last_seen_at`; `app.presence` green, yellow or red at the 2-minute edge | Integration | 3 | Epic 2 | Cosmetic. |
| R-039 | `job_health()` or keep-alive reports database size, storage size and Realtime peak | Integration | 1 | Later (clarification Q2) | No threshold yet. |
| R-041 | A student signing in with Google under their school email lands as a student | E2E | 1 (hand check) | Epic 2 spike | Workaround: password sign-in. |

**Band check:** 12 P0, 20 P1 risk rows plus 2 journey rows, 10 P2 risk rows plus 1 requirement row, 4 P3. 46 risk rows, one per risk, none under two headings. P0 is limited to direct security, data-integrity or compliance harm with no workaround. Risks whose harm is another risk's (R-005, R-011, R-036) are P1.

### 4.2 NFR Coverage and Evidence Plan

| NFR | Validation | Level or tool | Evidence for `nfr-assess` | Gaps |
| --- | --- | --- | --- | --- |
| Security | R-001 to R-004, R-008, R-012, R-017, R-018, R-020 to R-023, R-026, R-027, R-030, R-032 rows | pgTAP, Playwright api, deno, Dependency Review | `test.yml` run logs per lane; catalog test output; health-check run | None |
| Reliability and operations | R-007, R-024, R-025, R-033 rows | pgTAP, workflow runs | keep-alive and `job_health()` run history | Recovery time objective UNKNOWN (Q4) |
| Disaster recovery | R-009 row | backup workflow restore step | `backup.yml` run with restore step green | Recovery time objective UNKNOWN (Q4); the 7-day data-loss limit is implied, not stated |
| Deployability | R-029, R-031, R-036, R-038 rows; story 1.1 smoke | `test.yml` checks, deploy runs, Simulator | deploy run logs; `latest.json`; hand-check notes | Migration lint does not exist yet (TC-4) |
| Performance | none | none | none | **Blocker for any perf lane:** no target exists (Q1). No k6 lane is planned. |
| Scalability | R-039 row | `job_health()` readout | keep-alive output | User counts UNKNOWN (Q2) |
| Maintainability | lanes themselves; R-028 | ESLint, typecheck, Vitest coverage | coverage report | Coverage threshold UNKNOWN (Q3) |
| Compliance | R-010, R-026 rows | TestFlight walkthrough, deletion tests | review notes, deletion test file | Student-privacy law in scope UNKNOWN (Q5) |

### 4.3 Execution Strategy

- **Every PR and push (`test.yml`):** ESLint and typecheck, Vitest with coverage, pgTAP on a local stack (CLI 2.122.0), `deno test` over `supabase/functions`, Playwright on Desktop Chrome and iPhone WebKit (UI and api projects), burn-in of changed specs, and the "every test ran" check. All P0–P3 automated rows run here. Target: under 15 minutes. pgTAP and deno are fast; Playwright is the long pole.
- **Nightly:** nothing at first. Add a nightly full Playwright repeat only if burn-in starts missing flaky specs.
- **Scheduled (existing workflows, not `test.yml`):** keep-alive twice daily (R-007, R-033), backup weekly with its restore (R-009), `apple-secret.yml` monthly (R-034).
- **After each deploy:** the health check (R-032) and the commit-id smoke.
- **By hand, per native story and again on TestFlight:** R-029's shell part, R-037, R-042, R-044, R-045, R-041, and the tracer path's push leg.

### 4.4 Resource Estimates (ranges, whole initiative)

| Priority | Effort | What it is |
| --- | --- | --- |
| P0 | ~45–80 hours | The read and write matrices across about 30 tables, the catalog test, storage, deletion and health-check cases |
| P1 | ~35–60 hours | Predicate truth tables, pipeline, jobs, merge-gate and CI proofs, spikes' checks |
| P2 | ~12–25 hours | Archived refusals, companions, error map, hand checks |
| P3 | ~3–8 hours | Typecheck, presence edges, usage readout |
| **Total** | **~95–175 hours** | Spread over 13 epics; the framework run (story 1.3) is about 8–16 hours of that |

### 4.5 Quality Gates

- P0 pass rate = 100%
- P1 pass rate ≥ 95% (a waived failure carries a dated reason)
- Every high risk (≥ 6) has its mitigation in place before epic 13's App Store submission; R-002 and R-012 before any epic's tables reach hosted
- Coverage ≥ 80% lines for `app/src/api/` and stores (proposed; the rule allows adjustment. UI components get no threshold because the client is thin by design, AD-1). **Pending owner answer (Q3).**
- NFR evidence identified for every in-scope category (table 4.2); performance stays UNKNOWN until Q1 is answered
- PASS, CONCERNS or FAIL per NFR is decided later by `bmad-tea-nfr` from evidence, not here

## Step 5: Outputs

- **Execution mode:** sequential. Config `auto`, but this session spawns no helper agents unless the owner asks.
- **Outputs:**
  - `_bmad-output/test-artifacts/test-design/test-design-architecture.md`
  - `_bmad-output/test-artifacts/test-design/test-design-qa.md`
  - `_bmad-output/test-artifacts/test-design/Fermi-handoff.md`
- **Validation (run on the saved files after the last edit):** 46 unique risk IDs in each document; every Score = Probability × Impact; band cell counts 9, 8 and 7; one coverage row per risk with one canonical level; priorities and levels identical to step 4; handoff P×I, priority and level identical; register identical to step 3; no code in the architecture doc; no scored table in a blockquote or under an Example, Illustration or Reference heading; every test ID cited in the architecture doc and handoff exists in the QA doc.
- **Known deviation:** the architecture doc is 365 lines against the checklist's ~150–200 target. The 46-row register and 14 required mitigation plans account for most of it.
- **Open:** clarifications Q1–Q5; assumptions R-040 and R-043 (UNVERIFIED until epic 2's spikes).
