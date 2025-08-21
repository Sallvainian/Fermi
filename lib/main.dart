/// Main entry point for the Teacher Dashboard Flutter application.
///
/// This application provides a comprehensive education management platform
/// for teachers and students, built with Flutter and Firebase.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'shared/core/app_initializer.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/core/app_providers.dart';
import 'shared/routing/app_router.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/app_typography.dart';
import 'shared/widgets/splash_screen.dart';
import 'shared/widgets/pwa_update_notifier.dart';
import 'shared/widgets/web_notification_handler.dart';

/// Public getter for Firebase initialization status.
bool get isFirebaseInitialized => AppInitializer.isFirebaseInitialized;

/// Application entry point - shows splash screen immediately with enhanced error handling
Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      // Ensure Flutter bindings are initialized inside the zone
      WidgetsFlutterBinding.ensureInitialized();

      // Forward Flutter framework errors into Zone for unified logging
      FlutterError.onError = (FlutterErrorDetails details) {
        // Safely handle errors without causing recursive failures
        try {
          // Check if we're in a valid Zone context
          if (Zone.current != Zone.root) {
            Zone.current.handleUncaughtError(
                details.exception, details.stack ?? StackTrace.current);
          } else {
            // Fallback to simple logging if Zone is not available
            debugPrint('Flutter Error: ${details.exception}');
            debugPrint('Stack trace: ${details.stack}');
          }
        } catch (e) {
          // Last resort fallback - just print the error
          debugPrint('Error in error handler: $e');
          debugPrint('Original error: ${details.exception}');
        }
      };

      // Catch uncaught engine/platform errors
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('UNCAUGHT (platform): $error\n$stack');
        return true; // prevent the default "Uncaught" spam
      };

      // Load environment variables from .env file
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        // .env file is optional - don't fail if it doesn't exist
        debugPrint(
            'Note: .env file not found or could not be loaded. Using defaults.');
      }

      runApp(const InitializationWrapper());
    },
    (error, stack) {
      // Zone error handler - catches errors not caught elsewhere
      debugPrint('UNCAUGHT (zone): $error\n$stack');
      // Only call AppInitializer if it won't cause recursive errors
      try {
        AppInitializer.handleError(error, stack);
      } catch (e) {
        debugPrint('Failed to handle error in AppInitializer: $e');
      }
    },
  );
}

/// Global keys for PWA update notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Root widget of the Teacher Dashboard application - simplified and modular
class TeacherDashboardApp extends StatefulWidget {
  const TeacherDashboardApp({super.key});

  @override
  State<TeacherDashboardApp> createState() => _TeacherDashboardAppState();
}

class _TeacherDashboardAppState extends State<TeacherDashboardApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.getProviders(),
      child: Builder(
        builder: (context) {
          final authProvider = context.watch<AuthProvider>();
          final themeProvider = context.watch<ThemeProvider>();

          // Show loading screen while auth is initializing
          // This prevents login screen flash and route errors
          if (authProvider.status == AuthStatus.uninitialized) {
            return MaterialApp(
              title: 'Teacher Dashboard',
              theme: AppTheme.lightTheme(),
              darkTheme: AppTheme.darkTheme(),
              themeMode: themeProvider.themeMode,
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Create router only once when auth is initialized
          _router ??= AppRouter.createRouter(authProvider);

          return PWAUpdateNotifier(
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
            child: WebNotificationHandler(
              child: MaterialApp.router(
                title: 'Teacher Dashboard',
                scaffoldMessengerKey: scaffoldMessengerKey,
                theme: AppTheme.lightTheme().copyWith(
                  textTheme: AppTypography.createTextTheme(
                    AppTheme.lightTheme().colorScheme,
                  ),
                ),
                darkTheme: AppTheme.darkTheme().copyWith(
                  textTheme: AppTypography.createTextTheme(
                    AppTheme.darkTheme().colorScheme,
                  ),
                ),
                themeMode: themeProvider.themeMode,
                debugShowCheckedModeBanner: false,
                routerConfig: _router!,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Wrapper widget that handles async initialization with splash screen
class InitializationWrapper extends StatefulWidget {
  const InitializationWrapper({super.key});

  @override
  State<InitializationWrapper> createState() => _InitializationWrapperState();
}

class _InitializationWrapperState extends State<InitializationWrapper> {
  bool _isInitialized = false;
  String _currentStatus = 'Starting app...';
  double? _progress;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Show initial status
      setState(() {
        _currentStatus = 'Loading environment...';
        _progress = 0.1;
      });

      // Initialize services with progress updates
      await Future.delayed(
          const Duration(milliseconds: 100)); // Allow UI to update

      setState(() {
        _currentStatus = 'Initializing Firebase...';
        _progress = 0.3;
      });

      // Perform actual initialization
      await AppInitializer.initialize();

      setState(() {
        _currentStatus = 'Setting up providers...';
        _progress = 0.8;
      });

      // Small delay to show final progress
      await Future.delayed(const Duration(milliseconds: 300));

      // Mark as initialized
      setState(() {
        _isInitialized = true;
        _progress = 1.0;
      });
    } catch (e) {
      // Show error state
      setState(() {
        _currentStatus = 'Initialization failed. Please restart the app.';
        _progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized) {
      return const TeacherDashboardApp();
    }

    return SplashScreen(
      message: _currentStatus,
      progress: _progress,
    );
  }
}
