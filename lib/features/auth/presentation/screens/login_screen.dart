import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final _usernameController = TextEditingController();
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
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = context.read<AuthProvider>();
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      try {
        if (_isTeacherRole) {
          LoggerService.info('Attempting teacher sign in for username: $username', tag: 'LoginScreen');
          await authProvider.signInWithUsername(username, password);
          LoggerService.info('Teacher sign in successful for username: $username', tag: 'LoginScreen');
        } else {
          // Students still use email for now
          LoggerService.info('Attempting student sign in for email: $username', tag: 'LoginScreen');
          await authProvider.signInWithEmail(username, password);
          LoggerService.info('Student sign in successful for email: $username', tag: 'LoginScreen');
        }

        if (!mounted) return;

        // Navigate based on auth state
        if (authProvider.userModel != null) {
          final roleName = authProvider.userModel!.role?.name;
          LoggerService.info('User role detected: $roleName', tag: 'LoginScreen');

          // Navigate to dashboard - the router will handle role-based rendering
          LoggerService.info('Navigating to dashboard with role: $roleName', tag: 'LoginScreen');
          context.go('/dashboard');
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


  String? _validateInput(String? value) {
    if (value?.isEmpty ?? true) {
      return _isTeacherRole ? 'Please enter your username' : 'Please enter your email';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
                            // Username/Email Field
                            AuthTextField(
                              controller: _usernameController,
                              label: _isTeacherRole
                                  ? 'Username'
                                  : 'Student Email',
                              prefixIcon: _isTeacherRole ? Icons.person : Icons.email,
                              keyboardType: _isTeacherRole 
                                  ? TextInputType.text 
                                  : TextInputType.emailAddress,
                              validator: _validateInput,
                              enabled: !isLoading,
                            ),

                            const SizedBox(height: 16),

                            // Password Field
                            AuthTextField(
                              controller: _passwordController,
                              label: 'Password',
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
