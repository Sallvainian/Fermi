import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/logger_service.dart';
import 'dart:io' show Platform;

import '../widgets/auth_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  final String? role;

  const LoginScreen({
    super.key,
    this.role,
  });

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isTeacherRole = false;

  @override
  void initState() {
    super.initState();
    // Prefer widget param if provided
    _isTeacherRole = widget.role == 'teacher';
    LoggerService.info('LoginScreen initialized with role: ${widget.role}', tag: 'LoginScreen');

    // Also support role via query parameter (e.g., /auth/login?role=teacher)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final goState = GoRouterState.of(context);
        String? role = goState.uri.queryParameters['role'];
        if (role == null) {
          final location = goState.fullPath ?? goState.matchedLocation;
          if (location.contains('role=teacher')) role = 'teacher';
        }
        if (role != null) {
          setState(() {
            _isTeacherRole = role == 'teacher';
          });
        }
      } catch (e) {
        LoggerService.warning('Error parsing role parameter', tag: 'LoginScreen');
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = context.read<AuthProvider>();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      try {
        LoggerService.info('Attempting sign in for email: $email', tag: 'LoginScreen');
        await authProvider.signInWithEmail(email, password);
        LoggerService.info('Sign in successful for email: $email', tag: 'LoginScreen');

        if (!mounted) return;

        // Navigate based on auth state
        if (authProvider.userModel != null) {
          final roleName = authProvider.userModel!.role?.name;
          LoggerService.info('User role detected: $roleName', tag: 'LoginScreen');

          // Navigate based on role
          if (roleName == 'teacher') {
            LoggerService.info('Navigating to teacher dashboard', tag: 'LoginScreen');
            context.go('/teacher/dashboard');
          } else if (roleName == 'student') {
            LoggerService.info('Navigating to student dashboard', tag: 'LoginScreen');
            context.go('/student/dashboard');
          } else {
            LoggerService.info('Unknown role, navigating to role selection', tag: 'LoginScreen');
            context.go('/auth/role-selection');
          }
        }
      } catch (e) {
        LoggerService.error('Sign in error: $e', tag: 'LoginScreen', error: e);
        if (!mounted) return;

        String errorMessage;
        if (e.toString().contains('invalid-email') ||
            e.toString().contains('user-not-found')) {
          errorMessage = 'Invalid email or password';
        } else if (e.toString().contains('wrong-password')) {
          errorMessage = 'Invalid password';
        } else if (e.toString().contains('too-many-requests')) {
          errorMessage = 'Too many attempts. Please try again later';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection';
        } else {
          errorMessage = 'Login failed. Please try again';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    final authProvider = context.read<AuthProvider>();

    try {
      LoggerService.info('Attempting Google sign in', tag: 'LoginScreen');
      await authProvider.signInWithGoogle();
      LoggerService.info('Google sign in successful', tag: 'LoginScreen');

      if (!mounted) return;

      // Navigate after successful Google sign-in
      if (authProvider.userModel != null) {
        final roleName = authProvider.userModel!.role?.name;
        LoggerService.info('User role from Google sign-in: $roleName', tag: 'LoginScreen');

        if (roleName == 'teacher') {
          context.go('/teacher/dashboard');
        } else if (roleName == 'student') {
          context.go('/student/dashboard');
        } else {
          context.go('/auth/role-selection');
        }
      }
    } catch (e) {
      LoggerService.error('Google sign in error: $e', tag: 'LoginScreen', error: e);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google sign-in failed: ${e.toString()}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter your email';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: _isTeacherRole
          ? theme.colorScheme.secondary.withValues(alpha: 0.05)
          : theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 48.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Icon(
                    Icons.school,
                    size: 72,
                    color: _isTeacherRole
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isTeacherRole ? 'Teacher Login' : 'Student Login',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back to Fermi',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Form
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email Field
                            AuthTextField(
                              controller: _emailController,
                              label: _isTeacherRole
                                  ? 'Teacher Email'
                                  : 'Student Email',
                              prefixIcon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                              enabled: !isLoading,
                            ),

                            const SizedBox(height: 16),

                            // Password Field
                            AuthTextField(
                              controller: _passwordController,
                              label: _isTeacherRole
                                  ? 'Password or Teacher Code'
                                  : 'Password',
                              prefixIcon: Icons.lock,
                              obscureText: _obscurePassword,
                              enabled: !isLoading,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            // Forgot Password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => context.go('/auth/forgot-password'),
                                style: TextButton.styleFrom(
                                  foregroundColor: _isTeacherRole
                                      ? theme.colorScheme.secondary
                                      : theme.colorScheme.primary,
                                ),
                                child: const Text('Forgot Password?'),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Submit Button
                            ElevatedButton(
                              onPressed: isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: _isTeacherRole
                                    ? theme.colorScheme.secondary
                                    : theme.colorScheme.primary,
                                foregroundColor: _isTeacherRole
                                    ? theme.colorScheme.onSecondary
                                    : theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),

                            // Error Display
                            if (authProvider.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.error.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: theme.colorScheme.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        authProvider.errorMessage!,
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Sign up and back to role selection
                            const SizedBox(height: 24),
                            if (_isTeacherRole) ...[
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => context.go('/auth/signup?role=teacher'),
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context.go('/auth/role-selection'),
                              child: Text(
                                'Back to Role Selection',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Google Sign In (avoid Platform on web)
                  ...(){
                    bool showGoogle = true;
                    if (!kIsWeb) {
                      // Only check Platform on non-web targets
                      showGoogle = !Platform.isWindows;
                    }
                    if (!showGoogle) return <Widget>[];
                    return <Widget>[
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _signInWithGoogle,
                      icon: Image.asset(
                        'assets/images/google_logo.png',
                        height: 20,
                      ),
                      label: const Text('Sign in with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    ];
                  }(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
