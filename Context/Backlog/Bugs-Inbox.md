# Bugs Inbox
<!-- Template Version: 1 | ContextKit: 0.1.0 | Updated: 2025-09-15 -->

> [!NOTE]
> **✅ USER-EDITABLE FILE**: This file is completely yours to edit!
> - Edit manually, copy/paste between projects, add entries freely
> - Use simple `## [ID] Title` format for each entry
> - Add bugs via `/ctxk:bckl:add-bug [description]` or edit directly

**Purpose**: Quick bug capture for later triage
**Usage**: Add bugs manually or via `/ctxk:bckl:add-bug [description]` command
**Format**: Use `## [ID] Title` format for each entry

Bugs captured here will be moved to Bugs-Backlog.md during `/ctxk:bckl:prioritize-bugs` after triage.

---

## [BUG-001] Example bug title
<!-- Added: 2025-09-15 | Source: Me -->

Simple example of how to structure bugs in this inbox.

## [BUG-002] Another example bug
<!-- Added: 2025-09-15 | Source: Customer report -->

Shows how to capture bugs from external sources.

## [BUG-003] Memory leak in background sync causing performance degradation over time
<!-- Added: 2025-09-15 | Source: QA testing team -->

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum mauris massa, cursus vitae tincidunt eu, fermentum non nulla. Aliquam erat volutpat. Suspendisse potenti.

### Reproduction Steps
1. Start background sync process
2. Let app run for 2+ hours with sync active
3. Monitor memory usage over time
4. Observe gradual memory increase without release

### Environment
- iOS 18.2 on iPhone 15 Pro
- Background app refresh enabled
- Large dataset (10k+ items syncing)

### Expected vs Actual
**Expected**: Memory usage should stabilize after initial sync
**Actual**: Memory continuously grows, eventually causing system pressure warnings

Cras vehicula, nunc vel tempor bibendum, nulla nunc tincidunt leo, et varius tellus nunc eu lorem. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.

---

*Add new bugs above this line using the same format. Keep entries simple - detailed triage happens during prioritization.*