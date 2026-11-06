---
title: Rubric review of the 2026-11-06 update — Capacitor Supabase Port architecture spine
reviews: architecture-capacitor-supabase-port.md, epic-map-capacitor-supabase-port.md (working-tree diff against eb7fd06)
against: initiative-capacitor-supabase-port.md (R1-R30, K1-K18), tickets/tickets.toml, .memlog.md
date: 2026-11-06
---

# Rubric review of the 2026-11-06 update

**Verdict: not ready to bind epics yet.** The amendment does what the memlog's 2026-11-06 decisions asked: the admin's roster powers, the presence split, the deletion test file, the extensions and the health-check split all land in both the spine and the epic map, with the same owners. But two of the amended parts open new gaps. The health-check split leaves the hosted project open to self-sign-up between epic 1 and epic 2, and the admin roster screen has no read path that epic 3 is told to build. Three medium issues follow. None needs a user decision reopened.

Inputs read in full: the spine (447 lines), the epic map (74), the ticket (141), tickets.toml, the memlog tail, and the diff (`git diff` on the architecture folder: 3 files, 33 insertions, 26 deletions).

## Checklist results

| Check | Result |
| --- | --- |
| Divergence points fixed, none missed | Mostly. Missed: the admin's read path to any roster (H2), and who owns the audit-log read policy and screens (M4) |
| Each AD's Rule is enforceable and prevents its divergence | No for AD-21 after the split (H1), AD-16 (M1), AD-8 (M3) |
| Nothing under Deferred lets two epics diverge | Pass. Deferred did not change. The ticket's Notes defer "audit log screens" and "Settings owner" to refinement, outside the spine; see M4 |
| Covers R1-R30, K1-K18 | Pass on presence: every id is cited (`grep -c` per id ≥ 1). K1, K2, K8, K9 and K10 appear only in the frontmatter `binds` list (L2) |
| Epic map and ADs name the same owner | Pass for every amended object (AD-8, AD-11, AD-16, AD-21, AD-22). Small drift in L1 |
| Ordering | One new break: the deletion test's secret case (M2). Otherwise every amended "Uses" points to an earlier epic |

## High

### H1. The health-check split blesses a hosted project with open sign-up and no hook

Concerns AD-21: "Health check: … fails unless email sign-in is on, anonymous sign-ins are off and Realtime is private-only. Epic-invite-sign-in adds the check that the hook is registered, in the change that creates the hook." And the epic map row 1: "the config health check, without the hook assertion".

AD-7's Auth config is `[auth] enable_signup = true` and `[auth.email] enabled = true`. The `before_user_created` hook is the only thing that refuses email-provider sign-ups and unlisted Google or Apple accounts. Epic 1 pushes the hosted Auth config, and the hook does not exist until epic 2. So from epic 1's first deploy until epic 2's, anyone holding the public anon key (it ships in the web bundle) can call `/auth/v1/signup` with an email and password and get an Auth user. The health check now passes in that state on purpose. `on_auth_user_created` does not exist yet either, so these users get no `profiles` row, and nothing removes them when epic 2 lands. That breaks K3 ("nobody registers with an email and password") on the hosted project and leaves orphan Auth users behind.

Before the amendment the check would have failed at epic 1, so splitting it was right. The gap is that nothing replaces the hook as the gate until the hook exists.

**Fix:** in AD-21, have epic 1 push `[auth] enable_signup = false` and assert it in the health check. Epic 2 flips it to `true` in the same change that registers the hook and adds the hook assertion. Admin-API creation still works with sign-up off, and no one needs Google sign-in before epic 2. Add the flip to the epic map's "Health check | 1 → 2" seam.

### H2. The admin roster screen has no read path, and epic 12 "adds only the screen"

Concerns the epic map seam: "`add-students`, `enroll_student_as`, `reveal_student_password` and `reset-student-password` accept the admin for any class from epic 3 on; epic 12 adds only the screen (AD-8)". And AD-9: "Reads stay: teachers for their classes, students for their own records."

To show any class's roster, the admin must read `classes` and `enrollments` for classes they do not teach, plus each row's waiting-or-connected status (R26). No AD gives the admin `SELECT` on `classes` or `enrollments`. AD-9 names only teachers and students. The roster status source is not specified anywhere: the map gives epic 3 "roster status", but the status lives in `auth.users`, which the client cannot read. If epic 3 builds status as a teaches-only function, epic 12 either edits epic 3's policies and functions (an ownership break) or cannot list the roster. The seam promises epic 12 needs nothing more, but only the four write and reveal paths are listed.

**Fix:** in AD-8 or AD-9, state that the admin reads every class, enrollment and roster status. Name the status reader, for example `roster_status(class)`, allowed for `app.teaches` or `app.is_admin`, owned by epic 3. Add these to the "Admin roster" seam.

## Medium

### M1. AD-16 says the admin also needs an open removal request to delete a student

Concerns AD-16: "A teacher of that student, or the admin, can then delete the account, and never without an open request (`no_removal_request`)." The bullet above it says "the admin deletes anyone but themselves". R29 restricts only "a teacher of that student". Read literally, `delete-account` refuses the admin deleting a student who made no request, which contradicts R15 and the admin bullet. R29 and R28 were bound to this AD in the amendment, so the contradiction now sits on two requirements.

**Fix:** "A teacher of that student can then delete the account, and never without an open request (`no_removal_request`). The admin needs none."

### M2. The deletion test's "secret" case cannot pass before epic 12

Concerns AD-16 Tests: "Each later epic that adds a foreign key to `profiles`, a bucket or a secret adds its case". And "What deletion removes: the person's `staff_invites` row, their Vault secret and the Auth user". AD-16 makes `delete-account` (epic 12) remove the Vault secret. Epic 3 adds `student_credentials` and its secret, but a test that deletes the user and asserts that the Vault secret is gone fails until epic 12 ships. So epic 3 either writes a failing test, writes no case, or adds the cleanup on its own terms. That is the "depends on a later epic" pattern this amendment was meant to remove. The same applies to the `staff_invites` row: it is keyed by email, not a foreign key, so no cascade removes it.

**Fix:** have epic 3 remove the secret in an `AFTER DELETE` trigger on `student_credentials`, the same pattern as `storage_deletions`, so the cascade cleans it and epic 3's case passes. Otherwise, move the secret case to epic 12.

### M3. "Teaches or admin" is now restated in four places, outside schema `app`

Concerns AD-8: "checks `app.teaches` or `app.is_admin`, and `app.class_open`" and "each allowed for `app.teaches_student` or the admin". AD-2 says each relationship check is written once in `app`. The amendment adds a composite rule that `add-students`, `enroll_student_as`, `reveal_student_password` and `reset-student-password` each re-derive, and two of those are edge functions. A function that drops the admin clause is exactly the divergence the memlog names ("the admin path refused by a teaches-only check"). Separately, `add-students` creates the Auth user before `enroll_student_as` runs. The only class check named in AD-8 therefore fires after the account exists, and a caller refused there leaves a student outside any roster, which AD-8's Prevents forbids.

**Fix:** add `app.manages_class(u, class)` and `app.manages_student(u, s)` to AD-2's table, owned by epic 3. Require `add-students` to call an `internal.*_as` pre-check per class before any `createUser` call (AD-5).

### M4. Ownership of the audit log's read policy and screens is still open

Concerns AD-22: "a teacher reads events for their classes and their students", owned by "epic-invite-sign-in". The teacher read policy needs `app.teaches` and `app.teaches_student`, which epic 3 creates later. Epic 2 cannot write that policy, and AD-2's stub mechanism covers only `app.can_see_user`. R30's read side ("the admin reads every event, a teacher reads those for their classes") has no screen owner in the map. tickets.toml splits R30 across epics 2, 3 and 12 by write action only. The ticket's Notes defer "audit log screens" to refinement, which leaves three epics able to each build one, or none.

**Fix:** epic 2 ships the admin-only read policy. Epic 3 adds the teacher policy (state this in the map's Audit log seam). Name one epic, likely 12 for the admin and 3 for teachers, as the owner of each read screen.

## Low

- **L1. Epic 12 depends on epic 5 for the wrong reason.** The map says epic 12 uses "presence dots (5)" and tickets.toml says "presence for the online count". After the AD-11 split, the online count reads `profiles.last_seen_at`, which epic 2 owns. This is harmless for ordering, but the stated dependency no longer matches the owner.
- **L2. Some constraints are cited only in frontmatter.** K1, K2, K8, K9 and K10 appear only in `binds` (one hit each). K10 is substantively enforced by AD-8 and the Email convention row, so cite it there. The others are scope constraints with no architectural home, which is acceptable.
- **L3. The extensions rule is garbled.** "no other epic enables an extension they need" can be read as forbidding or as permitting. It also does not say who handles `pgtap` (tests) or confirms `supabase_vault` (epics 2 and 3). Suggested wording: "Only epic-platform-baseline enables extensions: `pg_cron`, `pg_net`, `pgtap`; `supabase_vault` is on by default and asserted by the health check."
- **L4. Binds lines lag the capability map.** AD-14's Binds lacks R27 and R29, though it owns `due_reminder` and `removal_request`. AD-15's Binds still says "due reminders" rather than R27 and omits epic 2's `sweep-storage` job, although the memlog says epics 2, 4 and 5 schedule jobs.
- **L5. Staff-list writer unnamed.** The epic map gives epic 2 "the admin's add/remove teacher email screen" and epic 12 "staff list management". The memlog decision was that epic 12 "shows the same list". Name the single writer function (for example `add_staff_invite` and `remove_staff_invite`, epic 2), which refuses `email_is_student` and calls `internal.audit`. Otherwise epic 12's management screen can grow a second write path.
- **L6. AD-8's Prevents was not updated.** The memlog records the amendment's Prevents ("the admin path refused by a teaches-only check, or a second admin-only write path"), but AD-8's Prevents line is unchanged.
