import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/teacher/presentation/screens/teacher_dashboard_screen.dart';
import '../../features/student/presentation/screens/student_dashboard_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';
import '../../features/chat/presentation/screens/simple_chat_screen.dart';
import '../../features/chat/presentation/screens/user_selection_screen.dart';
import '../../features/chat/presentation/screens/group_creation_screen.dart';
import '../../features/chat/presentation/screens/class_selection_screen.dart';
import '../../features/chat/presentation/screens/call_screen.dart';
import '../../features/chat/presentation/screens/incoming_call_screen.dart';
import '../../features/chat/domain/models/call.dart';
import '../../features/classes/presentation/screens/teacher/classes_screen.dart';
import '../../features/classes/presentation/screens/teacher/class_detail_screen.dart';
import '../../features/classes/presentation/screens/student/courses_screen.dart';
import '../../features/classes/presentation/screens/student/enrollment_screen.dart';
import '../../features/assignments/presentation/screens/teacher/assignments_list_screen.dart' as teacher_assignments;
import '../../features/assignments/presentation/screens/teacher/assignment_create_screen.dart';
import '../../features/assignments/presentation/screens/teacher/assignment_detail_screen.dart';
import '../../features/assignments/presentation/screens/teacher/assignment_edit_screen.dart';
import '../../features/assignments/presentation/screens/student/assignments_list_screen.dart' as student_assignments;
import '../../features/assignments/presentation/screens/student/assignment_submission_screen.dart';
import '../../features/grades/presentation/screens/teacher/gradebook_screen.dart';
import '../../features/grades/presentation/screens/teacher/grade_analytics_screen.dart';
import '../../features/grades/presentation/screens/student/grades_screen.dart';
import '../../features/student/presentation/screens/teacher/students_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/discussions/presentation/screens/discussion_boards_screen.dart';
import '../../features/discussions/presentation/screens/discussion_board_detail_screen.dart';
import '../../features/games/presentation/screens/jeopardy_screen.dart';
import '../../features/games/presentation/screens/jeopardy_create_screen.dart';
import '../../features/games/presentation/screens/jeopardy_play_screen.dart';
import '../screens/settings_screen.dart';
import '../models/user_model.dart';

/// Simplified router following Flutter best practices for auth handling.
/// 
/// Key principles:
/// 1. Simple redirect logic - only handle auth vs unauth
/// 2. No initialLocation - preserves browser URL on refresh  
/// 3. Let UI components handle complex state (role selection, email verification)
/// 4. Router just routes - doesn't enforce business logic
class AppRouter {
  
  /// Creates the app router with auth-aware navigation.
  /// 
  /// Standard Flutter pattern:
  /// - Watches auth state changes via refreshListenable
  /// - Simple redirect: unauthenticated users go to login
  /// - Authenticated users on auth routes go to dashboard
  /// - Everything else is allowed (handled by UI)
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuth = authProvider.status == AuthStatus.authenticated;
        final isAuthRoute = state.matchedLocation.startsWith('/auth');
        
        // During initialization, don't redirect
        // The app shows a loading screen before router is created
        if (authProvider.status == AuthStatus.uninitialized) {
          return null;
        }
        
        // Simple redirect logic - standard Flutter pattern
        if (!isAuth && !isAuthRoute) {
          // Not authenticated and trying to access protected route
          return '/auth/login';
        }
        
        if (isAuth && isAuthRoute) {
          // Authenticated but on auth route - go to dashboard
          return '/dashboard';
        }
        
        // Allow everything else
        return null;
      },
      routes: [
        // Root redirect
        GoRoute(
          path: '/',
          redirect: (context, state) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            return auth.isAuthenticated ? '/dashboard' : '/auth/login';
          },
        ),
        
        // Auth routes
        GoRoute(
          path: '/auth/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/signup', 
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/auth/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/auth/role-selection',
          builder: (context, state) => const RoleSelectionScreen(),
        ),
        GoRoute(
          path: '/auth/verify-email',
          builder: (context, state) => const VerifyEmailScreen(),
        ),
        
        // Main app routes
        GoRoute(
          path: '/dashboard',
          builder: (context, state) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            final user = auth.userModel;
            
            // Simple role-based dashboard
            if (user?.role == UserRole.teacher) {
              return const TeacherDashboardScreen();
            } else if (user?.role == UserRole.student) {
              return const StudentDashboardScreen();
            }
            
            // Fallback - shouldn't happen if auth is working
            return const Scaffold(
              body: Center(child: Text('Loading dashboard...')),
            );
          },
        ),
        
        // Chat routes
        GoRoute(
          path: '/messages',
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: '/messages/:chatRoomId',
          builder: (context, state) {
            final chatRoomId = state.pathParameters['chatRoomId']!;
            return ChatDetailScreen(chatRoomId: chatRoomId);
          },
        ),
        GoRoute(
          path: '/chat/:chatRoomId',
          builder: (context, state) {
            final chatRoomId = state.pathParameters['chatRoomId']!;
            return ChatDetailScreen(chatRoomId: chatRoomId);
          },
        ),
        GoRoute(
          path: '/simple-chat/:chatRoomId',
          builder: (context, state) {
            final chatRoomId = state.pathParameters['chatRoomId']!;
            final title = state.uri.queryParameters['title'] ?? 'Chat';
            return SimpleChatScreen(
              chatRoomId: chatRoomId,
              chatTitle: title,
            );
          },
        ),
        GoRoute(
          path: '/chat/simple/:chatRoomId',
          builder: (context, state) {
            final chatRoomId = state.pathParameters['chatRoomId'] ?? 'default';
            final chatTitle = state.uri.queryParameters['title'] ?? 'Chat';
            return SimpleChatScreen(
              chatRoomId: chatRoomId,
              chatTitle: chatTitle,
            );
          },
        ),
        
        // Chat creation routes
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
        
        // Settings
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        
        // Teacher routes
        GoRoute(
          path: '/teacher/classes',
          builder: (context, state) => const ClassesScreen(),
        ),
        GoRoute(
          path: '/class/:classId',
          builder: (context, state) {
            final classId = state.pathParameters['classId']!;
            return ClassDetailScreen(classId: classId);
          },
        ),
        GoRoute(
          path: '/teacher/assignments',
          builder: (context, state) =>
              const teacher_assignments.TeacherAssignmentsScreen(),
        ),
        GoRoute(
          path: '/teacher/assignments/create',
          builder: (context, state) => const AssignmentCreateScreen(),
        ),
        GoRoute(
          path: '/teacher/assignments/:assignmentId',
          builder: (context, state) {
            final assignmentId = state.pathParameters['assignmentId']!;
            return AssignmentDetailScreen(assignmentId: assignmentId);
          },
        ),
        GoRoute(
          path: '/teacher/assignments/:assignmentId/edit',
          builder: (context, state) {
            final assignmentId = state.pathParameters['assignmentId']!;
            return AssignmentEditScreen(assignmentId: assignmentId);
          },
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
          path: '/teacher/students',
          builder: (context, state) => const TeacherStudentsScreen(),
        ),
        GoRoute(
          path: '/teacher/games/jeopardy',
          builder: (context, state) => const JeopardyScreen(),
        ),
        GoRoute(
          path: '/teacher/games/jeopardy/create',
          builder: (context, state) => const JeopardyCreateScreen(),
        ),
        GoRoute(
          path: '/teacher/games/jeopardy/:gameId/play',
          builder: (context, state) {
            final gameId = state.pathParameters['gameId']!;
            return JeopardyPlayScreen(gameId: gameId);
          },
        ),
        GoRoute(
          path: '/teacher/games/jeopardy/:gameId/edit',
          builder: (context, state) {
            final gameId = state.pathParameters['gameId']!;
            return JeopardyCreateScreen(gameId: gameId);
          },
        ),
        GoRoute(
          path: '/grades',
          builder: (context, state) => const GradebookScreen(),
        ),
        GoRoute(
          path: '/assignments',
          builder: (context, state) => 
              const teacher_assignments.TeacherAssignmentsScreen(),
        ),
        
        // Student routes
        GoRoute(
          path: '/student/courses',
          builder: (context, state) => const StudentCoursesScreen(),
        ),
        GoRoute(
          path: '/student/assignments',
          builder: (context, state) =>
              const student_assignments.StudentAssignmentsScreen(),
        ),
        GoRoute(
          path: '/student/assignments/:assignmentId/submit',
          builder: (context, state) {
            final assignmentId = state.pathParameters['assignmentId']!;
            return AssignmentSubmissionScreen(assignmentId: assignmentId);
          },
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
          path: '/student/messages',
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: '/student/messages/:chatRoomId',
          builder: (context, state) {
            final chatRoomId = state.pathParameters['chatRoomId']!;
            return ChatDetailScreen(chatRoomId: chatRoomId);
          },
        ),
        GoRoute(
          path: '/student/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/student/discussions',
          builder: (context, state) => const DiscussionBoardsScreen(),
        ),
        
        // Common routes
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/discussions',
          builder: (context, state) => const DiscussionBoardsScreen(),
        ),
        GoRoute(
          path: '/discussions/:boardId',
          builder: (context, state) {
            final boardId = state.pathParameters['boardId']!;
            final boardTitle = state.uri.queryParameters['title'] ?? 
                'Discussion Board';
            return DiscussionBoardDetailScreen(
              boardId: boardId,
              boardTitle: boardTitle,
            );
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
        
        // Add other routes as needed, keeping them simple and flat
      ],
      
      // Error handling
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Page not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}