import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/common_widgets.dart';
import '../../theme/app_theme.dart';

class StudentGradesScreen extends StatefulWidget {
  const StudentGradesScreen({super.key});

  @override
  State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
  String _searchQuery = '';
  String _selectedCourseId = 'all';
  String _selectedFilter = 'All';

  // Hardcoded grades data for demonstration
  final List<StudentGradeEntry> _grades = [
    // Advanced Mathematics
    StudentGradeEntry(
      id: '1',
      courseId: '1',
      courseName: 'Advanced Mathematics',
      assignmentName: 'Calculus Quiz 3',
      assignmentType: AssignmentType.quiz,
      points: 45.0,
      maxPoints: 50.0,
      percentage: 90.0,
      letterGrade: 'A-',
      submittedDate: DateTime.now().subtract(const Duration(days: 2)),
      gradedDate: DateTime.now().subtract(const Duration(days: 1)),
      feedback: 'Excellent work on derivatives! Pay attention to chain rule applications.',
      status: GradeStatus.graded,
      courseColor: AppTheme.subjectColors[0],
    ),
    StudentGradeEntry(
      id: '2',
      courseId: '1',
      courseName: 'Advanced Mathematics',
      assignmentName: 'Quadratic Equations Homework',
      assignmentType: AssignmentType.homework,
      points: 18.0,
      maxPoints: 20.0,
      percentage: 90.0,
      letterGrade: 'A-',
      submittedDate: DateTime.now().subtract(const Duration(days: 7)),
      gradedDate: DateTime.now().subtract(const Duration(days: 6)),
      feedback: 'Good understanding of quadratic formulas.',
      status: GradeStatus.graded,
      courseColor: AppTheme.subjectColors[0],
    ),
    StudentGradeEntry(
      id: '3',
      courseId: '1',
      courseName: 'Advanced Mathematics',
      assignmentName: 'Midterm Exam',
      assignmentType: AssignmentType.test,
      points: 87.0,
      maxPoints: 100.0,
      percentage: 87.0,
      letterGrade: 'B+',
      submittedDate: DateTime.now().subtract(const Duration(days: 14)),
      gradedDate: DateTime.now().subtract(const Duration(days: 12)),
      feedback: 'Strong performance overall. Review trigonometric identities for next exam.',
      status: GradeStatus.graded,
      courseColor: AppTheme.subjectColors[0],
    ),
    
    // Biology Lab
    StudentGradeEntry(
      id: '4',
      courseId: '2',
      courseName: 'Biology Lab',
      assignmentName: 'Cell Division Lab Report',
      assignmentType: AssignmentType.project,
      points: 92.0,
      maxPoints: 100.0,
      percentage: 92.0,
      letterGrade: 'A-',
      submittedDate: DateTime.now().subtract(const Duration(days: 3)),
      gradedDate: DateTime.now().subtract(const Duration(days: 1)),
      feedback: 'Excellent observations and analysis. Clear methodology and conclusions.',
      status: GradeStatus.graded,
      courseColor: AppTheme.subjectColors[1],
    ),
    StudentGradeEntry(
      id: '5',
      courseId: '2',
      courseName: 'Biology Lab',
      assignmentName: 'Mitosis Quiz',
      assignmentType: AssignmentType.quiz,
      points: 42.0,
      maxPoints: 50.0,
      percentage: 84.0,
      letterGrade: 'B',
      submittedDate: DateTime.now().subtract(const Duration(days: 10)),
      gradedDate: DateTime.now().subtract(const Duration(days: 9)),
      feedback: 'Good understanding of mitosis phases.',
      status: GradeStatus.graded,
      courseColor: AppTheme.subjectColors[1],
    ),
    
    // Creative Writing
    StudentGradeEntry(
      id: '6',
      courseId: '3',
      courseName: 'Creative Writing',
      assignmentName: 'Character Analysis Essay',
      assignmentType: AssignmentType.project,
      points: 95.0,
      maxPoints: 100.0,
      percentage: 95.0,
      letterGrade: 'A',
      submittedDate: DateTime.now().subtract(const Duration(days: 5)),
      gradedDate: DateTime.now().subtract(const Duration(days: 3)),
      feedback: 'Outstanding analysis with excellent supporting evidence. Great writing style!',
      status: GradeStatus.graded,
      courseColor: AppTheme.subjectColors[2],
    ),
    StudentGradeEntry(
      id: '7',
      courseId: '3',
      courseName: 'Creative Writing',
      assignmentName: 'Poetry Collection',
      assignmentType: AssignmentType.project,
      points: null,
      maxPoints: 50.0,
      percentage: null,
      letterGrade: null,
      submittedDate: DateTime.now().subtract(const Duration(days: 1)),
      gradedDate: null,
      feedback: null,
      status: GradeStatus.submitted,
      courseColor: AppTheme.subjectColors[2],
    ),
    
    // World History
    StudentGradeEntry(
      id: '8',
      courseId: '4',
      courseName: 'World History',
      assignmentName: 'Renaissance Research Paper',
      assignmentType: AssignmentType.project,
      points: 88.0,
      maxPoints: 100.0,
      percentage: 88.0,
      letterGrade: 'B+',
      submittedDate: DateTime.now().subtract(const Duration(days: 8)),
      gradedDate: DateTime.now().subtract(const Duration(days: 6)),
      feedback: 'Well-researched paper with good historical context. Improve citation format.',
      status: GradeStatus.graded,
      courseColor: AppTheme.subjectColors[3],
    ),
    StudentGradeEntry(
      id: '9',
      courseId: '4',
      courseName: 'World History',
      assignmentName: 'Medieval Quiz',
      assignmentType: AssignmentType.quiz,
      points: 38.0,
      maxPoints: 40.0,
      percentage: 95.0,
      letterGrade: 'A',
      submittedDate: DateTime.now().subtract(const Duration(days: 15)),
      gradedDate: DateTime.now().subtract(const Duration(days: 14)),
      feedback: 'Excellent knowledge of medieval period.',
      status: GradeStatus.graded,
      courseColor: AppTheme.subjectColors[3],
    ),
    
    // AP Physics
    StudentGradeEntry(
      id: '10',
      courseId: '5',
      courseName: 'AP Physics',
      assignmentName: 'Mechanics Problem Set',
      assignmentType: AssignmentType.homework,
      points: null,
      maxPoints: 25.0,
      percentage: null,
      letterGrade: null,
      submittedDate: null,
      gradedDate: null,
      feedback: null,
      status: GradeStatus.missing,
      courseColor: AppTheme.subjectColors[1],
    ),
    StudentGradeEntry(
      id: '11',
      courseId: '5',
      courseName: 'AP Physics',
      assignmentName: 'Lab Report: Projectile Motion',
      assignmentType: AssignmentType.project,
      points: 96.0,
      maxPoints: 100.0,
      percentage: 96.0,
      letterGrade: 'A',
      submittedDate: DateTime.now().subtract(const Duration(days: 12)),
      gradedDate: DateTime.now().subtract(const Duration(days: 10)),
      feedback: 'Excellent experimental design and data analysis. Clear conclusions.',
      status: GradeStatus.graded,
      courseColor: AppTheme.subjectColors[1],
    ),
  ];

  final List<CourseOption> _courses = [
    CourseOption(id: 'all', name: 'All Courses'),
    CourseOption(id: '1', name: 'Advanced Mathematics'),
    CourseOption(id: '2', name: 'Biology Lab'),
    CourseOption(id: '3', name: 'Creative Writing'),
    CourseOption(id: '4', name: 'World History'),
    CourseOption(id: '5', name: 'AP Physics'),
  ];

  List<StudentGradeEntry> get _filteredGrades {
    List<StudentGradeEntry> filtered = _grades;

    // Apply course filter
    if (_selectedCourseId != 'all') {
      filtered = filtered.where((grade) => grade.courseId == _selectedCourseId).toList();
    }

    // Apply status filter
    if (_selectedFilter != 'All') {
      GradeStatus status = GradeStatus.values
          .firstWhere((s) => s.toString().split('.').last == _selectedFilter.toLowerCase());
      filtered = filtered.where((grade) => grade.status == status).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((grade) {
        return grade.assignmentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               grade.courseName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Sort by most recent first
    filtered.sort((a, b) {
      final aDate = a.gradedDate ?? a.submittedDate ?? DateTime(1900);
      final bDate = b.gradedDate ?? b.submittedDate ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });

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
        title: const Text('My Grades'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showGradeAnalytics,
            tooltip: 'Grade Analytics',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with stats
          _buildStatsHeader(),
          
          // Filters
          _buildFiltersSection(),
          
          // Grades list
          Expanded(
            child: _filteredGrades.isEmpty
                ? _searchQuery.isNotEmpty
                    ? EmptyState.noSearchResults(searchTerm: _searchQuery)
                    : const EmptyState(
                        icon: Icons.grade,
                        title: 'No Grades',
                        message: 'No grades found for the selected filters.',
                      )
                : _buildGradesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final gradedEntries = _grades.where((g) => g.status == GradeStatus.graded).toList();
    final totalPoints = gradedEntries.fold<double>(0, (sum, grade) => sum + (grade.points ?? 0));
    final totalMaxPoints = gradedEntries.fold<double>(0, (sum, grade) => sum + grade.maxPoints);
    final overallPercentage = totalMaxPoints > 0 ? (totalPoints / totalMaxPoints) * 100 : 0;
    
    final submittedCount = _grades.where((g) => g.status == GradeStatus.submitted).length;
    final missingCount = _grades.where((g) => g.status == GradeStatus.missing).length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactStatCard(
              title: 'Overall',
              value: _getLetterGrade(overallPercentage.toDouble()),
              subtitle: '${overallPercentage.toStringAsFixed(1)}%',
              icon: Icons.grade,
              valueColor: AppTheme.getGradeColor(_getLetterGrade(overallPercentage.toDouble())),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactStatCard(
              title: 'Graded',
              value: '${gradedEntries.length}',
              subtitle: 'Assignments',
              icon: Icons.check_circle,
              valueColor: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactStatCard(
              title: 'Pending',
              value: '$submittedCount',
              subtitle: 'Submitted',
              icon: Icons.pending,
              valueColor: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactStatCard(
              title: 'Missing',
              value: '$missingCount',
              subtitle: 'Not done',
              icon: Icons.warning,
              valueColor: Colors.red,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                size: 16,
                color: valueColor ?? Theme.of(context).colorScheme.primary,
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
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

  Widget _buildFiltersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search assignments...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          
          // Filter dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCourseId,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    border: OutlineInputBorder(),
                  ),
                  items: _courses
                      .map((course) => DropdownMenuItem(
                            value: course.id,
                            child: Text(course.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCourseId = value ?? 'all';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: ['All', 'Graded', 'Submitted', 'Missing']
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredGrades.length,
      itemBuilder: (context, index) {
        final grade = _filteredGrades[index];
        return _buildGradeCard(grade);
      },
    );
  }

  Widget _buildGradeCard(StudentGradeEntry grade) {
    return AppCard(
      onTap: () => _showGradeDetails(grade),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with assignment name and grade
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: grade.courseColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grade.assignmentName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      grade.courseName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (grade.letterGrade != null)
                StatusBadge.grade(grade: grade.letterGrade!)
              else
                _buildStatusChip(grade.status),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Grade info
          Row(
            children: [
              _buildInfoChip(Icons.category, _getAssignmentTypeLabel(grade.assignmentType)),
              const SizedBox(width: 8),
              if (grade.points != null)
                _buildInfoChip(Icons.score, '${grade.points!.toStringAsFixed(0)}/${grade.maxPoints.toStringAsFixed(0)}'),
              if (grade.percentage != null) ...[
                const SizedBox(width: 8),
                _buildInfoChip(Icons.percent, '${grade.percentage!.toStringAsFixed(1)}%'),
              ],
            ],
          ),
          
          if (grade.status == GradeStatus.graded && grade.percentage != null) ...[
            const SizedBox(height: 12),
            
            // Grade progress bar
            LinearProgressIndicator(
              value: grade.percentage! / 100,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                AppTheme.getGradeColor(grade.letterGrade ?? 'F'),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Date information
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _getDateText(grade),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          
          // Feedback preview
          if (grade.feedback != null && grade.feedback!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.feedback,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    grade.feedback!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildStatusChip(GradeStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case GradeStatus.graded:
        color = Colors.green;
        label = 'Graded';
        break;
      case GradeStatus.submitted:
        color = Colors.orange;
        label = 'Submitted';
        break;
      case GradeStatus.missing:
        color = Colors.red;
        label = 'Missing';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getAssignmentTypeLabel(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return 'Homework';
      case AssignmentType.quiz:
        return 'Quiz';
      case AssignmentType.test:
        return 'Test';
      case AssignmentType.project:
        return 'Project';
      case AssignmentType.exam:
        return 'Exam';
    }
  }

  String _getDateText(StudentGradeEntry grade) {
    if (grade.gradedDate != null) {
      final days = DateTime.now().difference(grade.gradedDate!).inDays;
      if (days == 0) return 'Graded today';
      if (days == 1) return 'Graded yesterday';
      return 'Graded $days days ago';
    } else if (grade.submittedDate != null) {
      final days = DateTime.now().difference(grade.submittedDate!).inDays;
      if (days == 0) return 'Submitted today';
      if (days == 1) return 'Submitted yesterday';
      return 'Submitted $days days ago';
    } else {
      return 'Not submitted';
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
    if (percentage >= 63) return 'D';
    if (percentage >= 60) return 'D-';
    return 'F';
  }

  void _showGradeDetails(StudentGradeEntry grade) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => GradeDetailSheet(grade: grade),
    );
  }

  void _showGradeAnalytics() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Grade analytics coming soon!'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }
}

// Grade detail modal sheet
class GradeDetailSheet extends StatelessWidget {
  final StudentGradeEntry grade;

  const GradeDetailSheet({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
                        color: grade.courseColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            grade.assignmentName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            grade.courseName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (grade.letterGrade != null)
                      StatusBadge.grade(grade: grade.letterGrade!)
                    else
                      StatusBadge.custom(
                        label: grade.status.toString().split('.').last,
                        color: _getStatusColor(grade.status),
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
                    if (grade.status == GradeStatus.graded) ...[
                      _buildDetailSection(
                        context,
                        'Grade Information',
                        [
                          if (grade.points != null)
                            _buildDetailRow(context, 'Points', '${grade.points!.toStringAsFixed(0)}/${grade.maxPoints.toStringAsFixed(0)}'),
                          if (grade.percentage != null)
                            _buildDetailRow(context, 'Percentage', '${grade.percentage!.toStringAsFixed(1)}%'),
                          if (grade.letterGrade != null)
                            _buildDetailRow(context, 'Letter Grade', grade.letterGrade!),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    _buildDetailSection(
                      context,
                      'Assignment Details',
                      [
                        _buildDetailRow(context, 'Type', _getAssignmentTypeLabel(grade.assignmentType)),
                        _buildDetailRow(context, 'Max Points', grade.maxPoints.toStringAsFixed(0)),
                        _buildDetailRow(context, 'Status', grade.status.toString().split('.').last),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildDetailSection(
                      context,
                      'Timeline',
                      [
                        if (grade.submittedDate != null)
                          _buildDetailRow(context, 'Submitted', _formatDate(grade.submittedDate!)),
                        if (grade.gradedDate != null)
                          _buildDetailRow(context, 'Graded', _formatDate(grade.gradedDate!)),
                      ],
                    ),
                    
                    if (grade.feedback != null && grade.feedback!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      
                      _buildDetailSection(
                        context,
                        'Teacher Feedback',
                        [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              grade.feedback!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
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

  String _getAssignmentTypeLabel(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return 'Homework';
      case AssignmentType.quiz:
        return 'Quiz';
      case AssignmentType.test:
        return 'Test';
      case AssignmentType.project:
        return 'Project';
      case AssignmentType.exam:
        return 'Exam';
    }
  }

  Color _getStatusColor(GradeStatus status) {
    switch (status) {
      case GradeStatus.graded:
        return Colors.green;
      case GradeStatus.submitted:
        return Colors.orange;
      case GradeStatus.missing:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    
    if (diff == 0) {
      return 'Today';
    } else if (diff == 1) {
      return 'Yesterday';
    } else if (diff < 7) {
      return '$diff days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Data models
class StudentGradeEntry {
  final String id;
  final String courseId;
  final String courseName;
  final String assignmentName;
  final AssignmentType assignmentType;
  final double? points;
  final double maxPoints;
  final double? percentage;
  final String? letterGrade;
  final DateTime? submittedDate;
  final DateTime? gradedDate;
  final String? feedback;
  final GradeStatus status;
  final Color courseColor;

  StudentGradeEntry({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.assignmentName,
    required this.assignmentType,
    this.points,
    required this.maxPoints,
    this.percentage,
    this.letterGrade,
    this.submittedDate,
    this.gradedDate,
    this.feedback,
    required this.status,
    required this.courseColor,
  });
}

class CourseOption {
  final String id;
  final String name;

  CourseOption({required this.id, required this.name});
}

enum AssignmentType {
  homework,
  quiz,
  test,
  project,
  exam,
}

enum GradeStatus {
  graded,
  submitted,
  missing,
}