import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/assignments/presentation/providers/assignment_provider.dart';
import '../../features/assignments/presentation/providers/student_assignment_provider.dart';
import '../providers/theme_provider.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import '../../features/discussions/presentation/providers/discussion_provider.dart';
import '../../features/calendar/presentation/providers/calendar_provider.dart';
import '../../features/grades/presentation/providers/grade_analytics_provider.dart';
import '../providers/navigation_provider.dart';
import '../../features/chat/presentation/providers/call_provider.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../../features/classes/presentation/providers/class_provider.dart';

/// Centralized provider configuration
class AppProviders {
  /// Create all app providers
  static List<SingleChildWidget> getProviders() {
    return [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ClassProvider()),
      ChangeNotifierProvider(create: (_) => AssignmentProvider()),
      ChangeNotifierProvider(create: (_) => StudentAssignmentProvider()),
      ChangeNotifierProvider(create: (_) => ChatProvider()),
      ChangeNotifierProvider(create: (_) => DiscussionProvider()),
      ChangeNotifierProvider(create: (_) => CalendarProvider()),
      ChangeNotifierProvider(create: (_) => GradeAnalyticsProvider()),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => CallProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
    ];
  }
}