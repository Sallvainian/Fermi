import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  // Hardcoded course data for demonstration
  final List<StudentCourse> _courses = [
    StudentCourse(
      id: '1',
      name: 'Advanced Mathematics',
      instructor: 'Dr. Sarah Johnson',
      room: 'Room 204',
      schedule: 'Mon, Wed, Fri - 9:00 AM',
      currentGrade: 'A-',
      gradePercentage: 87.5,
      nextAssignment: 'Calculus Quiz - Due Tomorrow',
      recentActivity: '3 new assignments posted',
      color: AppTheme.subjectColors[0], // Blue for Math
      status: CourseStatus.active,
      credits: 3,
      attendance: 95.0,
      upcomingEvents: [
        'Quiz on Friday',
        'Project due next week',
      ],
    ),
    StudentCourse(
      id: '2',
      name: 'Biology Lab',
      instructor: 'Ms. Emily Carter',
      room: 'Lab 105',
      schedule: 'Tue, Thu - 2:00 PM',
      currentGrade: 'B+',
      gradePercentage: 92.0,
      nextAssignment: 'Cell Division Report - Due Friday',
      recentActivity: 'Grade posted for last quiz',
      color: AppTheme.subjectColors[1], // Green for Science
      status: CourseStatus.active,
      credits: 4,
      attendance: 88.0,
      upcomingEvents: [
        'Lab experiment Thursday',
        'Report due Friday',
      ],
    ),
    StudentCourse(
      id: '3',
      name: 'Creative Writing',
      instructor: 'Mr. David Wilson',
      room: 'Room 108',
      schedule: 'Mon, Wed - 11:00 AM',
      currentGrade: 'A',
      gradePercentage: 95.0,
      nextAssignment: 'Poetry Assignment - Due Next Week',
      recentActivity: 'Feedback received on essay',
      color: AppTheme.subjectColors[2], // Orange for English
      status: CourseStatus.active,
      credits: 3,
      attendance: 92.0,
      upcomingEvents: [
        'Poetry reading Wednesday',
        'Assignment due next Monday',
      ],
    ),
    StudentCourse(
      id: '4',
      name: 'World History',
      instructor: 'Mrs. Lisa Rodriguez',
      room: 'Room 302',
      schedule: 'Daily - 1:00 PM',
      currentGrade: 'B',
      gradePercentage: 85.0,
      nextAssignment: 'Renaissance Essay - Due Monday',
      recentActivity: 'New study materials uploaded',
      color: AppTheme.subjectColors[3], // Purple for History
      status: CourseStatus.active,
      credits: 3,
      attendance: 90.0,
      upcomingEvents: [
        'Essay due Monday',
        'Test next Thursday',
      ],
    ),
    StudentCourse(
      id: '5',
      name: 'AP Physics',
      instructor: 'Dr. Michael Chang',
      room: 'Lab 203',
      schedule: 'Mon, Wed, Fri - 3:00 PM',
      currentGrade: 'A',
      gradePercentage: 94.0,
      nextAssignment: 'Quantum Mechanics Test - Next Friday',
      recentActivity: 'Lab results uploaded',
      color: AppTheme.subjectColors[1], // Green for Science
      status: CourseStatus.active,
      credits: 4,
      attendance: 96.0,
      upcomingEvents: [
        'Lab on Wednesday',
        'Test next Friday',
      ],
    ),
    StudentCourse(
      id: '6',
      name: 'Spanish II',
      instructor: 'Señora Martinez',
      room: 'Room 115',
      schedule: 'Tue, Thu - 10:00 AM',
      currentGrade: 'B-',
      gradePercentage: 82.0,
      nextAssignment: 'Conversation Practice - Due Thursday',
      recentActivity: 'Pronunciation exercise assigned',
      color: Colors.teal,
      status: CourseStatus.active,
      credits: 3,
      attendance: 85.0,
      upcomingEvents: [
        'Conversation practice Thursday',
        'Vocabulary quiz next week',
      ],
    ),
  ];

  List<StudentCourse> get _filteredCourses {
    List<StudentCourse> filtered = _courses;

    // Apply status filter
    if (_selectedFilter != 'All') {
      CourseStatus status = CourseStatus.values
          .firstWhere((s) => s.toString().split('.').last == _selectedFilter.toLowerCase());
      filtered = filtered.where((course) => course.status == status).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((course) {
        return course.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               course.instructor.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Back to Dashboard',
        ),
        title: const Text('My Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showScheduleView,
            tooltip: 'Schedule View',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with stats
          _buildStatsHeader(),
          
          // Search and filter bar
          _buildSearchAndFilterBar(),
          
          // Courses list
          Expanded(
            child: _filteredCourses.isEmpty
                ? _searchQuery.isNotEmpty
                    ? EmptyState.noSearchResults(searchTerm: _searchQuery)
                    : const EmptyState(
                        icon: Icons.school,
                        title: 'No Courses',
                        message: 'You are not enrolled in any courses yet.',
                      )
                : _buildCoursesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final totalCredits = _courses.fold<int>(0, (sum, course) => sum + course.credits);
    final avgGPA = _courses.fold<double>(0, (sum, course) => sum + course.gradePercentage) / _courses.length;
    final avgAttendance = _courses.fold<double>(0, (sum, course) => sum + course.attendance) / _courses.length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactStatCard(
              title: 'Courses',
              value: '${_courses.length}',
              subtitle: 'Enrolled',
              icon: Icons.school,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactStatCard(
              title: 'Credits',
              value: '$totalCredits',
              subtitle: 'This semester',
              icon: Icons.credit_score,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactStatCard(
              title: 'GPA',
              value: _getLetterGrade(avgGPA),
              subtitle: '${avgGPA.toStringAsFixed(1)}%',
              icon: Icons.grade,
              valueColor: AppTheme.getGradeColor(_getLetterGrade(avgGPA)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactStatCard(
              title: 'Attendance',
              value: '${avgAttendance.toStringAsFixed(0)}%',
              subtitle: 'Average',
              icon: Icons.check_circle,
              valueColor: _getAttendanceColor(avgAttendance),
            ),
          ),
        ],
      ),
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

  Widget _buildCoursesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredCourses.length,
      itemBuilder: (context, index) {
        final course = _filteredCourses[index];
        return _buildCourseCard(course);
      },
    );
  }

  Widget _buildCourseCard(StudentCourse course) {
    return AppCard(
      onTap: () => _showCourseDetails(course),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with course name and grade
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: course.color,
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      course.instructor,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge.grade(grade: course.currentGrade),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Course info
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              _buildInfoChip(Icons.room, course.room),
              _buildInfoChip(Icons.schedule, course.schedule),
              _buildInfoChip(Icons.credit_card, '${course.credits} credits'),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Grade progress bar
          Row(
            children: [
              Text(
                'Grade: ${course.gradePercentage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                'Attendance: ${course.attendance.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getAttendanceColor(course.attendance),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: course.gradePercentage / 100,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              AppTheme.getGradeColor(course.currentGrade),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Next assignment
          if (course.nextAssignment != null) ...{
            Row(
              children: [
                Icon(
                  Icons.assignment,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    course.nextAssignment!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          },
          
          // Recent activity
          if (course.recentActivity != null) ...{
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  course.recentActivity!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          },
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

  String _getLetterGrade(double percentage) {
    if (percentage >= 97) return 'A+';
    if (percentage >= 93) return 'A';
    if (percentage >= 90) return 'A-';
    if (percentage >= 87) return 'B+';
    if (percentage >= 83) return 'B';
    if (percentage >= 80) return 'B-';
    if (percentage >= 77) return 'C+';
    if (percentage >= 73) return 'C';
    if (percentage >= 70) return 'C-';
    if (percentage >= 67) return 'D+';
    if (percentage >= 63) return 'D';
    if (percentage >= 60) return 'D-';
    return 'F';
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 95) return Colors.green;
    if (percentage >= 90) return Colors.lightGreen;
    if (percentage >= 85) return Colors.orange;
    if (percentage >= 80) return Colors.deepOrange;
    return Colors.red;
  }

  void _showCourseDetails(StudentCourse course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CourseDetailSheet(course: course),
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
}

// Course detail modal sheet
class CourseDetailSheet extends StatelessWidget {
  final StudentCourse course;

  const CourseDetailSheet({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        color: course.color,
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
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            course.instructor,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge.grade(grade: course.currentGrade),
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
                        _buildDetailRow(context, 'Room', course.room),
                        _buildDetailRow(context, 'Schedule', course.schedule),
                        _buildDetailRow(context, 'Credits', '${course.credits}'),
                        _buildDetailRow(context, 'Status', course.status.toString().split('.').last),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildDetailSection(
                      context,
                      'Academic Progress',
                      [
                        _buildDetailRow(context, 'Current Grade', course.currentGrade),
                        _buildDetailRow(context, 'Percentage', '${course.gradePercentage.toStringAsFixed(1)}%'),
                        _buildDetailRow(context, 'Attendance', '${course.attendance.toStringAsFixed(1)}%'),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildDetailSection(
                      context,
                      'Upcoming Events',
                      course.upcomingEvents.map((event) => 
                        ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(event),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ).toList(),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Navigate to course grades
                        },
                        child: const Text('View Grades'),
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
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Data model for student course information
class StudentCourse {
  final String id;
  final String name;
  final String instructor;
  final String room;
  final String schedule;
  final String currentGrade;
  final double gradePercentage;
  final String? nextAssignment;
  final String? recentActivity;
  final Color color;
  final CourseStatus status;
  final int credits;
  final double attendance;
  final List<String> upcomingEvents;

  StudentCourse({
    required this.id,
    required this.name,
    required this.instructor,
    required this.room,
    required this.schedule,
    required this.currentGrade,
    required this.gradePercentage,
    this.nextAssignment,
    this.recentActivity,
    required this.color,
    required this.status,
    required this.credits,
    required this.attendance,
    required this.upcomingEvents,
  });
}

enum CourseStatus {
  active,
  completed,
  dropped,
}