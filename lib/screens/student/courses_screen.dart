import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../models/class_model.dart';
import '../../widgets/common/common_widgets.dart';
import '../../theme/app_theme.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';

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

  void _showSearchDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search functionality coming soon!'),
      ),
    );
  }

  void _showScheduleView() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Schedule view coming soon!'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: 'Search Courses',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showScheduleView,
            tooltip: 'Schedule View',
          ),
        ],
      ),
      body: Consumer<ClassProvider>(
        builder: (context, classProvider, child) {
          if (classProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (classProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${classProvider.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadStudentClasses,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final enrolledClasses = classProvider.studentClasses;
          
          if (enrolledClasses.isEmpty) {
            return Center(
              child: EmptyState(
                icon: Icons.school,
                title: 'No Classes Yet',
                message: 'You are not enrolled in any classes.',
                actionLabel: 'Join a Class',
                onAction: () => context.push('/student/enroll'),
              ),
            );
          }
          
          return Column(
            children: [
              // Header with stats
              _buildStatsHeaderFirebase(enrolledClasses),
              
              // Search and filter bar
              _buildSearchAndFilterBar(),
              
              // Courses list
              Expanded(
                child: _buildCoursesListFirebase(enrolledClasses),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsHeaderFirebase(List<ClassModel> classes) {
    final totalClasses = classes.length;
    final activeClasses = classes.where((c) => c.isActive).length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactStatCard(
              title: 'Courses',
              value: '$totalClasses',
              subtitle: 'Enrolled',
              icon: Icons.school,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactStatCard(
              title: 'Active',
              value: '$activeClasses',
              subtitle: 'This semester',
              icon: Icons.play_circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactStatCard(
              title: 'Teachers',
              value: '${classes.map((c) => c.teacherId).toSet().length}',
              subtitle: 'Instructors',
              icon: Icons.person,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesListFirebase(List<ClassModel> classes) {
    // Apply search filter
    List<ClassModel> filtered = classes;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((course) {
        return course.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               course.subject.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Apply status filter
    if (_selectedFilter != 'All') {
      if (_selectedFilter == 'Active') {
        filtered = filtered.where((c) => c.isActive).toList();
      } else if (_selectedFilter == 'Archived') {
        filtered = filtered.where((c) => !c.isActive).toList();
      }
    }
    
    if (filtered.isEmpty) {
      return _searchQuery.isNotEmpty
          ? EmptyState.noSearchResults(searchTerm: _searchQuery)
          : const EmptyState(
              icon: Icons.school,
              title: 'No Courses',
              message: 'No courses match your filter.',
            );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final course = filtered[index];
        return _buildCourseCardFirebase(course);
      },
    );
  }

  Widget _buildCourseCardFirebase(ClassModel course) {
    final theme = Theme.of(context);
    final colorIndex = course.subject.hashCode % AppTheme.subjectColors.length;
    final color = AppTheme.subjectColors[colorIndex];
    
    return AppCard(
      onTap: () => _showCourseDetailsFirebase(course),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with course name and status
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      course.subject,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!course.isActive)
                StatusBadge.custom(
                  label: 'Archived',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Course info
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              if (course.room != null)
                _buildInfoChip(Icons.room, course.room!),
              if (course.schedule != null)
                _buildInfoChip(Icons.schedule, course.schedule!),
              _buildInfoChip(Icons.school, 'Grade ${course.gradeLevel}'),
              _buildInfoChip(Icons.people, '${course.studentIds.length} students'),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Academic year and semester
          Row(
            children: [
              Icon(
                Icons.calendar_month,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${course.academicYear} - ${course.semester}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCourseDetailsFirebase(ClassModel course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CourseDetailSheetFirebase(course: course),
    );
  }

  Widget _buildCompactStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _selectedFilter,
            items: ['All', 'Active', 'Completed', 'Dropped']
                .map((filter) => DropdownMenuItem(
                      value: filter,
                      child: Text(filter),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedFilter = value ?? 'All';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// Firebase course detail modal sheet
class CourseDetailSheetFirebase extends StatelessWidget {
  final ClassModel course;

  const CourseDetailSheetFirebase({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorIndex = course.subject.hashCode % AppTheme.subjectColors.length;
    final color = AppTheme.subjectColors[colorIndex];
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            course.subject,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!course.isActive)
                      StatusBadge.custom(
                        label: 'Archived',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildDetailSection(
                      context,
                      'Course Information',
                      [
                        if (course.room != null)
                          _buildDetailRow(context, 'Room', course.room!),
                        if (course.schedule != null)
                          _buildDetailRow(context, 'Schedule', course.schedule!),
                        _buildDetailRow(context, 'Grade Level', course.gradeLevel),
                        _buildDetailRow(context, 'Academic Year', course.academicYear),
                        _buildDetailRow(context, 'Semester', course.semester),
                        _buildDetailRow(context, 'Students Enrolled', '${course.studentIds.length}${course.maxStudents != null ? ' / ${course.maxStudents}' : ''}'),
                      ],
                    ),
                    
                    if (course.description != null) ...[
                      const SizedBox(height: 24),
                      _buildDetailSection(
                        context,
                        'Description',
                        [
                          Text(
                            course.description!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    _buildDetailSection(
                      context,
                      'Quick Actions',
                      [
                        ListTile(
                          leading: const Icon(Icons.assignment),
                          title: const Text('View Assignments'),
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: Navigate to assignments
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.grade),
                          title: const Text('View Grades'),
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: Navigate to grades
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.chat),
                          title: const Text('Class Discussion'),
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: Navigate to discussion
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}