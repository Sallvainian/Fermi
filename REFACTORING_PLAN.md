# Refactoring Plan – Codebase Quality & Optimization

Status: In Progress

## Targets (Prioritized)
1) Unify Firebase options (Single source of truth) – DONE
   - Location: lib/config/firebase_options.dart and lib/firebase_options.dart
   - Issue: Duplicated config leads to drift and misconfiguration risk
   - Benefit: Fewer errors, simpler setup across platforms
   - Effort: Medium | Risk: Medium (platform coverage)
   - Context: AppInitializer imports config/, scripts import top-level; top-level lacks macOS/Linux support

2) Standardize logging (replace debugPrint with LoggerService) – PARTIAL (core + OAuth)
   - Location: lib/main.dart, lib/shared/routing/app_router.dart, app_password_wrapper, selected services
   - Issue: Inconsistent logging obscures diagnostics; missing severity levels
   - Benefit: Better observability and error triage
   - Effort: Medium (incremental) | Risk: Low
   - Context: LoggerService exists and is used; ErrorHandlerService available for UI feedback

3) Async setState safety (mounted checks) – PARTIAL (main + app wrapper)
   - Location: Widgets with async flows calling setState (sample: main/app wrappers)
   - Issue: setState after dispose can crash
   - Benefit: Reduce intermittent UI errors
   - Effort: Low/Medium | Risk: Low
   - Context: Many setState sites; apply to critical async paths first

4) Move dev-only script out of lib/ – DONE

## Analysis Notes / Context gathered
- Firebase options: Single canonical file at `lib/firebase_options.dart`. All imports updated; added macOS/Linux for parity and removed old `lib/config/` file to prevent drift.
- Logging: Core paths updated: `main.dart`, router `AppRouter`, AppPassword wrapper, PWA notifier, Calendar service, Desktop OAuth handler. Remaining: notification services, discussion providers, presence.
- Mounted checks: Guarded `setState` in `main.dart` initialization and `AppPasswordWrapper`. Analyzer hints resolved in auth flows; expand guards elsewhere next.
- Formatting & lint: Applied `dart format`; fixed import ordering; resolved unused imports/vars; addressed relative lib import in dev tool.
   - Location: lib/test_user_creation.dart
   - Issue: Dev scripts under lib/ ship with app, add noise
   - Benefit: Cleaner builds, clearer intent
   - Effort: Low | Risk: Low
   - Context: No imports depend on it; can move to tools/scripts/

## Approach
- Analyze usage and dependencies per target before changes.
- Implement sequentially from low-risk to higher value.
- Run analyzer/tests after each step.
- Keep commits small with clear messages.

## Notes
- Platforms: add macOS/Linux support to the canonical Firebase options to preserve current behavior.
- Router logs: convert to LoggerService.warning/error with clear tags.
- Calendar mapping: Consolidated repeated Firestore→model mapping using `CalendarEvent.fromFirestore` to reduce duplication and risk.
