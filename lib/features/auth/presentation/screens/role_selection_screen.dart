import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    setState(() => _isLoading = true);

    try {
      // Update AuthProvider with selected role first (before async)
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      authProvider.setSelectedRole(role);

      // Save selected role to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_role', role);

      // Navigate based on role
      if (mounted) {
        if (role == 'teacher') {
          // Teachers need additional password verification
          context.go('/auth/teacher-password');
        } else {
          // Students go directly to login
          context.go('/auth/login');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting role: $e'),
            backgroundColor: Colors.red.shade700,
          ),
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
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon
                  Icon(
                    Icons.school,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Welcome to Fermi+',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Subtitle
                  Text(
                    'Please select your role to continue',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Role selection cards/buttons
                  if (isLandscape) ...[
                    // Landscape: Side by side
                    Row(
                      children: [
                        Expanded(
                          child: _buildRoleCard(
                            context: context,
                            role: 'student',
                            title: "I'm a Student",
                            subtitle:
                                'Access assignments, grades, and class materials',
                            icon: Icons.person,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildRoleCard(
                            context: context,
                            role: 'teacher',
                            title: "I'm a Teacher",
                            subtitle:
                                'Manage classes, create assignments, and track progress',
                            icon: Icons.school,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Portrait: Stacked
                    _buildRoleCard(
                      context: context,
                      role: 'student',
                      title: "I'm a Student",
                      subtitle:
                          'Access assignments, grades, and class materials',
                      icon: Icons.person,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    _buildRoleCard(
                      context: context,
                      role: 'teacher',
                      title: "I'm a Teacher",
                      subtitle:
                          'Manage classes, create assignments, and track progress',
                      icon: Icons.school,
                      color: theme.colorScheme.secondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _isLoading ? null : () => _selectRole(role),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.arrow_forward, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
