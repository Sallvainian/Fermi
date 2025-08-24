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
import '../../features/chat/presentation/screens/simple_user_list.dart';
import '../../features/chat/presentation/screens/group_creation_screen.dart';
import '../../features/chat/presentation/screens/class_selection_screen.dart';
import '../../features/chat/presentation/screens/call_screen.dart';
import '../../features/chat/presentation/screens/incoming_call_screen.dart';
import '../../features/chat/domain/models/call.dart';
import '../../features/classes/presentation/screens/teacher/classes_screen.dart';
import '../../features/classes/presentation/screens/teacher/class_detail_screen.dart';
import '../../features/classes/presentation/screens/student/courses_screen.dart';
import '../../features/classes/presentation/screens/student/enrollment_screen.dart';
import '../../features/assignments/presentation/screens/teacher/assignments_list_screen.dart'
    as teacher_assignments;
import '../../features/assignments/presentation/screens/teacher/assignment_create_screen.dart';
import '../../features/assignments/presentation/screens/teacher/assignment_detail_screen.dart';
import '../../features/assignments/presentation/screens/teacher/assignment_edit_screen.dart';
import '../../features/assignments/presentation/screens/student/assignments_list_screen.dart'
    as student_assignments;
import '../../features/assignments/presentation/screens/student/assignment_submission_screen.dart';
import '../../features/grades/presentation/screens/teacher/gradebook_screen.dart';
import '../../features/grades/presentation/screens/teacher/grade_analytics_screen.dart';
import '../../features/grades/presentation/screens/student/grades_screen.dart';
import '../../features/student/presentation/screens/teacher/students_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/discussions/presentation/screens/discussion_boards_screen.dart';
import '../../features/discussions/presentation/screens/discussion_board_detail_screen.dart';
import '../../features/discussions/presentation/screens/thread_detail_screen.dart';
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
        final isAuthenticating = authProvider.status == AuthStatus.authenticating;
        final isAuthRoute = state.matchedLocation.startsWith('/auth');
        final hasError = authProvider.status == AuthStatus.error;

        // During initialization, don't redirect
        // The app shows a loading screen before router is created
        if (authProvider.status == AuthStatus.uninitialized) {
          return null;
        }

        // If there's an auth error, redirect to login to show the error
        // and allow the user to try signing in again
        if (hasError && !isAuthRoute) {
          return '/auth/login';
        }

        // If user is in the middle of OAuth flow (needs role selection)
        // redirect to role selection screen
        if (isAuthenticating && state.matchedLocation != '/auth/role-selection') {
          return '/auth/role-selection';
        }

        // Simple redirect logic - standard Flutter pattern
        if (!isAuth && !isAuthenticating && !isAuthRoute && !hasError) {
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
            final auth = Provider.of<AuthProvider>(context, listen: true);
            // CRITICAL: Get fresh userModel every time, not cached
            final user = auth.userModel;

            // Handle authenticating state (needs role selection)
            // BUT only if the user has no role - this prevents infinite loop
            // when transitioning from authenticating to authenticated
            if (auth.status == AuthStatus.authenticating && 
                user?.role == null && 
                auth.firebaseUser != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  GoRouter.of(context).go('/auth/role-selection');
                }
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Handle error state - shouldn't reach here due to redirect, but safety check
            if (auth.status == AuthStatus.error) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  GoRouter.of(context).go('/auth/login');
                }
              });
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        auth.errorMessage ?? 'Authentication error occurred',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => GoRouter.of(context).go('/auth/login'),
                        child: const Text('Go to Login'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Check if user needs role selection
            if (user?.role == null && auth.firebaseUser != null) {
              // User is authenticated but has no role - redirect to role selection
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  GoRouter.of(context).go('/auth/role-selection');
                }
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Simple role-based dashboard
            if (user?.role == UserRole.teacher) {
              return const TeacherDashboardScreen();
            } else if (user?.role == UserRole.student) {
              return const StudentDashboardScreen();
            }

            // Fallback - check if we're truly authenticated but missing user data
            // This should NEVER happen, but if it does, we need to handle it
            if (auth.status == AuthStatus.authenticated && user == null) {
              debugPrint('CRITICAL: Dashboard in authenticated state but userModel is null!');
              debugPrint('Auth status: ${auth.status}');
              debugPrint('User model: ${auth.userModel}');
              debugPrint('Firebase user: ${auth.firebaseUser?.uid}');
              
              // Immediately try to reload user data
              Future.microtask(() async {
                debugPrint('Emergency reload of user data...');
                await auth.reloadUser();
                
                // If we still don't have a user model, sign out and restart
                if (auth.userModel == null && context.mounted) {
                  debugPrint('CRITICAL: Cannot load user model, signing out...');
                  await auth.signOut();
                  if (context.mounted) {
                    GoRouter.of(context).go('/auth/login');
                  }
                }
              });
              
              // Show loading for max 3 seconds then redirect to login
              Future.delayed(const Duration(seconds: 3), () {
                if (context.mounted && auth.userModel == null) {
                  debugPrint('Timeout waiting for user model, redirecting to login...');
                  GoRouter.of(context).go('/auth/login');
                }
              });
              
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading your profile...',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This is taking longer than expected...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Final fallback - shouldn't happen if auth is working
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading dashboard...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (auth.status != AuthStatus.authenticated)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Status: ${auth.status}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // Chat routes
        GoRoute(
          path: '/messages',
          builder: (context, state) => const ChatListScreen(),
        ),
        // MUST BE BEFORE THE WILDCARD ROUTE!
        GoRoute(
          path: '/messages/select-user',
          builder: (context, state) => const SimpleUserList(),
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
            final recipientId = state.uri.queryParameters['recipientId'];
            final recipientName = state.uri.queryParameters['recipientName'];
            
            return SimpleChatScreen(
              chatRoomId: chatRoomId,
              chatTitle: title,
              recipientId: recipientId,
              recipientName: recipientName,
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

        // Chat creation routes (keeping old one for compatibility)
        GoRoute(
          path: '/chat/user-selection',
          builder: (context, state) => const SimpleUserList(), // USING SIMPLE VERSION
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
          builder: (context, state) {
            final classId = state.uri.queryParameters['classId'];
            return AssignmentCreateScreen(classId: classId);
          },
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
            final boardTitle = state.uri.queryParameters['title'] ?? 'Discussion Board';
            return DiscussionBoardDetailScreen(
              boardId: boardId,
              boardTitle: boardTitle,
            );
          },
          routes: [
            GoRoute(
              path: 'thread/:threadId',
              builder: (context, state) {
                final boardId = state.pathParameters['boardId']!;
                final threadId = state.pathParameters['threadId']!;
                return ThreadDetailScreen(
                  boardId: boardId,
                  threadId: threadId,
                );
              },
            ),
          ],
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
