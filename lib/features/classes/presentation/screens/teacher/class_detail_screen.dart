import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../../shared/widgets/common/common_widgets.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../domain/models/class_model.dart';
import '../../providers/class_provider.dart';
import '../../../../../features/student/domain/models/student.dart';
import '../../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../widgets/edit_class_dialog.dart';
import '../../widgets/enroll_students_dialog.dart';
import '../../../../../features/assignments/presentation/providers/assignment_provider.dart';
import '../../../../../features/assignments/domain/models/assignment.dart';

class ClassDetailScreen extends StatefulWidget {
  final String classId;

  const ClassDetailScreen({
    super.key,
    required this.classId,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ClassModel? _classModel;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClassData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClassData() async {
    final classProvider = context.read<ClassProvider>();
    final authProvider = context.read<AuthProvider>();
    final assignmentProvider = context.read<AssignmentProvider>();
    
    // Load teacher classes to get the specific class
    if (authProvider.userModel != null) {
      await classProvider.loadTeacherClasses(authProvider.userModel!.uid);
      
      // Find the specific class
      final classModel = classProvider.teacherClasses.firstWhere(
        (c) => c.id == widget.classId,
        orElse: () => throw Exception('Class not found'),
      );
      
      setState(() {
        _classModel = classModel;
      });
      
      // Set as selected class and load students
      classProvider.setSelectedClass(classModel);
      await classProvider.loadClassStudents(widget.classId);
      
      // Load assignments for this class
      await assignmentProvider.loadAssignmentsForClass(widget.classId);
    }
  }

  Color _getSubjectColor(String subject) {
    final subjectMap = {
      'Mathematics': AppTheme.subjectColors[0],
      'Science': AppTheme.subjectColors[1],
      'Biology': AppTheme.subjectColors[1],
      'Chemistry': AppTheme.subjectColors[1],
      'Physics': AppTheme.subjectColors[1],
      'English': AppTheme.subjectColors[2],
      'Social Studies': AppTheme.subjectColors[3],
      'History': AppTheme.subjectColors[3],
      'Computer Science': AppTheme.subjectColors[4],
      'Art': AppTheme.subjectColors[5],
      'Music': AppTheme.subjectColors[6],
      'Physical Education': AppTheme.subjectColors[7],
    };
    
    return subjectMap[subject] ?? AppTheme.subjectColors[0];
  }

  String _formatPeriodNumber(String period) {
    // Try to parse the period as a number and format it with ordinal suffix
    final number = int.tryParse(period);
    if (number == null) {
      // If it's not a number, return as is
      return period;
    }
    
    // Add ordinal suffix (1st, 2nd, 3rd, etc.)
    String suffix;
    if (number % 100 >= 11 && number % 100 <= 13) {
      suffix = 'th';
    } else {
      switch (number % 10) {
        case 1:
          suffix = 'st';
          break;
        case 2:
          suffix = 'nd';
          break;
        case 3:
          suffix = 'rd';
          break;
        default:
          suffix = 'th';
          break;
      }
    }
    
    return '$number$suffix';
  }

  @override
  Widget build(BuildContext context) {
    if (_classModel == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/teacher/classes'),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Consumer<ClassProvider>(
      builder: (context, classProvider, _) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/teacher/classes'),
              tooltip: 'Back to Classes',
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_classModel!.name),
                Text(
                  '${_classModel!.subject} • ${_classModel!.gradeLevel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditClassDialog(),
                tooltip: 'Edit Class',
              ),
              PopupMenuButton<String>(
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'regenerate_code',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 12),
                        Text('Regenerate Code'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _classModel!.isActive ? 'archive' : 'restore',
                    child: Row(
                      children: [
                        Icon(
                          _classModel!.isActive ? Icons.archive : Icons.unarchive,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(_classModel!.isActive ? 'Archive Class' : 'Restore Class'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Students'),
                Tab(text: 'Assignments'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildStudentsTab(classProvider),
              _buildAssignmentsTab(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Info Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getSubjectColor(_classModel!.subject),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Class Information',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _classModel!.isActive ? 'Active' : 'Archived',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _classModel!.isActive 
                                  ? Colors.green 
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildInfoRow(Icons.subject, 'Subject', _classModel!.subject),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.grade, 'Grade Level', _classModel!.gradeLevel),
                if (_classModel!.room != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.room, 'Room', _classModel!.room!),
                ],
                if (_classModel!.schedule != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.schedule, 'Period', _formatPeriodNumber(_classModel!.schedule!)),
                ],
                const SizedBox(height: 12),
                _buildInfoRow(Icons.calendar_today, 'Academic Year', _classModel!.academicYear),
                if (_classModel!.description != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _classModel!.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Enrollment Code Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enrollment Code',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _regenerateEnrollmentCode(),
                      tooltip: 'Regenerate Code',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _classModel!.enrollmentCode ?? 'No Code',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyEnrollmentCode(),
                        tooltip: 'Copy Code',
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share this code with students to allow them to enroll',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Statistics Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        Icons.people,
                        'Students',
                        '${_classModel!.studentCount}${_classModel!.maxStudents != null ? '/${_classModel!.maxStudents}' : ''}',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem(
                        Icons.assignment,
                        'Assignments',
                        '0', // Assignments data will be connected when assignment feature is implemented
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        Icons.grade,
                        'Avg Grade',
                        'N/A', // Grades data will be connected when grading feature is implemented
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem(
                        Icons.check_circle,
                        'Completion',
                        'N/A', // Completion data will be connected when analytics feature is implemented
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab(ClassProvider classProvider) {
    final students = classProvider.classStudents.where((student) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return student.displayName.toLowerCase().contains(query) ||
             (student.email?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Column(
      children: [
        // Search and Add Student Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search students...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showEnrollStudentsDialog(),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Students'),
              ),
            ],
          ),
        ),
        
        // Students List
        Expanded(
          child: classProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : students.isEmpty
                  ? _searchQuery.isNotEmpty
                      ? EmptyState.noSearchResults(searchTerm: _searchQuery)
                      : const EmptyState(
                          icon: Icons.people_outline,
                          title: 'No Students Yet',
                          message: 'Add students to this class using the enrollment code or the Add Students button',
                        )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return _buildStudentCard(student, classProvider);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(Student student, ClassProvider classProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              student.displayName.isNotEmpty
                  ? student.displayName[0].toUpperCase()
                  : 'S',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  student.email ?? student.username,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'remove') {
                _removeStudent(student.id, classProvider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Remove from Class'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    return Consumer<AssignmentProvider>(
      builder: (context, assignmentProvider, _) {
        // Filter assignments for this specific class
        final classAssignments = assignmentProvider.assignments
            .where((assignment) => assignment.classId == widget.classId)
            .toList();
        
        if (assignmentProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (classAssignments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Assignments Yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first assignment for this class',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to create assignment with this class pre-selected
                    context.push('/teacher/assignments/create?classId=${widget.classId}');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Assignment'),
                ),
              ],
            ),
          );
        }
        
        return Column(
          children: [
            // Header with assignment count and create button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${classAssignments.length} Assignment${classAssignments.length != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/teacher/assignments/create?classId=${widget.classId}');
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('New Assignment'),
                  ),
                ],
              ),
            ),
            
            // Assignments list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: classAssignments.length,
                itemBuilder: (context, index) {
                  final assignment = classAssignments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getAssignmentTypeColor(assignment.type),
                        child: Icon(
                          _getAssignmentTypeIcon(assignment.type),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(assignment.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(assignment.type.name),
                          Text(
                            'Due: ${_formatDate(assignment.dueDate)}',
                            style: TextStyle(
                              color: assignment.dueDate.isBefore(DateTime.now())
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (assignment.isPublished)
                            const Icon(Icons.visibility, size: 20)
                          else
                            const Icon(Icons.visibility_off, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${assignment.totalPoints.toInt()} pts',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      onTap: () {
                        // Navigate to assignment detail
                        context.push('/teacher/assignments/${assignment.id}');
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  Color _getAssignmentTypeColor(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return Colors.blue;
      case AssignmentType.quiz:
        return Colors.orange;
      case AssignmentType.test:
        return Colors.red;
      case AssignmentType.exam:
        return Colors.purple;
      case AssignmentType.project:
        return Colors.green;
      case AssignmentType.classwork:
        return Colors.teal;
      case AssignmentType.essay:
        return Colors.indigo;
      case AssignmentType.lab:
        return Colors.amber;
      case AssignmentType.presentation:
        return Colors.pink;
      case AssignmentType.other:
        return Colors.grey;
    }
  }
  
  IconData _getAssignmentTypeIcon(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return Icons.home_work;
      case AssignmentType.quiz:
        return Icons.quiz;
      case AssignmentType.test:
        return Icons.assignment_turned_in;
      case AssignmentType.exam:
        return Icons.school;
      case AssignmentType.project:
        return Icons.folder_special;
      case AssignmentType.classwork:
        return Icons.class_;
      case AssignmentType.essay:
        return Icons.edit_note;
      case AssignmentType.lab:
        return Icons.science;
      case AssignmentType.presentation:
        return Icons.present_to_all;
      case AssignmentType.other:
        return Icons.assignment;
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
      return 'In ${difference.inDays} days';
    } else if (difference.inDays < 0 && difference.inDays > -7) {
      return '${-difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _copyEnrollmentCode() {
    final code = _classModel?.enrollmentCode;
    if (code != null) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enrollment code $code copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _regenerateEnrollmentCode() async {
    final classProvider = context.read<ClassProvider>();
    final newCode = await classProvider.regenerateEnrollmentCode(widget.classId);
    
    if (newCode != null) {
      setState(() {
        _classModel = _classModel?.copyWith(enrollmentCode: newCode);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New enrollment code: $newCode'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () => _copyEnrollmentCode(),
            ),
          ),
        );
      }
    }
  }

  void _showEditClassDialog() {
    showDialog(
      context: context,
      builder: (context) => EditClassDialog(classModel: _classModel!),
    ).then((result) {
      if (result == true) {
        // Reload class data
        _loadClassData();
      }
    });
  }

  void _showEnrollStudentsDialog() {
    showDialog(
      context: context,
      builder: (context) => EnrollStudentsDialog(classModel: _classModel!),
    ).then((result) {
      if (result == true && mounted) {
        // Reload students
        context.read<ClassProvider>().loadClassStudents(widget.classId);
      }
    });
  }


  Future<void> _removeStudent(String? studentId, ClassProvider classProvider) async {
    if (studentId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: const Text('Are you sure you want to remove this student from the class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await classProvider.unenrollStudent(widget.classId, studentId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student removed from class'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  void _handleMenuAction(String action) async {
    final classProvider = context.read<ClassProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    switch (action) {
      case 'regenerate_code':
        await _regenerateEnrollmentCode();
        break;
      case 'archive':
        // ignore: use_build_context_synchronously
        final confirmed = await showDialog<bool>(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Archive Class'),
            content: const Text('Archived classes will be read-only. Students won\'t be able to submit new work. You can restore the class later.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Archive'),
              ),
            ],
          ),
        );
        
        if (confirmed == true) {
          final success = await classProvider.archiveClass(widget.classId);
          if (success && mounted) {
            setState(() {
              _classModel = _classModel!.copyWith(isActive: false);
            });
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Class archived successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        break;
      case 'restore':
        final success = await classProvider.restoreClass(widget.classId);
        if (success && mounted) {
          setState(() {
            _classModel = _classModel!.copyWith(isActive: true);
          });
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Class restored successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
    }
  }
}