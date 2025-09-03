# Code Dependency Map

This document maps internal Dart file dependencies derived from import statements. External packages (package:*) are omitted. Package imports (package:fermi_plus/…) were mapped to `lib/` paths.

## Summary
- Files scanned: 189
- Internal nodes (with internal deps): 189
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
- lib/features/notifications (11)
- lib/features/student (11)
- lib/features/teacher (3)
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
- lib/shared/core/app_providers.dart → 16
- lib/features/teacher/presentation/screens/teacher_dashboard_screen.dart → 15
- lib/features/student/presentation/screens/student_dashboard_screen.dart → 14
- lib/features/classes/presentation/screens/teacher/class_detail_screen.dart → 10
- lib/features/grades/presentation/screens/teacher/gradebook_screen.dart → 9
- lib/features/grades/presentation/screens/student/grades_screen.dart → 9
- lib/shared/screens/settings_screen.dart → 8
- lib/features/student/presentation/screens/teacher/students_screen.dart → 7
- lib/features/games/presentation/screens/jeopardy_screen.dart → 7
- lib/features/classes/presentation/screens/teacher/classes_screen.dart → 7
- lib/features/notifications/presentation/screens/notifications_screen.dart → 6
- lib/features/grades/presentation/screens/teacher/grade_analytics_screen.dart → 6
- lib/features/classes/presentation/screens/student/courses_screen.dart → 6
- lib/features/calendar/presentation/screens/calendar_screen.dart → 6
- lib/features/auth/providers/auth_provider.dart → 6
- lib/features/assignments/presentation/screens/teacher/assignments_list_screen.dart → 6
- lib/features/assignments/presentation/screens/student/assignments_list_screen.dart → 6

These are “coordination” files. Changes here often impact many screens and providers.

## Top Incoming References (widely used)
- lib/shared/services/logger_service.dart ← 45 files
- lib/features/auth/presentation/providers/auth_provider.dart ← 37
- lib/shared/widgets/common/adaptive_layout.dart ← 27
- lib/shared/models/user_model.dart ← 25
- lib/shared/widgets/common/responsive_layout.dart ← 15
- lib/features/classes/domain/models/class_model.dart ← 15
- lib/features/classes/presentation/providers/class_provider.dart ← 14
- lib/shared/theme/app_theme.dart ← 10
- lib/features/assignments/domain/models/assignment.dart ← 10
- lib/features/student/domain/models/student.dart ← 9
- lib/features/assignments/presentation/providers/assignment_provider_simple.dart ← 9

These are “shared dependencies”. Editing them has broad ripple effects; audit callsites before refactors.

## Key Relationships (high signal)
- Router → Screens/Providers
  - `lib/shared/routing/app_router.dart` imports most app screens and `AuthProvider`. Route changes affect presence (see `PresenceService.markUserActive`).
- Auth Provider/Service → Many Features
  - `AuthProvider` is consumed across features. Central to auth state transitions, presence updates, and post-login routing.
- LoggerService → Most Modules
  - Centralized logging; changing its interface/levels affects observability across the app.
- PresenceService → Router + Student Widgets
  - Router calls `PresenceService.markUserActive`; student dashboard/widgets depend on `PresenceService` streams.
- Chat Screens → Providers/Storage
  - Chat screens depend on `SimpleChatProvider`, Firebase Storage, and show lifecycle-sensitive async flows.

## Feature Maps (selected)

### Auth
- Providers/Services
  - `lib/features/auth/providers/auth_provider.dart`
    - depends on `AuthService`, `UsernameAuthService`, `PresenceService`, `Firestore`
    - consumed by: Router, many screens
  - `lib/features/auth/data/services/auth_service.dart`
    - depends on Firebase Auth/Firestore and platform-specific OAuth handlers
  - `lib/features/auth/utils/auth_error_mapper.dart`
    - maps `FirebaseAuthException`/OAuth errors to user messages; used by `AuthProvider`
- Screens
  - `login_screen.dart`, `signup_screen.dart`, `forgot_password_screen.dart`, `verify_email_screen.dart`, `role_selection_screen.dart`, `teacher_password(_reset)_screen.dart`, `email_linking_screen.dart`

### Chat
- Providers
  - `chat_provider_simple.dart` used by list/detail/simple screens
- Screens
  - `chat_list_screen.dart`, `chat_detail_screen.dart`, `simple_chat_screen.dart`, `simple_user_list.dart`, `call_screen.dart`, `incoming_call_screen.dart`, helpers
- Services
  - `scheduled_messages_service.dart`, `webrtc_service.dart`

### Classes
- Providers
  - `class_provider.dart`
- Services/Models
  - `class_service.dart`, `class_model.dart`
- Screens/Dialogs
  - Teacher: `classes_screen.dart`, `class_detail_screen.dart`
  - Student: `courses_screen.dart`, `enrollment_screen.dart`
  - Widgets: `create/edit/enroll_students_dialog.dart`

### Notifications
- Provider/Service
  - Notification provider + services under `features/notifications/*`
- Screens
  - `notifications_screen.dart`, `student_notifications_screen.dart`

### Grades
- Providers/Models
  - `assignment_provider_simple.dart`, `grade.dart`
- Screens
  - Teacher: `gradebook_screen.dart`, `grade_analytics_screen.dart`
  - Student: `grades_screen.dart`

### Games
- Screens
  - `jeopardy_screen.dart`, `jeopardy_play_screen.dart`, `jeopardy_create_screen.dart`

### Shared
- Routing
  - `app_router.dart` (hub), `auth_redirect.dart`
- Services
  - `logger_service.dart` (central), `navigation_service.dart`, `error_handler_service.dart`, etc.
- Widgets
  - `adaptive_layout.dart` (widely used), common components, navigation widgets
- Models/Providers
  - `user_model.dart`, `navigation_provider.dart`

## Practical Guidance
- Editing `AuthProvider` or `AppRouter`:
  - Check downstream usages across features (imports in dependency map). Expect ripple effects in dashboards, presence, and routing.
- Editing shared UI (AdaptiveLayout, common widgets):
  - Review all consumers listed; verify sizing/theming changes don’t break layouts.
- Editing LoggerService:
  - Ensure log level changes keep dev visibility and prod noise acceptable. New sinks (Crashlytics, etc.) should fail-safe.
- PresenceService changes:
  - Keep thresholds configurable and documented. Router and Student widgets rely on its semantics.

---

Generated automatically from imports; update this doc after large refactors.
