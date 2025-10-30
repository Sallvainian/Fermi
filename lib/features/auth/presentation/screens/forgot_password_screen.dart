import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

/// A screen that allows users to reset their password.
///
/// Users can enter their email address to receive a password reset link.
/// The screen provides feedback on the success or failure of this operation.
class ForgotPasswordScreen extends StatefulWidget {
  /// Creates a [ForgotPasswordScreen].
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

/// The state for the [ForgotPasswordScreen].
///
/// This class manages the form for entering the user's email, handles the
/// password reset logic, and displays success or error messages.
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Sends a password reset email to the user.
  ///
  /// This method validates the email address, then uses [FirebaseAuth] to
  /// send the reset link. It updates the UI to show loading and success states,
  /// and displays an error message if the process fails.
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      setState(() => _emailSent = true);
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email address';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/auth/login');
            }
          },
        ),
        title: const Text('Reset Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _emailSent ? _buildSuccessMessage(theme) : _buildForm(theme),
      ),
    );
  }

  /// Builds the form for entering the email address.
  ///
  /// This widget includes a text field for the email, a submit button, and
  /// associated informational text.
  ///
  /// - [theme]: The current theme data.
  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(Icons.lock_reset, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Forgot Password?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              // Enhanced email validation using regex
              final emailRegex = RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
              );
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  /// Builds the success message displayed after the email is sent.
  ///
  /// This widget informs the user that the email has been sent and provides
  /// a button to return to the login screen.
  ///
  /// - [theme]: The current theme data.
  Widget _buildSuccessMessage(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Email Sent!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a password reset link to ${_emailController.text}',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/auth/login');
            }
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }
}
