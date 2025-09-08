import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../shared/widgets/common/app_card.dart';
import '../providers/admin_provider.dart';
import '../widgets/system_stats_card.dart';
import '../widgets/user_list_card.dart';
import '../widgets/activity_feed_card.dart';
import '../widgets/quick_actions_grid.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late AdminProvider _adminProvider;

  @override
  void initState() {
    super.initState();
    _adminProvider = context.read<AdminProvider>();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    await _adminProvider.loadAdminDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    final isTablet = size.width > 600 && size.width <= 1200;

    return AdaptiveLayout(
      title: 'Administrator Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            context.go('/notifications');
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            context.go('/settings');
          },
        ),
      ],
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, _) {
          if (adminProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (adminProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    adminProvider.error!,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDashboard,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadDashboard,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  _buildWelcomeHeader(theme),
                  const SizedBox(height: 24),

                  // System Overview Section
                  Text(
                    'System Overview',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // System Stats Cards
                  if (isDesktop) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: SystemStatsCard(stats: adminProvider.systemStats),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: QuickActionsGrid(
                            onCreateStudent: () => _showCreateStudentDialog(context),
                            onCreateTeacher: () => _showCreateTeacherDialog(context),
                            onViewReports: () => context.go('/admin/reports'),
                            onSystemSettings: () => context.go('/admin/system-settings'),
                            onBulkImport: () => context.go('/admin/bulk-import'),
                            onManageUsers: () => context.go('/admin/users'),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isTablet) ...[
                    SystemStatsCard(stats: adminProvider.systemStats),
                    const SizedBox(height: 16),
                    QuickActionsGrid(
                      onCreateStudent: () => _showCreateStudentDialog(context),
                      onCreateTeacher: () => _showCreateTeacherDialog(context),
                      onViewReports: () => context.go('/admin/reports'),
                      onSystemSettings: () => context.go('/admin/system-settings'),
                      onBulkImport: () => context.go('/admin/bulk-import'),
                      onManageUsers: () => context.go('/admin/users'),
                    ),
                  ] else ...[
                    SystemStatsCard(stats: adminProvider.systemStats),
                    const SizedBox(height: 16),
                    QuickActionsGrid(
                      onCreateStudent: () => _showCreateStudentDialog(context),
                      onCreateTeacher: () => _showCreateTeacherDialog(context),
                      onViewReports: () => context.go('/admin/reports'),
                      onSystemSettings: () => context.go('/admin/system-settings'),
                      onBulkImport: () => context.go('/admin/bulk-import'),
                      onManageUsers: () => context.go('/admin/users'),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Recent Users and Activities Section
                  Text(
                    'Recent Activity',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isDesktop) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: UserListCard(
                            users: adminProvider.recentUsers,
                            onUserTap: (user) => _showUserDetails(context, user),
                            onViewAll: () => context.go('/admin/users'),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: ActivityFeedCard(
                            activities: adminProvider.recentActivities,
                            onViewAll: () => context.go('/admin/activity-log'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    UserListCard(
                      users: adminProvider.recentUsers,
                      onUserTap: (user) => _showUserDetails(context, user),
                      onViewAll: () => context.go('/admin/users'),
                    ),
                    const SizedBox(height: 16),
                    ActivityFeedCard(
                      activities: adminProvider.recentActivities,
                      onViewAll: () => context.go('/admin/activity-log'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeHeader(ThemeData theme) {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              size: 32,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Administrator',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage users, monitor system activity, and configure platform settings',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateStudentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateStudentDialog(
        adminProvider: _adminProvider,
      ),
    );
  }

  void _showCreateTeacherDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateTeacherDialog(
        adminProvider: _adminProvider,
      ),
    );
  }

  void _showUserDetails(BuildContext context, dynamic user) {
    // TODO: Implement user details dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User details for ${user.displayName}')),
    );
  }
}

// Create Student Dialog
class _CreateStudentDialog extends StatefulWidget {
  final AdminProvider adminProvider;

  const _CreateStudentDialog({required this.adminProvider});

  @override
  State<_CreateStudentDialog> createState() => _CreateStudentDialogState();
}

class _CreateStudentDialogState extends State<_CreateStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _gradeController = TextEditingController();
  String _generatedPassword = '';
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  void _generatePassword() {
    // Generate a simple password
    final timestamp = DateTime.now().millisecondsSinceEpoch % 10000;
    _generatedPassword = 'student$timestamp';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    final result = await widget.adminProvider.createStudentAccount(
      username: _usernameController.text,
      password: _generatedPassword,
      displayName: _displayNameController.text.isEmpty 
          ? _usernameController.text 
          : _displayNameController.text,
      grade: _gradeController.text,
    );

    if (mounted) {
      if (result != null) {
        // Show success dialog with credentials
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Student Account Created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account created successfully! Here are the login credentials:'),
                const SizedBox(height: 16),
                SelectableText('Username: ${result['email']}'),
                SelectableText('Password: ${result['password']}'),
                const SizedBox(height: 16),
                const Text(
                  'Please save these credentials and share them with the student.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close success dialog
                  Navigator.of(context).pop(); // Close create dialog
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create student account'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Student Account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter a unique username',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a username';
                }
                if (value.length < 3) {
                  return 'Username must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name (Optional)',
                hintText: 'Student\'s full name',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _gradeController,
              decoration: const InputDecoration(
                labelText: 'Grade Level (Optional)',
                hintText: 'e.g., 5th Grade',
                prefixIcon: Icon(Icons.school),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Generated Password:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SelectableText(_generatedPassword),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createStudent,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Account'),
        ),
      ],
    );
  }
}

// Create Teacher Dialog
class _CreateTeacherDialog extends StatefulWidget {
  final AdminProvider adminProvider;

  const _CreateTeacherDialog({required this.adminProvider});

  @override
  State<_CreateTeacherDialog> createState() => _CreateTeacherDialogState();
}

class _CreateTeacherDialogState extends State<_CreateTeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    final result = await widget.adminProvider.createTeacherAccount(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _displayNameController.text,
    );

    if (mounted) {
      if (result != null) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Teacher Account Created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account created successfully!'),
                const SizedBox(height: 16),
                SelectableText('Email: ${result['email']}'),
                const SizedBox(height: 8),
                const Text(
                  'The teacher should use their email and the password you provided to sign in.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close success dialog
                  Navigator.of(context).pop(); // Close create dialog
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create teacher account'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Teacher Account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'teacher@example.com',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'Teacher\'s full name',
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a display name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'Enter a secure password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createTeacher,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Account'),
        ),
      ],
    );
  }
}