# Implementation Plan

## Analysis & Groundwork
1. Inspect Firestore class documents to confirm where period metadata lives (`schedule`, `settings.period`, etc.) and document fallback parsing rules.
2. Audit existing behavior documents in Firestore (structure, security expectations) to ensure provider/service updates align; capture any rule gaps to flag.
3. Snapshot current widgets/screens (`BehaviorPointsScreen`, `StudentPointCard`, `BehaviorAssignmentPopup`, `TeacherDashboardScreen`) to baseline UI states before modifications.

## Implementation Steps
1. **Sorting & Data plumbing**
   - Add a reusable period parsing helper (likely in `ClassModel` or a new util) and update `ClassProvider` consumers (`BehaviorPointsScreen`, `TeacherDashboardScreen`) to work on sorted class lists.
   - Ensure dropdowns and dashboard cards react to provider updates without double sorting.
2. **Behavior provider/service refactor**
   - Extend `BehaviorPointsService` with Firestore CRUD for class behaviors (stream, create, delete) and adjust security assumptions if needed.
   - Update `BehaviorPointProvider` to subscribe to the new behavior stream, drop `Behavior.allDefaultBehaviors`, and support deleting any entry.
   - Remove static defaults from `Behavior` model; keep serialization helpers intact.
3. **Behavior assignment popup**
   - Strip mock behavior lists, consume provider data, and surface empty states / loading spinners.
   - Allow delete affordance for every behavior when in edit mode and wire to provider delete API.
   - Normalize opacity usages to `withValues`.
4. **Behavior points screen polish**
   - Rework summary header to include Positive/Negative rate cards with shared sizing; compute rates from aggregates.
   - Update student collection logic to build formatted names (`First LastInitial`), enlarge font to 12, and hide ranks for zero-point totals.
   - Mirror the student badge styling for the class tile and remove redundant text counters.
   - Tighten general opacity/gradient usage via `withValues` to restore readability.
5. **Teacher dashboard cards**
   - Create a denser layout (smaller padding/typography or grid) so six classes fit; ensure responsiveness and sorted order reuse the helper from step 1.
6. **Validation & cleanup**
   - Update/helpful docs or inline comments if contracts change (e.g., behavior provider).
   - Remove unused imports/constants left from default behaviors.
   - Hook Task Master: log progress via `task-master update-subtask` for each Task ID once milestones complete.

## Test Strategy
- Run targeted widget tests if present (e.g., `flutter test test/behavior_points_*`) focusing on provider behavior and card rendering; add new tests for formatting utilities if feasible.
- Manual QA checklist: class dropdown ordering, behavior popup load/delete, student ranking behavior, summary card metrics, teacher dashboard layout.
- Sanity regression: launch app in web/desktop mode (`flutter run -d chrome`) to visually confirm style adjustments.
