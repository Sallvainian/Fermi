import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../theme/app_spacing.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Student Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            // TODO: Navigate to notifications
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
                                : 'S',
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
                                'Welcome, ${user?.displayName ?? 'Student'}!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Grade ${user?.gradeLevel ?? 'N/A'} • Ready to learn today?',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Academic Overview
              Text(
                  'Academic Overview',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              _buildAcademicOverviewGrid(context),
              const SizedBox(height: AppSpacing.lg),

              // Upcoming Assignments
              Text(
                  'Upcoming Assignments',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              _buildUpcomingAssignmentsCard(context),
              const SizedBox(height: AppSpacing.lg),

              // Recent Grades
              Text(
                  'Recent Grades',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              _buildRecentGradesCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicOverviewGrid(BuildContext context) {
    return ResponsiveGrid(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mobileColumns: 2,
      tabletColumns: 4,
      desktopColumns: 4,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      childAspectRatio: 1.5,
      children: [
        _buildOverviewCard(
          context,
          icon: Icons.book,
          title: 'Courses',
          value: '6',
          color: Colors.blue,
        ),
        _buildOverviewCard(
          context,
          icon: Icons.assignment,
          title: 'Assignments',
          value: '12',
          color: Colors.orange,
        ),
        _buildOverviewCard(
          context,
          icon: Icons.schedule,
          title: 'Due Soon',
          value: '3',
          color: Colors.red,
        ),
        _buildOverviewCard(
          context,
          icon: Icons.trending_up,
          title: 'GPA',
          value: '3.8',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAssignmentsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAssignmentItem(
              context,
              subject: 'Mathematics',
              title: 'Algebra Problem Set 5',
              dueDate: 'Due Tomorrow',
              priority: 'High',
              color: Colors.red,
            ),
            const Divider(),
            _buildAssignmentItem(
              context,
              subject: 'Science',
              title: 'Lab Report: Chemical Reactions',
              dueDate: 'Due in 3 days',
              priority: 'Medium',
              color: Colors.orange,
            ),
            const Divider(),
            _buildAssignmentItem(
              context,
              subject: 'English',
              title: 'Book Report: To Kill a Mockingbird',
              dueDate: 'Due in 1 week',
              priority: 'Low',
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: Navigate to all assignments
                },
                child: const Text('View All Assignments'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentItem(
    BuildContext context, {
    required String subject,
    required String title,
    required String dueDate,
    required String priority,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(
          Icons.assignment,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text('$subject • $dueDate'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          priority,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildRecentGradesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildGradeItem(
              context,
              subject: 'Mathematics',
              assignment: 'Quiz 4: Quadratic Equations',
              grade: 'A-',
              points: '87/100',
              color: Colors.green,
            ),
            const Divider(),
            _buildGradeItem(
              context,
              subject: 'Science',
              assignment: 'Midterm Exam',
              grade: 'B+',
              points: '92/100',
              color: Colors.blue,
            ),
            const Divider(),
            _buildGradeItem(
              context,
              subject: 'English',
              assignment: 'Essay: Character Analysis',
              grade: 'A',
              points: '95/100',
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: Navigate to all grades
                },
                child: const Text('View All Grades'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeItem(
    BuildContext context, {
    required String subject,
    required String assignment,
    required String grade,
    required String points,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Text(
          grade,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        assignment,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text('$subject • $points'),
      contentPadding: EdgeInsets.zero,
    );
  }
}