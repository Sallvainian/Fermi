import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/call.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/teacher/teacher_dashboard_screen.dart';
import '../screens/teacher/classes/classes_screen.dart';
import '../screens/teacher/gradebook/gradebook_screen.dart';
import '../screens/teacher/grade_analytics_screen.dart';
import '../screens/teacher/assignments_screen.dart';
import '../screens/teacher/assignments/assignment_create_screen.dart';
import '../screens/teacher/assignments/assignment_detail_screen.dart';
import '../screens/teacher/assignments/assignment_edit_screen.dart';
import '../screens/teacher/students_screen.dart';
import '../screens/student/student_dashboard_screen.dart';
import '../screens/student/courses_screen.dart';
import '../screens/student/grades_screen.dart';
import '../screens/student/assignments_screen.dart';
import '../screens/student/assignment_submission_screen.dart';
import '../screens/student/enrollment_screen.dart';
import '../../features/notifications/presentation/screens/student_notifications_screen.dart' as student_notifications;
import '../screens/settings_screen.dart';
import '../screens/debug/update_display_name_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_detail_screen.dart';
import '../screens/chat/user_selection_screen.dart';
import '../screens/chat/group_creation_screen.dart';
import '../screens/chat/class_selection_screen.dart';
import '../screens/chat/call_screen.dart';
import '../screens/chat/incoming_call_screen.dart';
import '../screens/discussions/discussion_boards_screen.dart';
import '../screens/discussions/discussion_board_detail_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../screens/common/dashboard_screen.dart';
import '../screens/contact_support_screen.dart';
import '../../features/games/presentation/screens/jeopardy_screen.dart';
import '../../features/games/presentation/screens/jeopardy_play_screen.dart';
import '../../features/games/presentation/screens/jeopardy_create_screen.dart';

/// App router configuration
class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/auth/login',
      refreshListenable: authProvider,
      redirect: (context, state) => _handleRedirect(authProvider, state),
      routes: [
        ..._authRoutes(),
        ..._teacherRoutes(),
        ..._studentRoutes(),
        ..._commonRoutes(),
        _rootRedirect(),
      ],
    );
  }
  
  /// Handle authentication redirects
  static String? _handleRedirect(AuthProvider authProvider, GoRouterState state) {
    final isAuthenticated = authProvider.isAuthenticated;
    final isAuthRoute = state.matchedLocation.startsWith('/auth');
    
    // If not authenticated and trying to access protected route
    if (!isAuthenticated && !isAuthRoute) {
      return '/auth/login';
    }
    
    // If authenticated and trying to access auth routes
    if (isAuthenticated && isAuthRoute) {
      return '/dashboard';
    }
    
    // If authenticated but needs role selection (Google sign-in)
    if (authProvider.status == AuthStatus.authenticating &&
        state.matchedLocation != '/auth/role-selection') {
      return '/auth/role-selection';
    }
    
    return null;
  }
  
  /// Authentication routes
  static List<GoRoute> _authRoutes() => [
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/auth/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/auth/role-selection',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/auth/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
  ];
  
  /// Teacher-specific routes
  static List<GoRoute> _teacherRoutes() => [
    GoRoute(
      path: '/teacher/classes',
      builder: (context, state) => const ClassesScreen(),
    ),
    GoRoute(
      path: '/teacher/gradebook',
      builder: (context, state) => const GradebookScreen(),
    ),
    GoRoute(
      path: '/teacher/analytics',
      builder: (context, state) {
        final classId = state.uri.queryParameters['classId'];
        return GradeAnalyticsScreen(classId: classId);
      },
    ),
    GoRoute(
      path: '/teacher/assignments',
      builder: (context, state) => const TeacherAssignmentsScreen(),
      routes: [
        GoRoute(
          path: 'create',
          builder: (context, state) => const AssignmentCreateScreen(),
        ),
        GoRoute(
          path: ':assignmentId',
          builder: (context, state) {
            final assignmentId = state.pathParameters['assignmentId']!;
            return AssignmentDetailScreen(assignmentId: assignmentId);
          },
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final assignmentId = state.pathParameters['assignmentId']!;
                return AssignmentEditScreen(assignmentId: assignmentId);
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/teacher/students',
      builder: (context, state) => const TeacherStudentsScreen(),
    ),
    GoRoute(
      path: '/teacher/games/jeopardy',
      builder: (context, state) => const JeopardyScreen(),
      routes: [
        GoRoute(
          path: 'create',
          builder: (context, state) => const JeopardyCreateScreen(),
        ),
        GoRoute(
          path: ':gameId/edit',
          builder: (context, state) {
            final gameId = state.pathParameters['gameId']!;
            return JeopardyCreateScreen(gameId: gameId);
          },
        ),
        GoRoute(
          path: ':gameId/play',
          builder: (context, state) {
            final gameId = state.pathParameters['gameId']!;
            return JeopardyPlayScreen(gameId: gameId);
          },
        ),
      ],
    ),
  ];
  
  /// Student-specific routes
  static List<GoRoute> _studentRoutes() => [
    GoRoute(
      path: '/student/courses',
      builder: (context, state) => const StudentCoursesScreen(),
    ),
    GoRoute(
      path: '/student/assignments',
      builder: (context, state) => const StudentAssignmentsScreen(),
      routes: [
        GoRoute(
          path: ':assignmentId/submit',
          builder: (context, state) {
            final assignmentId = state.pathParameters['assignmentId']!;
            return AssignmentSubmissionScreen(assignmentId: assignmentId);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/student/grades',
      builder: (context, state) => const StudentGradesScreen(),
    ),
    GoRoute(
      path: '/student/enroll',
      builder: (context, state) => const EnrollmentScreen(),
    ),
    GoRoute(
      path: '/student/notifications',
      builder: (context, state) => const student_notifications.StudentNotificationsScreen(),
    ),
  ];
  
  /// Common routes available to all users
  static List<GoRoute> _commonRoutes() => [
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => _buildDashboard(context),
    ),
    GoRoute(
      path: '/messages',
      builder: (context, state) => const ChatListScreen(),
      routes: [
        GoRoute(
          path: ':chatRoomId',
          builder: (context, state) {
            final chatRoomId = state.pathParameters['chatRoomId']!;
            return ChatDetailScreen(chatRoomId: chatRoomId);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/discussions',
      builder: (context, state) => const DiscussionBoardsScreen(),
    ),
    GoRoute(
      path: '/discussions/:boardId',
      builder: (context, state) {
        final boardId = state.pathParameters['boardId']!;
        final boardTitle = state.uri.queryParameters['title'] ?? 'Discussion Board';
        return DiscussionBoardDetailScreen(
          boardId: boardId,
          boardTitle: boardTitle,
        );
      },
    ),
    GoRoute(
      path: '/chat/user-selection',
      builder: (context, state) => const UserSelectionScreen(),
    ),
    GoRoute(
      path: '/chat/group-creation',
      builder: (context, state) => const GroupCreationScreen(),
    ),
    GoRoute(
      path: '/chat/class-selection',
      builder: (context, state) => const ClassSelectionScreen(),
    ),
    GoRoute(
      path: '/chat/:chatRoomId',
      builder: (context, state) {
        final chatRoomId = state.pathParameters['chatRoomId']!;
        return ChatDetailScreen(chatRoomId: chatRoomId);
      },
    ),
    GoRoute(
      path: '/call',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return CallScreen(
          callId: extra['callId'],
          receiverId: extra['receiverId'],
          receiverName: extra['receiverName'],
          receiverPhotoUrl: extra['receiverPhotoUrl'],
          isVideoCall: extra['isVideoCall'] ?? false,
          chatRoomId: extra['chatRoomId'],
        );
      },
    ),
    GoRoute(
      path: '/incoming-call',
      builder: (context, state) {
        final call = state.extra as Call;
        return IncomingCallScreen(call: call);
      },
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/contact-support',
      builder: (context, state) => const ContactSupportScreen(),
    ),
    GoRoute(
      path: '/debug/update-name',
      builder: (context, state) => const UpdateDisplayNameScreen(),
    ),
  ];
  
  /// Root redirect
  static GoRoute _rootRedirect() => GoRoute(
    path: '/',
    redirect: (_, __) => '/auth/login',
  );
  
  /// Build appropriate dashboard based on user role
  static Widget _buildDashboard(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    
    if (user?.role == UserRole.teacher) {
      return const TeacherDashboardScreen();
    } else if (user?.role == UserRole.student) {
      return const StudentDashboardScreen();
    } else {
      return const DashboardScreen(); // Admin or fallback
    }
  }
}