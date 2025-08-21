import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/models/student.dart';
import '../../../../../features/classes/domain/models/class_model.dart';
import '../../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../../shared/widgets/common/common_widgets.dart';
import '../../providers/student_provider.dart';
import '../../../../../features/classes/presentation/providers/class_provider.dart';
import '../../../../../features/auth/presentation/providers/auth_provider.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedGrade = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    if (auth.userModel != null) {
      // First load classes, then load students in those classes
      final classProvider = context.read<ClassProvider>();
      classProvider.loadTeacherClasses(auth.userModel!.uid);

      // Load students after classes are loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (classProvider.teacherClasses.isNotEmpty) {
          context
              .read<StudentProvider>()
              .loadTeacherStudents(classProvider.teacherClasses);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Student> _filterStudents(List<Student> students) {
    return students.where((s) {
      final matchesSearch = _searchController.text.isEmpty ||
          '${s.firstName} ${s.lastName}'
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()) ||
          (s.email
                  ?.toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ??
              false);

      final matchesGrade = _selectedGrade == 'All' ||
          s.gradeLevel == int.tryParse(_selectedGrade);

      return matchesSearch && matchesGrade;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Students',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudentDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
      body: Column(
        children: [
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: 'All Students'),
                Tab(text: 'By Class'),
                Tab(text: 'Performance'),
              ],
            ),
          ),
          _buildSearchFilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllStudentsTab(),
                _buildByClassTab(),
                _buildPerformanceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search students...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            setState(() => _searchController.clear()),
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PopupMenuButton<String>(
              initialValue: _selectedGrade,
              onSelected: (value) => setState(() => _selectedGrade = value),
              itemBuilder: (context) => ['All', '9', '10', '11', '12']
                  .map((grade) => PopupMenuItem(
                        value: grade,
                        child: Text(
                            grade == 'All' ? 'All Grades' : 'Grade $grade'),
                      ))
                  .toList(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      _selectedGrade == 'All'
                          ? 'All Grades'
                          : 'Grade $_selectedGrade',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllStudentsTab() {
    return Consumer2<StudentProvider, ClassProvider>(
      builder: (context, studentProvider, classProvider, _) {
        if (studentProvider.isLoading || classProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Reload students when classes change
        if (classProvider.teacherClasses.isNotEmpty &&
            studentProvider.students.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            studentProvider.loadTeacherStudents(classProvider.teacherClasses);
          });
        }

        final students = _filterStudents(studentProvider.students);

        if (students.isEmpty) {
          return EmptyState(
            icon: Icons.people_outline,
            title: _searchController.text.isNotEmpty
                ? 'No students found'
                : 'No Students Yet',
            message: _searchController.text.isNotEmpty
                ? 'Try adjusting your search or filters'
                : 'No students enrolled in your classes yet',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: students.length,
          itemBuilder: (_, index) => _buildStudentCard(students[index]),
        );
      },
    );
  }

  Widget _buildByClassTab() {
    return Consumer<ClassProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading)
          return const Center(child: CircularProgressIndicator());

        final classes = provider.teacherClasses;

        if (classes.isEmpty) {
          return const EmptyState(
            icon: Icons.class_outlined,
            title: 'No Classes Yet',
            message: 'Create classes to organize your students',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: classes.length,
          itemBuilder: (_, index) => _buildClassCard(classes[index]),
        );
      },
    );
  }

  Widget _buildPerformanceTab() {
    return const Center(
      child: EmptyState(
        icon: Icons.analytics_outlined,
        title: 'Performance Analytics',
        message: 'Student performance tracking coming soon',
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    final fullName = '${student.firstName} ${student.lastName}';
    final initials =
        '${student.firstName[0]}${student.lastName[0]}'.toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(initials, style: const TextStyle(color: Colors.white)),
        ),
        title: Text(fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.email ?? student.username),
            Text('Grade ${student.gradeLevel}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              student.accountClaimed ? Icons.check_circle : Icons.pending,
              color: student.accountClaimed ? Colors.green : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showStudentActions(context, student),
            ),
          ],
        ),
        onTap: () => _showStudentDetails(context, student),
      ),
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            classModel.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(classModel.name),
        subtitle: Text('${classModel.studentCount} students'),
        children: [
          if (classModel.studentIds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No students enrolled'),
            )
          else
            FutureBuilder<List<Student>>(
              future: context
                  .read<StudentProvider>()
                  .loadStudentsByIds(classModel.studentIds),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  );
                }

                return Column(
                  children: snapshot.data!.map((student) {
                    final fullName = '${student.firstName} ${student.lastName}';
                    final initials =
                        '${student.firstName[0]}${student.lastName[0]}'
                            .toUpperCase();

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Text(initials),
                      ),
                      title: Text(fullName),
                      subtitle: Text(student.email ?? student.username),
                      onTap: () => _showStudentDetails(context, student),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Student'),
        content: const Text(
            'Student creation functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showStudentDetails(BuildContext context, Student student) {
    final fullName = '${student.firstName} ${student.lastName}';
    final initials =
        '${student.firstName[0]}${student.lastName[0]}'.toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(initials,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullName,
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(student.email ?? student.username,
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text('Grade ${student.gradeLevel}',
                            style: Theme.of(context).textTheme.bodySmall),
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
            const Divider(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDetailRow('Student ID', student.id),
                  _buildDetailRow('Username', student.username),
                  _buildDetailRow('Email', student.email ?? 'Not provided'),
                  _buildDetailRow(
                      'Parent Email', student.parentEmail ?? 'Not provided'),
                  _buildDetailRow('Account Status',
                      student.accountClaimed ? 'Claimed' : 'Pending'),
                  _buildDetailRow('Password Changed',
                      student.passwordChanged ? 'Yes' : 'No'),
                  if (student.backupEmail != null)
                    _buildDetailRow('Backup Email', student.backupEmail!),
                  _buildDetailRow('Created',
                      '${student.createdAt.month}/${student.createdAt.day}/${student.createdAt.year}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showStudentActions(BuildContext context, Student student) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Student'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Send Email'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Reset Password'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Remove Student',
                style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
