import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/profile_completion_dialog.dart';
import '../../../classes/presentation/providers/class_provider.dart';
import '../../../chat/presentation/providers/call_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../classes/domain/models/class_model.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../shared/widgets/common/responsive_layout.dart';
import '../../../../shared/widgets/common/common_widgets.dart';
import '../../../student/presentation/widgets/online_users_card.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/pwa_install_prompt.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/domain/models/activity_model.dart';
import '../../../assignments/presentation/providers/assignment_provider_simple.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  Stream<List<ClassModel>>? _classesStream;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize once in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _initializeDashboard();
        _checkProfileCompletion();
      }
    });
  }

  void _checkProfileCompletion() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.userModel;
    
    // Check if teacher needs to complete profile
    if (user != null && user.role?.name == 'teacher') {
      final needsProfileCompletion = 
          (user.firstName == null || user.firstName!.isEmpty) ||
          (user.lastName == null || user.lastName!.isEmpty);
      
      if (needsProfileCompletion) {
        // Show profile completion dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const ProfileCompletionDialog(isTeacher: true),
          );
        });
      }
    }
  }

  void _initializeDashboard() {
    if (_isInitialized) return; // Prevent multiple initializations

    final authProvider = context.read<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    final assignmentProvider = context.read<SimpleAssignmentProvider>();

    final teacherId =
        authProvider.firebaseUser?.uid ?? authProvider.userModel?.uid;

    // === INITIALIZING DASHBOARD FOR TEACHER: $teacherId ===

    if (teacherId != null) {
      _isInitialized = true; // Set this BEFORE loading to prevent re-runs

      // Load data and capture the stream
      _classesStream = classProvider.loadTeacherClasses(teacherId);
      dashboardProvider.loadTeacherDashboard(teacherId);
      assignmentProvider.loadAssignmentsForTeacher();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final callProvider = context.watch<CallProvider>();
    final classProvider = context.watch<ClassProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();
    final assignmentProvider = context.watch<SimpleAssignmentProvider>();
    final user = authProvider.userModel;
    final theme = Theme.of(context);

    // Handle incoming calls
    if (callProvider.hasIncomingCall &&
        callProvider.incomingCall != null &&
        !callProvider.isNavigationInProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        callProvider.setNavigationInProgress(true);
        context.push('/incoming-call', extra: callProvider.incomingCall).then((
          _,
        ) {
          // Reset navigation state after call screen is popped
          callProvider.setNavigationInProgress(false);
          // Optional: Add any post-call logic here
        });
      });
    }

    return AdaptiveLayout(
      title: 'Teacher Dashboard',
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
                          user?.displayName?.isNotEmpty == true
                              ? user!.displayName![0].toUpperCase()
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

              // PWA Install Prompt for iOS users
              const PWAInstallPrompt(),
              const SizedBox(height: 8),

              // Quick Stats - Smaller section
              _buildQuickStats(
                context,
                classProvider,
                dashboardProvider,
                assignmentProvider,
              ),
              const SizedBox(height: 24),

              // My Classes
              Text(
                'My Classes',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildClassesSection(context, classProvider),
              const SizedBox(height: AppSpacing.lg),

              // Recent Activity
              Text(
                'Recent Activity',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildRecentActivityCard(context, dashboardProvider),
              const SizedBox(height: AppSpacing.lg),

              // Online Users
              Text(
                'Online Users',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OnlineUsersCard(),
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

  Widget _buildQuickStats(
    BuildContext context,
    ClassProvider classProvider,
    DashboardProvider dashboardProvider,
    SimpleAssignmentProvider assignmentProvider,
  ) {
    final teacherClasses = classProvider.teacherClasses;
    final totalStudents = teacherClasses.fold<int>(
      0,
      (sum, classModel) => sum + classModel.studentCount,
    );

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
            value: '${assignmentProvider.teacherAssignments.length}',
            color: Colors.orange,
            onTap: () => context.go('/teacher/assignments'),
          ),
          const SizedBox(width: 12),
          _buildCompactStatCard(
            context,
            icon: Icons.grade,
            title: 'To Grade',
            value: '${dashboardProvider.assignmentsToGrade}',
            color: Colors.red,
            onTap: () => context.go('/teacher/gradebook'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesSection(
    BuildContext context,
    ClassProvider classProvider,
  ) {
    // Check if we have a valid teacher ID
    final authProvider = context.read<AuthProvider>();
    final teacherId =
        authProvider.firebaseUser?.uid ?? authProvider.userModel?.uid;

    if (teacherId == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                const Text('Unable to load classes'),
                const SizedBox(height: 8),
                const Text('Please try logging out and back in'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isInitialized = false;
                      _classesStream = null;
                      _initializeDashboard();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If not initialized or stream is null, show loading
    if (!_isInitialized || _classesStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<ClassModel>>(
      stream: _classesStream,
      builder: (context, snapshot) {
        // Handle connection state
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle errors
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading classes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isInitialized = false;
                          _classesStream = null;
                        });
                        // Re-initialize after a small delay
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _initializeDashboard();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // We have data - show it
        final teacherClasses = snapshot.data ?? [];

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

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final isWide = maxWidth > 960;
            final isMedium = maxWidth > 640 && maxWidth <= 960;
            final columns = isWide ? 3 : isMedium ? 2 : 1;
            final spacing = 16.0;
            final totalSpacing = columns > 1 ? spacing * (columns - 1) : 0.0;
            final cardWidth = columns > 1
                ? (maxWidth - totalSpacing) / columns
                : maxWidth;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: teacherClasses.map((course) {
                return SizedBox(
                  width: cardWidth,
                  child: _buildCompactClassCard(context, course),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildCompactClassCard(BuildContext context, ClassModel course) {
    final theme = Theme.of(context);
    final colorIndex = course.subject.hashCode % AppTheme.subjectColors.length;
    final color = AppTheme.subjectColors[colorIndex];
    final period = course.periodNumber;
    final scheduleLabel = course.schedule;

    final details = <String>[
      if (period != null) 'Period $period',
      if (scheduleLabel != null && (period == null || !scheduleLabel.toLowerCase().contains('period')))
        scheduleLabel,
    ];

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _navigateToClass(context, course),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.subject,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        details.join(' | '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 48),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${course.studentCount}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '${course.studentCount} students',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (course.room != null) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.meeting_room,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    course.room!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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
      width: 140,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: color),
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
                const SizedBox(height: 6),
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

  void _navigateToClass(BuildContext context, ClassModel course) {
    context.go('/class/${course.id}');
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
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
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

  Widget _buildRecentActivityCard(
    BuildContext context,
    DashboardProvider dashboardProvider,
  ) {
    final activities = dashboardProvider.recentActivities;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: dashboardProvider.isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : activities.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Recent Activity',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Activity from your classes will appear here',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  for (int i = 0; i < activities.take(3).length; i++) ...[
                    _buildActivityItemFromModel(context, activities[i]),
                    if (i < activities.take(3).length - 1) const Divider(),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildActivityItemFromModel(
    BuildContext context,
    ActivityModel activity,
  ) {
    IconData icon;
    Color color;

    switch (activity.type) {
      case ActivityType.assignmentSubmitted:
        icon = Icons.assignment_turned_in;
        color = Colors.green;
        break;
      case ActivityType.messageReceived:
        icon = Icons.message;
        color = Colors.blue;
        break;
      case ActivityType.upcomingDeadline:
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case ActivityType.assignmentGraded:
        icon = Icons.grade;
        color = Colors.purple;
        break;
      case ActivityType.studentJoined:
        icon = Icons.person_add;
        color = Colors.teal;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return _buildActivityItem(
      context,
      icon: icon,
      title: activity.title,
      subtitle: activity.description,
      time: activity.timeAgo,
      color: color,
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
            context.go('/teacher/assignments/create');
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.grade,
          title: 'Grade Work',
          subtitle: 'Review student submissions',
          onTap: () {
            context.go('/teacher/gradebook');
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
            context.go('/calendar');
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.backup,
          title: 'Export Data',
          subtitle: 'Download gradebook backup',
          onTap: () {
            _showExportDialog(context);
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
              Icon(icon, size: 32, color: theme.colorScheme.primary),
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
    if (user?.firstName?.isNotEmpty == true) {
      return '${user!.firstName}!';
    }

    // Try displayName from user model
    if (user?.displayName?.isNotEmpty == true) {
      final nameParts = user!.displayName!.split(' ');
      if (nameParts.isNotEmpty) {
        return '${nameParts.first}!';
      }
    }

    // Firebase User doesn't have displayName getter anymore
    // UserModel should be the single source of truth for user data

    // Default fallback
    return 'Teacher!';
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select data to export:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.grade),
              title: const Text('Gradebook Data'),
              subtitle: const Text('Export all grades as CSV'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gradebook export will be available soon'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Student List'),
              subtitle: const Text('Export student roster as CSV'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student list export will be available soon'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Assignments'),
              subtitle: const Text('Export assignment details as CSV'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Assignment export will be available soon'),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
