import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/presentation/screens/app_password_screen.dart';
import '../theme/app_theme.dart';
import '../services/logger_service.dart';

class AppPasswordWrapper extends StatefulWidget {
  final Widget child;

  const AppPasswordWrapper({super.key, required this.child});

  @override
  State<AppPasswordWrapper> createState() => _AppPasswordWrapperState();
}

class _AppPasswordWrapperState extends State<AppPasswordWrapper>
    with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isChecking = true;
  bool _hasAuthenticatedUser = false;
  ThemeMode _themeMode = ThemeMode.light; // Default to light
  bool _hasLoadedTheme = false; // Track if we loaded a theme preference
  String? _colorThemeId; // Track color theme preference

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUnlockStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _handleLifecycleChange(state);
  }

  Future<void> _handleLifecycleChange(AppLifecycleState state) async {
    final prefs = await SharedPreferences.getInstance();

    if (state == AppLifecycleState.resumed) {
      // App coming to foreground - check if we need to lock
      final backgroundTime = prefs.getInt('background_time');

      if (backgroundTime != null) {
        final backgroundDateTime = DateTime.fromMillisecondsSinceEpoch(
          backgroundTime,
        );
        final now = DateTime.now();
        final difference = now.difference(backgroundDateTime);

        if (difference.inMinutes >= 15) {
          // Been away for 15+ minutes, require password
          await prefs.setBool('app_unlocked', false);
          setState(() {
            _isUnlocked = false;
          });
        }
        // Clear the background time since we're now active
        await prefs.remove('background_time');
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - just save the timestamp, don't lock yet
      await prefs.setInt(
        'background_time',
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _checkUnlockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    // ALWAYS require password on app start
    await prefs.setBool('app_unlocked', false);

    // Load theme preference if available
    final themeString = prefs.getString('theme_mode');
    if (themeString != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == themeString,
        orElse: () => ThemeMode.light,
      );
      _hasLoadedTheme = true;
      LoggerService.info(
        'Loaded theme preference: $_themeMode',
        tag: 'AppPasswordWrapper',
      );
    } else {
      LoggerService.debug(
        'No theme preference found, using default',
        tag: 'AppPasswordWrapper',
      );
    }

    // Load color theme preference
    _colorThemeId = prefs.getString('color_theme');
    LoggerService.debug(
      'Loaded color theme: $_colorThemeId',
      tag: 'AppPasswordWrapper',
    );

    // Check if there's an authenticated Firebase user (only if Firebase is initialized)
    try {
      // First check if Firebase is initialized
      if (Firebase.apps.isNotEmpty) {
        final currentUser = FirebaseAuth.instance.currentUser;
        _hasAuthenticatedUser = currentUser != null;

        if (_hasAuthenticatedUser) {
          LoggerService.info(
            'Authenticated user: ${currentUser?.email}',
            tag: 'AppPasswordWrapper',
          );
        } else {
          LoggerService.debug(
            'No authenticated user found',
            tag: 'AppPasswordWrapper',
          );
        }
      } else {
        LoggerService.debug(
          'Firebase not initialized yet',
          tag: 'AppPasswordWrapper',
        );
        _hasAuthenticatedUser = false;
      }
    } catch (e) {
      // Firebase not initialized yet - that's OK, it will be initialized later
      LoggerService.warning(
        'Error checking auth: $e',
        tag: 'AppPasswordWrapper',
      );
      _hasAuthenticatedUser = false;
    }

    setState(() {
      _isUnlocked = false;
      _isChecking = false;
    });
  }

  void _onPasswordSuccess() {
    setState(() {
      _isUnlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // Show loading indicator while checking unlock status
      return MaterialApp(
        theme: AppTheme.lightTheme(colorThemeId: _colorThemeId),
        darkTheme: AppTheme.darkTheme(colorThemeId: _colorThemeId),
        themeMode: ThemeMode.system, // Use system theme while loading
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (!_isUnlocked) {
      // Show password screen with user's theme preference if authenticated
      return MaterialApp(
        title: 'Fermi+',
        theme: AppTheme.lightTheme(colorThemeId: _colorThemeId),
        darkTheme: AppTheme.darkTheme(colorThemeId: _colorThemeId),
        themeMode: _hasLoadedTheme ? _themeMode : ThemeMode.light,
        home: AppPasswordScreen(onSuccess: _onPasswordSuccess),
      );
    }

    // App is unlocked, show the main content
    // Pass the auth state through a special widget if authenticated
    if (_hasAuthenticatedUser) {
      return AuthenticatedWrapper._(child: widget.child);
    }
    return widget.child;
  }
}

// Widget to indicate that user was already authenticated
class AuthenticatedWrapper extends InheritedWidget {
  const AuthenticatedWrapper._({required super.child});

  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthenticatedWrapper>() !=
        null;
  }

  @override
  bool updateShouldNotify(AuthenticatedWrapper oldWidget) => false;
}
