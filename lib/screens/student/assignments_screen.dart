import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/common/error_aware_stream_builder.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_assignment_provider.dart';
import '../../models/assignment.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> with SingleTickerProviderStateMixin {
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
            .read<StudentAssignmentProvider>()
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
    final studentProvider = context.watch<StudentAssignmentProvider>();

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

          // Check if Firebase is initialized
          if (!isFirebaseInitialized) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Firebase not available',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Running in offline mode',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ErrorAwareStreamBuilder<List<StudentAssignment>>(
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
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.colorScheme.outline),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedSubject,
                                    isExpanded: true,
                                    items: _getSubjectsList(assignments).map((subject) {
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
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.outline),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _sortBy,
                                  items: [
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
                          _filterAssignments(_getPendingAssignments(assignments)),
                          emptyMessage: 'No pending assignments! 🎉',
                          emptyIcon: Icons.celebration_outlined,
                        ),
                        _buildAssignmentsList(
                          _filterAssignments(_getSubmittedAssignments(assignments)),
                          emptyMessage: 'No assignments waiting for grades',
                          emptyIcon: Icons.hourglass_empty,
                        ),
                        _buildAssignmentsList(
                          _filterAssignments(_getGradedAssignments(assignments)),
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

  List<String> _getSubjectsList(List<StudentAssignment> assignments) {
    final subjects = <String>{'All Subjects'};
    for (final assignment in assignments) {
      subjects.add(assignment.assignment.category);
    }
    return subjects.toList()..sort();
  }
  
  List<StudentAssignment> _getPendingAssignments(List<StudentAssignment> assignments) {
    return assignments.where((a) => !a.isSubmitted && !a.isOverdue).toList();
  }
  
  List<StudentAssignment> _getSubmittedAssignments(List<StudentAssignment> assignments) {
    return assignments.where((a) => a.isSubmitted && !a.isGraded).toList();
  }
  
  List<StudentAssignment> _getGradedAssignments(List<StudentAssignment> assignments) {
    return assignments.where((a) => a.isGraded).toList();
  }

  List<StudentAssignment> _filterAssignments(List<StudentAssignment> assignments) {
    var filtered = assignments;
    
    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((a) {
        return a.assignment.title.toLowerCase().contains(query) ||
               a.assignment.description.toLowerCase().contains(query) ||
               a.assignment.category.toLowerCase().contains(query);
      }).toList();
    }
    
    // Apply subject filter
    if (_selectedSubject != 'All Subjects') {
      filtered = filtered.where((a) => a.assignment.category == _selectedSubject).toList();
    }
    
    // Apply sorting
    switch (_sortBy) {
      case 'Due Date':
        filtered.sort((a, b) => a.assignment.dueDate.compareTo(b.assignment.dueDate));
        break;
      case 'Subject':
        filtered.sort((a, b) => a.assignment.title.compareTo(b.assignment.title));
        break;
      case 'Priority':
        // Sort by due date as proxy for priority
        filtered.sort((a, b) => a.assignment.dueDate.compareTo(b.assignment.dueDate));
        break;
      case 'Points':
        filtered.sort((a, b) => b.assignment.totalPoints.compareTo(a.assignment.totalPoints));
        break;
    }
    
    return filtered;
  }

  Widget _buildAssignmentsList(
    List<StudentAssignment> assignments, {
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
              color: Theme.of(context).colorScheme.primary.withAlpha(102),
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
        onRefresh: () => context.read<StudentAssignmentProvider>().refresh(),
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

  Widget _buildAssignmentCard(StudentAssignment studentAssignment) {
    final theme = Theme.of(context);
    final assignment = studentAssignment.assignment;
    final dueDate = assignment.dueDate;
    final isOverdue = studentAssignment.isOverdue;
    final isDueSoon = studentAssignment.isDueSoon;

    Color priorityColor = _getPriorityColor(assignment);
    Color statusColor = _getStatusColor(studentAssignment.status);
    IconData statusIcon = _getStatusIcon(studentAssignment.status);

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
                      _getAssignmentIcon(assignment.type),
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
                          assignment.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${assignment.category} • ${assignment.teacherName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Priority Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withAlpha(26),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          studentAssignment.status,
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
                        color: isOverdue ? Colors.red : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDueDate(dueDate),
                        style: TextStyle(
                          color: isOverdue ? Colors.red : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isDueSoon ? FontWeight.bold : FontWeight.normal,
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
                    label: '${assignment.totalPoints.toInt()} pts',
                    color: Colors.blue,
                  ),
                  if (studentAssignment.isGraded && studentAssignment.earnedPoints != null) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.grade,
                      label: '${studentAssignment.earnedPoints!.toInt()}/${assignment.totalPoints.toInt()}',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.school,
                      label: studentAssignment.letterGrade ?? 'N/A',
                      color: _getGradeColor(studentAssignment.letterGrade ?? 'N/A'),
                    ),
                  ],
                ],
              ),

              // Action Buttons
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!studentAssignment.isSubmitted && !studentAssignment.isOverdue)
                    TextButton.icon(
                      onPressed: () {
                        context.push('/student/assignments/${studentAssignment.assignment.id}/submit');
                      },
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Submit'),
                    ),
                  if (studentAssignment.isSubmitted)
                    TextButton.icon(
                      onPressed: () {
                        context.push('/student/assignments/${studentAssignment.assignment.id}/submit');
                      },
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text('View Submission'),
                    ),
                  if (studentAssignment.isGraded && studentAssignment.feedback != null)
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
        color: color.withAlpha(26),
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

  IconData _getAssignmentIcon(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return Icons.home_work_outlined;
      case AssignmentType.essay:
        return Icons.article_outlined;
      case AssignmentType.quiz:
        return Icons.quiz_outlined;
      case AssignmentType.test:
      case AssignmentType.exam:
        return Icons.assignment_outlined;
      case AssignmentType.lab:
        return Icons.science_outlined;
      case AssignmentType.project:
        return Icons.folder_special_outlined;
      case AssignmentType.presentation:
        return Icons.present_to_all_outlined;
      case AssignmentType.classwork:
        return Icons.work_outline;
      default:
        return Icons.assignment_outlined;
    }
  }

  Color _getPriorityColor(Assignment assignment) {
    final daysUntilDue = assignment.dueDate.difference(DateTime.now()).inDays;
    if (daysUntilDue <= 1) return Colors.red;
    if (daysUntilDue <= 3) return Colors.orange;
    return Colors.green;
  }

  String _getPriorityText(Assignment assignment) {
    final daysUntilDue = assignment.dueDate.difference(DateTime.now()).inDays;
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

  void _showAssignmentDetails(StudentAssignment studentAssignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssignmentDetailSheet(studentAssignment: studentAssignment),
    );
  }

  void _showFeedbackDialog(StudentAssignment studentAssignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teacher Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grade: ${studentAssignment.letterGrade ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Points: ${studentAssignment.earnedPoints?.toInt() ?? 0}/${studentAssignment.assignment.totalPoints.toInt()}'),
            const SizedBox(height: 16),
            const Text(
              'Feedback:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(studentAssignment.feedback ?? 'No feedback provided'),
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
  final StudentAssignment studentAssignment;

  const AssignmentDetailSheet({
    super.key,
    required this.studentAssignment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignment = studentAssignment.assignment;

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
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(77),
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
                            assignment.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildStatusBadge(studentAssignment.status),
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
                          '${assignment.category} • ${assignment.teacherName}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Description
                    if (assignment.description.isNotEmpty) ...[
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assignment.description,
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
                      assignment.instructions,
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
                    _buildDetailRow('Type', assignment.type.name.toUpperCase()),
                    _buildDetailRow('Points', '${assignment.totalPoints.toInt()}'),
                    _buildDetailRow('Due Date', _formatDetailDate(assignment.dueDate)),
                    if (assignment.allowLateSubmissions)
                      _buildDetailRow('Late Penalty', '${assignment.latePenaltyPercentage}% per day'),

                    if (studentAssignment.isSubmitted) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Submission Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (studentAssignment.submission != null)
                        _buildDetailRow('Submitted', _formatDetailDate(studentAssignment.submission!.submittedAt)),
                      if (studentAssignment.isGraded) ...[
                        _buildDetailRow('Grade', studentAssignment.letterGrade ?? 'N/A'),
                        _buildDetailRow('Points Earned', '${studentAssignment.earnedPoints?.toInt() ?? 0}/${assignment.totalPoints.toInt()}'),
                        if (studentAssignment.feedback != null) ...[
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
                            child: Text(studentAssignment.feedback!),
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
        color: color.withAlpha(26),
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

  String _formatDetailDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}