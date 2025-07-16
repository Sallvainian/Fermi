import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'auth_provider.dart';
import 'assignment_provider.dart';
import 'student_assignment_provider.dart';
import 'theme_provider.dart';
import 'chat_provider.dart';
import '../features/discussions/presentation/providers/discussion_provider.dart';
import 'calendar_provider.dart';
import '../features/grades/presentation/providers/grade_analytics_provider.dart';
import 'navigation_provider.dart';
import 'call_provider.dart';
import 'notification_provider.dart';
import '../features/classes/presentation/providers/class_provider.dart';

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