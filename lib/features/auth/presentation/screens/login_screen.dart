import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/logger_service.dart';

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
  String? _userRole;

  @override
  void initState() {
    super.initState();
    // Prefer widget param if provided
    _userRole = widget.role;
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
            _userRole = role;
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

  Future<void> _signInWithGoogle() async {
    final authProvider = context.read<AuthProvider>();
    
    try {
      LoggerService.info('Attempting Google sign-in for teacher', tag: 'LoginScreen');
      
      // Use the new teacher-only Google sign-in method
      await authProvider.signInWithGoogleAsTeacher();
      
      if (!mounted) return;
      
      // Navigate based on auth state
      if (authProvider.userModel != null) {
        final roleName = authProvider.userModel!.role?.name;
        LoggerService.info('Google sign-in successful for teacher: $roleName', tag: 'LoginScreen');
        
        // Navigate to dashboard
        context.go('/dashboard');
      }
    } catch (e) {
      LoggerService.error('Google sign-in error: $e', tag: 'LoginScreen', error: e);
      if (!mounted) return;
      
      // Error is already set in authProvider, just show it via UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Google sign-in failed'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = context.read<AuthProvider>();
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      try {
        // Admins use email login, teachers and students use username login
        if (_userRole == 'admin') {
          LoggerService.info('Attempting admin sign in with email: $username', tag: 'LoginScreen');
          await authProvider.signInWithEmail(username, password, expectedRole: 'admin');
          LoggerService.info('Admin sign in successful for email: $username', tag: 'LoginScreen');
        } else {
          LoggerService.info('Attempting sign in for username: $username as $_userRole', tag: 'LoginScreen');
          await authProvider.signInWithUsername(username, password, expectedRole: _userRole);
          LoggerService.info('Sign in successful for username: $username', tag: 'LoginScreen');
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
        final errorString = e.toString();
        
        // Check for role mismatch errors
        if (errorString.contains('has teacher access') || 
            errorString.contains('has admin access')) {
          errorMessage = errorString.replaceAll('Exception: ', '');
          // After showing error, redirect to role selection
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go('/auth/role-selection');
            }
          });
        } else if (errorString.contains('student account') && 
                   errorString.contains('student login instead')) {
          errorMessage = errorString.replaceAll('Exception: ', '');
          // Suggest using student login
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go('/auth/role-selection');
            }
          });
        } else if (errorString.contains('role mismatch')) {
          errorMessage = errorString.replaceAll('Exception: ', '');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go('/auth/role-selection');
            }
          });
        } else if (errorString.contains('invalid-email') ||
                   errorString.contains('user-not-found')) {
          errorMessage = 'Invalid username or password';
        } else if (errorString.contains('wrong-password')) {
          errorMessage = 'Invalid password';
        } else if (errorString.contains('too-many-requests')) {
          errorMessage = 'Too many attempts. Please try again later';
        } else if (errorString.contains('network')) {
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
      return 'Please enter your username';
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
                    _userRole == 'admin' ? Icons.admin_panel_settings : Icons.school,
                    size: 72,
                    color: _userRole == 'admin'
                        ? Colors.deepPurple
                        : _userRole == 'teacher'
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userRole == 'admin' ? 'Administrator Login' :
                    _userRole == 'teacher' ? 'Teacher Login' : 'Student Login',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back to Fermi',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                        color: theme.colorScheme.outline.withOpacity(0.2),
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
                              label: _userRole == 'admin' ? 'Email' : 'Username',
                              prefixIcon: _userRole == 'admin' ? Icons.email : Icons.person,
                              keyboardType: _userRole == 'admin' ? TextInputType.emailAddress : TextInputType.text,
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
                              showCapsLockIndicator: true, // Enable caps lock indicator
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
                                  foregroundColor: _userRole == 'admin'
                                      ? Colors.deepPurple
                                      : _userRole == 'teacher'
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
                                backgroundColor: _userRole == 'admin'
                                    ? Colors.deepPurple
                                    : _userRole == 'teacher'
                                        ? theme.colorScheme.secondary
                                        : theme.colorScheme.primary,
                                foregroundColor: _userRole == 'admin'
                                    ? Colors.white
                                    : _userRole == 'teacher'
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

                            // Google Sign In for Teachers
                            if (_userRole == 'teacher') ...[
                              const SizedBox(height: 16),
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Google Sign-In Button following Google's branding guidelines
                              ElevatedButton(
                                onPressed: isLoading ? null : _signInWithGoogle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 1,
                                  side: const BorderSide(color: Color(0xFFDADCE0)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Google "G" logo
                                    Container(
                                      height: 24,
                                      width: 24,
                                      padding: const EdgeInsets.all(2),
                                      child: const CustomPaint(
                                        painter: GoogleLogoPainter(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

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
                            if (_userRole == 'teacher') ...[
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Google Logo Painter for the official Google "G" logo
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -45 * 3.14159 / 180,
      -90 * 3.14159 / 180,
      true,
      paint,
    );
    
    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      225 * 3.14159 / 180,
      -90 * 3.14159 / 180,
      true,
      paint,
    );
    
    // Yellow
    paint.color = const Color(0xFFFBBC04);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      135 * 3.14159 / 180,
      -90 * 3.14159 / 180,
      true,
      paint,
    );
    
    // Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      45 * 3.14159 / 180,
      -90 * 3.14159 / 180,
      true,
      paint,
    );
    
    // White center circle
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.3,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
