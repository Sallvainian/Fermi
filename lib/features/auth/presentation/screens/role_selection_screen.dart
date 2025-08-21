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
  bool _isProcessing = false; // Prevent multiple simultaneous submissions

  Future<void> _completeSignUp() async {
    // Prevent multiple simultaneous submissions (spam clicking)
    if (_isProcessing) {
      debugPrint('Already processing role selection, ignoring duplicate request');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _isProcessing = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      
      // Check if we already have a role set (shouldn't happen but safety check)
      if (authProvider.userModel?.role != null) {
        debugPrint('User already has role: ${authProvider.userModel?.role}, navigating to dashboard');
        if (mounted) {
          context.go('/dashboard');
        }
        return;
      }
      
      // Use the generic OAuth completion method that works for both Google and Apple
      await authProvider.completeOAuthSignUp(
        role: _selectedRole,
        parentEmail: null,
        gradeLevel: null,
      );

      // Longer delay to ensure Firestore propagation AND provider update
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        // Re-read the provider to get the latest state
        final authProvider = context.read<AuthProvider>();
        final currentStatus = authProvider.status;
        final hasRole = authProvider.userModel?.role != null;
        final userModel = authProvider.userModel;
        
        debugPrint('Role selection complete - Status: $currentStatus, Has role: $hasRole, Role: ${userModel?.role}');
        debugPrint('UserModel exists: ${userModel != null}');
        debugPrint('UserModel details: id=${userModel?.id}, email=${userModel?.email}');
        
        if (currentStatus == AuthStatus.authenticated && hasRole && userModel != null) {
          // Force navigation to dashboard
          debugPrint('Successfully authenticated with role, navigating to dashboard');
          context.go('/dashboard');
        } else if (currentStatus == AuthStatus.error || 
                   currentStatus == AuthStatus.unauthenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 
                          'Failed to complete sign up. Please try again.'),
            ),
          );
          // Navigate back to login since sign up failed
          context.go('/auth/login');
        } else {
          // Still in authenticating state or no role
          debugPrint('Unexpected state - Status: $currentStatus, Role: ${authProvider.userModel?.role}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Setup incomplete. Please try signing in again.'),
            ),
          );
          context.go('/auth/login');
        }
      }
    } catch (e) {
      debugPrint('Error during role selection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        // Reset processing flag on error
        setState(() => _isProcessing = false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isProcessing = false;
        });
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
