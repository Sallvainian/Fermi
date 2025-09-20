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
import 'shared/services/logger_service.dart';

/// Public getter for Firebase initialization status.
bool get isFirebaseInitialized => AppInitializer.isFirebaseInitialized;

/// Application entry point - shows splash screen immediately with enhanced error handling
Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      // Ensure Flutter bindings are initialized inside the zone
      WidgetsFlutterBinding.ensureInitialized();

      // Disable Provider type checking for Flyer Chat compatibility
      // Flyer Chat internally uses Provider with ChangeNotifier, which triggers warnings
      Provider.debugCheckInvalidValueType = null;

      // Forward Flutter framework errors into Zone for unified logging
      FlutterError.onError = (FlutterErrorDetails details) {
        // Safely handle errors without causing recursive failures
        try {
          // Try to get the current stack trace safely
          StackTrace? stack = details.stack;
          if (stack == null) {
            try {
              stack = StackTrace.current;
            } catch (_) {
              // If we can't get the stack trace, that's OK
            }
          }

          // Check if we're in a valid Zone context
          try {
            if (Zone.current != Zone.root) {
              Zone.current.handleUncaughtError(
                details.exception,
                stack ?? StackTrace.empty,
              );
            } else {
              // Fallback to simple logging if Zone is not available
              LoggerService.error(
                'Flutter framework error',
                error: details.exception,
                stackTrace: stack,
              );
            }
          } catch (_) {
            // If Zone.current fails, just log directly
            LoggerService.error(
              'Flutter framework error',
              error: details.exception,
              stackTrace: stack,
            );
          }
        } catch (e) {
          // Last resort fallback - just log the error
          LoggerService.error('Error while handling FlutterError', error: e);
          LoggerService.error(
            'Original framework error',
            error: details.exception,
            stackTrace: details.stack,
          );
        }
      };

      // Catch uncaught engine/platform errors
      PlatformDispatcher.instance.onError = (error, stack) {
        LoggerService.error(
          'UNCAUGHT (platform)',
          error: error,
          stackTrace: stack,
        );
        return true; // prevent the default "Uncaught" spam
      };

      // Load environment variables from .env file (skip on web to avoid 404)
      if (!kIsWeb) {
        try {
          await dotenv.load(fileName: ".env");
          if (kDebugMode) {
            LoggerService.debug(
              '.env file loaded successfully',
              tag: 'Bootstrap',
            );
          }
        } catch (e) {
          // .env is optional - silently continue
        }
      }

      // Initialize MonitoringService in debug mode (skip on web - can't host WebSocket server)
      // TEMPORARILY DISABLED to debug crash issue
      /*
      if (kDebugMode && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        try {
          final monitoring = MonitoringService();
          await monitoring.initialize();
          LoggerService.debug(
            'MonitoringService initialized',
            tag: 'Bootstrap',
          );
        } catch (e) {
          LoggerService.error(
            'Failed to initialize MonitoringService',
            error: e,
          );
        }
      }
      */

      runApp(const InitializationWrapper());
    },
    (error, stack) {
      // Zone error handler - catches errors not caught elsewhere
      LoggerService.error('UNCAUGHT (zone)', error: error, stackTrace: stack);
      try {
        AppInitializer.handleError(error, stack);
      } catch (e) {
        LoggerService.error(
          'Failed to handle error in AppInitializer',
          error: e,
        );
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
          if (authProvider.status == AuthStatus.uninitialized ||
              authProvider.status == AuthStatus.authenticating) {
            return MaterialApp(
              title: 'Teacher Dashboard',
              theme: AppTheme.lightTheme(
                colorThemeId: themeProvider.colorThemeId,
              ),
              darkTheme: AppTheme.darkTheme(
                colorThemeId: themeProvider.colorThemeId,
              ),
              themeMode: themeProvider.themeMode,
              debugShowCheckedModeBanner: false,
              home: Builder(
                builder: (innerContext) => Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Theme.of(innerContext).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          authProvider.status == AuthStatus.authenticating
                              ? 'Loading your profile...'
                              : 'Initializing...',
                          style: Theme.of(innerContext).textTheme.bodyLarge,
                        ),
                      ],
                    ),
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
                theme:
                    AppTheme.lightTheme(
                      colorThemeId: themeProvider.colorThemeId,
                    ).copyWith(
                      textTheme: AppTypography.createTextTheme(
                        AppTheme.lightTheme(
                          colorThemeId: themeProvider.colorThemeId,
                        ).colorScheme,
                      ),
                    ),
                darkTheme:
                    AppTheme.darkTheme(
                      colorThemeId: themeProvider.colorThemeId,
                    ).copyWith(
                      textTheme: AppTypography.createTextTheme(
                        AppTheme.darkTheme(
                          colorThemeId: themeProvider.colorThemeId,
                        ).colorScheme,
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
  bool _quickInit = false; // Fast path for authenticated users
  String _currentStatus = 'Starting app...';
  double? _progress;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if Firebase is already initialized (handles hot restart)
      if (AppInitializer.isFirebaseInitialized) {
        // Fast path - Firebase already initialized
        LoggerService.info(
          'Fast initialization - Firebase already initialized',
          tag: 'Bootstrap',
        );
        setState(() {
          _quickInit = true;
          _isInitialized = true;
          _progress = 1.0;
        });
        return;
      }

      // Show initial status
      if (!mounted) return;
      setState(() {
        _currentStatus = 'Loading environment...';
        _progress = 0.1;
      });

      // Initialize services with progress updates
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Allow UI to update

      if (!mounted) return;
      setState(() {
        _currentStatus = 'Initializing Firebase...';
        _progress = 0.3;
      });

      // Perform actual initialization
      await AppInitializer.initialize();

      if (!mounted) return;
      setState(() {
        _currentStatus = 'Setting up providers...';
        _progress = 0.8;
      });

      // Small delay to show final progress
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
      // Mark as initialized
      setState(() {
        _isInitialized = true;
        _progress = 1.0;
      });
    } catch (e) {
      LoggerService.error('Initialization error', error: e);
      // If it's a duplicate app error, try to proceed anyway
      if (e.toString().contains('duplicate-app')) {
        LoggerService.warning(
          'Ignoring duplicate app error and proceeding...',
          tag: 'Bootstrap',
        );
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
          _progress = 1.0;
        });
      } else {
        // Show error state for other errors
        if (!mounted) return;
        setState(() {
          _currentStatus = 'Initialization failed. Please restart the app.';
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized) {
      // Skip splash for authenticated users
      if (_quickInit) {
        return const TeacherDashboardApp();
      }
      // Show app after normal initialization
      return const TeacherDashboardApp();
    }

    return SplashScreen(message: _currentStatus, progress: _progress);
  }
}
