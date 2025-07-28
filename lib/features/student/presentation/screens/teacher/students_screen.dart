import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/models/student.dart';
import '../../../data/services/student_service.dart';
import '../../../../../features/classes/domain/models/class_model.dart';
import '../../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../../shared/widgets/common/responsive_layout.dart';
import '../../../../../shared/widgets/preview/preview_example_wrapper.dart';
import '../../../../../shared/widgets/common/preview_button.dart';
import '../../widgets/preview_dialog.dart';
import '../../../../../shared/example/example_repository.dart';

class TeacherStudentsScreen extends StatefulWidget {
  final bool isPreviewMode;
  
  const TeacherStudentsScreen({
    super.key,
    this.isPreviewMode = false,
  });

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _studentService = StudentService();
  String _selectedFilter = 'All';
  String _selectedGrade = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Students',
      showBackButton: true,
      actions: [
        IconButton(
          onPressed: () => showPreviewDialog(context),
          icon: const Icon(Icons.preview),
          tooltip: 'Preview Full Features',
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(
            onPressed: () => showPreviewDialog(context),
            icon: const Icon(Icons.play_circle_outline, size: 20),
            label: const Text('Demo'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddStudentSheet(context);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
      body: Column(
        children: [
          // TabBar
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: 'All Students'),
                Tab(text: 'Classes'),
                Tab(text: 'Performance'),
                Tab(text: 'Reports'),
              ],
            ),
          ),
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Search Field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search students...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                // Grade Filter
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: PopupMenuButton<String>(
                    initialValue: _selectedGrade,
                    onSelected: (value) {
                      setState(() {
                        _selectedGrade = value;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'All', child: Text('All Grades')),
                      const PopupMenuItem(value: '9', child: Text('Grade 9')),
                      const PopupMenuItem(value: '10', child: Text('Grade 10')),
                      const PopupMenuItem(value: '11', child: Text('Grade 11')),
                      const PopupMenuItem(value: '12', child: Text('Grade 12')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.grade, size: 20),
                          const SizedBox(width: 8),
                          Text(_selectedGrade == 'All'
                              ? 'Grade'
                              : 'G$_selectedGrade'),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Status Filter
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: PopupMenuButton<String>(
                    initialValue: _selectedFilter,
                    onSelected: (value) {
                      setState(() {
                        _selectedFilter = value;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'All', child: Text('All Students')),
                      const PopupMenuItem(
                          value: 'Active', child: Text('Active')),
                      const PopupMenuItem(
                          value: 'Inactive', child: Text('Inactive')),
                      const PopupMenuItem(
                          value: 'Recent', child: Text('Recently Added')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list, size: 20),
                          const SizedBox(width: 8),
                          Text(_selectedFilter),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Students List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllStudents(),
                _buildClassesView(),
                _buildPerformanceView(),
                _buildReportsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllStudents() {
    // Get example students from repository
    final exampleStudents =
        ExampleRepository.of<Student>(ExampleDomain.students);

    // In preview mode, show a rich set of mock data
    // Otherwise, show empty state (simulating no real data)
    final List<Student> realStudents = widget.isPreviewMode 
        ? _generatePreviewStudents() 
        : []; // In real app, this would come from a provider or service

    return PreviewExampleWrapper<Student>(
      realData: realStudents,
      exampleData: exampleStudents,
      isLoading: false, // Set to true if loading from service
      builder: (context, students, isExample) {
        final filteredStudents = _filterStudents(students);

        if (filteredStudents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  isExample
                      ? 'No example students available'
                      : 'No students found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  isExample
                      ? 'Example data could not be loaded'
                      : 'Try adjusting your filters or add your first student',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _showAddStudentSheet(context),
                  child: Text(
                      isExample ? 'Add Real Student' : 'Add First Student'),
                ),
              ],
            ),
          );
        }

        return ResponsiveContainer(
          child: ListView.builder(
            itemCount: filteredStudents.length,
            itemBuilder: (context, index) {
              final student = filteredStudents[index];
              return _buildStudentCard(student, isExample: isExample);
            },
          ),
        );
      },
      onExampleTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.info_outline),
            title: const Text('Example Students'),
            content: const Text(
              'These are example students to show you how the app works. '
              'Add your own students to replace these examples.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showAddStudentSheet(context);
                },
                child: const Text('Add Student'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassesView() {
    final theme = Theme.of(context);

    // Get example classes from repository
    final exampleClasses =
        ExampleRepository.of<ClassModel>(ExampleDomain.classes);

    // In preview mode, show a rich set of mock data
    // Otherwise, show empty state (simulating no real data)
    final List<ClassModel> realClasses = widget.isPreviewMode 
        ? _generatePreviewClasses() 
        : []; // In real app, this would come from a provider or service

    return PreviewExampleWrapper<ClassModel>(
      realData: realClasses,
      exampleData: exampleClasses,
      isLoading: false, // Set to true if loading from service
      builder: (context, classes, isExample) {
        if (classes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.class_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  isExample
                      ? 'No example classes available'
                      : 'No classes found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  isExample
                      ? 'Example data could not be loaded'
                      : 'Create your first class to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to classes screen where users can create classes
                    context.go('/teacher/classes');
                  },
                  child: Text(
                      isExample ? 'Create Real Class' : 'Create First Class'),
                ),
              ],
            ),
          );
        }

        return ResponsiveContainer(
          child: Column(
            children: [
              // Class Statistics
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Total Classes',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (isExample) ...[
                                    const SizedBox(width: 8),
                                    PreviewButton(
                                      isCompact: true,
                                      onPressed: () => showPreviewDialog(context),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${classes.length}',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Total Students',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (isExample) ...[
                                    const SizedBox(width: 8),
                                    PreviewButton(
                                      isCompact: true,
                                      onPressed: () => showPreviewDialog(context),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${classes.fold(0, (sum, c) => sum + c.studentIds.length)}',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Classes List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: classes.length,
                  itemBuilder: (context, index) {
                    final classModel = classes[index];
                    return _buildClassCard(classModel, isExample: isExample);
                  },
                ),
              ),
            ],
          ),
        );
      },
      onExampleTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.info_outline),
            title: const Text('Example Classes'),
            content: const Text(
              'These are example classes to show you how the app works. '
              'Create your own classes to replace these examples.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate to classes screen where users can create classes
                  context.go('/teacher/classes');
                },
                child: const Text('Create Class'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassCard(ClassModel classModel, {bool isExample = false}) {
    final theme = Theme.of(context);

    // Define colors for different subjects
    final subjectColors = {
      'Mathematics': Colors.blue,
      'Science': Colors.green,
      'Physics': Colors.purple,
      'Chemistry': Colors.orange,
      'English': Colors.red,
      'History': Colors.brown,
    };

    final subjectColor = subjectColors[classModel.subject] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isExample
            ? () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    icon: const Icon(Icons.info_outline),
                    title: const Text('Example Class'),
                    content: Text(
                      'This is example class "${classModel.name}" to show you how the app works. '
                      'Create your own classes to replace these examples.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Got it'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Navigate to classes screen where users can create classes
                          context.go('/teacher/classes');
                        },
                        child: const Text('Create Class'),
                      ),
                    ],
                  ),
                );
              }
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening ${classModel.name}'),
                  ),
                );
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Class Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: subjectColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.class_,
                  color: subjectColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Class Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            classModel.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isExample) PreviewButton(
                          isCompact: true,
                          onPressed: () => showPreviewDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${classModel.subject} • ${classModel.gradeLevel}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${classModel.studentIds.length} students',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          classModel.room ?? 'No room',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classModel.schedule ?? 'No schedule',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceView() {
    final theme = Theme.of(context);

    // Mock performance data
    final performanceData = [
      {
        'grade': 'Grade 9',
        'avgGPA': 3.2,
        'students': 45,
        'topPerformers': 12,
        'needsSupport': 8,
        'attendance': 92,
      },
      {
        'grade': 'Grade 10',
        'avgGPA': 3.4,
        'students': 52,
        'topPerformers': 18,
        'needsSupport': 5,
        'attendance': 94,
      },
      {
        'grade': 'Grade 11',
        'avgGPA': 3.5,
        'students': 48,
        'topPerformers': 20,
        'needsSupport': 4,
        'attendance': 95,
      },
      {
        'grade': 'Grade 12',
        'avgGPA': 3.6,
        'students': 40,
        'topPerformers': 22,
        'needsSupport': 3,
        'attendance': 96,
      },
    ];

    return ResponsiveContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Statistics
            Text(
              'Overall Performance',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.school,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '3.43',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            'Avg GPA',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 32,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '94.25%',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'Attendance',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Grade-wise Performance
            Text(
              'Performance by Grade',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...performanceData.map((data) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['grade'] as String,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getGPAColor(data['avgGPA'] as double)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'GPA: ${data['avgGPA']}',
                              style: TextStyle(
                                color: _getGPAColor(data['avgGPA'] as double),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPerformanceMetric(
                              'Students',
                              '${data['students']}',
                              Icons.people,
                              theme.colorScheme.primary,
                            ),
                          ),
                          Expanded(
                            child: _buildPerformanceMetric(
                              'Top Performers',
                              '${data['topPerformers']}',
                              Icons.star,
                              Colors.amber,
                            ),
                          ),
                          Expanded(
                            child: _buildPerformanceMetric(
                              'Need Support',
                              '${data['needsSupport']}',
                              Icons.support,
                              Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _buildPerformanceMetric(
                              'Attendance',
                              '${data['attendance']}%',
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            // Top Performers
            Text(
              'Top Performers',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._buildTopPerformers(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTopPerformers(ThemeData theme) {
    final topPerformers = [
      {'name': 'Sarah Johnson', 'grade': 12, 'gpa': 4.0, 'rank': 1},
      {'name': 'Michael Chen', 'grade': 11, 'gpa': 3.98, 'rank': 2},
      {'name': 'Emma Williams', 'grade': 12, 'gpa': 3.95, 'rank': 3},
      {'name': 'David Kumar', 'grade': 10, 'gpa': 3.92, 'rank': 4},
      {'name': 'Jessica Martinez', 'grade': 11, 'gpa': 3.90, 'rank': 5},
    ];

    return topPerformers.map((student) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              '${student['rank']}',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(student['name'] as String),
          subtitle: Text('Grade ${student['grade']} • GPA: ${student['gpa']}'),
          trailing: const Icon(
            Icons.star,
            color: Colors.amber,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildReportsView() {
    final theme = Theme.of(context);

    // Mock report data
    final reports = [
      {
        'title': 'Monthly Progress Report',
        'type': 'Progress',
        'date': DateTime.now().subtract(const Duration(days: 2)),
        'status': 'Completed',
        'icon': Icons.trending_up,
        'color': Colors.green,
      },
      {
        'title': 'Attendance Summary',
        'type': 'Attendance',
        'date': DateTime.now().subtract(const Duration(days: 5)),
        'status': 'Completed',
        'icon': Icons.event_available,
        'color': Colors.blue,
      },
      {
        'title': 'Grade Distribution Analysis',
        'type': 'Academic',
        'date': DateTime.now().subtract(const Duration(days: 7)),
        'status': 'Completed',
        'icon': Icons.bar_chart,
        'color': Colors.purple,
      },
      {
        'title': 'Student Performance Report',
        'type': 'Performance',
        'date': DateTime.now().subtract(const Duration(days: 10)),
        'status': 'Completed',
        'icon': Icons.assessment,
        'color': Colors.orange,
      },
      {
        'title': 'Parent Communication Log',
        'type': 'Communication',
        'date': DateTime.now().subtract(const Duration(days: 15)),
        'status': 'Completed',
        'icon': Icons.message,
        'color': Colors.teal,
      },
    ];

    return ResponsiveContainer(
      child: Column(
        children: [
          // Report Actions
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _showGenerateReportDialog(context);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Generate Report'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opening report templates...'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Templates'),
                  ),
                ),
              ],
            ),
          ),
          // Recent Reports
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Reports',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          // Reports List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      _showReportDetails(context, report);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Report Icon
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: (report['color'] as Color)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              report['icon'] as IconData,
                              color: report['color'] as Color,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Report Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report['title'] as String,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        report['type'] as String,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(report['date'] as DateTime),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Actions
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'download':
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Downloading ${report['title']}...'),
                                    ),
                                  );
                                  break;
                                case 'share':
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Sharing ${report['title']}...'),
                                    ),
                                  );
                                  break;
                                case 'delete':
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Deleting ${report['title']}...'),
                                    ),
                                  );
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'download',
                                child: Row(
                                  children: [
                                    Icon(Icons.download, size: 20),
                                    SizedBox(width: 8),
                                    Text('Download'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share, size: 20),
                                    SizedBox(width: 8),
                                    Text('Share'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete,
                                        size: 20, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            child: const Icon(Icons.more_vert),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showGenerateReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.trending_up),
              title: const Text('Progress Report'),
              subtitle: const Text('Student progress over time'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generating progress report...'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Attendance Report'),
              subtitle: const Text('Attendance patterns and trends'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generating attendance report...'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.assessment),
              title: const Text('Performance Report'),
              subtitle: const Text('Academic performance analysis'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generating performance report...'),
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

  void _showReportDetails(BuildContext context, Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (report['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      report['icon'] as IconData,
                      color: report['color'] as Color,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report['title'] as String,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          'Generated on ${_formatDate(report['date'] as DateTime)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This is a mock report summary. In a real application, this would contain detailed analytics and insights based on actual student data.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Downloading report...'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Download'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sharing report...'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Student> _filterStudents(List<Student> students) {
    var filtered = students;

    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((student) {
        return student.displayName.toLowerCase().contains(query) ||
            student.email.toLowerCase().contains(query) ||
            student.firstName.toLowerCase().contains(query) ||
            student.lastName.toLowerCase().contains(query);
      }).toList();
    }

    // Filter by grade
    if (_selectedGrade != 'All') {
      final gradeLevel = int.parse(_selectedGrade);
      filtered = filtered
          .where((student) => student.gradeLevel == gradeLevel)
          .toList();
    }

    // Filter by status
    if (_selectedFilter != 'All') {
      switch (_selectedFilter) {
        case 'Active':
          filtered = filtered.where((student) => student.isActive).toList();
          break;
        case 'Inactive':
          filtered = filtered.where((student) => !student.isActive).toList();
          break;
        case 'Recent':
          final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
          filtered = filtered
              .where((student) => student.createdAt.isAfter(sevenDaysAgo))
              .toList();
          break;
      }
    }

    return filtered;
  }

  // Generate preview data for demonstration
  List<Student> _generatePreviewStudents() {
    final now = DateTime.now();
    final firstNames = ['Sarah', 'Mike', 'Emma', 'Alex', 'Lily', 'James', 'Sophia', 'Daniel', 'Olivia', 'Ryan', 
                       'Noah', 'Ava', 'Ethan', 'Isabella', 'Mason', 'Mia', 'Lucas', 'Charlotte', 'Oliver', 'Amelia'];
    final lastNames = ['Johnson', 'Chen', 'Davis', 'Martinez', 'Wilson', 'Brown', 'Taylor', 'Anderson', 'Thomas', 'Garcia',
                      'Rodriguez', 'Lee', 'Walker', 'Hall', 'Allen', 'Young', 'King', 'Wright', 'Lopez', 'Hill'];
    
    return List.generate(30, (index) {
      final firstName = firstNames[index % firstNames.length];
      final lastName = lastNames[(index + 3) % lastNames.length];
      final gradeLevel = 9 + (index % 4);
      
      return Student(
        id: 'preview_student_$index',
        userId: 'preview_user_$index',
        firstName: firstName,
        lastName: lastName,
        displayName: '$firstName $lastName',
        email: '${firstName.toLowerCase()}.${lastName.toLowerCase()}@school.edu',
        gradeLevel: gradeLevel,
        parentEmail: 'parent.${lastName.toLowerCase()}@email.com',
        classIds: List.generate(3 + (index % 3), (i) => 'preview_class_${(index + i) % 8}'),
        createdAt: now.subtract(Duration(days: 180 - index)),
        updatedAt: now.subtract(Duration(hours: index * 2)),
        isActive: index % 10 != 9, // 90% active
        metadata: {
          'overallGrade': 70 + (index % 30).toDouble(),
          'attendanceRate': 0.85 + (index % 15) * 0.01,
          'lastActive': now.subtract(Duration(hours: index)).toIso8601String(),
          'status': index % 10 == 9 ? 'Inactive' : 'Active',
        },
      );
    });
  }

  List<ClassModel> _generatePreviewClasses() {
    final now = DateTime.now();
    final subjects = ['Mathematics', 'Science', 'English', 'History', 'Physics', 'Chemistry', 'Biology', 'Geography',
                     'Art', 'Music', 'Physical Education', 'Computer Science'];
    final rooms = ['201', '102', '305', '415', 'Lab A', 'Lab B', 'Studio 1', 'Room 12', 'Gym', 'Music Room', 'Art Studio', 'Computer Lab'];
    
    return List.generate(12, (index) {
      final subject = subjects[index % subjects.length];
      final studentCount = 18 + (index * 2) % 12;
      
      return ClassModel(
        id: 'preview_class_$index',
        teacherId: 'teacher_1',
        name: _getPreviewClassName(subject, index),
        subject: subject,
        description: 'A comprehensive course covering fundamental and advanced topics in $subject',
        gradeLevel: '${9 + (index % 4)}',
        room: rooms[index % rooms.length],
        schedule: _getPreviewSchedule(index),
        studentIds: List.generate(studentCount, (i) => 'preview_student_$i'),
        createdAt: now.subtract(const Duration(days: 90)),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Spring',
        maxStudents: studentCount + 8,
        enrollmentCode: '${subject.substring(0, 3).toUpperCase()}-${100 + index}',
      );
    });
  }

  String _getPreviewClassName(String subject, int index) {
    switch (subject) {
      case 'Mathematics':
        return ['Algebra II', 'Geometry', 'Pre-Calculus', 'Statistics'][index % 4];
      case 'Science':
        return ['Biology', 'Chemistry', 'Physics', 'Environmental Science'][index % 4];
      case 'English':
        return ['Literature', 'Composition', 'Creative Writing', 'World Literature'][index % 4];
      case 'History':
        return ['World History', 'US History', 'European History', 'Ancient Civilizations'][index % 4];
      default:
        return '$subject ${['Intro', 'Advanced', 'Honors', 'AP'][index % 4]}';
    }
  }

  String _getPreviewSchedule(int index) {
    final schedules = [
      'Mon, Wed, Fri • 8:00 AM',
      'Tue, Thu • 9:30 AM',
      'Daily • 11:00 AM',
      'Mon, Wed, Fri • 1:00 PM',
      'Tue, Thu • 2:30 PM',
      'Mon, Tue, Thu • 10:00 AM',
    ];
    return schedules[index % schedules.length];
  }

  Widget _buildStudentCard(Student student, {bool isExample = false}) {
    final theme = Theme.of(context);
    final isActive = student.isActive;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: isExample
            ? () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    icon: const Icon(Icons.info_outline),
                    title: const Text('Example Student'),
                    content: Text(
                      'This is example student "${student.displayName}" to show you how the app works. '
                      'Add your own students to replace these examples.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Got it'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showAddStudentSheet(context);
                        },
                        child: const Text('Add Student'),
                      ),
                    ],
                  ),
                );
              }
            : () => _showStudentDetails(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Student Avatar
              CircleAvatar(
                backgroundColor: isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                child: student.photoURL != null
                    ? ClipOval(
                        child: Image.network(
                          student.photoURL!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.school,
                            color: isActive
                                ? theme.colorScheme.primary
                                : Colors.grey,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.school,
                        color:
                            isActive ? theme.colorScheme.primary : Colors.grey,
                      ),
              ),
              const SizedBox(width: 12),
              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and Grade
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isActive ? null : Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Grade ${student.gradeLevel}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Email
                    Text(
                      student.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Classes count and status
                    Row(
                      children: [
                        Icon(
                          Icons.class_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${student.classCount} classes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'Active' : 'Inactive',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Actions or Preview Button
              if (isExample)
                PreviewButton(
                  isCompact: true,
                  onPressed: () => showPreviewDialog(context),
                )
              else
                PopupMenuButton<String>(
                  onSelected: (value) => _handleStudentAction(value, student),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'view', child: Text('View Details')),
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit Student')),
                    const PopupMenuItem(
                        value: 'message', child: Text('Send Message')),
                    const PopupMenuItem(
                        value: 'parent', child: Text('Contact Parent')),
                    PopupMenuItem(
                      value: isActive ? 'deactivate' : 'activate',
                      child: Text(isActive ? 'Deactivate' : 'Activate'),
                    ),
                  ],
                  child: const Icon(Icons.more_vert),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGPAColor(double gpa) {
    if (gpa >= 3.5) return Colors.green;
    if (gpa >= 3.0) return Colors.blue;
    if (gpa >= 2.5) return Colors.orange;
    return Colors.red;
  }

  void _showStudentDetails(Student student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentDetailSheet(student: student),
    );
  }

  void _handleStudentAction(String action, Student student) {
    switch (action) {
      case 'view':
        _showStudentDetails(student);
        break;
      case 'edit':
        _showEditStudentSheet(student);
        break;
      case 'message':
        _showMessageStudent(student);
        break;
      case 'parent':
        _showContactParent(student);
        break;
      case 'activate':
        _toggleStudentStatus(student, true);
        break;
      case 'deactivate':
        _toggleStudentStatus(student, false);
        break;
    }
  }

  void _showEditStudentSheet(Student student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditStudentSheet(student: student),
    );
  }

  void _showMessageStudent(Student student) {
    // Navigate to messaging screen with student pre-selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening message to ${student.displayName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showContactParent(Student student) {
    if (student.parentEmail != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contact Parent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Parent Email: ${student.parentEmail}'),
              const SizedBox(height: 16),
              const Text('What would you like to do?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening email to ${student.parentEmail}'),
                  ),
                );
              },
              child: const Text('Send Email'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No parent email available for this student'),
        ),
      );
    }
  }

  void _toggleStudentStatus(Student student, bool isActive) async {
    try {
      if (isActive) {
        await _studentService.reactivateStudent(student.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${student.displayName} has been activated'),
            ),
          );
        }
      } else {
        await _studentService.deactivateStudent(student.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${student.displayName} has been deactivated'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating student status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddStudentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddStudentSheet(),
    );
  }
}

// Student Detail Sheet
class StudentDetailSheet extends StatelessWidget {
  final Student student;

  const StudentDetailSheet({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              // Handle Bar
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Content
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: student.photoURL != null
                              ? ClipOval(
                                  child: Image.network(
                                    student.photoURL!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Text(
                                      student.displayName
                                          .split(' ')
                                          .map((n) => n[0])
                                          .join(),
                                      style: TextStyle(
                                        color: theme
                                            .colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  student.displayName
                                      .split(' ')
                                      .map((n) => n[0])
                                      .join(),
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.displayName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Grade ${student.gradeLevel} Student',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Contact Information
                    Text(
                      'Contact Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildContactRow(
                        Icons.email, 'Student Email', student.email),
                    if (student.parentEmail != null)
                      _buildContactRow(Icons.family_restroom, 'Parent Email',
                          student.parentEmail!)
                    else
                      _buildContactRow(Icons.family_restroom, 'Parent Email',
                          'Not provided'),
                    const SizedBox(height: 24),

                    // Academic Performance
                    Text(
                      'Academic Performance',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPerformanceCard(
                            'Classes',
                            '${student.classCount}',
                            Icons.class_,
                            theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPerformanceCard(
                            'Grade Level',
                            '${student.gradeLevel}',
                            Icons.school,
                            theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Enrolled Classes
                    Text(
                      'Enrolled Classes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (student.classIds.isNotEmpty)
                      ...student.classIds.map((classId) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.class_),
                            title: Text('Class ID: $classId'),
                            subtitle: const Text('Click to view class details'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              // Navigate to classes screen
                              // TODO: When class detail screen is implemented, navigate directly to it
                              context.go('/teacher/classes');
                            },
                          ),
                        );
                      })
                    else
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('No classes enrolled'),
                          subtitle:
                              Text('Student is not enrolled in any classes'),
                        ),
                      ),

                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add Student Sheet
class AddStudentSheet extends StatefulWidget {
  const AddStudentSheet({super.key});

  @override
  State<AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends State<AddStudentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _studentService = StudentService();
  String _selectedGrade = '10';
  final List<String> _selectedClasses = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final email = _emailController.text.trim();
      final parentEmail = _parentEmailController.text.trim();
      final gradeLevel = int.parse(_selectedGrade);
      final now = DateTime.now();

      final newStudent = Student(
        id: '', // Will be set by Firestore
        userId: '', // Will be set when user account is created
        email: email,
        firstName: firstName,
        lastName: lastName,
        displayName: '$firstName $lastName',
        gradeLevel: gradeLevel,
        parentEmail: parentEmail.isEmpty ? null : parentEmail,
        classIds: List<String>.from(_selectedClasses),
        createdAt: now,
        updatedAt: now,
        isActive: true,
      );

      final createdStudent = await _studentService.createStudent(newStudent);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Student "${createdStudent.displayName}" added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding student: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Student',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // First Name Field
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        hintText: 'Enter first name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Last Name Field
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        hintText: 'Enter last name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Student Email',
                        hintText: 'student@example.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter student email';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                            .hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Parent Email Field
                    TextFormField(
                      controller: _parentEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Parent Email (Optional)',
                        hintText: 'parent@example.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.family_restroom),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                              .hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Grade Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                      items: ['9', '10', '11', '12'].map((grade) {
                        return DropdownMenuItem(
                          value: grade,
                          child: Text('Grade $grade'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGrade = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Classes Selection
                    Text(
                      'Assign to Classes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Math 101 - Section A',
                        'Environmental Science',
                        'Physics Honors',
                        'Chemistry 101',
                      ].map((className) {
                        final isSelected = _selectedClasses.contains(className);
                        return FilterChip(
                          label: Text(className),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedClasses.add(className);
                              } else {
                                _selectedClasses.remove(className);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _addStudent,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Add Student'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Edit Student Sheet
class EditStudentSheet extends StatefulWidget {
  final Student student;

  const EditStudentSheet({
    super.key,
    required this.student,
  });

  @override
  State<EditStudentSheet> createState() => _EditStudentSheetState();
}

class _EditStudentSheetState extends State<EditStudentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _studentService = StudentService();
  String _selectedGrade = '10';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.student.firstName;
    _lastNameController.text = widget.student.lastName;
    _emailController.text = widget.student.email;
    _parentEmailController.text = widget.student.parentEmail ?? '';
    _selectedGrade = widget.student.gradeLevel.toString();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Student',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        hintText: 'Enter first name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        hintText: 'Enter last name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Student Email',
                        hintText: 'student@example.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _parentEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Parent Email (Optional)',
                        hintText: 'parent@example.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.family_restroom),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                      items: ['9', '10', '11', '12'].map((grade) {
                        return DropdownMenuItem(
                          value: grade,
                          child: Text('Grade $grade'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGrade = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _updateStudent,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update Student'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedStudent = widget.student.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        displayName:
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        email: _emailController.text.trim(),
        parentEmail: _parentEmailController.text.trim().isEmpty
            ? null
            : _parentEmailController.text.trim(),
        gradeLevel: int.parse(_selectedGrade),
        updatedAt: DateTime.now(),
      );

      await _studentService.updateStudent(updatedStudent);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedStudent.displayName} updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating student: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
