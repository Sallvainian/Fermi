import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../models/assignment.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/assignment_provider.dart';

class TeacherAssignmentsScreen extends StatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  State<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends State<TeacherAssignmentsScreen> {
  String _selectedClass = 'All Classes';
  String _selectedStatus = 'All';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load assignments when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final assignmentProvider = context.read<AssignmentProvider>();
      final user = authProvider.userModel;
      
      if (user != null && user.role == UserRole.teacher) {
        assignmentProvider.loadAssignmentsForTeacher(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      title: 'Assignments',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateAssignmentSheet(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Assignment'),
      ),
      body: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters and Search
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search assignments...',
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
                    const SizedBox(height: 16),
                    // Filter Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Class Filter
                        ChoiceChip(
                          label: Text(_selectedClass),
                          selected: true,
                          onSelected: (_) {
                            _showClassFilterDialog();
                          },
                          avatar: const Icon(Icons.class_, size: 18),
                        ),
                        // Status Filter
                        ..._buildStatusChips(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Assignments List
            Expanded(
              child: _buildAssignmentsList(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatusChips() {
    final statuses = ['All', 'Active', 'Draft', 'Closed'];
    return statuses.map((status) {
      return FilterChip(
        label: Text(status),
        selected: _selectedStatus == status,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = selected ? status : 'All';
          });
        },
      );
    }).toList();
  }

  Widget _buildAssignmentsList() {
    final authProvider = context.watch<AuthProvider>();
    final assignmentProvider = context.watch<AssignmentProvider>();
    final user = authProvider.userModel;
    
    if (user == null) {
      return const Center(
        child: Text('Please log in to view assignments'),
      );
    }

    if (assignmentProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (assignmentProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${assignmentProvider.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                assignmentProvider.clearError();
                assignmentProvider.loadAssignmentsForTeacher(user.uid);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final assignments = assignmentProvider.teacherAssignments;
        
        // Filter assignments based on selected filters
        final filteredAssignments = assignments.where((assignment) {
          // Status filter
          if (_selectedStatus != 'All') {
            if (_selectedStatus == 'Active' && assignment.status != AssignmentStatus.active) return false;
            if (_selectedStatus == 'Draft' && (assignment.status != AssignmentStatus.draft || assignment.isPublished)) return false;
            if (_selectedStatus == 'Closed' && assignment.status != AssignmentStatus.completed) return false;
          }
          
          // Search filter
          if (_searchController.text.isNotEmpty) {
            final searchLower = _searchController.text.toLowerCase();
            return assignment.title.toLowerCase().contains(searchLower) ||
                   assignment.description.toLowerCase().contains(searchLower);
          }
          
          return true;
        }).toList();

        if (filteredAssignments.isEmpty) {
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
                  'No assignments found',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_searchController.text.isNotEmpty || _selectedStatus != 'All')
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _selectedStatus = 'All';
                      });
                    },
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          );
        }

    return ListView.builder(
      itemCount: filteredAssignments.length,
      itemBuilder: (context, index) {
        return _buildAssignmentCard(filteredAssignments[index]);
      },
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    final theme = Theme.of(context);
    final dueDate = assignment.dueDate;
    final isOverdue = dueDate.isBefore(DateTime.now()) && assignment.status == AssignmentStatus.active;
    
    Color statusColor;
    IconData statusIcon;
    switch (assignment.status) {
      case AssignmentStatus.active:
        statusColor = Colors.green;
        statusIcon = Icons.play_circle_outline;
        break;
      case AssignmentStatus.draft:
        statusColor = Colors.orange;
        statusIcon = Icons.edit_outlined;
        break;
      case AssignmentStatus.completed:
        statusColor = Colors.grey;
        statusIcon = Icons.check_circle_outline;
        break;
      case AssignmentStatus.archived:
        statusColor = Colors.grey;
        statusIcon = Icons.archive_outlined;
        break;
    }

    if (!assignment.isPublished) {
      if (assignment.publishAt != null) {
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
      } else {
        statusColor = Colors.orange;
        statusIcon = Icons.visibility_off;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/teacher/assignments/${assignment.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Assignment Type Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getAssignmentTypeIcon(assignment.type),
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and Category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          assignment.category,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          assignment.isPublished 
                              ? assignment.status.name.toUpperCase()
                              : assignment.publishAt != null
                                  ? 'SCHEDULED'
                                  : 'UNPUBLISHED',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Info Grid
              Row(
                children: [
                  // Due Date
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.calendar_today,
                      label: 'Due Date',
                      value: _formatDate(dueDate),
                      color: isOverdue ? Colors.red : null,
                    ),
                  ),
                  // Points
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.star_outline,
                      label: 'Points',
                      value: '${assignment.maxPoints.toInt()}',
                    ),
                  ),
                  // Type or Publish Date
                  Expanded(
                    child: assignment.publishAt != null && !assignment.isPublished
                      ? _buildInfoItem(
                          icon: Icons.schedule,
                          label: 'Publishes',
                          value: _formatDate(assignment.publishAt!),
                          color: Colors.blue,
                        )
                      : _buildInfoItem(
                          icon: Icons.assignment_outlined,
                          label: 'Type',
                          value: assignment.type.name.toUpperCase(),
                        ),
                  ),
                ],
              ),

              // Action Buttons
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (assignment.status == AssignmentStatus.active)
                    TextButton.icon(
                      onPressed: () {
                        context.go('/teacher/gradebook?assignmentId=${assignment.id}');
                      },
                      icon: const Icon(Icons.grading, size: 18),
                      label: const Text('Grade'),
                    ),
                  if (!assignment.isPublished)
                    TextButton.icon(
                      onPressed: () async {
                        final assignmentProvider = context.read<AssignmentProvider>();
                        await assignmentProvider.togglePublishStatus(assignment.id, true);
                      },
                      icon: const Icon(Icons.publish, size: 18),
                      label: const Text('Publish'),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      context.go('/teacher/assignments/${assignment.id}');
                    },
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color ?? theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  IconData _getAssignmentTypeIcon(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return Icons.home_work_outlined;
      case AssignmentType.essay:
        return Icons.article_outlined;
      case AssignmentType.exam:
        return Icons.quiz_outlined;
      case AssignmentType.test:
        return Icons.quiz_outlined;
      case AssignmentType.lab:
        return Icons.science_outlined;
      case AssignmentType.project:
        return Icons.folder_special_outlined;
      case AssignmentType.quiz:
        return Icons.quiz_outlined;
      case AssignmentType.presentation:
        return Icons.present_to_all_outlined;
      case AssignmentType.classwork:
        return Icons.work_outlined;
      case AssignmentType.other:
        return Icons.assignment_outlined;
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
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showClassFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile(
                title: const Text('All Classes'),
                value: 'All Classes',
                groupValue: _selectedClass,
                onChanged: (value) {
                  setState(() {
                    _selectedClass = value!;
                  });
                  Navigator.pop(context);
                },
              ),
              RadioListTile(
                title: const Text('Math 101 - Section A'),
                value: 'Math 101 - Section A',
                groupValue: _selectedClass,
                onChanged: (value) {
                  setState(() {
                    _selectedClass = value!;
                  });
                  Navigator.pop(context);
                },
              ),
              RadioListTile(
                title: const Text('Environmental Science'),
                value: 'Environmental Science',
                groupValue: _selectedClass,
                onChanged: (value) {
                  setState(() {
                    _selectedClass = value!;
                  });
                  Navigator.pop(context);
                },
              ),
              RadioListTile(
                title: const Text('Physics Honors'),
                value: 'Physics Honors',
                groupValue: _selectedClass,
                onChanged: (value) {
                  setState(() {
                    _selectedClass = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateAssignmentSheet(BuildContext context) {
    context.go('/teacher/assignments/create');
  }
}

// Assignment Detail Sheet
class AssignmentDetailSheet extends StatelessWidget {
  final Map<String, dynamic> assignment;

  const AssignmentDetailSheet({
    super.key,
    required this.assignment,
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
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                    // Title
                    Text(
                      assignment['title'],
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Class and Subject
                    Row(
                      children: [
                        Icon(
                          Icons.class_,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${assignment['class']} • ${assignment['subject']}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Instructions
                    Text(
                      'Instructions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete all problems from Chapter 5, pages 142-145. Show all your work and explain your reasoning for word problems. Submit your work as a PDF file.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    // Assignment Details
                    Text(
                      'Assignment Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Type', assignment['type']),
                    _buildDetailRow('Points', '${assignment['points']}'),
                    _buildDetailRow('Due Date', _formatDetailDate(assignment['dueDate'])),
                    _buildDetailRow('Status', assignment['status']),
                    const SizedBox(height: 24),

                    // Submission Statistics
                    Text(
                      'Submission Statistics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      'Submitted',
                      '${assignment['submissions']}',
                      Colors.green,
                      Icons.check_circle,
                    ),
                    _buildStatCard(
                      'Pending',
                      '${assignment['total'] - assignment['submissions']}',
                      Colors.orange,
                      Icons.pending,
                    ),
                    _buildStatCard(
                      'Total Students',
                      '${assignment['total']}',
                      Colors.blue,
                      Icons.groups,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  String _formatDetailDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// Create Assignment Sheet
class CreateAssignmentSheet extends StatefulWidget {
  const CreateAssignmentSheet({super.key});

  @override
  State<CreateAssignmentSheet> createState() => _CreateAssignmentSheetState();
}

class _CreateAssignmentSheetState extends State<CreateAssignmentSheet> {
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _pointsController = TextEditingController();
  String _selectedType = 'Homework';
  String _selectedClass = 'Math 101 - Section A';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _pointsController.dispose();
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
          // Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                  'Create Assignment',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Field
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Assignment Title',
                      hintText: 'Enter assignment title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Assignment Type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Homework', 'Essay', 'Exam', 'Lab Report', 'Project', 'Quiz'
                    ].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Class Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedClass,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Math 101 - Section A',
                      'Environmental Science',
                      'Physics Honors',
                      'Chemistry 101',
                    ].map((className) {
                      return DropdownMenuItem(
                        value: className,
                        child: Text(className),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClass = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Points Field
                  TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Points',
                      hintText: 'Enter total points',
                      border: OutlineInputBorder(),
                      suffixText: 'pts',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Due Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _dueDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Instructions Field
                  TextField(
                    controller: _instructionsController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                      hintText: 'Enter assignment instructions',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
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
                    onPressed: () {
                      // Create assignment logic
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Assignment created successfully'),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Create Assignment'),
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