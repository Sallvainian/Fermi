# Routing Architecture

## Table of Contents
- [Overview](#overview)
- [GoRouter Configuration](#gorouter-configuration)
- [Authentication Flow](#authentication-flow)
- [Route Structure](#route-structure)
- [Route Guards](#route-guards)
- [Role-Based Navigation](#role-based-navigation)
- [Deep Linking](#deep-linking)
- [Navigation Patterns](#navigation-patterns)
- [Best Practices](#best-practices)
- [Advanced Features](#advanced-features)

## Overview

Fermi uses **GoRouter 16.1.0+** for declarative routing with comprehensive authentication guards and role-based access control. The routing system provides:

- **Declarative Routing**: Route configuration separate from widget tree
- **Authentication Guards**: Automatic redirects based on auth state
- **Role-Based Access**: Different routes for teachers, students, and admins
- **Deep Link Support**: Direct navigation to specific app states
- **Type Safety**: Strongly typed route parameters and navigation

### Why GoRouter
- **Declarative API**: Routes defined in configuration, not imperative navigation
- **Web Support**: Full browser URL support with proper history management
- **Nested Routes**: Support for complex nested navigation structures
- **State Management Integration**: Works seamlessly with Provider pattern
- **Flutter Team Recommended**: Official Flutter team recommendation for routing

## GoRouter Configuration

### Main Router Configuration (`lib/shared/routing/app_router.dart`)

```dart
final appRouter = GoRouter(
  // Initial route - always start at login for unauthenticated users
  initialLocation: '/auth/login',
  
  // Global redirect logic - handles authentication flow
  redirect: (BuildContext context, GoRouterState state) {
    return AuthGuard.handleGlobalRedirect(context, state);
  },
  
  // Route definitions
  routes: [
    // Authentication Routes
    GoRoute(
      path: '/auth',
      name: 'auth',
      redirect: (context, state) => '/auth/login',
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (context, state) => const SignUpScreen(),
        ),
        GoRoute(
          path: '/role-selection',
          name: 'role-selection',
          builder: (context, state) => const RoleSelectionScreen(),
        ),
        GoRoute(
          path: '/verify-email',
          name: 'verify-email',
          builder: (context, state) => const EmailVerificationScreen(),
        ),
      ],
    ),

    // Teacher Routes
    GoRoute(
      path: '/teacher',
      name: 'teacher',
      redirect: (context, state) => '/teacher/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          name: 'teacher-dashboard',
          builder: (context, state) => const TeacherDashboardScreen(),
        ),
        GoRoute(
          path: '/classes',
          name: 'teacher-classes',
          builder: (context, state) => const TeacherClassesScreen(),
          routes: [
            GoRoute(
              path: '/:classId',
              name: 'class-detail',
              builder: (context, state) => ClassDetailScreen(
                classId: state.pathParameters['classId']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/assignments',
          name: 'teacher-assignments',
          builder: (context, state) => const TeacherAssignmentsScreen(),
          routes: [
            GoRoute(
              path: '/create',
              name: 'create-assignment',
              builder: (context, state) => const CreateAssignmentScreen(),
            ),
            GoRoute(
              path: '/:assignmentId',
              name: 'assignment-detail',
              builder: (context, state) => AssignmentDetailScreen(
                assignmentId: state.pathParameters['assignmentId']!,
              ),
            ),
          ],
        ),
      ],
    ),

    // Student Routes
    GoRoute(
      path: '/student',
      name: 'student',
      redirect: (context, state) => '/student/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          name: 'student-dashboard',
          builder: (context, state) => const StudentDashboardScreen(),
        ),
        GoRoute(
          path: '/assignments',
          name: 'student-assignments',
          builder: (context, state) => const StudentAssignmentsScreen(),
        ),
        GoRoute(
          path: '/grades',
          name: 'student-grades',
          builder: (context, state) => const StudentGradesScreen(),
        ),
      ],
    ),

    // Shared Routes (accessible by both roles)
    GoRoute(
      path: '/chat',
      name: 'chat',
      builder: (context, state) => const ChatListScreen(),
      routes: [
        GoRoute(
          path: '/:roomId',
          name: 'chat-room',
          builder: (context, state) => ChatScreen(
            roomId: state.pathParameters['roomId']!,
          ),
        ),
      ],
    ),

    GoRoute(
      path: '/discussions',
      name: 'discussions',
      builder: (context, state) => const DiscussionBoardsScreen(),
      routes: [
        GoRoute(
          path: '/:boardId',
          name: 'discussion-board',
          builder: (context, state) => DiscussionBoardScreen(
            boardId: state.pathParameters['boardId']!,
          ),
        ),
      ],
    ),
  ],

  // Error handling
  errorBuilder: (context, state) => ErrorScreen(error: state.error),
);
```

## Authentication Flow

### Authentication State Diagram
```
[Authentication Flow Diagram Placeholder]
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Unauthenticated │───▶│ Login/Signup     │───▶│ Role Selection  │
│ /auth/login     │    │ /auth/login      │    │ /auth/role-sel  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
┌─────────────────┐    ┌──────────────────┐             │
│ Email Verify    │◀───│ Needs Verification│◀────────────┘
│ /auth/verify    │    │ Check email      │
└─────────────────┘    └──────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌──────────────────┐
│ Teacher Dash    │    │ Student Dash     │
│ /teacher/dash   │    │ /student/dash    │
└─────────────────┘    └──────────────────┘
```

### AuthGuard Implementation
```dart
class AuthGuard {
  static String? handleGlobalRedirect(BuildContext context, GoRouterState state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentPath = state.uri.toString();

    // Skip redirect for auth routes
    if (currentPath.startsWith('/auth/')) {
      return null;
    }

    // Check authentication status
    final authState = authProvider.authState;
    final user = authProvider.user;
    final userRole = authProvider.userRole;

    switch (authState) {
      case AuthState.unknown:
      case AuthState.unauthenticated:
        return '/auth/login';

      case AuthState.authenticated:
        if (user == null) {
          return '/auth/login';
        }

        // Check email verification
        if (!user.emailVerified) {
          return '/auth/verify-email';
        }

        // Check if user has selected a role
        if (userRole == null) {
          return '/auth/role-selection';
        }

        // Check role-based access
        return _checkRoleBasedAccess(currentPath, userRole);

      case AuthState.loading:
        return null; // Don't redirect while loading

      default:
        return '/auth/login';
    }
  }

  static String? _checkRoleBasedAccess(String path, UserRole role) {
    switch (role) {
      case UserRole.teacher:
        if (path.startsWith('/student/')) {
          return '/teacher/dashboard';
        }
        break;
        
      case UserRole.student:
        if (path.startsWith('/teacher/')) {
          return '/student/dashboard';
        }
        break;
        
      case UserRole.admin:
        // Admins can access all routes
        break;
    }

    return null; // Access allowed
  }
}
```

## Route Structure

### Route Hierarchy
```
/
├── /auth/                      # Authentication routes
│   ├── /login                 # Login screen
│   ├── /signup                # Sign up screen
│   ├── /role-selection        # Role selection screen
│   └── /verify-email          # Email verification screen
│
├── /teacher/                   # Teacher-specific routes
│   ├── /dashboard             # Teacher dashboard
│   ├── /classes/              # Class management
│   │   └── /:classId          # Individual class detail
│   ├── /assignments/          # Assignment management
│   │   ├── /create            # Create new assignment
│   │   └── /:assignmentId     # Assignment detail/edit
│   ├── /grades/               # Grade management
│   └── /students/             # Student management
│
├── /student/                   # Student-specific routes
│   ├── /dashboard             # Student dashboard
│   ├── /assignments/          # View assignments
│   ├── /grades/               # View grades
│   └── /schedule/             # Class schedule
│
├── /chat/                      # Messaging (shared)
│   └── /:roomId               # Individual chat room
│
├── /discussions/               # Discussion boards (shared)
│   └── /:boardId              # Individual discussion board
│
├── /calendar/                  # Calendar (shared)
│   └── /event/:eventId        # Individual calendar event
│
└── /settings/                  # App settings (shared)
    ├── /profile               # User profile
    ├── /notifications         # Notification preferences
    └── /privacy               # Privacy settings
```

### Route Parameters and Query Parameters
```dart
// Path parameters
GoRoute(
  path: '/assignments/:assignmentId',
  builder: (context, state) {
    final assignmentId = state.pathParameters['assignmentId']!;
    return AssignmentDetailScreen(assignmentId: assignmentId);
  },
)

// Query parameters
GoRoute(
  path: '/assignments',
  builder: (context, state) {
    final filter = state.uri.queryParameters['filter'];
    final sortBy = state.uri.queryParameters['sortBy'];
    return AssignmentsScreen(filter: filter, sortBy: sortBy);
  },
)

// Multiple parameters
GoRoute(
  path: '/classes/:classId/assignments/:assignmentId',
  builder: (context, state) {
    final classId = state.pathParameters['classId']!;
    final assignmentId = state.pathParameters['assignmentId']!;
    return ClassAssignmentScreen(
      classId: classId, 
      assignmentId: assignmentId,
    );
  },
)
```

## Route Guards

### Authentication Guard
```dart
class AuthenticatedRoute extends GoRoute {
  AuthenticatedRoute({
    required String path,
    required String name,
    required Widget Function(BuildContext, GoRouterState) builder,
    List<RouteBase> routes = const [],
  }) : super(
          path: path,
          name: name,
          builder: builder,
          routes: routes,
          redirect: (context, state) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            
            if (!authProvider.isAuthenticated) {
              return '/auth/login';
            }
            
            if (!authProvider.user!.emailVerified) {
              return '/auth/verify-email';
            }
            
            return null; // Allow access
          },
        );
}
```

### Role-Specific Guards
```dart
class TeacherOnlyRoute extends GoRoute {
  TeacherOnlyRoute({
    required String path,
    required String name,
    required Widget Function(BuildContext, GoRouterState) builder,
    List<RouteBase> routes = const [],
  }) : super(
          path: path,
          name: name,
          builder: builder,
          routes: routes,
          redirect: (context, state) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            
            // Check authentication first
            if (!authProvider.isAuthenticated) {
              return '/auth/login';
            }
            
            // Check role
            if (authProvider.userRole != UserRole.teacher) {
              return '/student/dashboard'; // Redirect to appropriate dashboard
            }
            
            return null; // Allow access
          },
        );
}

// Usage
TeacherOnlyRoute(
  path: '/teacher/dashboard',
  name: 'teacher-dashboard',
  builder: (context, state) => const TeacherDashboardScreen(),
)
```

## Role-Based Navigation

### Navigation Based on User Role
```dart
class RoleBasedNavigator {
  static void navigateToDefaultDashboard(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    switch (authProvider.userRole) {
      case UserRole.teacher:
        context.goNamed('teacher-dashboard');
        break;
      case UserRole.student:
        context.goNamed('student-dashboard');
        break;
      case UserRole.admin:
        context.goNamed('admin-dashboard');
        break;
      case null:
        context.goNamed('role-selection');
        break;
    }
  }

  static List<NavigationItem> getNavigationItems(UserRole? role) {
    switch (role) {
      case UserRole.teacher:
        return [
          NavigationItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            route: 'teacher-dashboard',
          ),
          NavigationItem(
            icon: Icons.class_,
            label: 'Classes',
            route: 'teacher-classes',
          ),
          NavigationItem(
            icon: Icons.assignment,
            label: 'Assignments',
            route: 'teacher-assignments',
          ),
          NavigationItem(
            icon: Icons.grade,
            label: 'Grades',
            route: 'teacher-grades',
          ),
        ];

      case UserRole.student:
        return [
          NavigationItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            route: 'student-dashboard',
          ),
          NavigationItem(
            icon: Icons.assignment,
            label: 'Assignments',
            route: 'student-assignments',
          ),
          NavigationItem(
            icon: Icons.grade,
            label: 'Grades',
            route: 'student-grades',
          ),
        ];

      default:
        return [];
    }
  }
}
```

### Conditional Navigation Drawer
```dart
class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final navigationItems = RoleBasedNavigator.getNavigationItems(
          authProvider.userRole,
        );

        return Drawer(
          child: ListView(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(authProvider.user?.displayName ?? ''),
                accountEmail: Text(authProvider.user?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: authProvider.user?.photoURL != null
                      ? NetworkImage(authProvider.user!.photoURL!)
                      : null,
                ),
              ),
              ...navigationItems.map((item) => ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    onTap: () => context.goNamed(item.route),
                  )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () => context.goNamed('settings'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => authProvider.signOut(),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

## Deep Linking

### URL Structure for Deep Links
```dart
class DeepLinkHandler {
  static Map<String, String> parseDeepLink(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;

    // Handle different deep link patterns
    switch (segments.first) {
      case 'assignment':
        return {
          'type': 'assignment',
          'id': segments.length > 1 ? segments[1] : '',
          'action': uri.queryParameters['action'] ?? 'view',
        };

      case 'class':
        return {
          'type': 'class',
          'id': segments.length > 1 ? segments[1] : '',
          'section': uri.queryParameters['section'] ?? 'overview',
        };

      case 'chat':
        return {
          'type': 'chat',
          'roomId': segments.length > 1 ? segments[1] : '',
          'messageId': uri.queryParameters['messageId'] ?? '',
        };

      default:
        return {'type': 'unknown'};
    }
  }

  static void handleDeepLink(BuildContext context, Map<String, String> linkData) {
    switch (linkData['type']) {
      case 'assignment':
        context.goNamed(
          'assignment-detail',
          pathParameters: {'assignmentId': linkData['id']!},
          queryParameters: {'action': linkData['action']!},
        );
        break;

      case 'class':
        context.goNamed(
          'class-detail',
          pathParameters: {'classId': linkData['id']!},
          queryParameters: {'section': linkData['section']!},
        );
        break;

      case 'chat':
        context.goNamed(
          'chat-room',
          pathParameters: {'roomId': linkData['roomId']!},
          queryParameters: linkData['messageId']!.isNotEmpty
              ? {'messageId': linkData['messageId']!}
              : {},
        );
        break;
    }
  }
}
```

### Sharing URLs
```dart
class ShareService {
  static String generateShareableUrl(String baseUrl, String route, {
    Map<String, String>? parameters,
    Map<String, String>? queryParameters,
  }) {
    var url = '$baseUrl$route';

    // Add path parameters
    if (parameters != null) {
      parameters.forEach((key, value) {
        url = url.replaceAll(':$key', value);
      });
    }

    // Add query parameters
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final query = queryParameters.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      url += '?$query';
    }

    return url;
  }

  static Future<void> shareAssignment(String assignmentId) async {
    final url = generateShareableUrl(
      'https://fermi-edu.app',
      '/assignment/:assignmentId',
      parameters: {'assignmentId': assignmentId},
      queryParameters: {'action': 'view'},
    );

    await Share.share('Check out this assignment: $url');
  }
}
```

## Navigation Patterns

### Programmatic Navigation
```dart
class NavigationService {
  // Basic navigation
  static void goToScreen(BuildContext context, String route) {
    context.go(route);
  }

  // Named route navigation
  static void goToNamedRoute(BuildContext context, String name, {
    Map<String, String>? pathParameters,
    Map<String, String>? queryParameters,
  }) {
    context.goNamed(
      name,
      pathParameters: pathParameters ?? {},
      queryParameters: queryParameters ?? {},
    );
  }

  // Push navigation (keeps previous route in stack)
  static void pushScreen(BuildContext context, String route) {
    context.push(route);
  }

  // Replace current route
  static void replaceScreen(BuildContext context, String route) {
    context.go(route);
  }

  // Pop current route
  static void goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      // Navigate to default route if no previous route
      _navigateToDefault(context);
    }
  }

  static void _navigateToDefault(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    RoleBasedNavigator.navigateToDefaultDashboard(context);
  }
}
```

### Conditional Navigation
```dart
class ConditionalNavigation {
  static void navigateBasedOnCondition(
    BuildContext context, {
    required bool condition,
    required String trueRoute,
    required String falseRoute,
  }) {
    if (condition) {
      context.go(trueRoute);
    } else {
      context.go(falseRoute);
    }
  }

  static void navigateWithPermissionCheck(
    BuildContext context,
    String route,
    String permission,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.hasPermission(permission)) {
      context.go(route);
    } else {
      _showPermissionDeniedDialog(context);
    }
  }

  static void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text('You don\'t have permission to access this area.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

## Best Practices

### 1. Route Organization
- **Group related routes** under common parent routes
- **Use meaningful route names** that match the feature they represent
- **Maintain consistent URL patterns** across similar features
- **Keep route hierarchy shallow** to avoid complex navigation

### 2. Authentication Integration
```dart
// ✅ Good: Use provider-based auth checks
redirect: (context, state) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  return authProvider.isAuthenticated ? null : '/auth/login';
}

// ❌ Bad: Direct Firebase Auth checks in routes
redirect: (context, state) {
  final user = FirebaseAuth.instance.currentUser;
  return user != null ? null : '/auth/login';
}
```

### 3. Error Handling
```dart
// Global error builder
errorBuilder: (context, state) => Scaffold(
  appBar: AppBar(title: const Text('Error')),
  body: Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text('Route not found: ${state.uri}'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => context.go('/'),
          child: const Text('Go Home'),
        ),
      ],
    ),
  ),
),
```

### 4. Performance Considerations
```dart
// Lazy route loading for large features
GoRoute(
  path: '/large-feature',
  builder: (context, state) {
    return FutureBuilder(
      future: _loadLargeFeature(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        return LargeFeatureScreen();
      },
    );
  },
)
```

## Advanced Features

### 1. Custom Route Matching
```dart
class CustomRouteMatcher extends RouteMatcher {
  @override
  RouteMatch? matchRoute(String location, Map<String, String> pathParameters) {
    // Custom logic for route matching
    if (location.startsWith('/dynamic/')) {
      return RouteMatch(/* custom route match */);
    }
    return super.matchRoute(location, pathParameters);
  }
}
```

### 2. Route Transitions
```dart
GoRoute(
  path: '/animated-route',
  pageBuilder: (context, state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: const AnimatedScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
          ),
          child: child,
        );
      },
    );
  },
)
```

### 3. Route Data Passing
```dart
class RouteData {
  static void passData(BuildContext context, String route, Map<String, dynamic> data) {
    // Store data in a temporary service
    RouteDataService.store(route, data);
    context.go(route);
  }

  static Map<String, dynamic>? getData(String route) {
    return RouteDataService.retrieve(route);
  }
}
```

## Testing Routes

### Route Testing Setup
```dart
void main() {
  group('App Router Tests', () {
    testWidgets('should redirect unauthenticated user to login', (tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(mockAuthProvider.isAuthenticated).thenReturn(false);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: mockAuthProvider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('should navigate to teacher dashboard for teacher role', (tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(mockAuthProvider.isAuthenticated).thenReturn(true);
      when(mockAuthProvider.userRole).thenReturn(UserRole.teacher);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: mockAuthProvider,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TeacherDashboardScreen), findsOneWidget);
    });
  });
}
```

## [Code Examples Section]
[Detailed examples showing complex routing scenarios and implementation patterns]

## [Troubleshooting Section]
[Common routing issues, debugging techniques, and solutions]

## [Migration Guide Section]
[Guide for migrating from other routing solutions to GoRouter]