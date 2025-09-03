# Code Dependency Map

This document maps internal Dart file dependencies derived from import statements. External packages (package:*) are omitted. Package imports (package:fermi_plus/…) were mapped to `lib/` paths.

## Summary
- Files scanned: 189
- Internal nodes (with internal deps): 116
- Internal edges: 429

Top-level groups (folder → file count):
- lib/features/assignments (13)
- lib/features/auth (18)
- lib/features/calendar (9)
- lib/features/chat (22)
- lib/features/classes (11)
- lib/features/dashboard (3)
- lib/features/discussions (6)
- lib/features/games (5)
- lib/features/grades (9)
- lib/features/jeopardy (1)
- lib/features/notifications (11)
- lib/features/student (11)
- lib/features/teacher (3)
- lib/firebase_options.dart (1)
- lib/main.dart (1)
- lib/shared/core (3)
- lib/shared/models (2)
- lib/shared/providers (2)
- lib/shared/repositories (1)
- lib/shared/routing (2)
- lib/shared/screens (6)
- lib/shared/services (10)
- lib/shared/theme (4)
- lib/shared/utils (5)
- lib/shared/widgets (30)

## Top Outgoing Dependencies (hubs)
- lib/shared/routing/app_router.dart → 45 internal imports
- lib/shared/core/app_providers.dart → 16 internal imports
- lib/features/teacher/presentation/screens/teacher_dashboard_screen.dart → 15 internal imports
- lib/features/student/presentation/screens/student_dashboard_screen.dart → 14 internal imports
- lib/features/classes/presentation/screens/teacher/class_detail_screen.dart → 10 internal imports
- lib/features/grades/presentation/screens/student/grades_screen.dart → 9 internal imports
- lib/features/grades/presentation/screens/teacher/gradebook_screen.dart → 9 internal imports
- lib/shared/screens/settings_screen.dart → 8 internal imports
- lib/features/classes/presentation/screens/teacher/classes_screen.dart → 7 internal imports
- lib/features/games/presentation/screens/jeopardy_screen.dart → 7 internal imports
- lib/features/student/presentation/screens/teacher/students_screen.dart → 7 internal imports
- lib/features/classes/presentation/screens/student/courses_screen.dart → 6 internal imports
- lib/features/notifications/presentation/screens/notifications_screen.dart → 6 internal imports
- lib/features/grades/presentation/screens/teacher/grade_analytics_screen.dart → 6 internal imports
- lib/features/assignments/presentation/screens/student/assignments_list_screen.dart → 6 internal imports
- lib/features/assignments/presentation/screens/teacher/assignments_list_screen.dart → 6 internal imports
- lib/features/calendar/presentation/screens/calendar_screen.dart → 6 internal imports
- lib/features/auth/providers/auth_provider.dart → 6 internal imports
- lib/shared/core/app_initializer.dart → 5 internal imports
- lib/features/grades/data/services/grade_analytics_service.dart → 5 internal imports

## Top Incoming References (widely used)
- lib/shared/services/logger_service.dart ← referenced by 45 files
- lib/features/auth/presentation/providers/auth_provider.dart ← referenced by 37 files
- lib/shared/widgets/common/adaptive_layout.dart ← referenced by 27 files
- lib/shared/models/user_model.dart ← referenced by 25 files
- lib/features/classes/domain/models/class_model.dart ← referenced by 15 files
- lib/shared/widgets/common/responsive_layout.dart ← referenced by 15 files
- lib/features/classes/presentation/providers/class_provider.dart ← referenced by 14 files
- lib/features/assignments/domain/models/assignment.dart ← referenced by 10 files
- lib/shared/theme/app_theme.dart ← referenced by 10 files
- lib/features/student/domain/models/student.dart ← referenced by 9 files
- lib/features/assignments/presentation/providers/assignment_provider_simple.dart ← referenced by 9 files
- lib/shared/widgets/common/common_widgets.dart ← referenced by 8 files
- lib/shared/theme/app_spacing.dart ← referenced by 7 files
- lib/features/calendar/domain/models/calendar_event.dart ← referenced by 7 files
- lib/features/chat/domain/models/call.dart ← referenced by 6 files
- lib/features/chat/presentation/providers/chat_provider_simple.dart ← referenced by 6 files
- lib/features/discussions/presentation/providers/discussion_provider_simple.dart ← referenced by 6 files
- lib/features/grades/domain/models/grade.dart ← referenced by 6 files
- lib/features/games/presentation/providers/jeopardy_provider_simple.dart ← referenced by 4 files
- lib/features/notifications/domain/models/notification_model.dart ← referenced by 4 files

## Notes & Limitations
- Import-based only: dynamic wiring, reflection, and runtime provider lookups are not captured.
- Use this as a starting point for impact analysis; confirm with code navigation/tests.

