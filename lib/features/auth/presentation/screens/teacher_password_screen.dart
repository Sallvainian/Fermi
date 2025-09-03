import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class TeacherPasswordScreen extends StatefulWidget {
  const TeacherPasswordScreen({super.key});

  @override
  State<TeacherPasswordScreen> createState() => _TeacherPasswordScreenState();
}

class _TeacherPasswordScreenState extends State<TeacherPasswordScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _failedAttempts = 0;
  static const int _maxAttempts = 3;

  // Hash of teacher password - you can change this password by updating the hash
  // Default password: "educator2024"
  // To generate new hash: print(sha256.convert(utf8.encode('your_new_password')).toString());
  static const String _teacherPasswordHash =
      '6cd7ac617ec119dfbc5cee823bf710b7753512a18fa3608b0c51645ea818f2e2';

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _verifyPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final enteredPassword = _passwordController.text;
    final enteredHash = _hashPassword(enteredPassword);

    // Check if password is correct
    if (enteredHash == _teacherPasswordHash) {
      // Success - save teacher verification status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('teacher_verified', true);
      await prefs.setInt(
        'teacher_verify_time',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Navigate to teacher login
      if (mounted) {
        context.go('/auth/login?role=teacher');
      }
    } else {
      // Failed attempt
      _failedAttempts++;
      _passwordController.clear();

      if (_failedAttempts >= _maxAttempts) {
        // Too many failed attempts - go back to role selection
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('selected_role');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Too many failed attempts. Please select your role again.',
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
          context.go('/auth/role-selection');
        }
      } else {
        // Show error with remaining attempts
        if (mounted) {
          _showError(
            'Incorrect password. ${_maxAttempts - _failedAttempts} attempts remaining.',
          );
        }
      }
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goBack() {
    // Clear selected role and go back to role selection
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('selected_role');
    });
    context.go('/auth/role-selection');
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back to role selection',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Teacher Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 60,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Text(
                      'Teacher Verification',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Enter the teacher password to continue',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Teacher Password',
                        hintText: 'Enter teacher access password',
                        prefixIcon: const Icon(Icons.lock_person),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        errorMaxLines: 2,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the teacher password';
                        }
                        if (value.length < 4) {
                          return 'Password must be at least 4 characters';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _verifyPassword(),
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyPassword,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify & Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Cancel Button
                    TextButton(
                      onPressed: _isLoading ? null : _goBack,
                      child: Text(
                        'Not a teacher? Go back',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),

                    if (_failedAttempts > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Attempts remaining: ${_maxAttempts - _failedAttempts}',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
