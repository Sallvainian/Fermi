import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';
import 'screens/student/student_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const TeacherDashboardApp());
}

class TeacherDashboardApp extends StatelessWidget {
  const TeacherDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Gradebook provider will be added here
        // Chat provider will be added here
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.watch<AuthProvider>();
          
          return MaterialApp.router(
            title: 'Teacher Dashboard',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 2,
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            debugShowCheckedModeBanner: false,
            routerConfig: _createRouter(authProvider),
          );
        },
      ),
    );
  }

  GoRouter _createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/auth/login',
      refreshListenable: authProvider,
      redirect: (context, state) {
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
      },
      routes: [
        // Auth Routes
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
        
        // Main App Routes
        GoRoute(
          path: '/dashboard',
          builder: (context, state) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final user = authProvider.userModel;
            
            if (user?.role == UserRole.teacher) {
              return const TeacherDashboardScreen();
            } else if (user?.role == UserRole.student) {
              return const StudentDashboardScreen();
            } else {
              return const DashboardScreen(); // Admin or fallback
            }
          },
        ),
        
        // Teacher Routes
        GoRoute(
          path: '/teacher/classes',
          builder: (context, state) => const PlaceholderScreen(title: 'My Classes'),
        ),
        GoRoute(
          path: '/teacher/gradebook',
          builder: (context, state) => const PlaceholderScreen(title: 'Gradebook'),
        ),
        GoRoute(
          path: '/teacher/assignments',
          builder: (context, state) => const PlaceholderScreen(title: 'Assignments'),
        ),
        GoRoute(
          path: '/teacher/students',
          builder: (context, state) => const PlaceholderScreen(title: 'Students'),
        ),
        
        // Student Routes
        GoRoute(
          path: '/student/courses',
          builder: (context, state) => const PlaceholderScreen(title: 'My Courses'),
        ),
        GoRoute(
          path: '/student/assignments',
          builder: (context, state) => const PlaceholderScreen(title: 'Assignments'),
        ),
        GoRoute(
          path: '/student/grades',
          builder: (context, state) => const PlaceholderScreen(title: 'Grades'),
        ),
        
        // Common Routes
        GoRoute(
          path: '/messages',
          builder: (context, state) => const PlaceholderScreen(title: 'Messages'),
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const PlaceholderScreen(title: 'Calendar'),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const PlaceholderScreen(title: 'Notifications'),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const PlaceholderScreen(title: 'Settings'),
        ),
        GoRoute(
          path: '/help',
          builder: (context, state) => const PlaceholderScreen(title: 'Help & Support'),
        ),
        
        // Redirect root to login
        GoRoute(
          path: '/',
          redirect: (_, __) => '/auth/login',
        ),
      ],
    );
  }
}

// Temporary Dashboard Screen
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome, ${user?.displayName ?? 'User'}!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Role: ${user?.role.toString().split('.').last ?? 'Unknown'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

// Temporary screens - will be implemented next
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Role Selection Screen')),
    );
  }
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Forgot Password Screen')),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  
  const PlaceholderScreen({
    super.key,
    required this.title,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This screen is under construction',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}