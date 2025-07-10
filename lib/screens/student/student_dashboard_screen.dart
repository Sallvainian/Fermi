import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../models/user_model.dart';
import '../../models/class_model.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/common/common_widgets.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadStudentClasses();
  }

  void _loadStudentClasses() {
    final authProvider = context.read<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final studentId = authProvider.userModel?.uid;
    
    if (studentId != null) {
      classProvider.loadStudentClasses(studentId);
    }
  }

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
            context.go('/student/notifications');
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

  Widget _buildQuickStats(BuildContext context) {
    final classProvider = context.watch<ClassProvider>();
    final enrolledClasses = classProvider.studentClasses;
    
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCompactStatCard(
            context,
            icon: Icons.book,
            title: 'Courses',
            value: '${enrolledClasses.length}',
            color: Colors.blue,
            onTap: () => context.go('/student/courses'),
          ),
          const SizedBox(width: 12),
          _buildCompactStatCard(
            context,
            icon: Icons.assignment,
            title: 'Assignments',
            value: '12',
            color: Colors.orange,
            onTap: () => context.go('/student/assignments'),
          ),
          const SizedBox(width: 12),
          _buildCompactStatCard(
            context,
            icon: Icons.schedule,
            title: 'Due Soon',
            value: '3',
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          _buildCompactStatCard(
            context,
            icon: Icons.trending_up,
            title: 'GPA',
            value: '3.8',
            color: Colors.green,
            onTap: () => context.go('/student/grades'),
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
    
    final enrolledClasses = classProvider.studentClasses;
    
    if (enrolledClasses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.school_outlined,
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
                  'Join a class to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/student/enroll'),
                  child: const Text('Join a Class'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show max 4 classes on dashboard
    final displayClasses = enrolledClasses.take(4).toList();
    
    return Column(
      children: [
        ...displayClasses.map((course) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildClassCard(context, course),
        )),
        if (enrolledClasses.length > 4) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/student/courses'),
              child: Text('View All ${enrolledClasses.length} Classes'),
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
                    _buildInfoChip(Icons.school, course.gradeLevel),
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
    // Navigate to class detail or assignments
    context.go('/student/courses'); // You can change this to a specific class detail route
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
                onPressed: () => context.go('/student/assignments'),
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
                onPressed: () => context.go('/student/grades'),
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
    return 'Student!';
  }
}