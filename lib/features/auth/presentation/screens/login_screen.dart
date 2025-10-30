import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/logger_service.dart';

import '../widgets/auth_text_field.dart';
import '../providers/auth_provider.dart';

/// A screen that provides a user interface for users to log in.
///
/// This screen supports login via email/password and Google Sign-In. It adapts
/// its appearance and behavior based on the user's role (student, teacher, or admin).
class LoginScreen extends StatefulWidget {
  /// The user role, which determines the appearance and behavior of the login screen.
  ///
  /// This can be 'student', 'teacher', or 'admin'.
  final String? role;

  /// Creates a [LoginScreen].
  ///
  /// The [key] is required by Flutter, and [role] is optional.
  const LoginScreen({
    super.key,
    this.role,
  });

  @override
  LoginScreenState createState() => LoginScreenState();
}

/// The state for the [LoginScreen].
///
/// This class manages the form state, text controllers, and user interactions.
class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Initiates the Google Sign-In process.
  ///
  /// This method uses the [AuthProvider] to sign in with Google. Upon success,
  /// it navigates the user to the dashboard. If an error occurs, it displays
  /// a snackbar with an error message.
  Future<void> _signInWithGoogle() async {
    final authProvider = context.read<AuthProvider>();

    try {
      LoggerService.info('Attempting Google sign-in for $_userRole', tag: 'LoginScreen');

      // Use Google sign-in - role determined by email domain
      await authProvider.signInWithGoogle();

      if (!mounted) return;

      // Navigate based on auth state
      if (authProvider.userModel != null) {
        final roleName = authProvider.userModel!.role?.name;
        LoggerService.info('Google sign-in successful for $roleName', tag: 'LoginScreen');

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

  /// Initiates the email and password sign-in process.
  ///
  /// This method validates the form, then uses the [AuthProvider] to sign in.
  /// On success, it navigates to the dashboard. On failure, it displays a
  /// snackbar with a relevant error message.
  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = context.read<AuthProvider>();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      try {
        // Sign in with email - role determined by domain
        LoggerService.info('Attempting sign in with email: $email', tag: 'LoginScreen');
        await authProvider.signIn(email, password);
        LoggerService.info('Sign in successful for email: $email', tag: 'LoginScreen');

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
        
        // Check for domain-based errors
        if (errorString.contains('restricted to authorized school email')) {
          errorMessage = 'Please use your school email address';
        } else if (errorString.contains('invalid-email') ||
                   errorString.contains('user-not-found')) {
          errorMessage = 'Invalid email or password';
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


  /// Validates the user's email input.
  ///
  /// This method checks if the email is empty or does not contain an '@' symbol.
  ///
  /// - [value]: The email string to validate.
  ///
  /// Returns a `String` with an error message if validation fails, otherwise `null`.
  String? _validateInput(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter your email';
    }
    if (!value!.contains('@')) {
      return 'Please enter a valid email address';
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 179),
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
                        color: theme.colorScheme.outline.withValues(alpha: 51),
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
                              label: 'Email',
                              prefixIcon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
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

                            // Google Sign In for Teachers and Students
                            if (_userRole == 'teacher' || _userRole == 'student') ...[
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

/// A custom painter for rendering the official Google "G" logo.
///
/// This painter is used in the Google Sign-In button to display a high-fidelity
/// and scalable Google logo, following Google's branding guidelines.
class GoogleLogoPainter extends CustomPainter {
  /// Creates a [GoogleLogoPainter].
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
