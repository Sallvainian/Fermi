import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

/// A screen that allows users to select their role (e.g., student, teacher, admin).
///
/// This is typically the first screen a new user sees. Once a role is selected,
/// it's saved to [SharedPreferences] and the user is navigated to the login screen.
class RoleSelectionScreen extends StatefulWidget {
  /// Creates a [RoleSelectionScreen].
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

/// The state for the [RoleSelectionScreen].
///
/// This class handles the UI for role selection and the logic for persisting
/// the selected role.
class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  /// Handles the selection of a role.
  ///
  /// This method saves the selected role to [SharedPreferences], updates the
  /// [AuthProvider], and navigates to the login screen with the role as a
  /// query parameter.
  ///
  /// - [role]: The role that was selected (e.g., 'student', 'teacher').
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

      // Navigate to login for all roles with role parameter
      if (mounted) {
        context.go('/auth/login?role=$role');
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
              constraints: const BoxConstraints(maxWidth: 900),
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 179),
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
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildRoleCard(
                            context: context,
                            role: 'admin',
                            title: "I'm an Administrator",
                            subtitle:
                                'Manage users, system settings, and platform administration',
                            icon: Icons.admin_panel_settings,
                            color: Colors.deepPurple,
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
                    const SizedBox(height: 20),
                    _buildRoleCard(
                      context: context,
                      role: 'admin',
                      title: "I'm an Administrator",
                      subtitle:
                          'Manage users, system settings, and platform administration',
                      icon: Icons.admin_panel_settings,
                      color: Colors.deepPurple,
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

  /// Builds a card for a specific role.
  ///
  /// This widget is used to display a single role selection option. It includes
  /// an icon, title, subtitle, and is styled with a given color.
  ///
  /// - [context]: The build context.
  /// - [role]: The role identifier (e.g., 'student').
  /// - [title]: The title of the role.
  /// - [subtitle]: A brief description of the role.
  /// - [icon]: The icon representing the role.
  /// - [color]: The color associated with the role.
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
                  color: color.withValues(alpha: 0.2),
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
