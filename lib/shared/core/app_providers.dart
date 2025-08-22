import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/assignments/presentation/providers/assignment_provider.dart';
import '../../features/assignments/presentation/providers/student_assignment_provider.dart';
import '../providers/theme_provider.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import '../../features/discussions/presentation/providers/discussion_provider_simple.dart';
import '../../features/calendar/presentation/providers/calendar_provider.dart';
import '../../features/grades/presentation/providers/grade_analytics_provider.dart';
import '../providers/navigation_provider.dart';
import '../../features/chat/presentation/providers/call_provider.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../../features/classes/presentation/providers/class_provider.dart';
import '../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../features/student/presentation/providers/student_provider.dart';
import '../../features/grades/presentation/providers/grade_provider.dart';
import '../../features/games/presentation/providers/jeopardy_provider.dart';

/// Centralized provider configuration
class AppProviders {
  /// Create all app providers with lazy loading for non-critical providers
  static List<SingleChildWidget> getProviders() {
    return [
      // CRITICAL: Always needed immediately
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),

      // LAZY: Dashboard provider - only create when dashboard is accessed
      ChangeNotifierProvider(
        create: (_) => DashboardProvider(),
        lazy: true,
      ),

      // LAZY: Feature-specific providers loaded on demand
      ChangeNotifierProvider(
        create: (_) => ClassProvider(),
        lazy: true, // Only create when first accessed
      ),
      ChangeNotifierProvider(
        create: (_) => AssignmentProvider(),
        lazy: true,
      ),
      ChangeNotifierProvider(
        create: (_) => StudentAssignmentProvider(),
        lazy: true,
      ),
      ChangeNotifierProvider(
        create: (_) => ChatProvider(),
        lazy: true,
      ),
      ChangeNotifierProvider(
        create: (_) => SimpleDiscussionProvider(),
        lazy: true,
      ),
      ChangeNotifierProvider(
        create: (_) => CalendarProvider(),
        lazy: true,
      ),
      ChangeNotifierProvider(
        create: (_) => GradeAnalyticsProvider(),
        lazy: true,
      ),
      ChangeNotifierProvider(
        create: (_) => CallProvider(),
        lazy: true,
      ),
      ChangeNotifierProvider(
        create: (_) => NotificationProvider(),
        lazy: true,
      ),
      ChangeNotifierProvider(
        create: (_) => StudentProvider(),
        lazy: true,
      ),
      ChangeNotifierProvider(
        create: (_) => GradeProvider(),
        lazy: true,
      ),

      // Jeopardy game provider
      ChangeNotifierProvider(
        create: (_) => JeopardyProvider(),
        lazy: true,
      ),
    ];
  }
}
