import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // User Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      user?.displayName.isNotEmpty == true
                          ? user!.displayName[0].toUpperCase()
                          : 'U',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'User',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user?.role.toString().split('.').last.toUpperCase() ?? 'USER',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildNavItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    title: 'Dashboard',
                    route: '/dashboard',
                  ),

                  // Teacher-specific navigation
                  if (user?.role == UserRole.teacher) ...[
                    _buildNavItem(
                      context,
                      icon: Icons.class_outlined,
                      selectedIcon: Icons.class_,
                      title: 'My Classes',
                      route: '/teacher/classes',
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.grade_outlined,
                      selectedIcon: Icons.grade,
                      title: 'Gradebook',
                      route: '/teacher/gradebook',
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.assignment_outlined,
                      selectedIcon: Icons.assignment,
                      title: 'Assignments',
                      route: '/teacher/assignments',
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.people_outline,
                      selectedIcon: Icons.people,
                      title: 'Students',
                      route: '/teacher/students',
                    ),
                  ],

                  // Student-specific navigation
                  if (user?.role == UserRole.student) ...[
                    _buildNavItem(
                      context,
                      icon: Icons.book_outlined,
                      selectedIcon: Icons.book,
                      title: 'My Courses',
                      route: '/student/courses',
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.assignment_outlined,
                      selectedIcon: Icons.assignment,
                      title: 'Assignments',
                      route: '/student/assignments',
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.grade_outlined,
                      selectedIcon: Icons.grade,
                      title: 'Grades',
                      route: '/student/grades',
                    ),
                  ],

                  // Common navigation
                  _buildNavItem(
                    context,
                    icon: Icons.chat_outlined,
                    selectedIcon: Icons.chat,
                    title: 'Messages',
                    route: '/messages',
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.forum_outlined,
                    selectedIcon: Icons.forum,
                    title: 'Discussion Boards',
                    route: '/discussions',
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.calendar_month_outlined,
                    selectedIcon: Icons.calendar_month,
                    title: 'Calendar',
                    route: '/calendar',
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.notifications_outlined,
                    selectedIcon: Icons.notifications,
                    title: 'Notifications',
                    route: '/notifications',
                  ),

                  const Divider(height: 32),

                  _buildNavItem(
                    context,
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    title: 'Settings',
                    route: '/settings',
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.help_outline,
                    selectedIcon: Icons.help,
                    title: 'Help & Support',
                    route: '/help',
                  ),
                ],
              ),
            ),

            // Sign Out
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  authProvider.signOut();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required String route,
  }) {
    final theme = Theme.of(context);
    final router = GoRouter.of(context);
    final currentRoute = router.routeInformationProvider.value.uri.path;
    final isSelected = currentRoute == route;

    return ListTile(
      leading: Icon(
        isSelected ? selectedIcon : icon,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () {
        Navigator.of(context).pop(); // Close drawer first
        
        // Use go() for dashboard to reset stack, push() for everything else
        if (route == '/dashboard') {
          context.go(route);
        } else {
          context.push(route);
        }
      },
    );
  }
}