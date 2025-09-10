import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/services/logger_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController(); // For optional email

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isTeacherRole = false;

  @override
  void initState() {
    super.initState();
    // Clear error when user starts typing
    _usernameOrEmailController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _confirmPasswordController.addListener(_clearError);
    _firstNameController.addListener(_clearError);
    _lastNameController.addListener(_clearError);
    _emailController.addListener(_clearError);
    
    
    // Check for verified role or role parameter
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // First check for verified role from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final verifiedRole = prefs.getString('verified_role');
        final verificationTime = prefs.getInt('role_verification_time');
        
        // Check if verified role exists and is not expired (30 minutes)
        bool useVerifiedRole = false;
        if (verifiedRole != null && verificationTime != null) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - verificationTime;
          final thirtyMinutes = 30 * 60 * 1000; // 30 minutes in milliseconds
          
          if (elapsed < thirtyMinutes) {
            useVerifiedRole = true;
            LoggerService.info('Using verified role: $verifiedRole', tag: 'SignupScreen');
            setState(() {
              _isTeacherRole = verifiedRole == 'teacher';
              // Note: If we add admin role later, handle it here
            });
          } else {
            // Expired - clear the verified role
            await prefs.remove('verified_role');
            await prefs.remove('role_verification_time');
            LoggerService.info('Verified role expired, cleared from storage', tag: 'SignupScreen');
          }
        }
        
        // If no valid verified role, check URL parameters
        if (!useVerifiedRole) {
          final goRouterState = GoRouterState.of(context);
          final uri = goRouterState.uri;
          
          // Check query parameters
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
        }
      } catch (e) {
        LoggerService.error('Error determining role: $e', tag: 'SignupScreen');
      }
    });
  }

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _clearError() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.errorMessage != null) {
      authProvider.clearError();
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    
    // Check for verified role one more time to ensure we use the correct role
    final prefs = await SharedPreferences.getInstance();
    final verifiedRole = prefs.getString('verified_role');
    final verificationTime = prefs.getInt('role_verification_time');
    
    String roleToUse = 'student'; // Default to student
    
    // Use verified role if it exists and is not expired
    if (verifiedRole != null && verificationTime != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - verificationTime;
      final thirtyMinutes = 30 * 60 * 1000;
      
      if (elapsed < thirtyMinutes) {
        roleToUse = verifiedRole;
        LoggerService.info('Using verified role for signup: $roleToUse', tag: 'SignupScreen');
      }
    } else if (_isTeacherRole) {
      roleToUse = 'teacher';
    }
    
    if (roleToUse == 'teacher' || _isTeacherRole) {
      // Teachers sign up with username
      await authProvider.signUpWithUsername(
        username: _usernameOrEmailController.text.trim(),
        password: _passwordController.text,
        role: roleToUse,
      );
    } else {
      // Students sign up with email
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final displayName = '$firstName $lastName'.trim();
      
      await authProvider.signUpWithEmail(
        email: _usernameOrEmailController.text.trim(),
        password: _passwordController.text,
        role: roleToUse,
        displayName: displayName,
      );
    }

    // Clear the verified role after successful signup
    if (authProvider.isAuthenticated && mounted) {
      await prefs.remove('verified_role');
      await prefs.remove('role_verification_time');
      LoggerService.info('Cleared verified role after successful signup', tag: 'SignupScreen');
      
      // Router will automatically redirect to appropriate dashboard
      // No need to manually navigate - handled by main.dart redirect logic
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(_isTeacherRole 
              ? '/auth/login?role=teacher' 
              : '/auth/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24.0,
              24.0,
              24.0,
              48.0,
            ), // Extra bottom padding
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Text(
                      'Create Account',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join the Fermi community',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                  // Sign Up Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Only show name fields for students
                        if (!_isTeacherRole) ...[
                          Row(
                            children: [
                              Expanded(
                                child: AuthTextField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  prefixIcon: Icons.person_outline,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your first name';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: AuthTextField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your last name';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Username for teachers, Email for students
                        AuthTextField(
                          controller: _usernameOrEmailController,
                          label: _isTeacherRole ? 'Username' : 'Email',
                          keyboardType: _isTeacherRole 
                              ? TextInputType.text
                              : TextInputType.emailAddress,
                          prefixIcon: _isTeacherRole 
                              ? Icons.person
                              : Icons.email_outlined,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return _isTeacherRole 
                                  ? 'Please enter your username'
                                  : 'Please enter your email';
                            }
                            if (!_isTeacherRole) {
                              // Email validation for students
                              final emailRegex = RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                              );
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _passwordController,
                          label: 'Password',
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline,
                          showCapsLockIndicator: true, // Enable caps lock indicator
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
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
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: Icons.lock_outline,
                          showCapsLockIndicator: true, // Enable caps lock indicator
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sign Up Button
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return FilledButton(
                        onPressed: authProvider.isLoading ? null : _signUp,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: _isTeacherRole 
                              ? theme.colorScheme.secondary
                              : null,
                          foregroundColor: _isTeacherRole
                              ? theme.colorScheme.onSecondary
                              : null,
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create Account'),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Sign In Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: theme.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go(_isTeacherRole 
                            ? '/auth/login?role=teacher'
                            : '/auth/login'),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),

                  // Error Message
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      if (authProvider.errorMessage != null) {
                        return Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authProvider.errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
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
