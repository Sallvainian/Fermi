import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../domain/models/grade.dart';
import '../../providers/grade_provider_simple.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../assignments/presentation/providers/assignment_provider_simple.dart';
import '../../../../assignments/domain/models/assignment.dart';
import '../../../../classes/presentation/providers/class_provider.dart';
import '../../../../classes/domain/models/class_model.dart';

class StudentGradesScreen extends StatefulWidget {
  const StudentGradesScreen({super.key});

  @override
  State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
  String _searchQuery = '';
  String _selectedCourseId = 'all';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGrades();
    });
  }

  void _loadGrades() {
    final authProvider = context.read<AuthProvider>();
    final gradeProvider = context.read<SimpleGradeProvider>();
    final classProvider = context.read<ClassProvider>();
    final assignmentProvider = context.read<SimpleAssignmentProvider>();

    final studentId = authProvider.userModel?.uid;
    if (studentId != null) {
      // Load student's grades
      gradeProvider.loadStudentGrades(studentId);

      // Load classes for course names
      classProvider.loadStudentClasses(studentId);

      // Load assignments for each class the student is in
      for (final classId in authProvider.userModel?.enrolledClassIds ?? []) {
        assignmentProvider.loadAssignmentsForClass(classId);
      }
    }
  }

  // Helper method to get all assignments for a student's classes
  List<Map<String, dynamic>> _getAllStudentAssignments(
    List<ClassModel> classes,
    SimpleAssignmentProvider provider,
  ) {
    // Filter assignments to only those belonging to student's classes
    final classIds = classes.map((c) => c.id).toSet();
    return provider.assignments
        .where((assignment) => classIds.contains(assignment['classId']))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradeProvider = context.watch<SimpleGradeProvider>();
    final classProvider = context.watch<ClassProvider>();
    final assignmentProvider = context.watch<SimpleAssignmentProvider>();
    final grades = gradeProvider.studentGrades;
    final classes = classProvider.studentClasses;

    // Filter grades based on search and filters
    final allAssignments = _getAllStudentAssignments(
      classes,
      assignmentProvider,
    );
    final filteredGrades = _filterGrades(grades, classes, allAssignments);

    // Group grades by course
    final courseGroups = _groupGradesByCourse(filteredGrades, classes);

    // Calculate statistics
    final stats = _calculateStatistics(filteredGrades);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Grades'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: gradeProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : grades.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                // Statistics Summary
                _buildStatsHeader(context, stats),

                // Search and Filters
                _buildSearchAndFilters(context, classes),

                // Grades List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: courseGroups.length,
                    itemBuilder: (context, index) {
                      final courseId = courseGroups.keys.elementAt(index);
                      final courseGrades = courseGroups[courseId]!;
                      final course = classes.firstWhere(
                        (c) => c.id == courseId,
                        orElse: () => ClassModel(
                          id: courseId,
                          name: 'Unknown Course',
                          teacherId: '',
                          subject: '',
                          gradeLevel: '',
                          studentIds: [],
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          academicYear: DateTime.now().year.toString(),
                          semester: 'Fall',
                          isActive: true,
                        ),
                      );

                      return _buildCourseSection(
                        context,
                        course,
                        courseGrades,
                        allAssignments,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.grade_outlined,
            size: 80,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 128),
          ),
          const SizedBox(height: 16),
          Text(
            'No Grades Yet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your grades will appear here once your\nteacher grades your assignments',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, Map<String, dynamic> stats) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 26),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 51),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            'Overall GPA',
            stats['gpa'].toStringAsFixed(2),
            Icons.school,
            _getGPAColor(stats['gpa']),
          ),
          _buildStatItem(
            context,
            'Avg Score',
            '${stats['average'].toStringAsFixed(1)}%',
            Icons.analytics,
            _getGradeColor(stats['average']),
          ),
          _buildStatItem(
            context,
            'Completed',
            '${stats['completed']}/${stats['total']}',
            Icons.check_circle,
            Colors.green,
          ),
          _buildStatItem(
            context,
            'Pending',
            '${stats['pending']}',
            Icons.schedule,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context,
    List<ClassModel> classes,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search assignments...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              fillColor: theme.colorScheme.surfaceContainerHighest,
              filled: true,
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Course Filter
                _buildFilterChip(
                  context,
                  'All Courses',
                  _selectedCourseId == 'all',
                  () {
                    setState(() {
                      _selectedCourseId = 'all';
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...classes.map(
                  (course) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      context,
                      course.name,
                      _selectedCourseId == course.id,
                      () {
                        setState(() {
                          _selectedCourseId = course.id;
                        });
                      },
                    ),
                  ),
                ),

                // Status Filter
                const SizedBox(width: 16),
                _buildFilterChip(context, 'All', _selectedFilter == 'All', () {
                  setState(() {
                    _selectedFilter = 'All';
                  });
                }),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  'Graded',
                  _selectedFilter == 'Graded',
                  () {
                    setState(() {
                      _selectedFilter = 'Graded';
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  'Pending',
                  _selectedFilter == 'Pending',
                  () {
                    setState(() {
                      _selectedFilter = 'Pending';
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.primary.withValues(alpha: 51),
      checkmarkColor: theme.colorScheme.primary,
    );
  }

  Widget _buildCourseSection(
    BuildContext context,
    ClassModel course,
    List<Map<String, dynamic>> grades,
    List<Map<String, dynamic>> assignments,
  ) {
    final theme = Theme.of(context);
    final colorIndex = course.subject.hashCode % AppTheme.subjectColors.length;
    final courseColor = AppTheme.subjectColors[colorIndex];

    // Calculate course average
    final gradedGrades = grades
        .where((g) => g['status'] == 'graded' || g['status'] == 'returned')
        .toList();
    final courseAverage = gradedGrades.isEmpty
        ? 0.0
        : gradedGrades.fold<double>(
                0,
                (sum, g) => sum + (g['percentage'] as double),
              ) /
              gradedGrades.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Course Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: courseColor.withValues(alpha: 26),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: courseColor,
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        course.subject,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      courseAverage > 0
                          ? '${courseAverage.toStringAsFixed(1)}%'
                          : 'N/A',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getGradeColor(courseAverage),
                      ),
                    ),
                    Text(
                      courseAverage > 0 ? _getLetterGrade(courseAverage) : '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _getGradeColor(courseAverage),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Grades List
          ...grades.map((grade) {
            final assignment = assignments.firstWhere(
              (a) => a['id'] == grade['assignmentId'],
              orElse: () => {
                'id': grade['assignmentId'],
                'title': 'Unknown Assignment',
                'description': '',
                'type': 'homework',
                'classId': grade['classId'],
                'teacherId': grade['teacherId'],
                'totalPoints': grade['pointsPossible'],
                'maxPoints': grade['pointsPossible'],
                'dueDate': DateTime.now(),
                'createdAt': DateTime.now(),
                'updatedAt': DateTime.now(),
                'instructions': '',
                'category': 'Other',
                'teacherName': '',
                'isPublished': true,
                'allowLateSubmissions': false,
                'latePenaltyPercentage': 0,
                'status': 'active',
              },
            );

            return _buildGradeItem(context, grade, assignment, courseColor);
          }),
        ],
      ),
    );
  }

  Widget _buildGradeItem(
    BuildContext context,
    Map<String, dynamic> grade,
    Map<String, dynamic> assignment,
    Color courseColor,
  ) {
    final theme = Theme.of(context);
    final isGraded =
        grade['status'] == 'graded' || grade['status'] == 'returned';

    return InkWell(
      onTap: () => _showGradeDetails(context, grade, assignment),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 128),
            ),
          ),
        ),
        child: Row(
          children: [
            // Assignment Type Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getAssignmentTypeColor(
                  assignment['type'],
                ).withValues(alpha: 26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getAssignmentTypeIcon(assignment['type']),
                color: _getAssignmentTypeColor(assignment['type']),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Assignment Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment['title'],
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _getAssignmentTypeName(assignment['type']),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• Due ${_formatDate(assignment['dueDate'])}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Grade Display
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isGraded) ...[
                  Text(
                    '${(grade['pointsEarned'] as double).toStringAsFixed(1)}/${(grade['pointsPossible'] as double).toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(grade['percentage'] as double).toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getGradeColor(grade['percentage'] as double),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        grade['letterGrade'] ??
                            _getLetterGrade(grade['percentage'] as double),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getGradeColor(grade['percentage'] as double),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        grade['status'],
                      ).withValues(alpha: 26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(grade['status']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(grade['status']),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGradeDetails(
    BuildContext context,
    Map<String, dynamic> grade,
    Map<String, dynamic> assignment,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _GradeDetailsSheet(grade: grade, assignment: assignment),
    );
  }

  List<Map<String, dynamic>> _filterGrades(
    List<Map<String, dynamic>> grades,
    List<ClassModel> classes,
    List<Map<String, dynamic>> assignments,
  ) {
    return grades.where((grade) {
      // Course filter
      if (_selectedCourseId != 'all' && grade['classId'] != _selectedCourseId) {
        return false;
      }

      // Status filter
      if (_selectedFilter == 'Graded' &&
          grade['status'] != 'graded' &&
          grade['status'] != 'returned') {
        return false;
      }
      if (_selectedFilter == 'Pending' &&
          grade['status'] != 'pending' &&
          grade['status'] != 'draft') {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final assignment = assignments.firstWhere(
          (a) => a['id'] == grade['assignmentId'],
          orElse: () => {
            'id': '',
            'title': '',
            'description': '',
            'type': 'homework',
            'classId': '',
            'teacherId': '',
            'totalPoints': 0,
            'maxPoints': 0,
            'dueDate': DateTime.now(),
            'createdAt': DateTime.now(),
            'updatedAt': DateTime.now(),
            'instructions': '',
            'category': 'Other',
            'teacherName': '',
            'isPublished': true,
            'allowLateSubmissions': false,
            'latePenaltyPercentage': 0,
            'status': 'active',
          },
        );

        return (assignment['title'] ?? '').toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
      }

      return true;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupGradesByCourse(
    List<Map<String, dynamic>> grades,
    List<ClassModel> classes,
  ) {
    final Map<String, List<Map<String, dynamic>>> groups = {};

    for (final grade in grades) {
      if (!groups.containsKey(grade['classId'])) {
        groups[grade['classId']] = [];
      }
      groups[grade['classId']]!.add(grade);
    }

    // Sort grades within each group by date
    for (final grades in groups.values) {
      grades.sort(
        (a, b) =>
            (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime),
      );
    }

    return groups;
  }

  Map<String, dynamic> _calculateStatistics(List<Map<String, dynamic>> grades) {
    final gradedGrades = grades
        .where((g) => g['status'] == 'graded' || g['status'] == 'returned')
        .toList();

    final pendingGrades = grades
        .where((g) => g['status'] == 'pending' || g['status'] == 'draft')
        .toList();

    final average = gradedGrades.isEmpty
        ? 0.0
        : gradedGrades.fold<double>(
                0,
                (sum, g) => sum + (g['percentage'] as double),
              ) /
              gradedGrades.length;

    final gpa = _calculateGPA(average);

    return {
      'average': average,
      'gpa': gpa,
      'total': grades.length,
      'completed': gradedGrades.length,
      'pending': pendingGrades.length,
    };
  }

  double _calculateGPA(double percentage) {
    if (percentage >= 93) return 4.0;
    if (percentage >= 90) return 3.7;
    if (percentage >= 87) return 3.3;
    if (percentage >= 83) return 3.0;
    if (percentage >= 80) return 2.7;
    if (percentage >= 77) return 2.3;
    if (percentage >= 73) return 2.0;
    if (percentage >= 70) return 1.7;
    if (percentage >= 67) return 1.3;
    if (percentage >= 65) return 1.0;
    return 0.0;
  }

  String _getLetterGrade(double percentage) {
    if (percentage >= 93) return 'A';
    if (percentage >= 90) return 'A-';
    if (percentage >= 87) return 'B+';
    if (percentage >= 83) return 'B';
    if (percentage >= 80) return 'B-';
    if (percentage >= 77) return 'C+';
    if (percentage >= 73) return 'C';
    if (percentage >= 70) return 'C-';
    if (percentage >= 67) return 'D+';
    if (percentage >= 65) return 'D';
    return 'F';
  }

  Color _getGradeColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 80) return Colors.blue;
    if (percentage >= 70) return Colors.orange;
    if (percentage >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  Color _getGPAColor(double gpa) {
    if (gpa >= 3.5) return Colors.green;
    if (gpa >= 3.0) return Colors.blue;
    if (gpa >= 2.5) return Colors.orange;
    if (gpa >= 2.0) return Colors.deepOrange;
    return Colors.red;
  }

  IconData _getAssignmentTypeIcon(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return Icons.home_work;
      case AssignmentType.quiz:
        return Icons.quiz;
      case AssignmentType.test:
        return Icons.assignment;
      case AssignmentType.projectsLabs:
        return Icons.science;
      case AssignmentType.classworkActivities:
        return Icons.school;
    }
  }

  Color _getAssignmentTypeColor(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return Colors.blue;
      case AssignmentType.quiz:
        return Colors.purple;
      case AssignmentType.test:
        return Colors.red;
      case AssignmentType.projectsLabs:
        return Colors.green;
      case AssignmentType.classworkActivities:
        return Colors.teal;
    }
  }

  String _getAssignmentTypeName(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return 'Homework';
      case AssignmentType.quiz:
        return 'Quiz';
      case AssignmentType.test:
        return 'Test';
      case AssignmentType.projectsLabs:
        return 'Projects/Labs';
      case AssignmentType.classworkActivities:
        return 'Classwork/Activities';
    }
  }

  Color _getStatusColor(GradeStatus status) {
    switch (status) {
      case GradeStatus.graded:
      case GradeStatus.returned:
        return Colors.green;
      case GradeStatus.pending:
        return Colors.orange;
      case GradeStatus.draft:
        return Colors.blue;
      case GradeStatus.revised:
        return Colors.purple;
      case GradeStatus.notSubmitted:
        return Colors.red;
    }
  }

  String _getStatusText(GradeStatus status) {
    switch (status) {
      case GradeStatus.graded:
        return 'Graded';
      case GradeStatus.returned:
        return 'Returned';
      case GradeStatus.pending:
        return 'Pending';
      case GradeStatus.draft:
        return 'Draft';
      case GradeStatus.revised:
        return 'Revised';
      case GradeStatus.notSubmitted:
        return 'Not Submitted';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays == -1) {
      return 'Yesterday';
    } else if (difference.inDays > 0 && difference.inDays < 7) {
      return 'in ${difference.inDays} days';
    } else if (difference.inDays < 0 && difference.inDays > -7) {
      return '${-difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

// Grade Details Bottom Sheet
class _GradeDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> grade;
  final Map<String, dynamic> assignment;

  const _GradeDetailsSheet({required this.grade, required this.assignment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGraded =
        grade['status'] == 'graded' || grade['status'] == 'returned';

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 77),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Assignment Title
                  Text(
                    assignment['title'],
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Assignment Type and Due Date
                  Row(
                    children: [
                      StatusBadge.assignmentType(type: assignment['type']),
                      const SizedBox(width: 8),
                      Text(
                        'Due ${_formatDate(assignment['dueDate'])}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Grade Information
                  if (isGraded) ...[
                    Card(
                      color: theme.colorScheme.primary.withValues(alpha: 26),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your Score',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(grade['pointsEarned'] as double).toStringAsFixed(1)} / ${(grade['pointsPossible'] as double).toStringAsFixed(0)}',
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Grade',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${(grade['percentage'] as double).toStringAsFixed(1)}%',
                                          style: theme.textTheme.headlineMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: _getGradeColor(
                                                  grade['percentage'] as double,
                                                ),
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          grade['letterGrade'] ??
                                              _getLetterGrade(
                                                grade['percentage'] as double,
                                              ),
                                          style: theme.textTheme.headlineMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: _getGradeColor(
                                                  grade['percentage'] as double,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (grade['gradedAt'] != null) ...[
                              const SizedBox(height: 16),
                              Divider(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Graded on',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '${(grade['gradedAt'] as DateTime).month}/${(grade['gradedAt'] as DateTime).day}/${(grade['gradedAt'] as DateTime).year}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Teacher Feedback
                    if (grade['feedback'] != null &&
                        grade['feedback']!.isNotEmpty) ...[
                      Text(
                        'Teacher Feedback',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            grade['feedback']!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ] else ...[
                    // Pending Status
                    Card(
                      color: _getStatusColor(
                        grade['status'],
                      ).withValues(alpha: 26),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(grade['status']),
                              color: _getStatusColor(grade['status']),
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getStatusText(grade['status']),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(
                                            grade['status'],
                                          ),
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getStatusDescription(grade['status']),
                                    style: theme.textTheme.bodySmall?.copyWith(
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
                    const SizedBox(height: 16),
                  ],

                  // Assignment Description
                  if (assignment['description'].isNotEmpty) ...[
                    Text(
                      'Assignment Description',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      assignment['description'],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Rubric Scores (if available)
                  if (grade['rubricScores'] != null &&
                      grade['rubricScores']!.isNotEmpty) ...[
                    Text(
                      'Rubric Scores',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children:
                              (grade['rubricScores']! as Map<String, dynamic>)
                                  .entries
                                  .map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(entry.key),
                                          Text(
                                            entry.value.toString(),
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })
                                  .toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Close Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 80) return Colors.blue;
    if (percentage >= 70) return Colors.orange;
    if (percentage >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  String _getLetterGrade(double percentage) {
    if (percentage >= 93) return 'A';
    if (percentage >= 90) return 'A-';
    if (percentage >= 87) return 'B+';
    if (percentage >= 83) return 'B';
    if (percentage >= 80) return 'B-';
    if (percentage >= 77) return 'C+';
    if (percentage >= 73) return 'C';
    if (percentage >= 70) return 'C-';
    if (percentage >= 67) return 'D+';
    if (percentage >= 65) return 'D';
    return 'F';
  }

  Color _getStatusColor(GradeStatus status) {
    switch (status) {
      case GradeStatus.graded:
      case GradeStatus.returned:
        return Colors.green;
      case GradeStatus.pending:
        return Colors.orange;
      case GradeStatus.draft:
        return Colors.blue;
      case GradeStatus.revised:
        return Colors.purple;
      case GradeStatus.notSubmitted:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(GradeStatus status) {
    switch (status) {
      case GradeStatus.graded:
      case GradeStatus.returned:
        return Icons.check_circle;
      case GradeStatus.pending:
        return Icons.schedule;
      case GradeStatus.draft:
        return Icons.edit;
      case GradeStatus.revised:
        return Icons.refresh;
      case GradeStatus.notSubmitted:
        return Icons.warning;
    }
  }

  String _getStatusText(GradeStatus status) {
    switch (status) {
      case GradeStatus.graded:
        return 'Graded';
      case GradeStatus.returned:
        return 'Returned';
      case GradeStatus.pending:
        return 'Pending Review';
      case GradeStatus.draft:
        return 'Draft';
      case GradeStatus.revised:
        return 'Revised';
      case GradeStatus.notSubmitted:
        return 'Not Submitted';
    }
  }

  String _getStatusDescription(GradeStatus status) {
    switch (status) {
      case GradeStatus.pending:
        return 'Your submission is awaiting teacher review';
      case GradeStatus.draft:
        return 'Assignment is in draft status';
      case GradeStatus.revised:
        return 'Grade has been revised after initial grading';
      case GradeStatus.notSubmitted:
        return 'You have not submitted this assignment';
      default:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays == -1) {
      return 'Yesterday';
    } else if (difference.inDays > 0 && difference.inDays < 7) {
      return 'in ${difference.inDays} days';
    } else if (difference.inDays < 0 && difference.inDays > -7) {
      return '${-difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
