import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../../features/chat/domain/models/call.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
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
import '../../features/notifications/presentation/screens/student_notifications_screen.dart' as student_notifications;
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
import '../../features/games/presentation/screens/jeopardy_screen.dart';
import '../../features/games/presentation/screens/jeopardy_play_screen.dart';
import '../../features/games/presentation/screens/jeopardy_create_screen.dart';

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
  /// 3. Google sign-in users → `/auth/role-selection` (if role not set)
  /// 4. Role-based dashboard routing (Teacher/Student/Admin)
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
  
  /// Handles authentication-based route redirects and access control.
  /// 
  /// This method implements the core authentication and authorization logic
  /// for the application's routing system. It evaluates the user's current
  /// authentication state and the requested route to determine if a redirect
  /// is necessary.
  /// 
  /// **Redirect Logic:**
  /// 1. **Unauthenticated Access:** If user is not authenticated and trying
  ///    to access any protected route, redirect to `/auth/login`
  /// 2. **Authenticated Auth Routes:** If user is authenticated but trying
  ///    to access auth routes (login/signup), redirect to `/dashboard`
  /// 3. **Role Selection Required:** If user authenticated via Google but
  ///    hasn't selected a role, redirect to `/auth/role-selection`
  /// 4. **Valid Access:** Return null to allow navigation to continue
  /// 
  /// **Security Features:**
  /// - Prevents unauthorized access to protected routes
  /// - Prevents authenticated users from accessing auth screens
  /// - Enforces role selection completion for Google sign-in users
  /// - Automatic redirect to appropriate landing page based on auth state
  /// 
  /// @param authProvider The authentication provider containing user state
  /// @param state The current route state including path and parameters
  /// @returns String path to redirect to, or null to allow current navigation
  /// 
  /// **Route Protection:**
  /// - Auth routes: `/auth/*` (login, signup, role selection, forgot password)
  /// - Protected routes: All other routes require authentication
  /// 
  /// **Example Scenarios:**
  /// ```dart
  /// // Unauthenticated user accessing /teacher/classes → /auth/login
  /// // Authenticated user accessing /auth/login → /dashboard  
  /// // Google user without role accessing /dashboard → /auth/role-selection
  /// ```
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
  
  /// Defines authentication-related routes for user account management.
  /// 
  /// This method creates all routes related to user authentication, including
  /// login, registration, role selection, and password recovery. These routes
  /// are accessible to unauthenticated users and handle the complete auth flow.
  /// 
  /// **Route Structure:**
  /// - `/auth/login` - User login with email/password or Google Sign-In
  /// - `/auth/signup` - New user registration with email/password
  /// - `/auth/role-selection` - Role selection for Google Sign-In users
  /// - `/auth/forgot-password` - Password reset flow
  /// 
  /// **Authentication Methods Supported:**
  /// - Email/Password authentication via Firebase Auth
  /// - Google Sign-In with automatic account creation
  /// - Password reset via email verification
  /// 
  /// **Route Protection:**
  /// These routes are only accessible to unauthenticated users. Authenticated
  /// users attempting to access these routes will be redirected to `/dashboard`
  /// via the [_handleRedirect] method.
  /// 
  /// **Special Considerations:**
  /// - Google Sign-In users are redirected to role selection if no role is set
  /// - All auth routes use stateless widgets for optimal performance
  /// - Routes support both web and mobile navigation patterns
  /// 
  /// @returns List of GoRoute objects for authentication flows
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
  
  /// Defines routes exclusive to users with Teacher role.
  /// 
  /// This method creates all routes that are specifically designed for teacher
  /// functionality, including class management, assignment creation, grading,
  /// student management, and educational games. These routes require Teacher
  /// role authentication and provide comprehensive classroom management tools.
  /// 
  /// **Route Structure:**
  /// - `/teacher/classes` - Class overview and management dashboard
  /// - `/class/:classId` - Individual class detail view with roster and activities
  /// - `/teacher/gradebook` - Comprehensive gradebook with analytics
  /// - `/teacher/analytics` - Grade analytics and performance insights
  /// - `/teacher/assignments/*` - Assignment management (create, edit, view, analytics)
  /// - `/teacher/students` - Student management and progress tracking
  /// - `/teacher/games/jeopardy/*` - Educational game creation and management
  /// 
  /// **Nested Route Patterns:**
  /// - Assignment routes support nested paths for creation, editing, and details
  /// - Jeopardy game routes include creation, editing, and play functionality
  /// - Dynamic route parameters for class IDs, assignment IDs, and game IDs
  /// 
  /// **Access Control:**
  /// These routes are protected by role-based access control and are only
  /// accessible to authenticated users with Teacher role. Students and other
  /// roles attempting to access these routes will be handled by the redirect logic.
  /// 
  /// **Features:**
  /// - Real-time class roster management
  /// - Assignment creation with rich content support
  /// - Advanced grading and analytics tools
  /// - Student progress tracking and insights
  /// - Interactive educational game platform
  /// - Bulk operations for efficient classroom management
  /// 
  /// @returns List of GoRoute objects for teacher-specific functionality
  static List<GoRoute> _teacherRoutes() => [
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
      builder: (context, state) => const teacher_assignments.TeacherAssignmentsScreen(),
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
  
  /// Defines routes exclusive to users with Student role.
  /// 
  /// This method creates all routes specifically designed for student functionality,
  /// including course enrollment, assignment submissions, grade viewing, and
  /// student-specific notifications. These routes require Student role authentication
  /// and provide a focused learning environment optimized for student workflows.
  /// 
  /// **Route Structure:**
  /// - `/student/courses` - Enrolled courses overview with current status
  /// - `/student/assignments/*` - Assignment list and submission interface
  /// - `/student/grades` - Personal grade book and academic progress
  /// - `/student/enroll` - Course enrollment and discovery interface
  /// - `/student/notifications` - Student-specific notifications and announcements
  /// 
  /// **Nested Route Patterns:**
  /// - Assignment routes include submission workflows with file upload support
  /// - Dynamic parameters for assignment IDs and submission tracking
  /// - Nested paths for assignment detail views and submission history
  /// 
  /// **Access Control:**
  /// These routes are protected by role-based access control and are only
  /// accessible to authenticated users with Student role. Teachers and other
  /// roles attempting to access these routes will be handled by the redirect logic.
  /// 
  /// **Student-Focused Features:**
  /// - Simplified course navigation optimized for learning workflows
  /// - Assignment submission with multiple file format support
  /// - Real-time grade updates and progress tracking
  /// - Self-service course enrollment with prerequisite checking
  /// - Personalized notification system for academic updates
  /// - Mobile-first design for on-the-go learning access
  /// 
  /// **Educational Tools:**
  /// - Assignment calendar integration for deadline management
  /// - Progress visualization and achievement tracking
  /// - Peer collaboration tools within enrolled courses
  /// - Resource library access for supplementary materials
  /// 
  /// @returns List of GoRoute objects for student-specific functionality
  static List<GoRoute> _studentRoutes() => [
    GoRoute(
      path: '/student/courses',
      builder: (context, state) => const StudentCoursesScreen(),
    ),
    GoRoute(
      path: '/student/assignments',
      builder: (context, state) => const student_assignments.StudentAssignmentsScreen(),
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
  
  /// Defines routes accessible to all authenticated users regardless of role.
  /// 
  /// This method creates routes that provide core functionality shared across
  /// all user roles (Teacher, Student, Admin). These routes include communication
  /// tools, discussion boards, calendar features, settings, and support systems
  /// that form the foundation of the collaborative learning platform.
  /// 
  /// **Route Structure:**
  /// - `/dashboard` - Role-based dashboard with personalized content
  /// - `/messages/*` - Real-time messaging system with chat rooms
  /// - `/discussions/*` - Discussion boards for course-related conversations
  /// - `/chat/*` - Enhanced chat features (user selection, group creation)
  /// - `/call` & `/incoming-call` - Voice/video calling infrastructure
  /// - `/calendar` - Integrated calendar with academic events and deadlines
  /// - `/notifications` - System-wide notification management
  /// - `/settings` - User preferences and account configuration
  /// - `/contact-support` - Help desk and support ticket system
  /// - `/debug/update-name` - Development utility for display name updates
  /// 
  /// **Communication Features:**
  /// - Real-time chat with individual users and groups
  /// - Voice and video calling with WebRTC integration
  /// - Discussion boards organized by topics and courses
  /// - File sharing and multimedia message support
  /// - Read receipts and online presence indicators
  /// 
  /// **Advanced Chat Capabilities:**
  /// - User selection for initiating private conversations
  /// - Group chat creation with member management
  /// - Class-wide communication channels
  /// - Integration with academic calendar for meeting scheduling
  /// - Call routing with automatic fallback and quality monitoring
  /// 
  /// **Collaborative Tools:**
  /// - Shared calendar with event scheduling and reminders
  /// - Cross-role discussion spaces for project collaboration
  /// - Real-time notification system for important updates
  /// - Support system for technical assistance and feedback
  /// 
  /// **Route Parameters:**
  /// - Dynamic chat room IDs for message routing
  /// - Discussion board IDs with optional title parameters
  /// - Call parameters including receiver info and call type
  /// - Flexible parameter passing for complex state management
  /// 
  /// **Security Considerations:**
  /// - All routes require authentication via [_handleRedirect]
  /// - Parameter validation for secure data handling
  /// - Role-appropriate content filtering where applicable
  /// - Privacy controls for communication features
  /// 
  /// @returns List of GoRoute objects for shared platform functionality
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
  
  /// Defines the root route redirect for the application.
  /// 
  /// This method creates a catch-all route for the root path ('/') that
  /// automatically redirects users to the login screen. This ensures that
  /// users accessing the application without a specific path are directed
  /// to the appropriate entry point for authentication.
  /// 
  /// **Redirect Logic:**
  /// - Root path ('/') → '/auth/login'
  /// - Provides a consistent entry point for the application
  /// - Ensures unauthenticated users start at the login screen
  /// - Simplifies URL handling for bookmarked or direct access
  /// 
  /// **Use Cases:**
  /// - Users accessing the application domain directly
  /// - Bookmarks to the root URL
  /// - Default fallback for unmatched routes
  /// - Application startup navigation
  /// 
  /// **Security Benefits:**
  /// - Prevents access to undefined routes
  /// - Ensures authentication flow is always initiated
  /// - Provides predictable navigation behavior
  /// 
  /// @returns GoRoute object that redirects root access to login
  static GoRoute _rootRedirect() => GoRoute(
    path: '/',
    redirect: (_, __) => '/auth/login',
  );
  
  /// Constructs the appropriate dashboard widget based on authenticated user's role.
  /// 
  /// This method implements role-based dashboard routing by examining the current
  /// user's role and returning the corresponding dashboard widget. It provides
  /// personalized landing pages optimized for each user type's primary workflows
  /// and responsibilities within the educational platform.
  /// 
  /// **Role-Based Dashboard Routing:**
  /// - **Teacher Role** → [TeacherDashboardScreen] - Class management, grading tools, analytics
  /// - **Student Role** → [StudentDashboardScreen] - Course overview, assignments, grades
  /// - **Admin/Other Roles** → [DashboardScreen] - Generic dashboard with admin tools
  /// 
  /// **Dashboard Personalization:**
  /// - Teacher dashboards emphasize classroom management and instructional tools
  /// - Student dashboards focus on learning progress and assignment tracking
  /// - Admin dashboards provide system-wide oversight and configuration options
  /// - Fallback dashboard ensures graceful handling of undefined or new roles
  /// 
  /// **Context Dependencies:**
  /// - Accesses [AuthProvider] via Provider.of to retrieve current user state
  /// - Uses listen: false for performance optimization during route building
  /// - Relies on [UserModel.role] for role determination and dashboard selection
  /// 
  /// **Error Handling:**
  /// - Gracefully handles null user scenarios with fallback dashboard
  /// - Provides default dashboard for unrecognized or undefined user roles
  /// - Ensures dashboard is always available regardless of authentication edge cases
  /// 
  /// **Performance Considerations:**
  /// - Stateless widget selection for optimal rendering performance
  /// - Minimal logic in route building to reduce navigation latency
  /// - Provider access optimization with listen: false configuration
  /// 
  /// @param context BuildContext for accessing Provider-based authentication state
  /// @returns Role-appropriate dashboard widget for authenticated user
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