import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../models/assignment.dart';
import '../../../providers/assignment_provider.dart';
import '../../../widgets/common/adaptive_layout.dart';
import '../../../widgets/common/responsive_layout.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final String assignmentId;

  const AssignmentDetailScreen({
    super.key,
    required this.assignmentId,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  Assignment? _assignment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }

  Future<void> _loadAssignment() async {
    final assignmentProvider = context.read<AssignmentProvider>();
    
    try {
      final assignment = await assignmentProvider.getAssignmentById(widget.assignmentId);
      if (mounted) {
        setState(() {
          _assignment = assignment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assignment Not Found')),
        body: const Center(
          child: Text('Assignment not found or you don\'t have access to it.'),
        ),
      );
    }

    return AdaptiveLayout(
      title: _assignment!.title,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            context.push('/teacher/assignments/${widget.assignmentId}/edit');
          },
          tooltip: 'Edit Assignment',
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'duplicate':
                _duplicateAssignment();
                break;
              case 'archive':
                _archiveAssignment();
                break;
              case 'delete':
                _deleteAssignment();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'duplicate',
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('Duplicate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'archive',
              child: ListTile(
                leading: Icon(Icons.archive),
                title: Text('Archive'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and Publishing Info
              _buildStatusCard(theme),
              const SizedBox(height: 16),

              // Assignment Details Card
              _buildDetailsCard(theme),
              const SizedBox(height: 16),

              // Instructions Card
              _buildInstructionsCard(theme),
              const SizedBox(height: 16),

              // Submission Settings Card
              _buildSubmissionSettingsCard(theme),
              const SizedBox(height: 16),

              // Submission Statistics Card
              _buildStatisticsCard(theme),
              const SizedBox(height: 16),

              // Action Buttons
              _buildActionButtons(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (!_assignment!.isPublished) {
      if (_assignment!.publishAt != null) {
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        statusText = 'Scheduled to publish on ${_formatDate(_assignment!.publishAt ?? DateTime.now())}';
      } else {
        statusColor = Colors.orange;
        statusIcon = Icons.visibility_off;
        statusText = 'Unpublished Draft';
      }
    } else {
      switch (_assignment!.status) {
        case AssignmentStatus.active:
          statusColor = Colors.green;
          statusIcon = Icons.play_circle_outline;
          statusText = 'Published and Active';
          break;
        case AssignmentStatus.completed:
          statusColor = Colors.grey;
          statusIcon = Icons.check_circle_outline;
          statusText = 'Completed';
          break;
        case AssignmentStatus.archived:
          statusColor = Colors.grey;
          statusIcon = Icons.archive_outlined;
          statusText = 'Archived';
          break;
        default:
          statusColor = Colors.grey;
          statusIcon = Icons.info_outline;
          statusText = _assignment!.status.name;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (_assignment!.isPublished)
                    Text(
                      'Published on ${_formatDate(_assignment!.createdAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (!_assignment!.isPublished)
              FilledButton.icon(
                onPressed: _publishAssignment,
                icon: const Icon(Icons.publish),
                label: const Text('Publish Now'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assignment Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Type', _assignment!.type.name.toUpperCase()),
            _buildDetailRow('Category', _assignment!.category),
            _buildDetailRow('Due Date', _formatDateTime(_assignment!.dueDate)),
            _buildDetailRow('Points', '${_assignment!.maxPoints.toInt()}'),
            _buildDetailRow('Created', _formatDate(_assignment!.createdAt)),
            if (_assignment!.updatedAt != null)
              _buildDetailRow('Last Updated', _formatDate(_assignment!.updatedAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _assignment!.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_assignment!.instructions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                _assignment!.instructions,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionSettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submission Settings',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                _assignment!.allowLateSubmissions 
                    ? Icons.check_circle 
                    : Icons.cancel,
                color: _assignment!.allowLateSubmissions 
                    ? Colors.green 
                    : Colors.red,
              ),
              title: const Text('Late Submissions'),
              subtitle: Text(
                _assignment!.allowLateSubmissions
                    ? 'Allowed with ${_assignment!.latePenaltyPercentage}% penalty per day'
                    : 'Not allowed',
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(ThemeData theme) {
    // These would come from real data in production
    const totalStudents = 30;
    const submittedCount = 18;
    const gradedCount = 12;
    const averageScore = 85.5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submission Statistics',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Submitted',
                    '$submittedCount/$totalStudents',
                    Colors.blue,
                    Icons.upload_file,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'Graded',
                    '$gradedCount/$submittedCount',
                    Colors.green,
                    Icons.grading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Average Score',
                    '${averageScore.toStringAsFixed(1)}%',
                    Colors.purple,
                    Icons.analytics,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'Pending',
                    '${totalStudents - submittedCount}',
                    Colors.orange,
                    Icons.pending,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              context.go('/teacher/gradebook?assignmentId=${widget.assignmentId}');
            },
            icon: const Icon(Icons.grading),
            label: const Text('Grade Submissions'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              // Navigate to submissions view
              context.go('/teacher/assignments/${widget.assignmentId}/submissions');
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('View Submissions'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
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
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final time = TimeOfDay.fromDateTime(date);
    return '${_formatDate(date)} at ${time.format(context)}';
  }

  Future<void> _publishAssignment() async {
    final assignmentProvider = context.read<AssignmentProvider>();
    
    try {
      await assignmentProvider.togglePublishStatus(widget.assignmentId, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment published successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAssignment(); // Reload to update UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _duplicateAssignment() async {
    // TODO: Implement assignment duplication
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicate functionality coming soon')),
    );
  }

  Future<void> _archiveAssignment() async {
    final assignmentProvider = context.read<AssignmentProvider>();
    
    try {
      await assignmentProvider.updateAssignmentStatus(
        widget.assignmentId, 
        AssignmentStatus.archived,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment archived successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/teacher/assignments');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAssignment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: const Text(
          'Are you sure you want to delete this assignment? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final assignmentProvider = context.read<AssignmentProvider>();
      
      try {
        await assignmentProvider.deleteAssignment(widget.assignmentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/teacher/assignments');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting assignment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}