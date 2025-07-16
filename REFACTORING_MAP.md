# Feature-Based Refactoring Map

## Shared Resources (Move First)

### Shared Models
- lib/models/user_model.dart → lib/shared/models/user_model.dart
- lib/models/nav_item.dart → lib/shared/models/nav_item.dart

### Shared Repositories
- lib/repositories/base_repository.dart → lib/shared/repositories/base_repository.dart
- lib/repositories/firestore_repository.dart → lib/shared/repositories/firestore_repository.dart
- lib/repositories/firestore_repository_enhanced.dart → lib/shared/repositories/firestore_repository_enhanced.dart
- lib/repositories/mixins/pagination_mixin.dart → lib/shared/repositories/mixins/pagination_mixin.dart

### Shared Services
- lib/services/firestore_service.dart → lib/shared/services/firestore_service.dart
- lib/services/firestore_service_enhanced.dart → lib/shared/services/firestore_service_enhanced.dart
- lib/services/logger_service.dart → lib/shared/services/logger_service.dart
- lib/services/error_handler_service.dart → lib/shared/services/error_handler_service.dart
- lib/services/navigation_service.dart → lib/shared/services/navigation_service.dart
- lib/services/cache_service.dart → lib/shared/services/cache_service.dart
- lib/services/performance_service.dart → lib/shared/services/performance_service.dart
- lib/services/retry_service.dart → lib/shared/services/retry_service.dart
- lib/services/validation_service.dart → lib/shared/services/validation_service.dart

### Shared Widgets
- lib/widgets/common/common_widgets.dart → lib/shared/widgets/common/common_widgets.dart
- lib/widgets/common/app_card.dart → lib/shared/widgets/common/app_card.dart
- lib/widgets/common/adaptive_layout.dart → lib/shared/widgets/common/adaptive_layout.dart
- lib/widgets/common/custom_list_tile.dart → lib/shared/widgets/common/custom_list_tile.dart
- lib/widgets/common/empty_state.dart → lib/shared/widgets/common/empty_state.dart
- lib/widgets/common/error_aware_stream_builder.dart → lib/shared/widgets/common/error_aware_stream_builder.dart
- lib/widgets/common/firebase_error_boundary.dart → lib/shared/widgets/common/firebase_error_boundary.dart
- lib/widgets/common/global_error_handler.dart → lib/shared/widgets/common/global_error_handler.dart
- lib/widgets/common/responsive_layout.dart → lib/shared/widgets/common/responsive_layout.dart
- lib/widgets/common/stat_card.dart → lib/shared/widgets/common/stat_card.dart
- lib/widgets/common/status_badge.dart → lib/shared/widgets/common/status_badge.dart

### Navigation Widgets
- lib/widgets/common/app_drawer.dart → lib/shared/widgets/navigation/app_drawer.dart
- lib/widgets/common/bottom_nav_bar.dart → lib/shared/widgets/navigation/bottom_nav_bar.dart
- lib/widgets/common/favorites_nav_bar.dart → lib/shared/widgets/navigation/favorites_nav_bar.dart

### Theme
- lib/theme/app_theme.dart → lib/shared/theme/app_theme.dart
- lib/theme/app_spacing.dart → lib/shared/theme/app_spacing.dart
- lib/theme/app_typography.dart → lib/shared/theme/app_typography.dart

### Core
- lib/core/app_initializer.dart → lib/shared/core/app_initializer.dart
- lib/core/service_locator.dart → lib/shared/core/service_locator.dart

### Utils
- lib/utils/error_handler.dart → lib/shared/utils/error_handler.dart

### Routing
- lib/routing/app_router.dart → lib/shared/routing/app_router.dart

### Config
- lib/firebase_options.dart → lib/config/firebase_options.dart
- firebase_options.dart → lib/config/firebase_options_backup.dart (remove after updating imports)

## Feature: Authentication

### Domain
- lib/repositories/auth_repository.dart → lib/features/auth/domain/repositories/auth_repository.dart
- lib/repositories/user_repository.dart → lib/features/auth/domain/repositories/user_repository.dart

### Data
- lib/repositories/auth_repository_impl.dart → lib/features/auth/data/repositories/auth_repository_impl.dart
- lib/repositories/user_repository_impl.dart → lib/features/auth/data/repositories/user_repository_impl.dart
- lib/services/auth_service.dart → lib/features/auth/data/services/auth_service.dart
- lib/services/google_sign_in_service.dart → lib/features/auth/data/services/google_sign_in_service.dart

### Presentation
- lib/providers/auth_provider.dart → lib/features/auth/presentation/providers/auth_provider.dart
- lib/screens/auth/login_screen.dart → lib/features/auth/presentation/screens/login_screen.dart
- lib/screens/auth/signup_screen.dart → lib/features/auth/presentation/screens/signup_screen.dart
- lib/screens/auth/role_selection_screen.dart → lib/features/auth/presentation/screens/role_selection_screen.dart
- lib/screens/auth/forgot_password_screen.dart → lib/features/auth/presentation/screens/forgot_password_screen.dart
- lib/widgets/auth/auth_text_field.dart → lib/features/auth/presentation/widgets/auth_text_field.dart
- lib/widgets/auth/google_sign_in_button_web.dart → lib/features/auth/presentation/widgets/google_sign_in_button_web.dart

## Feature: Games

### Domain
- lib/models/jeopardy_game.dart → lib/features/games/domain/models/jeopardy_game.dart

### Presentation
- lib/screens/games/jeopardy_screen.dart → lib/features/games/presentation/screens/jeopardy_screen.dart
- lib/screens/games/jeopardy_create_screen.dart → lib/features/games/presentation/screens/jeopardy_create_screen.dart
- lib/screens/games/jeopardy_play_screen.dart → lib/features/games/presentation/screens/jeopardy_play_screen.dart

## Feature: Calendar

### Domain
- lib/models/calendar_event.dart → lib/features/calendar/domain/models/calendar_event.dart
- lib/repositories/calendar_repository.dart → lib/features/calendar/domain/repositories/calendar_repository.dart

### Data
- lib/repositories/calendar_repository_impl.dart → lib/features/calendar/data/repositories/calendar_repository_impl.dart
- lib/services/calendar_service.dart → lib/features/calendar/data/services/calendar_service.dart
- lib/services/device_calendar_service.dart → lib/features/calendar/data/services/device_calendar_service.dart
- lib/services/device_calendar_service_factory.dart → lib/features/calendar/data/services/device_calendar_service_factory.dart
- lib/services/device_calendar_service_interface.dart → lib/features/calendar/data/services/device_calendar_service_interface.dart
- lib/services/device_calendar_service_mobile.dart → lib/features/calendar/data/services/device_calendar_service_mobile.dart
- lib/services/device_calendar_service_stub.dart → lib/features/calendar/data/services/device_calendar_service_stub.dart
- lib/services/device_calendar_service_web.dart → lib/features/calendar/data/services/device_calendar_service_web.dart

### Presentation
- lib/providers/calendar_provider.dart → lib/features/calendar/presentation/providers/calendar_provider.dart
- lib/screens/calendar_screen.dart → lib/features/calendar/presentation/screens/calendar_screen.dart

## Feature: Chat

### Domain
- lib/models/chat_room.dart → lib/features/chat/domain/models/chat_room.dart
- lib/models/message.dart → lib/features/chat/domain/models/message.dart
- lib/models/call.dart → lib/features/chat/domain/models/call.dart
- lib/repositories/chat_repository.dart → lib/features/chat/domain/repositories/chat_repository.dart

### Data
- lib/repositories/chat_repository_impl.dart → lib/features/chat/data/repositories/chat_repository_impl.dart
- lib/services/chat_service.dart → lib/features/chat/data/services/chat_service.dart
- lib/services/webrtc_service.dart → lib/features/chat/data/services/webrtc_service.dart
- lib/services/scheduled_messages_service.dart → lib/features/chat/data/services/scheduled_messages_service.dart

### Presentation
- lib/providers/chat_provider.dart → lib/features/chat/presentation/providers/chat_provider.dart
- lib/providers/call_provider.dart → lib/features/chat/presentation/providers/call_provider.dart
- lib/screens/chat/chat_list_screen.dart → lib/features/chat/presentation/screens/chat_list_screen.dart
- lib/screens/chat/chat_detail_screen.dart → lib/features/chat/presentation/screens/chat_detail_screen.dart
- lib/screens/chat/call_screen.dart → lib/features/chat/presentation/screens/call_screen.dart
- lib/screens/chat/incoming_call_screen.dart → lib/features/chat/presentation/screens/incoming_call_screen.dart
- lib/screens/chat/group_creation_screen.dart → lib/features/chat/presentation/screens/group_creation_screen.dart
- lib/screens/chat/user_selection_screen.dart → lib/features/chat/presentation/screens/user_selection_screen.dart
- lib/screens/chat/class_selection_screen.dart → lib/features/chat/presentation/screens/class_selection_screen.dart

## Feature: Assignments

### Domain
- lib/models/assignment.dart → lib/features/assignments/domain/models/assignment.dart
- lib/models/submission.dart → lib/features/assignments/domain/models/submission.dart
- lib/repositories/assignment_repository.dart → lib/features/assignments/domain/repositories/assignment_repository.dart
- lib/repositories/submission_repository.dart → lib/features/assignments/domain/repositories/submission_repository.dart

### Data
- lib/repositories/assignment_repository_impl.dart → lib/features/assignments/data/repositories/assignment_repository_impl.dart
- lib/repositories/submission_repository_impl.dart → lib/features/assignments/data/repositories/submission_repository_impl.dart
- lib/services/assignment_service.dart → lib/features/assignments/data/services/assignment_service.dart
- lib/services/submission_service.dart → lib/features/assignments/data/services/submission_service.dart

### Presentation
- lib/providers/assignment_provider.dart → lib/features/assignments/presentation/providers/assignment_provider.dart
- lib/providers/student_assignment_provider.dart → lib/features/assignments/presentation/providers/student_assignment_provider.dart
- lib/screens/teacher/assignments_screen.dart → lib/features/assignments/presentation/screens/teacher/assignments_list_screen.dart
- lib/screens/teacher/assignments/assignment_create_screen.dart → lib/features/assignments/presentation/screens/teacher/assignment_create_screen.dart
- lib/screens/teacher/assignments/assignment_detail_screen.dart → lib/features/assignments/presentation/screens/teacher/assignment_detail_screen.dart
- lib/screens/teacher/assignments/assignment_edit_screen.dart → lib/features/assignments/presentation/screens/teacher/assignment_edit_screen.dart
- lib/screens/student/assignments_screen.dart → lib/features/assignments/presentation/screens/student/assignments_list_screen.dart
- lib/screens/student/assignment_submission_screen.dart → lib/features/assignments/presentation/screens/student/assignment_submission_screen.dart

## Feature: Grades

### Domain
- lib/models/grade.dart → lib/features/grades/domain/models/grade.dart
- lib/models/grade_analytics.dart → lib/features/grades/domain/models/grade_analytics.dart
- lib/repositories/grade_repository.dart → lib/features/grades/domain/repositories/grade_repository.dart

### Data
- lib/repositories/grade_repository_impl.dart → lib/features/grades/data/repositories/grade_repository_impl.dart
- lib/services/grade_analytics_service.dart → lib/features/grades/data/services/grade_analytics_service.dart

### Presentation
- lib/providers/grade_provider.dart → lib/features/grades/presentation/providers/grade_provider.dart
- lib/providers/grade_analytics_provider.dart → lib/features/grades/presentation/providers/grade_analytics_provider.dart
- lib/screens/teacher/gradebook/gradebook_screen.dart → lib/features/grades/presentation/screens/teacher/gradebook_screen.dart
- lib/screens/teacher/grade_analytics_screen.dart → lib/features/grades/presentation/screens/teacher/grade_analytics_screen.dart
- lib/screens/student/grades_screen.dart → lib/features/grades/presentation/screens/student/grades_screen.dart

## Feature: Classes

### Domain
- lib/models/class_model.dart → lib/features/classes/domain/models/class_model.dart
- lib/repositories/class_repository.dart → lib/features/classes/domain/repositories/class_repository.dart

### Data
- lib/repositories/class_repository_impl.dart → lib/features/classes/data/repositories/class_repository_impl.dart
- lib/services/class_service.dart → lib/features/classes/data/services/class_service.dart
- lib/services/class_service_enhanced.dart → lib/features/classes/data/services/class_service_enhanced.dart

### Presentation
- lib/providers/class_provider.dart → lib/features/classes/presentation/providers/class_provider.dart
- lib/screens/teacher/classes/classes_screen.dart → lib/features/classes/presentation/screens/teacher/classes_screen.dart
- lib/screens/student/courses_screen.dart → lib/features/classes/presentation/screens/student/courses_screen.dart
- lib/screens/student/enrollment_screen.dart → lib/features/classes/presentation/screens/student/enrollment_screen.dart
- lib/widgets/teacher/create_class_dialog.dart → lib/features/classes/presentation/widgets/create_class_dialog.dart

## Feature: Discussions

### Domain
- lib/models/discussion_board.dart → lib/features/discussions/domain/models/discussion_board.dart
- lib/repositories/discussion_repository.dart → lib/features/discussions/domain/repositories/discussion_repository.dart

### Data
- lib/repositories/discussion_repository_impl.dart → lib/features/discussions/data/repositories/discussion_repository_impl.dart

### Presentation
- lib/providers/discussion_provider.dart → lib/features/discussions/presentation/providers/discussion_provider.dart
- lib/screens/discussions/discussion_boards_screen.dart → lib/features/discussions/presentation/screens/discussion_boards_screen.dart
- lib/screens/discussions/discussion_board_detail_screen.dart → lib/features/discussions/presentation/screens/discussion_board_detail_screen.dart
- lib/screens/discussions/thread_detail_screen.dart → lib/features/discussions/presentation/screens/thread_detail_screen.dart
- lib/screens/discussions/create_board_dialog.dart → lib/features/discussions/presentation/widgets/create_board_dialog.dart
- lib/screens/discussions/create_thread_dialog.dart → lib/features/discussions/presentation/widgets/create_thread_dialog.dart

## Feature: Notifications

### Domain
- lib/models/notification.dart → lib/features/notifications/domain/models/notification.dart
- lib/models/notification_model.dart → lib/features/notifications/domain/models/notification_model.dart

### Data
- lib/services/notification_service.dart → lib/features/notifications/data/services/notification_service.dart
- lib/services/firebase_notification_service.dart → lib/features/notifications/data/services/firebase_notification_service.dart

### Presentation
- lib/providers/notification_provider.dart → lib/features/notifications/presentation/providers/notification_provider.dart
- lib/screens/notifications_screen.dart → lib/features/notifications/presentation/screens/notifications_screen.dart
- lib/screens/student/notifications_screen.dart → lib/features/notifications/presentation/screens/student_notifications_screen.dart

## Feature: Student

### Domain
- lib/models/student.dart → lib/features/student/domain/models/student.dart
- lib/repositories/student_repository.dart → lib/features/student/domain/repositories/student_repository.dart

### Data
- lib/repositories/student_repository_impl.dart → lib/features/student/data/repositories/student_repository_impl.dart
- lib/services/student_service.dart → lib/features/student/data/services/student_service.dart
- lib/services/presence_service.dart → lib/features/student/data/services/presence_service.dart

### Presentation
- lib/providers/student_provider.dart → lib/features/student/presentation/providers/student_provider.dart
- lib/screens/student/student_dashboard_screen.dart → lib/features/student/presentation/screens/student_dashboard_screen.dart
- lib/screens/student/messages_screen.dart → lib/features/student/presentation/screens/messages_screen.dart
- lib/screens/teacher/students_screen.dart → lib/features/student/presentation/screens/teacher/students_screen.dart
- lib/widgets/dashboard/online_users_card.dart → lib/features/student/presentation/widgets/online_users_card.dart

## Feature: Teacher

### Presentation
- lib/screens/teacher/teacher_dashboard_screen.dart → lib/features/teacher/presentation/screens/teacher_dashboard_screen.dart
- lib/screens/teacher/messages_screen.dart → lib/features/teacher/presentation/screens/messages_screen.dart

## Other Screens

### Common
- lib/screens/common/dashboard_screen.dart → lib/shared/screens/dashboard_screen.dart
- lib/screens/common/placeholder_screen.dart → lib/shared/screens/placeholder_screen.dart
- lib/screens/help_screen.dart → lib/shared/screens/help_screen.dart
- lib/screens/contact_support_screen.dart → lib/shared/screens/contact_support_screen.dart
- lib/screens/settings_screen.dart → lib/shared/screens/settings_screen.dart
- lib/screens/debug/update_display_name_screen.dart → lib/shared/screens/debug/update_display_name_screen.dart

## Providers (Shared)
- lib/providers/app_providers.dart → lib/shared/providers/app_providers.dart
- lib/providers/theme_provider.dart → lib/shared/providers/theme_provider.dart
- lib/providers/navigation_provider.dart → lib/shared/providers/navigation_provider.dart

## Files to Keep in Place
- lib/main.dart (update imports only)