import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../../shared/widgets/common/responsive_layout.dart';
import '../../../../../shared/widgets/common/error_aware_stream_builder.dart';
import '../../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../providers/student_assignment_provider_simple.dart';
import '../../../domain/models/assignment.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedSubject = 'All Subjects';
  String _sortBy = 'Due Date';
  Future<void>? _initializationFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);

    // Initialize the provider with student data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.userModel != null) {
        _initializationFuture = context
            .read<SimpleStudentAssignmentProvider>()
            .initializeForStudent(authProvider.userModel!.uid);
        setState(() {});
      }
    });
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
    final studentProvider = context.watch<SimpleStudentAssignmentProvider>();

    return AdaptiveLayout(
      title: 'Assignments',
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Pending'),
          Tab(text: 'Submitted'),
          Tab(text: 'Graded'),
          Tab(text: 'All'),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error initializing assignments: ${snapshot.error}'),
            );
          }

          return ErrorAwareStreamBuilder<List<Map<String, dynamic>>>(
            stream: studentProvider.assignmentsStream,
            onRetry: () => studentProvider.refresh(),
            // Don't check if data is empty - let tabs handle their own empty states
            builder: (context, assignments) {
              return Column(
                children: [
                  // Search and Filters
                  Container(
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
                        const SizedBox(height: 12),
                        // Filter Row
                        Row(
                          children: [
                            // Subject Filter
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedSubject,
                                    isExpanded: true,
                                    items: _getSubjectsList(assignments).map((
                                      subject,
                                    ) {
                                      return DropdownMenuItem(
                                        value: subject,
                                        child: Text(subject),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedSubject = value!;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Sort Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outline,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _sortBy,
                                  items:
                                      [
                                        'Due Date',
                                        'Subject',
                                        'Priority',
                                        'Points',
                                      ].map((sort) {
                                        return DropdownMenuItem(
                                          value: sort,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.sort, size: 18),
                                              const SizedBox(width: 8),
                                              Text(sort),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _sortBy = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Assignments List
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAssignmentsList(
                          _filterAssignments(
                            _getPendingAssignments(assignments),
                          ),
                          emptyMessage: 'No pending assignments! 🎉',
                          emptyIcon: Icons.celebration_outlined,
                        ),
                        _buildAssignmentsList(
                          _filterAssignments(
                            _getSubmittedAssignments(assignments),
                          ),
                          emptyMessage: 'No assignments waiting for grades',
                          emptyIcon: Icons.hourglass_empty,
                        ),
                        _buildAssignmentsList(
                          _filterAssignments(
                            _getGradedAssignments(assignments),
                          ),
                          emptyMessage: 'No graded assignments yet',
                          emptyIcon: Icons.grade_outlined,
                        ),
                        _buildAssignmentsList(
                          _filterAssignments(assignments),
                          emptyMessage: 'No assignments yet',
                          emptyIcon: Icons.assignment_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<String> _getSubjectsList(List<Map<String, dynamic>> assignments) {
    final subjects = <String>{'All Subjects'};
    for (final assignment in assignments) {
      subjects.add(assignment['category'] ?? 'General');
    }
    return subjects.toList()..sort();
  }

  List<Map<String, dynamic>> _getPendingAssignments(
    List<Map<String, dynamic>> assignments,
  ) {
    return assignments
        .where(
          (a) => !(a['isSubmitted'] ?? false) && !(a['isOverdue'] ?? false),
        )
        .toList();
  }

  List<Map<String, dynamic>> _getSubmittedAssignments(
    List<Map<String, dynamic>> assignments,
  ) {
    return assignments
        .where((a) => (a['isSubmitted'] ?? false) && !(a['isGraded'] ?? false))
        .toList();
  }

  List<Map<String, dynamic>> _getGradedAssignments(
    List<Map<String, dynamic>> assignments,
  ) {
    return assignments.where((a) => a['isGraded'] ?? false).toList();
  }

  List<Map<String, dynamic>> _filterAssignments(
    List<Map<String, dynamic>> assignments,
  ) {
    var filtered = assignments;

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((a) {
        return (a['title'] ?? '').toLowerCase().contains(query) ||
            (a['description'] ?? '').toLowerCase().contains(query) ||
            (a['category'] ?? '').toLowerCase().contains(query);
      }).toList();
    }

    // Apply subject filter
    if (_selectedSubject != 'All Subjects') {
      filtered = filtered
          .where((a) => (a['category'] ?? 'General') == _selectedSubject)
          .toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'Due Date':
        filtered.sort((a, b) {
          final aDue = a['dueDate'] as Timestamp?;
          final bDue = b['dueDate'] as Timestamp?;
          if (aDue == null) return 1;
          if (bDue == null) return -1;
          return aDue.compareTo(bDue);
        });
        break;
      case 'Subject':
        filtered.sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));
        break;
      case 'Priority':
        // Sort by due date as proxy for priority
        filtered.sort((a, b) {
          final aDue = a['dueDate'] as Timestamp?;
          final bDue = b['dueDate'] as Timestamp?;
          if (aDue == null) return 1;
          if (bDue == null) return -1;
          return aDue.compareTo(bDue);
        });
        break;
      case 'Points':
        filtered.sort(
          (a, b) => (b['totalPoints'] ?? 0).compareTo(a['totalPoints'] ?? 0),
        );
        break;
    }

    return filtered;
  }

  Widget _buildAssignmentsList(
    List<Map<String, dynamic>> assignments, {
    required String emptyMessage,
    IconData emptyIcon = Icons.assignment_outlined,
  }) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha:0.4),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ResponsiveContainer(
      child: RefreshIndicator(
        onRefresh: () =>
            context.read<SimpleStudentAssignmentProvider>().refresh(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final studentAssignment = assignments[index];
            return _buildAssignmentCard(studentAssignment);
          },
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> studentAssignment) {
    final theme = Theme.of(context);
    final assignment =
        studentAssignment['assignment'] ??
        studentAssignment; // Use assignment data or the whole object
    final dueDate = assignment['dueDate'] as Timestamp?;
    final isOverdue = studentAssignment['isOverdue'] ?? false;
    final isDueSoon = studentAssignment['isDueSoon'] ?? false;

    Color priorityColor = _getPriorityColor(assignment);
    Color statusColor = _getStatusColor(
      studentAssignment['status'] ?? 'pending',
    );
    IconData statusIcon = _getStatusIcon(
      studentAssignment['status'] ?? 'pending',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAssignmentDetails(studentAssignment),
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
                      _getAssignmentIcon(assignment['type']),
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and Class
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment['title'] ?? 'Untitled',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${assignment['category'] ?? 'General'} • ${assignment['teacherName'] ?? 'Unknown'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Priority Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getPriorityText(assignment),
                      style: TextStyle(
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Status and Due Date Row
              Row(
                children: [
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          studentAssignment['status'] ?? 'Unknown',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Due Date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: isOverdue
                            ? Colors.red
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDueDate(dueDate?.toDate() ?? DateTime.now()),
                        style: TextStyle(
                          color: isOverdue
                              ? Colors.red
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isDueSoon
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Points and Grade (if graded)
              Row(
                children: [
                  // Points
                  _buildInfoChip(
                    icon: Icons.star_outline,
                    label: '${assignment['totalPoints']?.toInt() ?? 0} pts',
                    color: Colors.blue,
                  ),
                  if ((studentAssignment['isGraded'] ?? false) &&
                      studentAssignment['earnedPoints'] != null) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.grade,
                      label:
                          '${studentAssignment['earnedPoints']!.toInt()}/${assignment['totalPoints']?.toInt() ?? 0}',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.school,
                      label: studentAssignment['letterGrade'] ?? 'N/A',
                      color: _getGradeColor(
                        studentAssignment['letterGrade'] ?? 'N/A',
                      ),
                    ),
                  ],
                ],
              ),

              // Action Buttons
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!(studentAssignment['isSubmitted'] ?? false) &&
                      !(studentAssignment['isOverdue'] ?? false))
                    TextButton.icon(
                      onPressed: () {
                        context.push(
                          '/student/assignments/${studentAssignment['assignment']?['id'] ?? studentAssignment['id']}/submit',
                        );
                      },
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Submit'),
                    ),
                  if (studentAssignment['isSubmitted'] ?? false)
                    TextButton.icon(
                      onPressed: () {
                        context.push(
                          '/student/assignments/${studentAssignment['assignment']?['id'] ?? studentAssignment['id']}/submit',
                        );
                      },
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text('View Submission'),
                    ),
                  if ((studentAssignment['isGraded'] ?? false) &&
                      studentAssignment['feedback'] != null)
                    TextButton.icon(
                      onPressed: () {
                        _showFeedbackDialog(studentAssignment);
                      },
                      icon: const Icon(Icons.feedback, size: 18),
                      label: const Text('Feedback'),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      _showAssignmentDetails(studentAssignment);
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAssignmentIcon(dynamic type) {
    // Handle both string and AssignmentType
    if (type is String) {
      switch (type.toLowerCase()) {
        case 'homework':
          return Icons.home_work_outlined;
        case 'quiz':
          return Icons.quiz_outlined;
        case 'test':
          return Icons.assignment_outlined;
        case 'project':
          return Icons.folder_special_outlined;
        case 'lab':
          return Icons.science_outlined;
        case 'classwork':
          return Icons.work_outline;
        case 'activity':
          return Icons.sports_handball_outlined;
        default:
          return Icons.assignment_outlined;
      }
    }
    if (type is! AssignmentType) return Icons.assignment_outlined;
    switch (type) {
      case AssignmentType.homework:
        return Icons.home_work_outlined;
      case AssignmentType.quiz:
        return Icons.quiz_outlined;
      case AssignmentType.test:
        return Icons.assignment_outlined;
      case AssignmentType.project:
        return Icons.folder_special_outlined;
      case AssignmentType.lab:
        return Icons.science_outlined;
      case AssignmentType.classwork:
        return Icons.work_outline;
      case AssignmentType.activity:
        return Icons.sports_handball_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  Color _getPriorityColor(Map<String, dynamic> assignment) {
    final dueDateTimestamp = assignment['dueDate'] as Timestamp?;
    if (dueDateTimestamp == null) return Colors.grey;

    final dueDate = dueDateTimestamp.toDate();
    final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
    if (daysUntilDue <= 1) return Colors.red;
    if (daysUntilDue <= 3) return Colors.orange;
    return Colors.green;
  }

  String _getPriorityText(Map<String, dynamic> assignment) {
    final dueDateTimestamp = assignment['dueDate'] as Timestamp?;
    if (dueDateTimestamp == null) return 'Unknown';

    final dueDate = dueDateTimestamp.toDate();
    final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
    if (daysUntilDue <= 1) return 'High';
    if (daysUntilDue <= 3) return 'Medium';
    return 'Low';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.grey;
      case 'Overdue':
        return Colors.red;
      case 'Submitted':
        return Colors.orange;
      case 'Graded':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.pending_outlined;
      case 'Overdue':
        return Icons.warning_outlined;
      case 'Submitted':
        return Icons.check_circle_outline;
      case 'Graded':
        return Icons.grade;
      default:
        return Icons.assignment_outlined;
    }
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return Colors.green;
    if (grade.startsWith('B')) return Colors.blue;
    if (grade.startsWith('C')) return Colors.orange;
    if (grade.startsWith('D')) return Colors.red;
    if (grade.startsWith('F')) return Colors.red[800]!;
    return Colors.grey;
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      if (difference.inHours > 0) {
        return 'Due in ${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return 'Due in ${difference.inMinutes}m';
      } else {
        return 'Due now';
      }
    } else if (difference.inDays == 1) {
      return 'Due tomorrow';
    } else if (difference.inDays == -1) {
      return 'Due yesterday';
    } else if (difference.inDays > 0 && difference.inDays < 7) {
      return 'Due in ${difference.inDays} days';
    } else if (difference.inDays < 0 && difference.inDays > -7) {
      return '${-difference.inDays} days overdue';
    } else {
      return 'Due ${date.day}/${date.month}/${date.year}';
    }
  }

  void _showAssignmentDetails(Map<String, dynamic> studentAssignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AssignmentDetailSheet(studentAssignment: studentAssignment),
    );
  }

  void _showFeedbackDialog(Map<String, dynamic> studentAssignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teacher Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grade: ${studentAssignment['letterGrade'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Points: ${(studentAssignment['earnedPoints'] ?? 0).toInt()}/${(studentAssignment['assignment']?['totalPoints'] ?? 0).toInt()}',
            ),
            const SizedBox(height: 16),
            const Text(
              'Feedback:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(studentAssignment['feedback'] ?? 'No feedback provided'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Assignment Detail Sheet
class AssignmentDetailSheet extends StatelessWidget {
  final Map<String, dynamic> studentAssignment;

  const AssignmentDetailSheet({super.key, required this.studentAssignment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignment = studentAssignment['assignment'] ?? studentAssignment;

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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha:0.3),
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
                    // Title and Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            assignment['title'] ?? 'Untitled',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildStatusBadge(
                          studentAssignment['status'] ?? 'pending',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Class and Teacher
                    Row(
                      children: [
                        Icon(
                          Icons.class_,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${assignment['category'] ?? 'General'} • ${assignment['teacherName'] ?? 'Unknown'}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Description
                    if ((assignment['description'] ?? '').isNotEmpty) ...[
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assignment['description'] ?? '',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Instructions
                    Text(
                      'Instructions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      assignment['instructions'] ?? 'No instructions provided',
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
                    _buildDetailRow(
                      'Type',
                      (assignment['type'] ?? 'assignment')
                          .toString()
                          .toUpperCase(),
                    ),
                    _buildDetailRow(
                      'Points',
                      '${(assignment['totalPoints'] ?? 0).toInt()}',
                    ),
                    _buildDetailRow(
                      'Due Date',
                      _formatDetailDate(
                        (assignment['dueDate'] as Timestamp?)?.toDate() ??
                            DateTime.now(),
                      ),
                    ),
                    if (assignment['allowLateSubmissions'] ?? false)
                      _buildDetailRow(
                        'Late Penalty',
                        '${assignment['latePenaltyPercentage'] ?? 0}% per day',
                      ),

                    if (studentAssignment['isSubmitted'] ?? false) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Submission Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (studentAssignment['submission'] != null)
                        _buildDetailRow(
                          'Submitted',
                          _formatDetailDate(
                            studentAssignment['submission']!['submittedAt'],
                          ),
                        ),
                      if (studentAssignment['isGraded'] ?? false) ...[
                        _buildDetailRow(
                          'Grade',
                          studentAssignment['letterGrade'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Points Earned',
                          '${(studentAssignment['earnedPoints'] ?? 0).toInt()}/${(assignment['totalPoints'] ?? 0).toInt()}',
                        ),
                        if (studentAssignment['feedback'] != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Teacher Feedback',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(studentAssignment['feedback']!),
                          ),
                        ],
                      ],
                    ],

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

  Widget _buildStatusBadge(String status) {
    Color color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.grey;
      case 'Overdue':
        return Colors.red;
      case 'Submitted':
        return Colors.orange;
      case 'Graded':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDetailDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
