import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../../features/chat/domain/models/call.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/teacher/presentation/screens/teacher_dashboard_screen.dart';
import '../../features/classes/presentation/screens/teacher/classes_screen.dart';
import '../../features/classes/presentation/screens/teacher/class_detail_screen.dart';
import '../../features/grades/presentation/screens/teacher/gradebook_screen.dart';
import '../../features/grades/presentation/screens/teacher/grade_analytics_screen.dart';
import '../../features/assignments/presentation/screens/teacher/assignments_list_screen.dart' as teacher_assignments;
import '../../features/assignments/presentation/screens/teacher/assignment_create_screen.dart';
import '../../features/assignments/presentation/screens/teacher/assignment_detail_screen.dart';
import '../../features/assignments/presentation/screens/teacher/assignment_edit_screen.dart';
import '../../features/student/presentation/screens/teacher/students_screen.dart';
import '../../features/student/presentation/screens/student_dashboard_screen.dart';
import '../../features/classes/presentation/screens/student/courses_screen.dart';
import '../../features/grades/presentation/screens/student/grades_screen.dart';
import '../../features/assignments/presentation/screens/student/assignments_list_screen.dart' as student_assignments;
import '../../features/assignments/presentation/screens/student/assignment_submission_screen.dart';
import '../../features/classes/presentation/screens/student/enrollment_screen.dart';
// import '../../features/notifications/presentation/screens/student_notifications_screen.dart' as student_notifications;
import '../screens/settings_screen.dart';
import '../screens/debug/debug/update_display_name_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';
import '../../features/chat/presentation/screens/user_selection_screen.dart';
import '../../features/chat/presentation/screens/group_creation_screen.dart';
import '../../features/chat/presentation/screens/class_selection_screen.dart';
import '../../features/chat/presentation/screens/call_screen.dart';
import '../../features/chat/presentation/screens/incoming_call_screen.dart';
import '../../features/discussions/presentation/screens/discussion_boards_screen.dart';
import '../../features/discussions/presentation/screens/discussion_board_detail_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../screens/common/common/dashboard_screen.dart';
import '../screens/contact_support_screen.dart';
// import '../../features/games/presentation/screens/jeopardy_screen.dart';
// import '../../features/games/presentation/screens/jeopardy_play_screen.dart';
// import '../../features/games/presentation/screens/jeopardy_create_screen.dart';

/// Application router configuration using GoRouter for declarative navigation.
///
/// This class provides the main routing configuration for the Teacher Dashboard
/// application, implementing role-based navigation with authentication guards.
/// It supports Teacher, Student, and Admin roles with appropriate route restrictions.
///
/// Features:
/// - Authentication-based route protection
/// - Role-based route access (Teacher/Student/Admin)
/// - Automatic redirects based on auth state
/// - Nested route support for complex navigation hierarchies
/// - Parameter extraction from routes (IDs, query params)
///
/// The router uses a hierarchical structure:
/// - `/auth/*` - Authentication routes (login, signup, role selection)
/// - `/teacher/*` - Teacher-specific routes (classes, assignments, analytics)
/// - `/student/*` - Student-specific routes (courses, grades, submissions)
/// - Common routes available to all authenticated users
///
/// Route protection is handled via [_handleRedirect] which checks authentication
/// status and user roles before allowing access to protected routes.
class AppRouter {
  /// Creates and configures the main application router.
  ///
  /// This method initializes the GoRouter with authentication-aware routing,
  /// automatic redirects, and role-based access control. The router listens
  /// to the [authProvider] for authentication state changes and automatically
  /// handles redirects when the user's auth status changes.
  ///
  /// **Route Structure:**
  /// - Initial location: `/auth/login`
  /// - Auth routes: Login, signup, role selection, forgot password
  /// - Teacher routes: Classes, assignments, gradebook, analytics, students
  /// - Student routes: Courses, assignments, grades, enrollment
  /// - Common routes: Dashboard, messages, discussions, calendar, settings
  ///
  /// **Authentication Flow:**
  /// 1. Unauthenticated users → `/auth/login`
  /// 2. Authenticated users on auth routes → `/dashboard`
  /// 3. Google sign‑in users → `/auth/role-selection` (if role not set)
  /// 4. Role‑based dashboard routing (Teacher/Student/Admin)
  ///
  /// @param authProvider The authentication provider that manages user state
  /// @returns Configured GoRouter instance with all application routes
  ///
  /// **Example Usage:**
  /// ```dart
  /// final router = AppRouter.createRouter(authProvider);
  /// MaterialApp.router(routerConfig: router);
  /// ```
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

  /// Compute the redirection for a given auth state and route.
  ///
  /// This helper isolates the core redirect logic from GoRouter so that
  /// it can be unit tested without needing to construct a `GoRouterState`.
  /// The parameters mirror the inputs required by the original redirect:
  /// [isAuthenticated] indicates whether the user has a fully authenticated
  /// session; [status] reflects the broader authentication status from
  /// [AuthProvider]; and [matchedLocation] is the current route path.
  ///
  /// The rules enforced are:
  ///  - If the user is not authenticated (including uninitialized or error
  ///    states) and attempts to access a protected route (not under `/auth`),
  ///    they are redirected to `/auth/login`.
  ///  - Fully authenticated users attempting to access any auth route are
  ///    redirected to `/dashboard`.
  ///  - Users in the `authenticating` state (e.g. Google sign‑in without a role)
  ///    must complete role selection; any route other than `/auth/role-selection`
  ///    redirects them to `/auth/role-selection`.
  ///  - All other cases are allowed (return `null`).
  static String? computeRedirect({
    required bool isAuthenticated,
    required AuthStatus status,
    required bool emailVerified,
    required String matchedLocation,
    UserRole? role,
  }) {
    final bool isAuthRoute = matchedLocation.startsWith('/auth');

    // Determine broad auth buckets. Unauthenticated covers uninitialized and
    // error states as well, since [isAuthenticated] is derived from the
    // `AuthStatus.authenticated` value only.
    final bool unauthenticated = !isAuthenticated;
    final bool needsRoleSelection = status == AuthStatus.authenticating;
    final bool needsEmailVerification = isAuthenticated && !needsRoleSelection && !emailVerified;

    // Unauthenticated users are only allowed to access auth routes. Any
    // non‑auth route is redirected to the login page.
    if (unauthenticated) {
      if (!isAuthRoute) {
        return '/auth/login';
      }
      return null;
    }

    // Users awaiting role selection must complete it before proceeding. This
    // takes precedence over email verification, since a role is required to
    // create a user profile.
    if (needsRoleSelection) {
      if (matchedLocation != '/auth/role-selection') {
        return '/auth/role-selection';
      }
      return null;
    }

    // If the user is fully authenticated but their email is not verified,
    // they must go through the verify email flow. Only allow navigation
    // directly to the verification route until the email is confirmed.
    if (needsEmailVerification) {
      if (matchedLocation != '/auth/verify-email') {
        return '/auth/verify-email';
      }
      return null;
    }

    // At this point, the user is fully authenticated (role selected and
    // email verified). Auth routes are off‑limits and should redirect
    // to the dashboard.
    if (isAuthRoute) {
      return '/dashboard';
    }

    // Role‑based route protection. Once the user is authenticated and
    // email verified, restrict access to routes based on the assigned
    // role. Teacher routes start with `/teacher`; student routes start
    // with `/student`. Admins are allowed to access both.
    if (matchedLocation.startsWith('/teacher') && role != null && role != UserRole.teacher) {
      return '/dashboard';
    }
    if (matchedLocation.startsWith('/student') && role != null && role != UserRole.student) {
      return '/dashboard';
    }

    // No redirect necessary.
    return null;
  }

  /// Handles authentication‑based route redirects and access control.
  ///
  /// This method delegates to [computeRedirect] and simply adapts the
  /// parameters from [AuthProvider] and [GoRouterState]. Keeping this logic
  /// thin makes unit testing simpler and ensures the redirect rules are
  /// centralized in one place.
  static String? _handleRedirect(
    AuthProvider authProvider,
    GoRouterState state,
  ) {
    return computeRedirect(
      isAuthenticated: authProvider.isAuthenticated,
      status: authProvider.status,
      emailVerified: authProvider.firebaseUser?.emailVerified ?? false,
      matchedLocation: state.matchedLocation,
      role: authProvider.userModel?.role,
    );
  }

  /// Defines authentication‑related routes for user account management.
  ///
  /// This method creates all routes related to user authentication, including
  /// login, registration, role selection, and password recovery. These routes
  /// are accessible to unauthenticated users and handle the complete auth flow.
  static List<GoRoute> _authRoutes() => [
        GoRoute(
          path: '/auth/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/signup',
          name: 'signup',
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/auth/role-selection',
          name: 'roleSelection',
          builder: (context, state) => const RoleSelectionScreen(),
        ),
        GoRoute(
          path: '/auth/forgot-password',
          name: 'forgotPassword',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/auth/verify-email',
          name: 'verifyEmail',
          builder: (context, state) => const VerifyEmailScreen(),
        ),
      ];

  /// Defines routes exclusive to users with Teacher role.
  static List<GoRoute> _teacherRoutes() => [
        GoRoute(
          path: '/teacher/classes',
          name: 'teacherClasses',
          builder: (context, state) => const ClassesScreen(),
        ),
        GoRoute(
          path: '/class/:classId',
          name: 'classDetail',
          builder: (context, state) {
            final classId = state.pathParameters['classId']!;
            return ClassDetailScreen(classId: classId);
          },
        ),
        GoRoute(
          path: '/teacher/gradebook',
          name: 'gradebook',
          builder: (context, state) => const GradebookScreen(),
        ),
        GoRoute(
          path: '/teacher/analytics',
          name: 'analytics',
          builder: (context, state) {
            final classId = state.uri.queryParameters['classId'];
            return GradeAnalyticsScreen(classId: classId);
          },
        ),
        GoRoute(
          path: '/teacher/assignments',
          name: 'teacherAssignments',
          builder: (context, state) =>
              const teacher_assignments.TeacherAssignmentsScreen(),
          routes: [
            GoRoute(
              path: 'create',
              name: 'assignmentCreate',
              builder: (context, state) => const AssignmentCreateScreen(),
            ),
            GoRoute(
              path: ':assignmentId',
              name: 'assignmentDetail',
              builder: (context, state) {
                final assignmentId = state.pathParameters['assignmentId']!;
                return AssignmentDetailScreen(assignmentId: assignmentId);
              },
            ),
            GoRoute(
              path: ':assignmentId/edit',
              name: 'assignmentEdit',
              builder: (context, state) {
                final assignmentId = state.pathParameters['assignmentId']!;
                return AssignmentEditScreen(assignmentId: assignmentId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/teacher/students',
          name: 'students',
          builder: (context, state) => const TeacherStudentsScreen(),
        ),
      ];

  /// Defines routes exclusive to users with Student role.
  static List<GoRoute> _studentRoutes() => [
        GoRoute(
          path: '/student/courses',
          name: 'courses',
          builder: (context, state) => const StudentCoursesScreen(),
        ),
        GoRoute(
          path: '/student/grades',
          name: 'grades',
          builder: (context, state) => const StudentGradesScreen(),
        ),
        GoRoute(
          path: '/student/assignments',
          name: 'studentAssignments',
          builder: (context, state) =>
              const student_assignments.StudentAssignmentsScreen(),
          routes: [
            GoRoute(
              path: ':assignmentId',
              name: 'assignmentSubmission',
              builder: (context, state) {
                final assignmentId = state.pathParameters['assignmentId']!;
                return AssignmentSubmissionScreen(assignmentId: assignmentId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/student/enroll',
          name: 'enrollment',
          builder: (context, state) => const EnrollmentScreen(),
        ),
      ];

  /// Defines routes available to all authenticated users regardless of role.
  static List<GoRoute> _commonRoutes() => [
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => _buildDashboard(context),
        ),
        GoRoute(
          path: '/messages',
          name: 'chatList',
          builder: (context, state) => const ChatListScreen(),
          routes: [
            GoRoute(
              path: ':chatRoomId',
              name: 'chatDetail',
              builder: (context, state) {
                final chatRoomId = state.pathParameters['chatRoomId']!;
                return ChatDetailScreen(chatRoomId: chatRoomId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/discussions',
          name: 'discussions',
          builder: (context, state) => const DiscussionBoardsScreen(),
        ),
        GoRoute(
          path: '/discussions/:boardId',
          name: 'discussionDetail',
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
          path: '/chat/user-selection',
          name: 'userSelection',
          builder: (context, state) => const UserSelectionScreen(),
        ),
        GoRoute(
          path: '/chat/group-creation',
          name: 'groupCreation',
          builder: (context, state) => const GroupCreationScreen(),
        ),
        GoRoute(
          path: '/chat/class-selection',
          name: 'classSelection',
          builder: (context, state) => const ClassSelectionScreen(),
        ),
        GoRoute(
          path: '/chat/:chatRoomId',
          name: 'chatDetailRoot',
          builder: (context, state) {
            final chatRoomId = state.pathParameters['chatRoomId']!;
            return ChatDetailScreen(chatRoomId: chatRoomId);
          },
        ),
        GoRoute(
          path: '/call',
          name: 'call',
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
          name: 'incomingCall',
          builder: (context, state) {
            final call = state.extra as Call;
            return IncomingCallScreen(call: call);
          },
        ),
        GoRoute(
          path: '/calendar',
          name: 'calendar',
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/contact-support',
          name: 'contactSupport',
          builder: (context, state) => const ContactSupportScreen(),
        ),
        GoRoute(
          path: '/debug/update-name',
          name: 'updateDisplayName',
          builder: (context, state) => const UpdateDisplayNameScreen(),
        ),
      ];

  /// Defines the root route redirect for the application.
  static GoRoute _rootRedirect() => GoRoute(
        path: '/',
        redirect: (_, __) => '/auth/login',
      );

  /// Constructs the appropriate dashboard widget based on authenticated user's role.
  static Widget _buildDashboard(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;

    if (user?.role == UserRole.teacher) {
      return const TeacherDashboardScreen();
    } else if (user?.role == UserRole.student) {
      return const StudentDashboardScreen();
    }

    // Default dashboard for admin or unknown roles
    return const DashboardScreen();
  }
}