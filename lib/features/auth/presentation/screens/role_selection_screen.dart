import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../providers/auth_provider.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // Student role is the only option
  final UserRole _selectedRole = UserRole.student;
  bool _isLoading = false;

  Future<void> _completeSignUp() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      // Use the generic OAuth completion method that works for both Google and Apple
      await authProvider.completeOAuthSignUp(
        role: _selectedRole,
        parentEmail: null,
        gradeLevel: null,
      );

      // Small delay to ensure state propagation
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        // Check the current status after completion
        final currentStatus = authProvider.status;
        
        if (currentStatus == AuthStatus.authenticated) {
          // Force navigation to dashboard
          // Use pushReplacement to ensure clean navigation stack
          context.go('/dashboard');
        } else if (currentStatus == AuthStatus.error || 
                   currentStatus == AuthStatus.unauthenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 
                          'Failed to complete sign up'),
            ),
          );
          // Navigate back to login since sign up failed
          context.go('/auth/login');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome Student!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your profile to get started',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Student Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Profile',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display student info
                    ListTile(
                      leading: const Icon(Icons.school),
                      title: const Text('Student Account'),
                      subtitle: const Text(
                          'Access your assignments, grades, and chat with your teacher'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Complete Button
            FilledButton(
              onPressed: _isLoading ? null : _completeSignUp,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start Learning'),
            ),
          ],
        ),
      ),
    );
  }
}
