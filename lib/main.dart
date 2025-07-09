/// Main entry point for the Teacher Dashboard Flutter application.
/// 
/// This application provides a comprehensive education management platform
/// for teachers and students, built with Flutter and Firebase.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_initializer.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/app_providers.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';

/// Public getter for Firebase initialization status.
bool get isFirebaseInitialized => AppInitializer.isFirebaseInitialized;

/// Application entry point - simplified to delegate initialization
void main() {
  runZonedGuarded(
    () async {
      await AppInitializer.initialize();
      
      runApp(const TeacherDashboardApp());
    },
    AppInitializer.handleError,
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

          return MaterialApp.router(
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
          );
        },
      ),
    );
  }
}
