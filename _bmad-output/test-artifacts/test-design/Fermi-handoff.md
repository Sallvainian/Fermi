---
title: 'TEA Test Design → BMAD Handoff Document'
version: '1.0'
workflowType: 'testarch-test-design-handoff'
inputDocuments:
  - _bmad-output/test-artifacts/test-design/test-design-architecture.md
  - _bmad-output/test-artifacts/test-design/test-design-qa.md
sourceWorkflow: 'testarch-test-design'
generatedBy: 'TEA Master Test Architect'
generatedAt: '2026-11-06'
projectName: 'Fermi'
---

# TEA → BMAD Integration Handoff

## Purpose

This document carries the system-level test design into the initiative's ticket tree. Fermi's epics and epic 1's stories already exist (`tickets/tickets.toml`), so it feeds two later steps: each epic's refinement, with its own epic-level `bmad-tea-test-design` run, and the stories' `verify` lines.

## TEA Artifacts Inventory

| Artifact | Path | BMAD Integration Point |
| --- | --- | --- |
| Test Design Document (architecture) | `_bmad-output/test-artifacts/test-design/test-design-architecture.md` | Epic quality requirements; testability blockers TC-1 to TC-4 |
| Test Design Document (QA) | `_bmad-output/test-artifacts/test-design/test-design-qa.md` | Story acceptance criteria; story 1.3's framework run |
| Risk Assessment | (embedded in the architecture doc) | Epic risk classification, story priority |
| Coverage Strategy | (embedded in the QA doc) | Story test requirements |
| Progress checkpoint | `_bmad-output/test-artifacts/test-design/test-design-progress-system.md` | Resume and audit trail |

## Epic-Level Integration Guidance

### Risk References

P0 and P1 risks each epic carries as a quality gate in its Done when:

- **Epic 1 Platform baseline:** R-005, R-007, R-008, R-012, R-029, R-031, R-032, R-033, R-036, R-038
- **Epic 2 Sign-in:** R-001, R-003, R-020, R-021, R-022, R-025, R-026 (creates the deletion file), R-030, R-035, R-040, R-042
- **Epic 3 Classes and rosters:** R-002, R-004, R-011, R-013, R-014, R-018, R-020's class clauses, R-035
- **Epic 4 Assignments and grades:** R-002, R-004, R-018, R-023, R-025, R-026
- **Epic 5 Chat:** R-002, R-004, R-011, R-017, R-018, R-020's chat clause, R-023, R-025, R-030
- **Epic 6 Notifications:** R-024
- **Epics 7, 8, 9, 10, 11:** R-002, R-004 for their tables; R-018 for epics 7 and 8
- **Epic 12 Admin console:** R-026, R-027, R-035
- **Epic 13 App Store release:** R-010, plus the TestFlight rerun of every hand check

### Quality Gates

- Every epic: P0 tests for its tables at 100% before the tables reach hosted; P1 ≥ 95%; its rows added to the catalog fixture (R-012) and the read and write matrices (R-002, R-004); its case added to `NN_account_deletion.sql` when it adds a foreign key to `profiles`, a bucket or a secret (R-026)
- Every epic: an epic-level `bmad-tea-test-design` run at refinement and a `bmad-tea-trace` run in its Done when (initiative Notes)
- Epic 13: every high risk (≥ 6) mitigated before submission

## Story-Level Integration Guidance

### P0/P1 Test Scenarios → Story Acceptance Criteria

- **Story 1.3:** the TC-1 staff session helper exists in test code only, uses the local stack's `service_role` key and refuses any non-local Supabase URL (no test sign-in in `app/`, functions or hosted config); TC-3 personas exist; P1-001 (R-005) is its verify; the migration lint (TC-4) is added here or in story 1.11
- **Story 1.4:** P0-012 (R-032) health-check drift cases
- **Story 1.6:** P0-006 (R-012) catalog test
- **Story 1.7:** P1-002 (R-007) and P1-015 (R-033)
- **Story 1.8:** P0-005 (R-008) encrypted artifact only; P2-001 (R-009) restore
- **Stories 1.9 and 1.10:** P1-012 (R-029)
- **Story 1.13:** P1-017 (R-036)
- **Epic 2 hook story:** P0-003 (R-003); the health-check hook-URI swap
- **Epic 2 profiles story:** P0-001 (R-001), P0-008 (R-020)
- **Epic 3 roster stories:** P1-006 (R-014), P0-007 (R-018)
- **Each table-adding story, all epics:** its P0-002 and P0-004 matrix rows

### Data-TestId Requirements

Recommended stable test ids for the screens the P0 and P1 journeys touch:

- Sign-in: `signin-teacher`, `signin-student`, `signin-google`, `signin-apple`, `signin-email`, `signin-password`, `signin-submit`, `signin-error`
- Roster row: `roster-row`, `roster-status`, `roster-show-password`, `roster-reset-password`, `roster-remove`
- Add students: `add-students-csv`, `add-students-row-result`, `add-students-print-sheet`
- Admin teacher list: `staff-invite-email`, `staff-invite-add`, `staff-invite-remove`
- Shell: `build-commit-id`, `update-restart`, `appstore-banner-update`, `appstore-banner-later`

## Risk-to-Story Mapping

| Risk ID | Category | P×I | Recommended Story/Epic | Test Level |
| ------- | -------- | --- | ---------------------- | ---------- |
| R-001 | SEC | 1×3=3 | Epic 2 (P0) | Integration |
| R-002 | SEC | 3×3=9 | Each table's owning epic; the matrix pattern starts in story 1.3 (P0) | Integration |
| R-003 | SEC | 2×3=6 | Epic 2; story 1.4 (P0) | Integration |
| R-004 | SEC | 2×3=6 | Each table's owning epic (P0) | Integration |
| R-005 | TECH | 3×2=6 | Story 1.3, story 1.13 (P1) | E2E |
| R-006 | DATA | 1×2=2 | Every epic (P3) | Unit |
| R-007 | OPS | 2×2=4 | Story 1.7 (P1) | API |
| R-008 | SEC | 1×3=3 | Stories 1.1, 1.8 (P0) | Integration |
| R-009 | DATA | 2×2=4 | Story 1.8 (owner accepts the residual) (P2) | Integration |
| R-010 | BUS | 2×3=6 | Epic 13 (P1) | E2E |
| R-011 | TECH | 2×2=4 | Epics 2, 3, 5 (P1) | Integration |
| R-012 | SEC | 3×3=9 | Story 1.6, then every epic (P0) | Integration |
| R-013 | DATA | 2×2=4 | Every epic (P1) | Integration |
| R-014 | DATA | 2×2=4 | Epic 3 (P1) | API |
| R-015 | BUS | 2×2=4 | Epics 3, 4, 5, 7, 8 (P2) | Integration |
| R-016 | DATA | 1×2=2 | Epics 5, 7 (P2) | Integration |
| R-017 | SEC | 1×3=3 | Epic 5 (P1) | Integration |
| R-018 | SEC | 2×3=6 | Epic 3 (removal), epics 4, 5, 7 and 8 (their tables) (P0) | Integration |
| R-019 | SEC | 1×2=2 | Epic 2 (P3) | Integration |
| R-020 | SEC | 2×3=6 | Epic 2 (shape), epics 3 and 5 (clauses) (P0) | Integration |
| R-021 | SEC | 2×2=4 | Epic 2 (pattern), bucket owners (P1) | API |
| R-022 | SEC | 2×2=4 | Epic 2 (P1) | Unit |
| R-023 | SEC | 2×3=6 | Epic 2 (avatars), epic 4 (assignment and submission files), epic 5 (chat files) (P0) | Integration |
| R-024 | OPS | 2×2=4 | Epic 6 (P1) | Integration |
| R-025 | OPS | 2×2=4 | Epics 2, 4, 5 (P1) | Integration |
| R-026 | DATA | 2×2=4 | Epic 2 (file), every epic with a foreign key, bucket or secret (P0) | Integration |
| R-027 | SEC | 1×3=3 | Epic 12 (P0) | Integration |
| R-028 | TECH | 1×2=2 | Story 1.5 (P2) | Unit |
| R-029 | TECH | 2×3=6 | Stories 1.9, 1.10, 1.13 (P1) | E2E |
| R-030 | SEC | 2×2=4 | Story 1.4; epics 2, 5 (P1) | Integration |
| R-031 | TECH | 2×2=4 | Epic 1 (lint), every epic (P1) | E2E |
| R-032 | OPS | 2×3=6 | Story 1.4; epic 2 (hook assertion) (P0) | API |
| R-033 | OPS | 3×2=6 | Story 1.7; epics 2, 4, 5, 6 (their jobs) (P1) | Integration |
| R-034 | OPS | 2×2=4 | Epic 2 (P2) | E2E |
| R-035 | OPS | 2×2=4 | Epics 2, 3, 12 (P1) | Integration |
| R-036 | OPS | 2×3=6 | Stories 1.3, 1.13 (P1) | E2E |
| R-037 | TECH | 2×2=4 | Epics 1, 2, 4, 6, 13 (P2) | E2E |
| R-038 | OPS | 1×3=3 | Epic 1 (P1) | Integration |
| R-039 | PERF | 1×2=2 | Later (clarification Q2) (P3) | Integration |
| R-040 | TECH | 2×2=4 | Epic 2 spike (P1) | API |
| R-041 | TECH | 2×1=2 | Epic 2 spike (P3) | E2E |
| R-042 | SEC | 2×3=6 | Epic 2 spike; epic 13 (P1) | E2E |
| R-043 | SEC | 2×2=4 | Epic 2 spike, epic 3 (P2) | API |
| R-044 | TECH | 2×2=4 | Epic 4 spike (P2) | E2E |
| R-045 | TECH | 2×2=4 | Epic 6 spike (P2) | E2E |
| R-046 | BUS | 2×2=4 | Epic 8 (P2) | Integration |

## Recommended BMAD → TEA Workflow Sequence

1. **TEA Test Design, system level** (`bmad-tea-test-design`): this run. It produces this handoff.
2. **TEA Framework** (`bmad-tea-framework`, framework and CI together) in story 1.3. It builds the lanes, TC-1 and TC-3.
3. **Per epic, at refinement:** an epic-level `bmad-tea-test-design`, then `bmad-tea-automate` in red mode for the P0 and P1 scenarios.
4. **BMAD build** (`bmad-build` or the bmad-loop) implements each story against those failing tests.
5. **TEA Automate** (`bmad-tea-automate` expand mode) fills the remaining coverage.
6. **TEA Trace** (`bmad-tea-trace`) in each epic's Done when, and over R1–R30 at epic 13.

## Phase Transition Quality Gates

| From Phase | To Phase | Gate Criteria |
| --- | --- | --- |
| Test Design | Epic/Story Creation | All P0 risks have a mitigation strategy (architecture doc) |
| Epic/Story Creation | ATDD | Each story's `verify` names its P0/P1 scenarios from the QA doc |
| ATDD | Implementation | Failing acceptance tests exist for all P0/P1 scenarios of the story |
| Implementation | Test Automation | All acceptance tests pass in `test.yml` |
| Test Automation | Release | The trace matrix shows ≥80% coverage of P0/P1 requirements; P0 at 100% |
