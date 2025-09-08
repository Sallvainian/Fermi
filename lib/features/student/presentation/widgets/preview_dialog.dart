import 'package:flutter/material.dart';
import '../../../../shared/models/user_model.dart';
import '../../../classes/domain/models/class_model.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/common/responsive_layout.dart';
import 'preview_with_data.dart';

class PreviewDialog extends StatefulWidget {
  const PreviewDialog({super.key});

  @override
  State<PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<PreviewDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: screenSize.width * 0.9,
        height: screenSize.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 1200, minWidth: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.preview_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Students Preview',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'This is what your students page will look like with real data',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
            ),

            // Tabs
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: TabBar(
                controller: _tabController,
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

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllStudentsTab(context),
                  _buildClassesTab(context),
                  _buildPerformanceTab(context),
                  _buildReportsTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllStudentsTab(BuildContext context) {
    final theme = Theme.of(context);
    final students = _generateMockStudents();

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final avatarColor = theme.colorScheme.primary;

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: avatarColor,
              child: Text(
                student.displayName?[0].toUpperCase() ?? '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              student.displayNameOrFallback,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Grade ${student.gradeLevel ?? ''} • ${student.email}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusChip('Active', Colors.green),
                const SizedBox(width: AppSpacing.sm),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClassesTab(BuildContext context) {
    final theme = Theme.of(context);
    final classes = _generateMockClasses();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsiveGrid(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        mobileColumns: 1,
        tabletColumns: 2,
        desktopColumns: 3,
        children: classes.map((classModel) {
          final colorIndex =
              classModel.subject.hashCode % AppTheme.subjectColors.length;
          final color = AppTheme.subjectColors[colorIndex];

          return Card(
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getSubjectIcon(classModel.subject),
                            color: color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                classModel.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                classModel.subject,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        _buildClassInfo(
                          Icons.people,
                          '${classModel.studentCount} students',
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _buildClassInfo(
                          Icons.schedule,
                          classModel.schedule ?? 'Daily',
                        ),
                      ],
                    ),
                    if (classModel.room != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _buildClassInfo(Icons.room, classModel.room!),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPerformanceTab(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          ResponsiveGrid(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            mobileColumns: 2,
            tabletColumns: 4,
            desktopColumns: 4,
            children: [
              _buildSummaryCard(
                'Class Average',
                '87.5%',
                Icons.school,
                Colors.blue,
              ),
              _buildSummaryCard(
                'Top Performer',
                'Sarah Johnson',
                Icons.star,
                Colors.amber,
              ),
              _buildSummaryCard(
                'Attendance',
                '94%',
                Icons.check_circle,
                Colors.green,
              ),
              _buildSummaryCard(
                'Assignments',
                '142',
                Icons.assignment,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Performance Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grade Distribution',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildGradeDistribution(context),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Recent Assessments
          Text(
            'Recent Assessments',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._buildRecentAssessments(context),
        ],
      ),
    );
  }

  Widget _buildReportsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assessment, color: Colors.blue),
            ),
            title: const Text('Progress Report - Q3 2024'),
            subtitle: const Text('Generated on January 15, 2025'),
            trailing: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {},
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bar_chart, color: Colors.green),
            ),
            title: const Text('Attendance Summary - December 2024'),
            subtitle: const Text('Generated on January 1, 2025'),
            trailing: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {},
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.analytics, color: Colors.purple),
            ),
            title: const Text('Performance Analytics - Fall 2024'),
            subtitle: const Text('Generated on December 20, 2024'),
            trailing: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildClassInfo(IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppSpacing.md),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
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

  Widget _buildGradeDistribution(BuildContext context) {
    final theme = Theme.of(context);
    final grades = ['A', 'B', 'C', 'D', 'F'];
    final percentages = [35, 40, 20, 4, 1];
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
    ];

    return Column(
      children: List.generate(grades.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  grades[index],
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentages[index] / 100,
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors[index],
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 50,
                child: Text(
                  '${percentages[index]}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _buildRecentAssessments(BuildContext context) {
    final assessments = [
      {
        'title': 'Math Quiz - Chapter 5',
        'date': 'Jan 18, 2025',
        'average': '85%',
      },
      {'title': 'Science Lab Report', 'date': 'Jan 15, 2025', 'average': '92%'},
      {'title': 'English Essay', 'date': 'Jan 12, 2025', 'average': '88%'},
    ];

    return assessments.map((assessment) {
      return Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          title: Text(assessment['title']!),
          subtitle: Text(assessment['date']!),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                assessment['average']!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text(
                'Class Average',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return Icons.calculate;
      case 'science':
        return Icons.science;
      case 'english':
      case 'language arts':
        return Icons.menu_book;
      case 'history':
      case 'social studies':
        return Icons.history_edu;
      case 'art':
        return Icons.palette;
      case 'music':
        return Icons.music_note;
      case 'physical education':
      case 'pe':
        return Icons.sports;
      default:
        return Icons.school;
    }
  }

  // Mock Data Generators
  List<UserModel> _generateMockStudents() {
    final now = DateTime.now();
    return [
      UserModel(
        uid: '1',
        email: 'sarah.johnson@school.edu',
        displayName: 'Sarah Johnson',
        firstName: 'Sarah',
        lastName: 'Johnson',
        role: UserRole.student,
        createdAt: now.subtract(const Duration(days: 180)),
        lastActive: now.subtract(const Duration(hours: 2)),
        studentId: 'STU001',
        gradeLevel: '10',
        parentEmail: 'parent.johnson@email.com',
        enrolledClassIds: ['1', '2', '3'],
      ),
      UserModel(
        uid: '2',
        email: 'mike.chen@school.edu',
        displayName: 'Mike Chen',
        firstName: 'Mike',
        lastName: 'Chen',
        role: UserRole.student,
        createdAt: now.subtract(const Duration(days: 200)),
        lastActive: now.subtract(const Duration(hours: 1)),
        studentId: 'STU002',
        gradeLevel: '10',
        parentEmail: 'parent.chen@email.com',
        enrolledClassIds: ['1', '3', '4'],
      ),
      UserModel(
        uid: '3',
        email: 'emma.davis@school.edu',
        displayName: 'Emma Davis',
        firstName: 'Emma',
        lastName: 'Davis',
        role: UserRole.student,
        createdAt: now.subtract(const Duration(days: 150)),
        lastActive: now.subtract(const Duration(hours: 3)),
        studentId: 'STU003',
        gradeLevel: '11',
        parentEmail: 'parent.davis@email.com',
        enrolledClassIds: ['2', '4', '5'],
      ),
      UserModel(
        uid: '4',
        email: 'alex.martinez@school.edu',
        displayName: 'Alex Martinez',
        firstName: 'Alex',
        lastName: 'Martinez',
        role: UserRole.student,
        createdAt: now.subtract(const Duration(days: 170)),
        lastActive: now.subtract(const Duration(minutes: 30)),
        studentId: 'STU004',
        gradeLevel: '10',
        parentEmail: 'parent.martinez@email.com',
        enrolledClassIds: ['1', '2', '6'],
      ),
      UserModel(
        uid: '5',
        email: 'lily.wilson@school.edu',
        displayName: 'Lily Wilson',
        firstName: 'Lily',
        lastName: 'Wilson',
        role: UserRole.student,
        createdAt: now.subtract(const Duration(days: 190)),
        lastActive: now.subtract(const Duration(hours: 4)),
        studentId: 'STU005',
        gradeLevel: '11',
        parentEmail: 'parent.wilson@email.com',
        enrolledClassIds: ['3', '5', '6'],
      ),
      UserModel(
        uid: '6',
        email: 'james.brown@school.edu',
        displayName: 'James Brown',
        firstName: 'James',
        lastName: 'Brown',
        role: UserRole.student,
        createdAt: now.subtract(const Duration(days: 160)),
        lastActive: now,
        studentId: 'STU006',
        gradeLevel: '10',
        parentEmail: 'parent.brown@email.com',
        enrolledClassIds: ['1', '4', '5'],
      ),
    ];
  }

  List<ClassModel> _generateMockClasses() {
    final now = DateTime.now();
    return [
      ClassModel(
        id: '1',
        name: 'Algebra II - Period 1',
        subject: 'Mathematics',
        teacherId: 'teacher1',
        studentIds: List.generate(28, (i) => 'student$i'),
        schedule: 'Mon, Wed, Fri',
        room: 'Room 201',
        gradeLevel: '10',
        createdAt: now.subtract(const Duration(days: 30)),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Spring',
        maxStudents: 30,
        enrollmentCode: 'ALG2-P1',
      ),
      ClassModel(
        id: '2',
        name: 'Physics - Period 3',
        subject: 'Science',
        teacherId: 'teacher1',
        studentIds: List.generate(24, (i) => 'student$i'),
        schedule: 'Tue, Thu',
        room: 'Lab 102',
        gradeLevel: '11',
        createdAt: now.subtract(const Duration(days: 30)),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Spring',
        maxStudents: 25,
        enrollmentCode: 'PHY-P3',
      ),
      ClassModel(
        id: '3',
        name: 'English Literature',
        subject: 'English',
        teacherId: 'teacher1',
        studentIds: List.generate(30, (i) => 'student$i'),
        schedule: 'Daily',
        room: 'Room 305',
        gradeLevel: '10-11',
        createdAt: now.subtract(const Duration(days: 30)),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Spring',
        maxStudents: 32,
        enrollmentCode: 'ENG-LIT',
      ),
      ClassModel(
        id: '4',
        name: 'AP History',
        subject: 'History',
        teacherId: 'teacher1',
        studentIds: List.generate(22, (i) => 'student$i'),
        schedule: 'Mon, Wed, Fri',
        room: 'Room 415',
        gradeLevel: '11-12',
        createdAt: now.subtract(const Duration(days: 30)),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Spring',
        maxStudents: 25,
        enrollmentCode: 'AP-HIST',
      ),
      ClassModel(
        id: '5',
        name: 'Geometry - Period 5',
        subject: 'Mathematics',
        teacherId: 'teacher1',
        studentIds: List.generate(26, (i) => 'student$i'),
        schedule: 'Daily',
        room: 'Room 203',
        gradeLevel: '9-10',
        createdAt: now.subtract(const Duration(days: 30)),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Spring',
        maxStudents: 30,
        enrollmentCode: 'GEO-P5',
      ),
      ClassModel(
        id: '6',
        name: 'Chemistry Honors',
        subject: 'Science',
        teacherId: 'teacher1',
        studentIds: List.generate(20, (i) => 'student$i'),
        schedule: 'Tue, Thu',
        room: 'Lab 104',
        gradeLevel: '11-12',
        createdAt: now.subtract(const Duration(days: 30)),
        isActive: true,
        academicYear: '2024-2025',
        semester: 'Spring',
        maxStudents: 22,
        enrollmentCode: 'CHEM-H',
      ),
    ];
  }
}

// Helper function to show the preview dialog
void showPreviewDialog(BuildContext context) {
  // Show the actual Students screen with mock data
  showPreviewWithData(context);
}
