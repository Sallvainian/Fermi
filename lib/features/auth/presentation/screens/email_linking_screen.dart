import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class EmailLinkingScreen extends StatefulWidget {
  final String userType; // 'teacher' or 'student'

  const EmailLinkingScreen({super.key, required this.userType});

  @override
  State<EmailLinkingScreen> createState() => _EmailLinkingScreenState();
}

class _EmailLinkingScreenState extends State<EmailLinkingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isUpdating = false;
  bool _showSkipConfirmation = false;

  // Email validation regex
  final _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  bool get _isValidEmail {
    final text = _emailController.text.trim();
    return text.isNotEmpty && _emailRegex.hasMatch(text);
  }

  @override
  void initState() {
    super.initState();
    // Listen to text changes to enable/disable the button
    _emailController.addListener(() {
      setState(() {}); // Trigger rebuild when text changes
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _linkEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final newEmail = _emailController.text.trim();

      // For Firebase Auth 6.0+, we need to use the credential approach for email updates
      // Since we're using synthetic emails, we'll just update Firestore
      // The actual Firebase Auth email stays as the synthetic one for username login
      
      // Update Firestore document with the real email for notifications/recovery
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'realEmail': newEmail,  // Store the real email for notifications
        'email': user.email,    // Keep synthetic email for auth
        'emailLinkedAt': FieldValue.serverTimestamp(),
        'hasLinkedEmail': true,
      });

      // Refresh the auth provider's user model
      final authProvider = context.read<AuthProvider>();
      await authProvider.reloadUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email successfully linked to $newEmail',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate to dashboard
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to link email';
        
        if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'This email is already in use by another account';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Please enter a valid email address';
        } else if (e.toString().contains('requires-recent-login')) {
          errorMessage = 'Please sign out and sign in again to link your email';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _skipEmailLinking() {
    setState(() => _showSkipConfirmation = true);
  }

  void _confirmSkip() {
    // Navigate to dashboard without linking email
    context.go('/dashboard');
  }

  void _cancelSkip() {
    setState(() => _showSkipConfirmation = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final username = authProvider.userModel?.username ?? 'User';
    final isTeacher = widget.userType == 'teacher';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _showSkipConfirmation
                  ? _buildSkipConfirmation(theme)
                  : _buildEmailForm(theme, username, isTeacher),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm(ThemeData theme, String username, bool isTeacher) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                (isTeacher
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary)
                    .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.email,
            size: 60,
            color: isTeacher
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          'Link Your Email',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isTeacher
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          'Add an email address to enable notifications and account recovery',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Username Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                (isTeacher
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary)
                    .withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  (isTeacher
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary)
                      .withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person,
                color: isTeacher
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Username',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isTeacher
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    username,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Form
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email Field
              AuthTextField(
                controller: _emailController,
                label: 'Email Address',
                prefixIcon: Icons.email,
                enabled: !_isUpdating,
                keyboardType: TextInputType.emailAddress,
                suffixIcon: _emailController.text.isNotEmpty
                    ? Icon(
                        _isValidEmail ? Icons.check_circle : Icons.error,
                        color: _isValidEmail ? Colors.green : Colors.red,
                      )
                    : null,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Only validate if user entered something
                    if (!_emailRegex.hasMatch(value)) {
                      return 'Please enter a valid email address (e.g., user@example.com)';
                    }
                  }
                  return null; // Email is optional
                },
              ),
              const SizedBox(height: 24),

              // Link Email Button
              ElevatedButton(
                onPressed: _isUpdating || !_isValidEmail
                    ? null
                    : _linkEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isTeacher
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                  foregroundColor: isTeacher
                      ? theme.colorScheme.onSecondary
                      : theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUpdating
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
                        'Link Email & Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // Skip Button
              TextButton(
                onPressed: _isUpdating ? null : _skipEmailLinking,
                child: Text(
                  'Skip for Now',
                  style: TextStyle(
                    color: isTeacher
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ),

              // Benefits Info
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Benefits of Linking Email',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Receive important notifications\n'
                      '• Reset your password if forgotten\n'
                      '• Recover your username\n'
                      '• Enhanced account security',
                      style: TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkipConfirmation(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Warning Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning, size: 60, color: Colors.orange),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          'Skip Email Linking?',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Standardized Warning Message
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'Are you sure you don\'t want to link an email? Linking an email enables '
            'email notifications and enhanced account security as well as the ability '
            'to recover your password or username if you lose it. You can always link '
            'it later in the settings menu of your account.',
            style: TextStyle(fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),

        // Buttons
        ElevatedButton(
          onPressed: _cancelSkip,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Go Back & Add Email',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),

        TextButton(
          onPressed: _confirmSkip,
          child: Text(
            'Continue Without Email',
            style: TextStyle(color: Colors.orange.shade700, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
