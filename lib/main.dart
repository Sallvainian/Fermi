/// Main entry point for the Teacher Dashboard Flutter application.
/// 
/// This application provides a comprehensive education management platform
/// for teachers and students, built with Flutter and Firebase.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shared/core/app_initializer.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/core/app_providers.dart';
import 'shared/routing/app_router.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/app_typography.dart';
import 'shared/widgets/splash_screen.dart';
import 'shared/widgets/pwa_update_notifier.dart';

/// Public getter for Firebase initialization status.
bool get isFirebaseInitialized => AppInitializer.isFirebaseInitialized;

/// Application entry point - shows splash screen immediately
Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const InitializationWrapper());
    },
    (error, stack) {
      AppInitializer.handleError(error, stack);
    },
  );
}

/// Root widget of the Teacher Dashboard application - simplified and modular
class TeacherDashboardApp extends StatelessWidget {
  const TeacherDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.getProviders(),
      child: Builder(
        builder: (context) {
          final authProvider = context.watch<AuthProvider>();
          final themeProvider = context.watch<ThemeProvider>();

          return PWAUpdateNotifier(
            child: MaterialApp.router(
              title: 'Teacher Dashboard',
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
              routerConfig: AppRouter.createRouter(authProvider),
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
      await Future.delayed(const Duration(milliseconds: 100)); // Allow UI to update

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
