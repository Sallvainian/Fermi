import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../domain/models/grade.dart';
import '../../providers/grade_provider_simple.dart';
import '../../../../assignments/presentation/providers/assignment_provider_simple.dart';
import '../../../../classes/presentation/providers/class_provider.dart';
import '../../../../classes/domain/models/class_model.dart';
import '../../../../student/domain/models/student.dart';
import '../../../../student/presentation/providers/student_provider_simple.dart';

class GradebookScreen extends StatefulWidget {
  const GradebookScreen({super.key});

  @override
  State<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends State<GradebookScreen> {
  String _searchQuery = '';
  String? _selectedClassId;
  List<Student> _students = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final classProvider = context.read<ClassProvider>();
    final gradeProvider = context.read<SimpleGradeProvider>();

    // Load classes and set default selection
    if (classProvider.teacherClasses.isNotEmpty) {
      final firstClass = classProvider.teacherClasses.first;
      setState(() {
        _selectedClassId = firstClass.id;
      });

      // Load grades for the selected class
      gradeProvider.loadClassGrades(firstClass.id);

      // TODO: Load students for the class
      // For now, we'll use class student IDs
      _loadStudentsForClass(firstClass);
    }
  }

  void _loadStudentsForClass(ClassModel classModel) async {
    // Load actual students from Firebase using SimpleStudentProvider
    final studentProvider = context.read<SimpleStudentProvider>();

    if (classModel.studentIds.isNotEmpty) {
      final students =
          await studentProvider.loadStudentsByIds(classModel.studentIds);
      setState(() {
        _students = students;
      });
    } else {
      setState(() {
        _students = [];
      });
    }
  }

  List<Student> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    return _students.where((student) {
      final fullName = '${student.firstName} ${student.lastName}';
      return fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (student.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final gradeProvider = context.watch<SimpleGradeProvider>();
    final assignmentProvider = context.watch<SimpleAssignmentProvider>();
    final classProvider = context.watch<ClassProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Back to Dashboard',
        ),
        title: const Text('Gradebook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _showExportDialog,
            tooltip: 'Export Grades',
          ),
        ],
      ),
      body: gradeProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildGradebookBody(
              context, gradeProvider, assignmentProvider, classProvider),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAssignmentDialog,
        child: const Icon(Icons.assignment_add),
      ),
    );
  }

  Widget _buildGradebookBody(BuildContext context, SimpleGradeProvider gradeProvider,
      SimpleAssignmentProvider assignmentProvider, ClassProvider classProvider) {
    if (classProvider.teacherClasses.isEmpty) {
      return const EmptyState(
        icon: Icons.class_outlined,
        title: 'No Classes Yet',
        message: 'Create a class to start managing grades',
      );
    }

    return Column(
      children: [
        // Statistics Header
        _buildStatsHeader(context, gradeProvider),

        // Class Selector and Search
        _buildControlsSection(context, classProvider),

        // Students List
        Expanded(
          child: _filteredStudents.isEmpty
              ? _searchQuery.isNotEmpty
                  ? EmptyState.noSearchResults(searchTerm: _searchQuery)
                  : const EmptyState(
                      icon: Icons.people_outline,
                      title: 'No Students',
                      message:
                          'Students will appear here when they join your class',
                    )
              : _buildStudentsList(context, gradeProvider, assignmentProvider),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(BuildContext context, SimpleGradeProvider gradeProvider) {
    final stats = gradeProvider.classStatistics;

    final classAverage = (stats['average'] as double?) ?? 0.0;
    // Calculate completion rate from grades
    final totalGrades = gradeProvider.classGrades.length;
    final completedGrades = gradeProvider.classGrades
        .where((g) =>
            g['status'] == 'graded' || g['status'] == 'returned')
        .length;
    final completionRate =
        totalGrades > 0 ? (completedGrades / totalGrades) * 100 : 0.0;
    final studentCount = _students.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactStatCard(
              title: 'Class Avg',
              value: '${classAverage.toStringAsFixed(1)}%',
              subtitle: _getLetterGrade(classAverage),
              icon: Icons.trending_up,
              valueColor: AppTheme.getGradeColor(_getLetterGrade(classAverage)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactStatCard(
              title: 'Completion',
              value: '${completionRate.toStringAsFixed(0)}%',
              subtitle:
                  '${gradeProvider.classGrades.where((g) => g['status'] == 'graded').length}/${gradeProvider.classGrades.length} done',
              icon: Icons.assignment_turned_in,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactStatCard(
              title: 'Students',
              value: '$studentCount',
              subtitle: 'Enrolled',
              icon: Icons.people,
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
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection(
      BuildContext context, ClassProvider classProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Class Selector
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedClassId,
                isExpanded: true,
                underline: const SizedBox(),
                items: classProvider.teacherClasses.map((cls) {
                  return DropdownMenuItem(
                    value: cls.id,
                    child: Text(cls.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClassId = value;
                  });
                  if (value != null) {
                    final selectedClass = classProvider.teacherClasses
                        .firstWhere((c) => c.id == value);
                    context.read<SimpleGradeProvider>().loadClassGrades(value);
                    _loadStudentsForClass(selectedClass);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Search Bar
          Expanded(
            flex: 3,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search students...',
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
        ],
      ),
    );
  }

  void _showStudentGradeDetail(Student student) {
    final gradeProvider = context.read<SimpleGradeProvider>();
    final assignmentProvider = context.read<SimpleAssignmentProvider>();

    // Load grades for this specific student
    gradeProvider.loadStudentClassGrades(student.id, _selectedClassId!);

    // Create a lookup map for quick grade access
    final Map<String, Map<String, dynamic>> gradeLookup = {};
    for (final grade in gradeProvider.studentGrades) {
      gradeLookup['${grade['assignmentId']}_${grade['studentId']}'] = grade;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StudentGradeDetailSheet(
        student: student,
        assignments: assignmentProvider.teacherAssignments
            .where((a) => a['classId'] == _selectedClassId)
            .toList(),
        onGradeUpdate: (assignmentId, newPoints, newStatus) {
          // Find the grade and update it
          final grade = gradeProvider.studentGrades
              .firstWhere((g) => g['assignmentId'] == assignmentId);
          gradeProvider.gradeSubmission(
            submissionId: grade['id'],
            points: newPoints ?? 0,
            maxPoints: 100,
            feedback: '',
          );
        },
      ),
    );
  }

  Widget _buildStudentsList(BuildContext context, SimpleGradeProvider gradeProvider,
      SimpleAssignmentProvider assignmentProvider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
        return _buildStudentCard(student, gradeProvider);
      },
    );
  }

  Widget _buildStudentCard(Student student, SimpleGradeProvider gradeProvider) {
    // Calculate student's overall grade
    final studentGrades = gradeProvider.classGrades
        .where((g) => g['studentId'] == student.id)
        .toList();

    final overallGrade = _calculateStudentOverallGrade(studentGrades);
    final completedAssignments =
        studentGrades.where((g) => g['status'] == 'graded').length;
    final totalAssignments = studentGrades.length;

    return AppCard(
      onTap: () => _showStudentGradeDetail(student),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  '${student.firstName[0]}${student.lastName[0]}'.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.firstName} ${student.lastName}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      student.email ?? student.username,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge.grade(grade: _getLetterGrade(overallGrade)),
                  const SizedBox(height: 4),
                  Text(
                    '${overallGrade.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Summary
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assignments Completed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: totalAssignments > 0
                                ? completedAssignments / totalAssignments
                                : 0.0,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$completedAssignments/$totalAssignments',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildQuickStatusChips(studentGrades),
            ],
          ),

          const SizedBox(height: 8),

          // Tap hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Tap to view detailed grades',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatusChips(List<Map<String, dynamic>> studentGrades) {
    final missingCount =
        studentGrades.where((g) => g['status'] == 'notSubmitted').length;
    final lateCount =
        studentGrades.where((g) => g['status'] == 'revised').length;

    return Row(
      children: [
        if (missingCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$missingCount Missing',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        if (lateCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$lateCount Late',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ],
    );
  }

  double _calculateStudentOverallGrade(List<Map<String, dynamic>> grades) {
    if (grades.isEmpty) return 0.0;

    double totalPoints = 0;
    double maxPoints = 0;

    for (final grade in grades) {
      if (grade['status'] == 'graded') {
        totalPoints += (grade['pointsEarned'] as num?)?.toDouble() ?? 0.0;
        maxPoints += (grade['pointsPossible'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return maxPoints > 0 ? (totalPoints / maxPoints) * 100 : 0.0;
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
    if (percentage >= 65) return 'D';
    if (percentage >= 60) return 'D-';
    return 'F';
  }

  void _showAddAssignmentDialog() {
    // Navigate to the assignment creation screen
    context.go('/teacher/assignments/create');
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Grades'),
        content:
            const Text('Export options would appear here (CSV, PDF, etc.).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature coming soon!')),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }
}

// Student Grade Detail Bottom Sheet
class StudentGradeDetailSheet extends StatelessWidget {
  final Student student;
  final List<Map<String, dynamic>> assignments;
  final Function(String assignmentId, double?, GradeStatus) onGradeUpdate;

  const StudentGradeDetailSheet({
    super.key,
    required this.student,
    required this.assignments,
    required this.onGradeUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final gradeProvider = context.watch<SimpleGradeProvider>();
    final studentGrades = gradeProvider.studentGrades;
    final overallGrade = _calculateStudentOverallGrade(studentGrades);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  '${student.firstName[0]}${student.lastName[0]}'.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.firstName} ${student.lastName}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      student.email ?? student.username,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Overall Grade Summary
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Grade',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StatusBadge.grade(
                              grade: _getLetterGrade(overallGrade)),
                          const SizedBox(width: 8),
                          Text(
                            '${overallGrade.toStringAsFixed(1)}%',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Completed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      '${studentGrades.where((g) => g['status'] == 'graded').length}/${assignments.length}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Assignment Breakdown',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 12),

          // Assignments List
          Expanded(
            child: ListView.builder(
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                final assignment = assignments[index];
                final Map<String, dynamic> grade = studentGrades.firstWhere(
                  (g) => g['assignmentId'] == assignment['id'],
                  orElse: () => {
                    'id': 'temp_${student.id}_${assignment['id']}',
                    'studentId': student.id,
                    'studentName': '${student.firstName} ${student.lastName}',
                    'assignmentId': assignment['id'],
                    'classId': assignment['classId'],
                    'teacherId': assignment['teacherId'],
                    'pointsPossible': (assignment['totalPoints'] as num?)?.toDouble() ?? 0.0,
                    'pointsEarned': 0.0,
                    'percentage': 0.0,
                    'status': 'pending',
                    'createdAt': DateTime.now(),
                    'updatedAt': DateTime.now(),
                  },
                );
                return _buildAssignmentGradeCard(context, assignment, grade);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentGradeCard(BuildContext context,
      Map<String, dynamic> assignment, Map<String, dynamic> grade) {
    final dueDate = assignment['dueDate'];
    final isOverdue = dueDate != null && 
        (dueDate is Timestamp ? dueDate.toDate() : dueDate as DateTime).isBefore(DateTime.now());

    Color statusColor;
    String statusText;
    String scoreText;

    final gradeStatus = grade['status'] ?? 'pending';
    switch (gradeStatus) {
      case 'graded':
      case 'returned':
        final pointsEarned = (grade['pointsEarned'] as num?)?.toDouble() ?? 0.0;
        final pointsPossible = (grade['pointsPossible'] as num?)?.toDouble() ?? 1.0;
        final percentage = (pointsEarned / pointsPossible) * 100;
        statusColor = AppTheme.getGradeColor(_getLetterGrade(percentage));
        statusText = _getLetterGrade(percentage);
        scoreText =
            '${pointsEarned.toInt()}/${pointsPossible.toInt()} (${percentage.toStringAsFixed(1)}%)';
        break;
      case 'notSubmitted':
        statusColor = Theme.of(context).colorScheme.error;
        statusText = 'Not Submitted';
        final pointsPossible = (grade['pointsPossible'] as num?)?.toInt() ?? 0;
        scoreText = '0/$pointsPossible (0%)';
        break;
      case 'revised':
        statusColor = AppTheme.warningColor;
        statusText = 'Revised';
        final pointsEarned = (grade['pointsEarned'] as num?)?.toDouble() ?? 0.0;
        final pointsPossible = (grade['pointsPossible'] as num?)?.toDouble() ?? 0.0;
        scoreText = pointsEarned > 0
            ? '${pointsEarned.toInt()}/${pointsPossible.toInt()}'
            : 'Not graded';
        break;
      case 'draft':
        statusColor = Theme.of(context).colorScheme.onSurfaceVariant;
        statusText = 'Draft';
        scoreText = '-';
        break;
      case 'pending':
      default:
        statusColor = Theme.of(context).colorScheme.onSurfaceVariant;
        statusText = 'Not Submitted';
        scoreText = '-';
        break;
    }

    return AppCard(
      onTap: () => _showGradeEntryDialog(context, assignment, grade),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assignment Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment['title'] ?? '',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusBadge.assignmentType(type: assignment['type'] ?? 'assignment'),
                        const SizedBox(width: 8),
                        Text(
                          'Due: ${(assignment['dueDate'] as DateTime?)?.month ?? ''}/${(assignment['dueDate'] as DateTime?)?.day ?? ''}/${(assignment['dueDate'] as DateTime?)?.year ?? ''}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isOverdue
                                        ? Theme.of(context).colorScheme.error
                                        : null,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(
                    label: statusText,
                    type: StatusType.custom,
                    customColor: statusColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scoreText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress Bar for graded assignments
          if (grade['status'] == 'graded' ||
              grade['status'] == 'returned') ...[
            LinearProgressIndicator(
              value: ((grade['pointsEarned'] as num?)?.toDouble() ?? 0.0) / ((grade['pointsPossible'] as num?)?.toDouble() ?? 1.0),
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 8),
          ],

          // Tap hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.edit,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Tap to edit grade',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGradeEntryDialog(BuildContext context,
      Map<String, dynamic> assignment, Map<String, dynamic> grade) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GradeEntrySheet(
          student: student,
          assignment: assignment,
          grade: grade,
          onSave: (newPoints, newStatus) {
            onGradeUpdate(assignment['id'], newPoints, newStatus);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  double _calculateStudentOverallGrade(List<Map<String, dynamic>> grades) {
    if (grades.isEmpty) return 0.0;

    double totalPoints = 0;
    double maxPoints = 0;

    for (final grade in grades) {
      if (grade['status'] == 'graded' ||
          grade['status'] == 'returned') {
        totalPoints += (grade['pointsEarned'] as num?)?.toDouble() ?? 0.0;
        maxPoints += (grade['pointsPossible'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return maxPoints > 0 ? (totalPoints / maxPoints) * 100 : 0.0;
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
    if (percentage >= 65) return 'D';
    if (percentage >= 60) return 'D-';
    return 'F';
  }
}

// Grade Entry Bottom Sheet
class GradeEntrySheet extends StatefulWidget {
  final Student student;
  final Map<String, dynamic> assignment;
  final Map<String, dynamic> grade;
  final Function(double?, GradeStatus) onSave;

  const GradeEntrySheet({
    super.key,
    required this.student,
    required this.assignment,
    required this.grade,
    required this.onSave,
  });

  @override
  State<GradeEntrySheet> createState() => _GradeEntrySheetState();
}

class _GradeEntrySheetState extends State<GradeEntrySheet> {
  late TextEditingController _pointsController;
  late GradeStatus _selectedStatus;

  GradeStatus _getGradeStatusFromString(String status) {
    switch (status) {
      case 'draft':
        return GradeStatus.draft;
      case 'graded':
        return GradeStatus.graded;
      case 'returned':
        return GradeStatus.returned;
      case 'revised':
        return GradeStatus.revised;
      case 'notSubmitted':
        return GradeStatus.notSubmitted;
      case 'pending':
      default:
        return GradeStatus.pending;
    }
  }

  @override
  void initState() {
    super.initState();
    _pointsController = TextEditingController(
      text: ((widget.grade['pointsEarned'] as num?)?.toDouble() ?? 0.0) > 0
          ? ((widget.grade['pointsEarned'] as num?)?.toDouble() ?? 0.0).toString()
          : '',
    );
    _selectedStatus = _getGradeStatusFromString(widget.grade['status'] ?? 'pending');
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = _pointsController.text.isNotEmpty
        ? (double.tryParse(_pointsController.text) ?? 0) /
            ((widget.assignment['totalPoints'] as num?)?.toDouble() ?? 1.0) *
            100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Grade Entry',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Student and Assignment Info
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.student.firstName} ${widget.student.lastName}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.assignment['title'] ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StatusBadge.assignmentType(
                        type: widget.assignment['type'] ?? 'assignment'),
                    const SizedBox(width: 8),
                    Text(
                      'Due: ${(widget.assignment['dueDate'] as DateTime?)?.month ?? ''}/${(widget.assignment['dueDate'] as DateTime?)?.day ?? ''}/${(widget.assignment['dueDate'] as DateTime?)?.year ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Points Entry
          TextField(
            controller: _pointsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Points Earned',
              hintText: 'Enter points (0-${widget.assignment['totalPoints'] ?? 0})',
              border: const OutlineInputBorder(),
              suffix: Text('/ ${widget.assignment['totalPoints'] ?? 0}'),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Grade Preview
          if (_pointsController.text.isNotEmpty) ...[
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.grade),
                  const SizedBox(width: 8),
                  Text('Grade: ${percentage.toStringAsFixed(1)}%'),
                  const SizedBox(width: 8),
                  StatusBadge.grade(grade: _getLetterGrade(percentage)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Status Selection
          Text(
            'Status',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: GradeStatus.values.map((status) {
              return ChoiceChip(
                label: Text(_getStatusLabel(status)),
                selected: _selectedStatus == status,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedStatus = status;
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSave() ? _saveGrade : null,
              child: const Text('Save Grade'),
            ),
          ),
        ],
      ),
    );
  }

  bool _canSave() {
    if (_selectedStatus == GradeStatus.graded) {
      final points = double.tryParse(_pointsController.text);
      return points != null &&
          points >= 0 &&
          points <= ((widget.assignment['totalPoints'] as num?)?.toDouble() ?? 0.0);
    }
    return true;
  }

  void _saveGrade() {
    final points = _selectedStatus == GradeStatus.graded
        ? double.tryParse(_pointsController.text)
        : null;

    widget.onSave(points, _selectedStatus);
  }

  String _getStatusLabel(GradeStatus status) {
    switch (status) {
      case GradeStatus.graded:
        return 'Graded';
      case GradeStatus.notSubmitted:
        return 'Not Submitted';
      case GradeStatus.revised:
        return 'Revised';
      case GradeStatus.pending:
        return 'Pending';
      case GradeStatus.returned:
        return 'Returned';
      case GradeStatus.draft:
        return 'Draft';
    }
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
    if (percentage >= 65) return 'D';
    if (percentage >= 60) return 'D-';
    return 'F';
  }
}
