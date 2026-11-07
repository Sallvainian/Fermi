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
  - .claude/skills/bmod-tea/knowledge/adr-quality-readiness-checklist.md
  - .claude/skills/bmod-tea/knowledge/nfr-criteria.md
  - .claude/skills/bmod-tea/knowledge/test-levels-framework.md
  - .claude/skills/bmod-tea/knowledge/risk-governance.md
  - .claude/skills/bmod-tea/knowledge/test-quality.md
  - .claude/skills/bmod-tea/knowledge/test-priorities-matrix.md
  - .claude/skills/bmod-tea/knowledge/playwright-cli.md
---

# Test Design for QA: Capacitor Supabase Port

**Purpose:** The test recipe for the port: what to test, at which level, in which lane, and what the builds must provide first. Story 1.3's `bmad-tea-framework` run follows this document. Each later epic's `bmad-tea-test-design` run refines its part.

**Date:** 2026-11-06
**Author:** Murat (TEA Master Test Architect), for Sallvainian
**Status:** Draft
**Project:** Fermi

**Related:** `test-design-architecture.md` for the full risk register, testability concerns TC-1 to TC-8, and the mitigation plans.

---

## Executive Summary

**Scope:** Every test kind the port needs across its 13 epics: pgTAP on the local Supabase stack, `deno test` for edge-function handlers, Vitest for `app/src`, Playwright (Desktop Chrome and iPhone WebKit, UI and api projects), workflow-run checks, and dated hand checks for native-only paths.

**Risk Summary:**

- Total risks: 46 (14 high-priority score ≥6, 26 medium, 6 low)
- Critical categories: SEC (17 risks, 8 of the 14 high) and OPS (3 of the 14 high)

**Coverage Summary:**

- P0 tests: ~165 (access matrices, grants, admission, deletion, config)
- P1 tests: ~136 (predicates, pipeline, jobs, merge gate, native release controls)
- P2 tests: ~34 (archived refusals, error map, spikes' hand checks)
- P3 tests: ~6 (typecheck, presence edges, usage readout)
- **Total:** ~341 tests (~2.5–4.5 weeks of one person's full-time effort, spread over the epics)

---

## Not in Scope

| Item | Reasoning | Mitigation |
| --- | --- | --- |
| **The Firebase backend (`functions/`, Firestore rules)** | Being retired; "Out: fixing or hardening the Firebase backend" (initiative Boundaries) | Removed by epic 13; its red Dependabot security runs are expected until then (story 1.1) |
| **Android, macOS, Windows and Linux** | D1, D5 | None needed |
| **Moving Firebase users or data** | D2, K8 | Fresh start; nothing to test |
| **Performance and load testing** | No latency or throughput target exists (Q1) | Revisit when the owner sets a target; R-039 reports Free-plan usage |
| **Production APNs** | First checked on epic 13's TestFlight build (spine conventions) | Sandbox APNs checked by epic 6's spike (R-045) |
| **Per-kind push switches and data purging** | Spine Deferred | None needed |

---

## Dependencies & Test Blockers

**CRITICAL:** these must exist before epic 2's tests can be written. The architecture doc's Quick Guide has the reasoning.

### Backend/Architecture Dependencies (Pre-Implementation)

1. **TC-1 Staff session on the local stack (decided rule)** - story 1.3 - before epic 2
   - Decided 2026-11-06: any helper that signs in a teacher or the admin lives only in test code and runs only against the local Supabase stack. It creates the user and gets a session with that stack's own `service_role` key, and it refuses to run when the Supabase URL is not local (`127.0.0.1` or `localhost`). Nothing in `app/`, `supabase/functions/` or the hosted Supabase config adds a test-only way to sign in; the hosted project keeps Google and Apple as the only staff sign-in. Real Google and Apple sign-in is checked by hand in the Simulator in epic-invite-sign-in, not by automated tests. Because the helper creates users through the admin API, which bypasses `before_user_created`, browser tests signed in this way never exercise admission; admission is covered by P0-003 (R-003) and those hand checks.
   - Required check: a unit test proves the helper throws for a non-local Supabase URL
   - Without the helper, no Playwright test can act as staff
2. **TC-3 Persona cast** - story 1.3 - before epic 2
   - A pgTAP helper that creates admin, teacher A, teacher B, a student only in A, a student in A and B, a removed student and an archived class, and sets JWT claims per test
   - Every access matrix (P0-002, P0-004) depends on it
3. **TC-2 Run time as a parameter** - epic 2 (first cron job) - before the first scheduled job
   - Cron workers accept the run time so tests never wait
4. **TC-4 Migration lint** - story 1.3 or 1.11 - epic 1
   - Fails a new migration with `DROP`, `RENAME` or a changed function signature unless it carries a contract marker (R-031)
5. **Spikes** - epic 2 (R-040 to R-043), epic 4 (R-044), epic 6 (R-045)
   - Each spike's outcome sets the shape of its tests

### QA Infrastructure Setup (Pre-Implementation)

1. **Test data factories** - story 1.3
   - TypeScript factories for users, classes and enrollments, with faker-unique emails, created through `service_role` on the local stack and cleaned up after each test
   - pgTAP files run inside `begin … rollback`, so they leave nothing behind
2. **Test environments**
   - Local: `supabase start` (CLI 2.122.0), `supabase test db`, `deno test`, Vitest, Playwright against the built shell
   - CI: the same, as `test.yml` lanes on a fresh local stack per run, reading no secret (AD-23)
   - Staging: none (spine Structural Seed). Hosted checks are the post-deploy health check and the scheduled workflows.

**Factory pattern (Playwright Utils, as AGENTS.md will require):**

```typescript
import { test } from '@seontechnologies/playwright-utils/api-request/fixtures';
import { expect } from '@playwright/test';
import { faker } from '@faker-js/faker';

// Runs against the local stack. The anon key comes from `supabase status` in CI, not from a secret.
test('@P0 @API @Security an email-and-password sign-up is refused', async ({ apiRequest }) => {
  const { status, body } = await apiRequest({
    method: 'POST',
    path: '/auth/v1/signup',
    headers: { apikey: process.env.SUPABASE_ANON_KEY ?? '' },
    body: {
      email: faker.internet.email().toLowerCase(),
      password: faker.internet.password({ length: 16 }),
    },
  });

  expect(status).toBeGreaterThanOrEqual(400);
  expect(status).toBeLessThan(500);
  expect(body).not.toHaveProperty('access_token');
});
```

The exact refusal status for a disabled sign-up and for a hook refusal is UNVERIFIED. Epic 2 pins it once the hook exists.

---

## Risk Assessment

Full descriptions, scores and mitigations are in the architecture doc. This table maps each risk to its planned coverage.

### High-Priority Risks (Score ≥6)

| Risk ID | Category | Description | Score | QA Test Coverage |
| ------- | -------- | ----------- | ----- | ---------------- |
| R-002 | SEC | Cross-user private reads | 9 | P0-002 (Integration) |
| R-003 | SEC | Unlisted Google or Apple account, or email sign-up, admitted | 6 | P0-003 (Integration) |
| R-004 | SEC | Cross-scope writes | 6 | P0-004 (Integration) |
| R-005 | TECH | No tests or CI on pull requests yet | 6 | P1-001 (E2E) |
| R-010 | BUS | App Review rejects the iOS update | 6 | P1-003 (E2E) |
| R-012 | SEC | Default grants (EXECUTE to PUBLIC, definer views) | 9 | P0-006 (Integration) |
| R-018 | SEC | Removed student keeps access | 6 | P0-007 (Integration) |
| R-020 | SEC | Emails exposed beyond D20 | 6 | P0-008 (Integration) |
| R-023 | SEC | Storage scope (submissions, paths) | 6 | P0-009 (Integration) |
| R-029 | TECH | Live update reaches an incompatible native shell | 6 | P1-012 (E2E) |
| R-032 | OPS | Hosted Auth or Realtime config drift | 6 | P0-012 (API) |
| R-033 | OPS | Silent job failures | 6 | P1-015 (Integration) |
| R-036 | OPS | Merge gate bypassed | 6 | P1-017 (E2E) |
| R-042 | SEC | Apple sign-in through the NativeAuth sheet fails | 6 | P1-020 (E2E) |

### Medium/Low-Priority Risks (Score 1-5)

| Risk ID | Category | Description | Score | QA Test Coverage |
| ------- | -------- | ----------- | ----- | ---------------- |
| R-001 | SEC | Role self-change | 3 | P0-001 (Integration) |
| R-006 | DATA | One concept stored two ways | 2 | P3-001 (Unit) |
| R-007 | OPS | Free project pauses | 4 | P1-002 (API) |
| R-008 | SEC | Data or secrets committed to the public repo | 3 | P0-005 (Integration) |
| R-009 | DATA | Backup excludes Storage bytes and the Vault key | 4 | P2-001 (Integration) |
| R-011 | TECH | Relationship predicates drift between epics | 4 | P1-004 (Integration) |
| R-013 | DATA | Second write path or half-applied change | 4 | P1-005 (Integration) |
| R-014 | DATA | Student-account creation integrity | 4 | P1-006 (API) |
| R-015 | BUS | Writes into an archived class | 4 | P2-002 (Integration) |
| R-016 | DATA | Companion rows missing or doubled | 2 | P2-003 (Integration) |
| R-017 | SEC | Chat pairing bypassed on some path | 3 | P1-007 (Integration) |
| R-019 | SEC | Presence faked or over-exposed | 2 | P3-002 (Integration) |
| R-021 | SEC | Upload size or type trusts the client | 4 | P1-008 (API) |
| R-022 | SEC | Long-lived signed links | 4 | P1-009 (Unit) |
| R-024 | OPS | Notifications reach the wrong person or device | 4 | P1-010 (Integration) |
| R-025 | OPS | Scheduled jobs bypass checks or loop | 4 | P1-011 (Integration) |
| R-026 | DATA | Account deletion leaves orphans | 4 | P0-010 (Integration) |
| R-027 | SEC | Wrong person deletes an account | 3 | P0-011 (Integration) |
| R-028 | TECH | Error codes lost | 2 | P2-004 (Unit) |
| R-030 | SEC | Realtime topics exposed or forged | 4 | P1-013 (Integration) |
| R-031 | TECH | Migration breaks older clients | 4 | P1-014 (E2E) |
| R-034 | OPS | Apple client secret expires | 4 | P2-005 (E2E) |
| R-035 | OPS | Audit log incomplete | 4 | P1-016 (Integration) |
| R-037 | TECH | Native-only paths checked only by hand | 4 | P2-006 (E2E) |
| R-038 | OPS | No staging and no rollback | 3 | P1-018 (Integration) |
| R-039 | PERF | Free-plan ceilings unmeasured | 2 | P3-003 (Integration) |
| R-040 | TECH | Hook fires on admin-API creation | 4 | P1-019 (API) |
| R-041 | TECH | Google sign-in not linked to the student account | 2 | P3-004 (E2E) |
| R-043 | SEC | Student changes own password through the Auth API | 4 | P2-007 (API) |
| R-044 | TECH | Drive picker fails on iOS | 4 | P2-008 (E2E) |
| R-045 | TECH | APNs to a closed app unverifiable in the Simulator | 4 | P2-009 (E2E) |
| R-046 | BUS | Points value unvalidated | 4 | P2-010 (Integration) |

---

## NFR Test Coverage Plan

| NFR Category | Requirement / Threshold | Planned Validation | Tool / Level | Evidence Artifact | Priority |
| --- | --- | --- | --- | --- | --- |
| Security | No `anon` grants; RLS on every table; uploads ≤ 10 MB with exact MIME types; signed URLs ≤ 3600 s; D20 email visibility | Access matrices, catalog test, storage policies, admission hook, health check | pgTAP (Integration), Playwright api (API), Vitest (Unit) | `test.yml` lane logs; health-check run | P0 |
| Reliability | Keep-alive twice daily; job refusals marked `failed` and never retried; dead tokens removed on 410/404 | `job_health()` cases, worker refusal cases, `push_targets` and `send-push` cases | pgTAP, `deno test`, workflow runs | keep-alive run history; `test.yml` logs | P1 |
| Disaster recovery | Weekly dump restores (data-loss limit implied at 7 days) | Restore into a throwaway database | `backup.yml` (Integration) | backup run with restore step | P2 |
| Deployability | `min_native_build` respected; expand-only migrations; one merge gate | `MIN_NATIVE_BUILD` check, migration lint, ruleset checks | `test.yml` jobs, Simulator hand check | `test.yml` logs; `latest.json`; hand-check notes | P1 |
| Performance | UNKNOWN | None | None | None | - |
| Scalability | Free plan: 500 MB DB, 1 GB storage, 200 Realtime connections | Usage readout | `job_health()` (Integration) | keep-alive output | P3 |
| Maintainability | pgTAP for every object, `deno test` for every handler; coverage threshold UNKNOWN | Lanes plus coverage report | Vitest coverage, ESLint, typecheck | coverage report | P1 |
| Compliance | App Store 4.8 and 5.1.1(v) | Deletion test file; TestFlight walkthrough | pgTAP, E2E by hand | deletion test logs; review notes | P0 (deletion), P1 (review) |

**Missing thresholds or evidence sources:** performance targets (Q1), user and concurrency counts (Q2), coverage threshold (Q3), recovery time objective (Q4), applicable student-privacy law (Q5). `bmad-tea-nfr` treats each as CONCERNS until answered.

---

## Entry Criteria

- [ ] Story 1.3's `test.yml` runs every lane, and Test Summary fails when any lane fails
- [ ] TC-1 (staff session) and TC-3 (personas) exist on the local stack
- [ ] The privilege fixture and catalog test exist (story 1.6) before the first epic-2 table
- [ ] Factories create unique data and clean up; pgTAP files roll back
- [ ] For each epic: its spike outcomes are recorded and its own `bmad-tea-test-design` run is done before its stories

## Exit Criteria

- [ ] P0 pass rate = 100%
- [ ] P1 pass rate ≥ 95%, each waived failure with a dated reason
- [ ] Every high risk (≥ 6) mitigated before epic 13's App Store submission; R-002 and R-012 before any epic's tables reach hosted
- [ ] No open P0 or P1 defects
- [ ] Line coverage ≥ 80% for `app/src/api/` and stores (proposed; UI components carry no threshold because the client is thin by design, AD-1). Pending the owner's answer to Q3.
- [ ] NFR evidence exists for each in-scope category in the table above; PASS, CONCERNS or FAIL is left to `bmad-tea-nfr`
- [ ] `bmad-tea-trace` run at each epic's Done when, and over R1–R30 at epic 13 (initiative Notes)

---

## Test Coverage Plan

**IMPORTANT:** P0, P1, P2 and P3 are **priority and risk level**, not execution timing. Every automated test runs on every PR; see Execution Strategy.

Test IDs here are system-level. Each epic's own test design maps them to `{EPIC}.{STORY}-{LEVEL}-{SEQ}` IDs. Levels: pgTAP on the local stack is Integration; one Supabase HTTP service (edge function, Auth, Storage, Management API) is API; `deno test` and Vitest are Unit; anything spanning GitHub, the hosted project, Apple, Google or a device is E2E.

### P0 (Critical)

**Criteria:** Critical business, security, data-integrity, or compliance impact with no safe workaround. Risk score is supporting evidence and is not a required condition.

| Test IDs | Requirement | Test Level | Risk Link | Test Count | Notes |
| -------- | ----------- | ---------- | --------- | ---------: | ----- |
| **P0-001** | K4, AD-6 | Integration | R-001 | 6 | No persona can change their own or anyone's `profiles.role`; profiles are created only by `on_auth_user_created`. Owner: Epic 2. Mechanism: a role write grant or a second profile writer, at the Postgres boundary, so Integration. Scenarios: `UPDATE role` refused for student, teacher and admin; direct `INSERT profiles` refused; role set from `staff_invites`, bootstrap and `fermi_role` only; no policy reads `app_metadata`. Consequence: self-elevation to teacher or admin (Done when). Workaround: none. |
| **P0-002** | K5, AD-1 | Integration | R-002 | 45 | Persona × table read matrix: each persona reads exactly what AD-2's predicates allow, and nothing outside its classes. Owner: Each table's owning epic. Mechanism: an RLS read policy at the Postgres boundary, so Integration. Scenarios per table: an outsider student and an outsider teacher get 0 rows; the owner or member gets theirs; the admin's view matches AD-9. Consequence: student data leak. Workaround: none. |
| **P0-003** | R1, R2, K3, AD-7 | Integration | R-003 | 6 | `before_user_created` admits only listed or bootstrap Google or Apple emails. Owner: Epic 2. Mechanism: the hook function in Postgres, so Integration. Scenarios: listed admitted; unlisted refused; Apple relay refused with its message; `email` provider refused; bootstrap admitted; email case and whitespace normalised. Consequence: a stranger gets in (Done when). Workaround: none. |
| **P0-004** | K5, AD-4 | Integration | R-004 | 45 | Persona × table write matrix: insert, update and delete refused outside ownership or membership; single-writer tables have no direct write. Owner: Each table's owning epic. Mechanism: RLS write policies and `_as` checks at Postgres, so Integration. Parity regressions: student rewriting a roster, cross-teacher assignment, submission without enrollment, like with extra columns, deleting another's message. Consequence: data written into other classes. Workaround: none. |
| **P0-005** | K18, AD-21 | Integration | R-008 | 2 | The backup artifact holds only the age-encrypted dump; no workflow writes a secret or plaintext dump. Owner: Story 1.8. Mechanism: the backup workflow's artifact file, one file boundary, so Integration. Scenarios: the artifact list has only the `.age` file; decrypting with the wrong key fails. Consequence: student data published in a public repo; irreversible. Workaround: none. |
| **P0-006** | AD-3 | Integration | R-012 | 4 | Catalog test: every table, column, function and view grant matches the privilege fixture; `anon` has nothing; `internal.*` has no `authenticated` EXECUTE. Owner: Story 1.6, then every migration. Mechanism: Postgres default grants, so Integration. Scenarios: a function without a fixture entry fails; EXECUTE granted to `anon` fails; a definer view in `public` fails (story 1.6 verify). Consequence: full impersonation through `_as`. Workaround: none. |
| **P0-007** | R4, R10, AD-9 | Integration | R-018 | 8 | After `remove_student`, every class-scoped read and write by that student is refused (chat, groups, boards, grades, points). Owner: Epic 3, plus epics 4, 5, 7, 8. Mechanism: predicate results after the enrollment row goes, so Integration. Rows stay visible to the teacher. A Realtime case asserts payloads carry ids only. Consequence: a removed student keeps class data. Workaround: none. |
| **P0-008** | K16, AD-12 | Integration | R-020 | 10 | `authenticated` cannot select `profiles.email`; `app.visible_email` follows D20 for every persona pair; `app.can_see_user` clauses. Owner: Epic 2 (shape), epics 3, 5 (clauses). Mechanism: column grants and a definer function, so Integration. Scenarios: classmate gets null; student sees their teachers and the admin; teacher sees their students and the admin; admin sees all. Consequence: minors' emails exposed. Workaround: none. |
| **P0-009** | R6, AD-13 | Integration | R-023 | 16 | Storage policies per bucket and persona: insert, read, update and delete as AD-13's table; path prefix matches the row's scope. Owner: Epics 2, 4, 5. Mechanism: `storage.objects` RLS, so Integration. Scenarios: classmate reads a submission (refused); student updates after submit (refused); a row path pointing at another class (refused). Consequence: work copied or swapped. Workaround: none. |
| **P0-010** | R28, AD-16 | Integration | R-026 | 12 | `NN_account_deletion.sql`: deleting the `auth.users` row removes or nulls every dependent row, queues files, deletes the Vault secret and the `staff_invites` row. Owner: Epic 2 (file), every epic adding a foreign key. Mechanism: cascades and `AFTER DELETE` triggers, so Integration. Consequence: data kept after deletion (App Store 5.1.1(v)); a deleted teacher signs back in. Workaround: none. |
| **P0-011** | R15, R29, AD-16 | Integration | R-027 | 6 | `internal.delete_account_as` permits exactly AD-16's matrix. Owner: Epic 12. Scenarios: admin deletes others but not self; teacher deletes self after cascade; teacher with an open request deletes the student; without a request refused (`no_removal_request`); student self refused. Consequence: irreversible wrong deletion. Workaround: none (backup is up to 7 days old). |
| **P0-012** | K7, AD-21 | API | R-032 | 5 | The health check fails on hosted Auth or Realtime drift. Owner: Story 1.4; epic 2. Mechanism: Management API read-back, one HTTP service, so API. Scenarios: anonymous sign-ins on (fail, story 1.4 verify); sign-up on before the hook (fail); `private_only` missing (fail); email sign-in off (fail); after epic 2, hook URI mismatch (fail). Consequence: anonymous or unlisted users authenticated; K7 and AD-21 mandate the control. Workaround: none. |

**Total P0:** ~165 tests

---

### P1 (High)

**Criteria:** Core, frequent, or complex behavior with material user reach and a limited workaround. Risk score is supporting evidence and is not a required condition.

| Test IDs | Requirement | Test Level | Risk Link | Test Count | Notes |
| -------- | ----------- | ---------- | --------- | ---------: | ----- |
| **P1-001** | K13 | E2E | R-005 | 1 | A pull request with one failing ESLint rule, Vitest test, pgTAP test and Playwright test turns each job and Test Summary red; reverting turns it green. Owner: Story 1.3. Mechanism: CI on pull requests spans GitHub Actions and every lane, so E2E. Consequence: regressions merge unseen; other risks' harm lasts longer. Workaround: stories' hand `verify` steps until 1.3. |
| **P1-002** | K18, AD-21 | API | R-007 | 2 | A manual keep-alive run is green, runs a real query, and the monthly re-enable call succeeds. Owner: Story 1.7. Mechanism: a workflow calling the hosted Supabase API, so API. Consequence: the whole app is down while paused. Recovery path: not stated in sources (unresolved). |
| **P1-003** | K11 | E2E | R-010 | 3 | TestFlight build per-role walkthrough with demo accounts; Apple sign-in parity with Google. Owner: Epic 13. Mechanism: a shipped build plus App Review, so E2E. Consequence: the iOS update is rejected. Workaround: the website and Home Screen web app (D9). |
| **P1-004** | AD-2 | Integration | R-011 | 33 | One truth-table file per `app.*` predicate asserting AD-2's table, archived and removed columns included. Owner: Epics 2, 3, 5. Consequence: R-002 and R-004's harm, which carry the P0 cases. |
| **P1-005** | AD-4 | Integration | R-013 | 15 | Single-writer tables have no direct write grant; a refused `_as` call leaves no partial rows. Owner: Every epic. Consequence: inconsistent rows. Workaround: a corrective call by the owner. |
| **P1-006** | R5, AD-8 | API | R-014 | 7 | `add-students` per-row outcomes: staff, bootstrap, teacher or admin email refused; existing student enrolled keeping password and name; new student created; admin works on any class; 1000-row CSV in 10 chunks. Owner: Epic 3. Mechanism: an edge function plus the Auth admin API, one HTTP service, so API. Handler branches are also covered by `deno test`. Consequence: wrong accounts or changed passwords. Workaround: Show or Reset password (R26), admin delete (R15). |
| **P1-007** | R10, AD-10 | Integration | R-017 | 6 | `internal.send_message_as` pairing matrix for typed and scheduled sends: student–student refused, teacher–untaught student refused, admin–teacher allowed. Owner: Epic 5. Consequence: unsupervised pairs chat. Workaround: limited; users already share the directory. |
| **P1-008** | K17, AD-13 | API | R-021 | 6 | Storage upload of 10 MB + 1 byte refused; SVG refused; `.jpg` as `image/jpeg` accepted. Owner: Epic 2 (pattern), bucket owners. Mechanism: Storage HTTP enforcing bucket config, so API. Consequence: storage fills; scriptable files stored. |
| **P1-009** | AD-13 | Unit | R-022 | 2 | The signed-URL helper in `app/src/api/` never asks for more than 3600 s. Owner: Epic 2. Mechanism: an expiry parameter in client code, no boundary, so Unit. Consequence: a forwarded link exposes a file long after. |
| **P1-010** | R11, R12, R24, AD-14 | Integration | R-024 | 10 | `internal.push_targets` per kind skips DND and non-members; `send-push` deletes on 410, 404 and web-push 410, keeps 400; sign-out unregisters. Owner: Epic 6. Mechanism: recipient and target selection in Postgres, so Integration. Handler status cases run in `deno test`. Consequence: pushes to the wrong device or person. Workaround: the inbox stays correct. |
| **P1-011** | R16, R27, AD-15 | Integration | R-025 | 12 | A due row that is refused is marked `failed` with its key, writes `job_failures`, and is not retried; the worker takes the run time as a parameter. Owner: Epics 2, 4, 5. Consequence: posts after access is lost, or jobs loop. |
| **P1-012** | R23, K15, AD-18 | E2E | R-029 | 4 | `latest.json` skip when `min_native_build` > installed; App Store banner; the `MIN_NATIVE_BUILD` check fails a plugin added without a raise. Owner: Stories 1.9, 1.10. Mechanism: a release control for an installed build (shipped shell + Workers site), so E2E. Simulator hand check for the shell part. Consequence: broken iOS app. Workaround: the website (D9). |
| **P1-013** | AD-19 | Integration | R-030 | 6 | `realtime.messages` policies: `chat:` read only for members, client writes only Presence; `user:` only self. Owner: Epics 2, 5. Consequence: ids leak to non-members. |
| **P1-014** | AD-20 | E2E | R-031 | 1 | The previous bundle's api tests pass against the new migrations. Owner: Epic 1 (TC-4), every epic. Mechanism: a migration and an older client are two deployables, so E2E. Consequence: older iOS builds break. Workaround: restart onto the live update. |
| **P1-015** | AD-21 | Integration | R-033 | 4 | `job_health()` returns failure when a `job_failures` row, a failed `cron.job_run_details` row or a non-2xx `net._http_response` exists; keep-alive then fails. Owner: Story 1.7. Consequence: reminders, messages and sweeps silently stop. |
| **P1-016** | R30, AD-22 | Integration | R-035 | 15 | Each AD-22 action writes exactly one `audit_events` row in the same transaction; no update or delete grant; reads by role. Owner: Epics 2, 3, 12. Consequence: R30's trail has holes that can't be rebuilt. |
| **P1-017** | AD-23 | E2E | R-036 | 4 | Ruleset targets main only and requires exactly Test Summary and Dependency Review; a Dependabot PR outside the native group auto-merges after both pass; a native-group PR does not; a moderate advisory blocks. Owner: Story 1.13. Mechanism: GitHub ruleset, workflows and Dependabot, so E2E. Consequence: untested or vulnerable code deploys within a day. Workaround: manual PR review. |
| **P1-018** | K7 | Integration | R-038 | 1 | Every migration applies on CI's fresh local stack and every pgTAP test passes before merge. Owner: Story 1.3. Consequence: a broken migration on the only hosted project. Recovery: weekly backup (AD-21). |
| **P1-019** | R5, AD-6 | API | R-040 | 1 | On the hosted project, an admin-API-created user is not refused by `before_user_created`. Owner: Epic 2 spike. Consequence: no student can be created (R5 blocked). Recovery: unresolved until the spike. |
| **P1-020** | R1, K11 | E2E | R-042 | 1 | Sign in with Apple through the NativeAuth sheet completes and lands a listed teacher on the dashboard. Owner: Epic 2 spike. Consequence: Apple sign-in broken on iOS (K11). Workaround: Google. |
| **P1-021** | Initiative Tracer path | E2E | - | 1 | Tracer path: admin lists a teacher → teacher creates class and adds a student → student signs in with the sheet's password → teacher messages → push to a closed app. Owner: Epic 13 closing suite. Initiative "Tracer path". Playwright for the web part; the push leg is a hand check. |
| **P1-022** | K7, story 1.1 | E2E | - | 1 | The deployed shell shows the commit id of the push. Owner: Story 1.1. Story 1.1 verify; becomes the post-deploy smoke. |

**Total P1:** ~136 tests

---

### P2 (Medium)

**Criteria:** Secondary behavior with narrower user reach and an acceptable workaround. Risk score is supporting evidence and is not a required condition.

| Test IDs | Requirement | Test Level | Risk Link | Test Count | Notes |
| -------- | ----------- | ---------- | --------- | ---------: | ----- |
| **P2-001** | K18, AD-21 | Integration | R-009 | 1 | The weekly dump restores into a throwaway database, and row counts match. Owner: Story 1.8. Consequence: rare project loss. Workaround for passwords: teachers reset (AD-21). Files: unresolved (accepted). |
| **P2-002** | R21, AD-9 | Integration | R-015 | 10 | Each class-scoped `_as` function and write policy refuses an archived class. Owner: Epics 3, 4, 5, 7, 8. Workaround: the teacher removes the stray item. |
| **P2-003** | AD-9 | Integration | R-016 | 4 | Inserting a class creates exactly one class chat and one Announcements board; backfill covers existing classes. Owner: Epics 5, 7. Workaround: rerun the backfill. |
| **P2-004** | AD-17 | Unit | R-028 | 6 | The error map turns each SQLSTATE and key into text; the edge helper returns real status and `{error:{code,message}}`. Owner: Story 1.5. Consequence: generic error text. |
| **P2-005** | R1, AD-21 | E2E | R-034 | 1 | Apple sign-in on hosted works after the monthly `apple-secret.yml` run. Owner: Epic 2. Workaround: Google sign-in (R1). |
| **P2-006** | Spine conventions (Tests) | E2E | R-037 | 4 | Hand-check notes for each native-only path, rerun on TestFlight. Owner: Epics 1, 2, 4, 6, 13. Workaround: the website. |
| **P2-007** | R26, K10, AD-8 | API | R-043 | 1 | A student JWT calling Auth's update-user to change the password is refused. Owner: Epic 2 spike, epic 3. Workaround: the teacher resets the password (R26). |
| **P2-008** | R6, AD-13 | E2E | R-044 | 1 | The Drive picker page in the NativeAuth sheet returns a file that uploads. Owner: Epic 4 spike. Workaround: attach from the device. |
| **P2-009** | R11, AD-14 | E2E | R-045 | 1 | A sandbox APNs push reaches a closed app in the Simulator, or on a development build. Owner: Epic 6 spike. Fallback stated in the spine. |
| **P2-010** | R7 | Integration | R-046 | 3 | The award function refuses non-integer and out-of-range points with `22023`. Owner: Epic 8. Workaround: undo (R7). |
| **P2-011** | R25 | Component | - | 2 | Landing page says who Fermi is for, shows Home Screen steps and links the App Store (R25). Owner: Epic 2.  |

**Total P2:** ~34 tests

---

### P3 (Low)

**Criteria:** Rare, cosmetic, or experimental behavior with minimal impact and an easy workaround. Risk score is supporting evidence and is not a required condition.

| Test IDs | Requirement | Test Level | Risk Link | Test Count | Notes |
| -------- | ----------- | ---------- | --------- | ---------: | ----- |
| **P3-001** | K14 | Unit | R-006 | 1 | Typecheck against the generated `Database` types; shared shape names only. Owner: Every epic. Workaround: a code fix. |
| **P3-002** | R12, AD-11 | Integration | R-019 | 3 | No update grant on `last_seen_at`; `app.presence` green, yellow or red at the 2-minute edge. Owner: Epic 2. Cosmetic. |
| **P3-003** | K18 | Integration | R-039 | 1 | `job_health()` or keep-alive reports database size, storage size and Realtime peak. Owner: Later (clarification Q2). No threshold yet. |
| **P3-004** | AD-6 | E2E | R-041 | 1 | A student signing in with Google under their school email lands as a student. Owner: Epic 2 spike. Workaround: password sign-in. |

**Total P3:** ~6 tests

---

## Execution Strategy

**Philosophy:** run everything in PRs unless it is expensive or long-running. Playwright with parallel workers runs hundreds of tests in about 10–15 minutes; pgTAP, `deno test` and Vitest take seconds to a few minutes.

### Every PR: Playwright Tests (~10-15 min)

All automated tests, every priority, as `test.yml` lanes that Test Summary waits on:

- ESLint and typecheck; Vitest with coverage; pgTAP through `supabase test db`; `deno test` over `supabase/functions`; Playwright on Desktop Chrome and iPhone WebKit (UI and api projects), with burn-in of changed specs and the every-test-ran check
- The migration lint (TC-4) and the `MIN_NATIVE_BUILD` check (story 1.9) as their own jobs
- Playwright shards are added only when the run takes longer than 15 minutes

### Nightly: k6 Performance Tests (~30-60 min)

None planned. No performance target exists (Q1), so a k6 lane would have nothing to pass or fail against.

### Weekly: Chaos & Long-Running (~hours)

The scheduled workflows already carry the long-running checks: `backup.yml` weekly with its restore step (P2-001), `keep-alive.yml` twice daily with `job_health()` (P1-002, P1-015), and `apple-secret.yml` monthly (P2-005).

**Manual tests** (dated hand checks, rerun on epic 13's TestFlight build):

- Live-update restart and App Store banner (P1-012's shell part, story 1.10)
- Sign in with Apple through the NativeAuth sheet (P1-020), the Drive picker page (P2-008), APNs to a closed app (P2-009), Google linking for a student (P3-004)
- The tracer path's push leg (P1-021)
- After each deploy: the health check (P0-012) and the commit-id smoke (P1-022) run automatically

---

## QA Effort Estimate

Test-writing effort only. The builds and the framework setup are counted in their stories.

| Priority | Count | Effort Range | Notes |
| --- | --- | --- | --- |
| P0 | ~165 | ~1–2 weeks | The read and write matrices grow with every table |
| P1 | ~136 | ~1–1.5 weeks | Predicates, pipeline, jobs, CI proofs |
| P2 | ~34 | ~2–3 days | Archived refusals, error map, hand checks |
| P3 | ~6 | ~0.5–1 day | Typecheck, presence edges |
| **Total** | ~341 | **~2.5–4.5 weeks** | **One person, full time, spread across 13 epics** |

**Assumptions:**

- Includes writing, debugging and CI wiring; excludes ongoing maintenance
- Assumes TC-1 to TC-3 exist after story 1.3
- Most tests are written by the bmad-loop builds alongside each story, so this is effort, not calendar time

---

## Implementation Planning Handoff

| Work Item | Owner | Target Milestone | Dependencies/Notes |
| --- | --- | --- | --- |
| Lanes, Test Summary, burn-in, every-test-ran check | Story 1.3 | Epic 1 | Uses this document |
| Staff session helper (TC-1, local-only rule) and persona helper plus factories (TC-3) | Story 1.3 | Before epic 2 | P0-002 and P0-004 depend on both; the helper refuses non-local URLs |
| Migration lint (TC-4) | Story 1.3 or 1.11 | Epic 1 | Owner approves (architecture doc ⚠️ 2) |
| Catalog test and privilege fixture | Story 1.6 | Epic 1 | P0-006 |
| Hook, role, directory and deletion-file tests | Epic 2 | Epic 2 | After epic 2's spikes |
| Per-epic matrix rows, archived and removal cases | Epics 3–12 | Each epic | Each epic's own test design picks them up |
| TestFlight rerun of every hand check | Epic 13 | Submission | P1-003, P2-006 |

---

## Tooling & Access

| Tool or Service | Purpose | Access Required | Status |
| --- | --- | --- | --- |
| Supabase CLI 2.122.0 local stack | pgTAP, local Auth, Storage, Realtime | None (Docker on the CI runner) | Pending (story 1.3) |
| `@seontechnologies/playwright-utils` | Playwright fixtures (`apiRequest` and others) | npm | Pending (story 1.3) |
| Supabase Management API | Health check read-back (P0-012) | `SUPABASE_ACCESS_TOKEN` in the Production environment, deploy only, never in `test.yml` | Ready (story 1.1 setup) |
| iOS Simulator on the build Mac | Native hand checks | Xcode | Ready |
| TestFlight | Final native rerun, production APNs | App Store Connect | Pending (epic 13) |

---

## Interworking & Regression

| Service/Component | Impact | Regression Scope | Validation Steps |
| --- | --- | --- | --- |
| **`app.*` predicates** | Every epic's policies call them | Predicate truth tables (P1-004) and every epic's matrix rows | Changing a predicate reruns the whole pgTAP lane |
| **`app.can_see_user`** | Epics 3 and 5 replace its stub clauses | Directory and email cases (P0-008) | Each clause change ships with its clause tests |
| **`NN_account_deletion.sql`** | Every epic with a foreign key, bucket or secret adds a case | The whole file (P0-010) | Runs in the pgTAP lane on every PR |
| **`deploy.yml` and the health check** | Epics 2 and 6 add steps and assertions | P0-012 and the commit-id smoke | Health check after every deploy |
| **The Flutter app (until epic 13)** | Lives beside `app/` | None; it is not tested | Removed in epic 13 |

**Regression strategy:** every lane runs on every PR, so each epic's tests guard the earlier epics. Nothing is split into a separate regression run.

---

## Appendix A: Code Examples & Tagging

**Playwright tags** follow the priority and level: `@P0`, `@P1`, `@API`, `@Security`. See the factory pattern above.

**pgTAP shape for an access-matrix case.** The persona helper's name is decided in story 1.3; `tests.authenticate_as` here is a placeholder.

```sql
begin;
select plan(2);

select tests.authenticate_as('student_only_in_a');

select is_empty(
  $$ select 1 from public.profiles where id = tests.persona_id('student_only_in_b') $$,
  'a student does not see a student who shares no class'
);

select throws_ok(
  $$ update public.profiles set role = 'admin' where id = auth.uid() $$,
  '42501',
  null,
  'no one updates their own role'
);

select * from finish();
rollback;
```

**Run by tag:**

```bash
# Run only P0 Playwright tests
npx playwright test --grep @P0

# Run P0 + P1
npx playwright test --grep "@P0|@P1"

# Run only security tests
npx playwright test --grep @Security

# Run the pgTAP lane locally
supabase test db
```

---

## Appendix B: Knowledge Base References

- **Risk Governance**: `risk-governance.md` - Risk scoring methodology
- **Test Priorities Matrix**: `test-priorities-matrix.md` - P0-P3 criteria
- **Test Levels Framework**: `test-levels-framework.md` - E2E vs API vs Unit selection
- **Test Quality**: `test-quality.md` - Definition of Done (no hard waits, ≤1000 lines, <1.5 min)
- **NFR Criteria**: `nfr-criteria.md` - NFR planning and the CONCERNS default for undefined targets
- **ADR Quality Readiness Checklist**: `adr-quality-readiness-checklist.md` - testability review categories

---

**Generated by:** BMad TEA Agent
**Workflow:** `bmad-tea-test-design`
**Version:** 4.0 (BMad v6)
