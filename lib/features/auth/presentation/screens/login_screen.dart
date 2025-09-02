import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../../../../shared/models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isTeacherRole = false;

  @override
  void initState() {
    super.initState();
    
    // Clear error when user starts typing
    _usernameController.addListener(_clearError);
    _passwordController.addListener(_clearError);

    // Check for role parameter and auth errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check for role parameter - handle both hash and non-hash routing
      try {
        final goRouterState = GoRouterState.of(context);
        final uri = goRouterState.uri;
        
        // First try standard query parameters
        String? role = uri.queryParameters['role'];
        
        // If not found, check the full location for hash routing
        if (role == null) {
          final fullLocation = goRouterState.fullPath ?? goRouterState.matchedLocation;
          if (fullLocation.contains('role=teacher')) {
            role = 'teacher';
          }
        }
        
        setState(() {
          _isTeacherRole = role == 'teacher';
        });
      } catch (e) {
        debugPrint('Error parsing role parameter: $e');
      }

      // Check for auth errors
      final authProvider = context.read<AuthProvider>();
      if (authProvider.status == AuthStatus.error && authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Theme.of(context).colorScheme.onError,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.errorMessage != null) {
      authProvider.clearError();
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    // Check if this is a teacher verification password
    if (_isTeacherRole && password == 'educator2024') {
      // This is a teacher verification - create/update user with teacher role
      final success = await authProvider.verifyTeacherAndSignIn(username, password);
      if (success && mounted) {
        context.go('/dashboard');
      }
      return;
    }

    // Normal sign in flow
    await authProvider.signInWithUsername(username, password);

    if (authProvider.isAuthenticated && mounted) {
      // Check if user needs email linking
      final hasEmail = authProvider.userModel?.email?.isNotEmpty ?? false;
      if (!hasEmail) {
        // Route based on role
        if (authProvider.userModel?.role == UserRole.teacher) {
          context.go('/auth/teacher-setup/email');
        } else {
          context.go('/auth/student-setup/email');
        }
      } else {
        context.go('/dashboard');
      }
    }
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
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo and Title
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _isTeacherRole
                          ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isTeacherRole ? Icons.school : Icons.person,
                      size: 60,
                      color: _isTeacherRole
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isTeacherRole ? 'Teacher Portal' : 'Student Login',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isTeacherRole
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isTeacherRole 
                        ? 'Enter your credentials or use teacher verification password'
                        : 'Enter your credentials to continue',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Username Field
                        AuthTextField(
                          controller: _usernameController,
                          label: 'Username',
                          prefixIcon: Icons.person,
                          enabled: !isLoading,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a username';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        AuthTextField(
                          controller: _passwordController,
                          label: _isTeacherRole ? 'Password or Teacher Code' : 'Password',
                          prefixIcon: Icons.lock,
                          obscureText: _obscurePassword,
                          enabled: !isLoading,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Submit Button
                        ElevatedButton(
                          onPressed: isLoading 
                              ? null 
                              : _signIn,
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
                                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.error.withValues(alpha: 0.3),
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

                            // Back to role selection
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context.go('/auth/role-selection'),
                              child: Text(
                                'Back to Role Selection',
                                style: TextStyle(
                                  color: _isTeacherRole
                                      ? theme.colorScheme.secondary
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}