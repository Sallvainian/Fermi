import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../providers/auth_provider.dart';
import '../../../classes/presentation/providers/class_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../classes/domain/models/class_model.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../shared/widgets/common/responsive_layout.dart';
import '../../../../shared/widgets/common/common_widgets.dart';
import '../../../student/presentation/widgets/online_users_card.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_theme.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadTeacherClasses();
  }

  void _loadTeacherClasses() {
    final authProvider = context.read<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final teacherId = authProvider.userModel?.uid;
    
    if (teacherId != null) {
      classProvider.loadTeacherClasses(teacherId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Teacher Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            // TODO: Navigate to notifications
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            context.go('/settings');
          },
        ),
      ],
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Card(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            user?.displayName.isNotEmpty == true
                                ? user!.displayName[0].toUpperCase()
                                : 'T',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome Back',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _getUserFirstName(user, authProvider),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Quick Stats - Smaller section
              _buildQuickStats(context),
              const SizedBox(height: 24),

              // My Classes
              Text(
                  'My Classes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              _buildClassesSection(context),
              const SizedBox(height: AppSpacing.lg),

              // Recent Activity
              Text(
                  'Recent Activity',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              _buildRecentActivityCard(context),
              const SizedBox(height: AppSpacing.lg),
              
              // Online Users
              Text(
                  'Online Users',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 300,
                child: OnlineUsersCard(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Quick Actions
              Text(
                  'Quick Actions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              _buildQuickActionsGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final classProvider = context.watch<ClassProvider>();
    final teacherClasses = classProvider.teacherClasses;
    final totalStudents = teacherClasses.fold<int>(0, (sum, classModel) => sum + classModel.studentCount);
    
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCompactStatCard(
            context,
            icon: Icons.class_,
            title: 'Classes',
            value: '${teacherClasses.length}',
            color: Colors.blue,
            onTap: () => context.go('/teacher/classes'),
          ),
          const SizedBox(width: 12),
          _buildCompactStatCard(
            context,
            icon: Icons.people,
            title: 'Students',
            value: '$totalStudents',
            color: Colors.green,
            onTap: () => context.go('/teacher/students'),
          ),
          const SizedBox(width: 12),
          _buildCompactStatCard(
            context,
            icon: Icons.assignment,
            title: 'Assignments',
            value: '23',
            color: Colors.orange,
            onTap: () => context.go('/teacher/assignments'),
          ),
          const SizedBox(width: 12),
          _buildCompactStatCard(
            context,
            icon: Icons.grade,
            title: 'To Grade',
            value: '8',
            color: Colors.red,
            onTap: () => context.go('/teacher/gradebook'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesSection(BuildContext context) {
    final classProvider = context.watch<ClassProvider>();
    
    if (classProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final teacherClasses = classProvider.teacherClasses;
    
    if (teacherClasses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.class_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Classes Yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first class to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/teacher/classes'),
                  child: const Text('Create a Class'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show max 4 classes on dashboard
    final displayClasses = teacherClasses.take(4).toList();
    
    return Column(
      children: [
        ...displayClasses.map((course) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildClassCard(context, course),
        )),
        if (teacherClasses.length > 4) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/teacher/classes'),
              child: Text('View All ${teacherClasses.length} Classes'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildClassCard(BuildContext context, ClassModel course) {
    final theme = Theme.of(context);
    final colorIndex = course.subject.hashCode % AppTheme.subjectColors.length;
    final color = AppTheme.subjectColors[colorIndex];
    
    return AppCard(
      onTap: () => _navigateToClass(context, course),
      child: Row(
        children: [
          // Color indicator
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          
          // Class info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  course.subject,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: [
                    if (course.room != null)
                      _buildInfoChip(Icons.room, course.room!),
                    if (course.schedule != null)
                      _buildInfoChip(Icons.schedule, course.schedule!),
                    _buildInfoChip(Icons.people, '${course.studentCount} students'),
                  ],
                ),
              ],
            ),
          ),
          
          // Arrow icon
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  void _navigateToClass(BuildContext context, ClassModel course) {
    // Set the selected class in the provider
    context.read<ClassProvider>().setSelectedClass(course);
    // Navigate to classes screen with selected class
    context.go('/teacher/classes');
  }

  Widget _buildCompactStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    
    return SizedBox(
      width: 120,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildActivityItem(
              context,
              icon: Icons.assignment_turned_in,
              title: 'New assignment submitted',
              subtitle: 'John Doe submitted Math Homework #5',
              time: '2 hours ago',
              color: Colors.green,
            ),
            const Divider(),
            _buildActivityItem(
              context,
              icon: Icons.message,
              title: 'New message',
              subtitle: 'Parent inquiry about Sarah\'s progress',
              time: '4 hours ago',
              color: Colors.blue,
            ),
            const Divider(),
            _buildActivityItem(
              context,
              icon: Icons.schedule,
              title: 'Upcoming deadline',
              subtitle: 'Science Project due tomorrow',
              time: '1 day left',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Text(
        time,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return ResponsiveGrid(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mobileColumns: 2,
      tabletColumns: 3,
      desktopColumns: 3,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      childAspectRatio: 1.0, // Reduced to give more height for action cards
      children: [
        _buildActionCard(
          context,
          icon: Icons.add_circle_outline,
          title: 'Create Assignment',
          subtitle: 'Add new homework or project',
          onTap: () {
            // TODO: Navigate to create assignment
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.grade,
          title: 'Grade Work',
          subtitle: 'Review student submissions',
          onTap: () {
            // TODO: Navigate to grading
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.chat,
          title: 'Message Parents',
          subtitle: 'Send updates and announcements',
          onTap: () {
            context.go('/messages');
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.analytics,
          title: 'View Reports',
          subtitle: 'Class performance analytics',
          onTap: () {
            context.go('/teacher/analytics');
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.schedule,
          title: 'Schedule Event',
          subtitle: 'Add to class calendar',
          onTap: () {
            // TODO: Navigate to calendar
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.backup,
          title: 'Export Data',
          subtitle: 'Download gradebook backup',
          onTap: () {
            // TODO: Export functionality
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.grid_view_rounded,
          title: 'Jeopardy Games',
          subtitle: 'Create and play quiz games',
          onTap: () {
            context.go('/teacher/games/jeopardy');
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getUserFirstName(UserModel? user, AuthProvider authProvider) {
    // Try firstName field first
    if (user?.firstName.isNotEmpty == true) {
      return '${user!.firstName}!';
    }
    
    // Try displayName from user model
    if (user?.displayName.isNotEmpty == true) {
      final nameParts = user!.displayName.split(' ');
      if (nameParts.isNotEmpty) {
        return '${nameParts.first}!';
      }
    }
    
    // Try Firebase Auth displayName
    final firebaseUser = authProvider.firebaseUser;
    if (firebaseUser?.displayName?.isNotEmpty == true) {
      final nameParts = firebaseUser!.displayName!.split(' ');
      if (nameParts.isNotEmpty) {
        return '${nameParts.first}!';
      }
    }
    
    // Default fallback
    return 'Teacher!';
  }
}