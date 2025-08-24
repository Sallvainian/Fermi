import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
// import '../../../domain/models/assignment.dart'; // Using Map<String, dynamic> instead
// import '../../../domain/models/submission.dart'; // Using Map<String, dynamic> instead
import '../../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../providers/student_assignment_provider_simple.dart';
import '../../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../../shared/widgets/common/responsive_layout.dart';

class AssignmentSubmissionScreen extends StatefulWidget {
  final String assignmentId;

  const AssignmentSubmissionScreen({
    super.key,
    required this.assignmentId,
  });

  @override
  State<AssignmentSubmissionScreen> createState() =>
      _AssignmentSubmissionScreenState();
}

class _AssignmentSubmissionScreenState
    extends State<AssignmentSubmissionScreen> {
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _studentAssignment;
  bool _isLoading = true;
  bool _isSubmitting = false;
  PlatformFile? _selectedFile;
  String? _fileError;

  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignment() async {
    final studentProvider = context.read<SimpleStudentAssignmentProvider>();

    try {
      await studentProvider.loadAssignmentDetails(widget.assignmentId);
      final assignment = studentProvider.getAssignmentById(widget.assignmentId);

      if (mounted) {
        setState(() {
          _studentAssignment = assignment;
          _isLoading = false;

          // If there's an existing submission, load its content
          if (assignment?['submission']?['textContent'] != null) {
            _textController.text = assignment!['submission']!['textContent']!;
          }
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

  Future<void> _pickFile() async {
    try {
      setState(() => _fileError = null);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size (max 10MB)
        if (file.size > 10 * 1024 * 1024) {
          setState(() => _fileError = 'File size must be less than 10MB');
          return;
        }

        setState(() => _selectedFile = file);
      }
    } catch (e) {
      setState(() => _fileError = 'Error selecting file: $e');
    }
  }

  Future<void> _submitAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_textController.text.trim().isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide text content or upload a file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final studentProvider = context.read<SimpleStudentAssignmentProvider>();

      final success = await studentProvider.submitAssignment(
        assignmentId: widget.assignmentId,
        studentName: authProvider.userModel?.displayName ?? 'Student',
        textContent: _textController.text.trim(),
        file: _selectedFile,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit: ${studentProvider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _updateSubmission() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // This would need to be implemented in the provider
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update functionality coming soon'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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

    if (_studentAssignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assignment Not Found')),
        body: const Center(
          child: Text('Assignment not found or you don\'t have access to it.'),
        ),
      );
    }

    final assignment = _studentAssignment!['assignment'];
    final isSubmitted = _studentAssignment!['isSubmitted'] ?? false;
    final isOverdue = _studentAssignment!['isOverdue'] ?? false;
    final canSubmit = !isOverdue || (assignment['allowLateSubmissions'] ?? false);

    return AdaptiveLayout(
      title: isSubmitted ? 'View Submission' : 'Submit Assignment',
      body: ResponsiveContainer(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assignment Info Card
                _buildAssignmentInfoCard(theme, assignment),
                const SizedBox(height: 16),

                // Submission Status Card (if already submitted)
                if (isSubmitted && _studentAssignment!['submission'] != null)
                  _buildSubmissionStatusCard(theme),
                const SizedBox(height: 16),

                // Submission Form
                if (!isSubmitted ||
                    _studentAssignment!['submission']?['status'] ==
                        'submitted')
                  _buildSubmissionForm(theme, assignment, canSubmit),

                // Grading Info (if graded)
                if (_studentAssignment!['isGraded'] ?? false) _buildGradingCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentInfoCard(ThemeData theme, Map<String, dynamic> assignment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getAssignmentIcon(assignment['type']),
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment['title'] ?? 'Untitled Assignment',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${assignment['category'] ?? ''} • ${assignment['teacherName'] ?? ''}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.calendar_today,
              'Due Date',
              _formatDateTime(assignment['dueDate']),
              (_studentAssignment!['isOverdue'] ?? false) ? Colors.red : null,
            ),
            _buildInfoRow(
              Icons.star,
              'Points',
              '${assignment['totalPoints']?.toInt() ?? 0} points',
              Colors.blue,
            ),
            if (assignment['allowLateSubmissions'] ?? false)
              _buildInfoRow(
                Icons.warning,
                'Late Policy',
                '${assignment['latePenaltyPercentage'] ?? 0}% penalty per day',
                Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionStatusCard(ThemeData theme) {
    final submission = _studentAssignment!['submission']!;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Submitted',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Submitted on ${_formatDateTime(submission.submittedAt)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            if (submission.fileName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.attach_file,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      submission.fileName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionForm(
      ThemeData theme, Map<String, dynamic> assignment, bool canSubmit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Submission',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assignment['instructions'] ?? 'No instructions provided',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Text Input
            TextFormField(
              controller: _textController,
              enabled: canSubmit && !_isSubmitting,
              decoration: InputDecoration(
                labelText: 'Answer / Text Submission',
                hintText: 'Type your answer or paste your work here...',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                counterText: '${_textController.text.length} characters',
              ),
              maxLines: 10,
              minLines: 5,
              maxLength: 5000,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              validator: (value) {
                if ((value == null || value.trim().isEmpty) &&
                    _selectedFile == null) {
                  return 'Please provide an answer or upload a file';
                }
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // File Upload Section
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canSubmit && !_isSubmitting ? _pickFile : null,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                        _selectedFile == null ? 'Attach File' : 'Change File'),
                  ),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: canSubmit && !_isSubmitting
                        ? () => setState(() => _selectedFile = null)
                        : null,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Remove file',
                  ),
                ],
              ],
            ),

            // Selected File Display
            if (_selectedFile != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFile!.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatFileSize(_selectedFile!.size),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // File Error
            if (_fileError != null) ...[
              const SizedBox(height: 8),
              Text(
                _fileError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              'Accepted formats: PDF, DOC, DOCX, TXT, PNG, JPG, JPEG (Max 10MB)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canSubmit && !_isSubmitting
                    ? ((_studentAssignment!['isSubmitted'] ?? false)
                        ? _updateSubmission
                        : _submitAssignment)
                    : null,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon((_studentAssignment!['isSubmitted'] ?? false)
                        ? Icons.update
                        : Icons.upload),
                label: Text(
                  _isSubmitting
                      ? 'Submitting...'
                      : ((_studentAssignment!['isSubmitted'] ?? false)
                          ? 'Update Submission'
                          : 'Submit Assignment'),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            if (!canSubmit && (_studentAssignment!['isOverdue'] ?? false)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This assignment is overdue and late submissions are not allowed.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGradingCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.grade,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Grading',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Grade Circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _getGradeColor(_studentAssignment!['letterGrade'] ?? 'N/A')
                            .withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _studentAssignment!['letterGrade'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _getGradeColor(
                                _studentAssignment!['letterGrade'] ?? 'N/A'),
                          ),
                        ),
                        Text(
                          '${_studentAssignment!['percentage']?.toStringAsFixed(1) ?? 0}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getGradeColor(
                                _studentAssignment!['letterGrade'] ?? 'N/A'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Grade Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGradeRow(
                        'Points Earned',
                        '${_studentAssignment!['earnedPoints']?.toInt() ?? 0} / ${_studentAssignment!['assignment']?['totalPoints']?.toInt() ?? 0}',
                      ),
                      const SizedBox(height: 8),
                      if (_studentAssignment!['submission']?['gradedAt'] != null)
                        _buildGradeRow(
                          'Graded On',
                          _formatDate(
                              _studentAssignment!['submission']!['gradedAt']!),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_studentAssignment!['feedback'] != null) ...[
              const SizedBox(height: 16),
              const Divider(),
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
                child: Text(
                  _studentAssignment!['feedback']!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: color ?? Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeRow(String label, String value) {
    return Row(
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
    );
  }

  IconData _getAssignmentIcon(String? type) {
    switch (type) {
      case 'homework':
        return Icons.home_work_outlined;
      case 'essay':
        return Icons.article_outlined;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'test':
      case 'exam':
        return Icons.assignment_outlined;
      case 'lab':
        return Icons.science_outlined;
      case 'project':
        return Icons.folder_special_outlined;
      case 'presentation':
        return Icons.present_to_all_outlined;
      case 'classwork':
        return Icons.work_outline;
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

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final time = TimeOfDay.fromDateTime(date);
    return '${_formatDate(date)} at ${time.format(context)}';
  }

  String _formatFileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }
}
