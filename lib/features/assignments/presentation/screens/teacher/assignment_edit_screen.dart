import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
// Assignment model removed - using Map<String, dynamic> directly
import '../../providers/assignment_provider_simple.dart';
import '../../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../../shared/widgets/common/responsive_layout.dart';
import '../../../../../shared/widgets/custom_radio_list_tile.dart';

class AssignmentEditScreen extends StatefulWidget {
  final String assignmentId;

  const AssignmentEditScreen({
    super.key,
    required this.assignmentId,
  });

  @override
  State<AssignmentEditScreen> createState() => _AssignmentEditScreenState();
}

class _AssignmentEditScreenState extends State<AssignmentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _maxPointsController = TextEditingController();

  Map<String, dynamic>? _assignment;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _dueTime = const TimeOfDay(hour: 23, minute: 59);
  String _selectedType = 'essay';
  bool _allowLateSubmissions = true;
  int _latePenaltyPercentage = 10;
  bool _isLoading = true;
  bool _isSaving = false;

  // Publishing options
  bool _updatePublishStatus = false;
  bool _publishNow = false;
  DateTime? _scheduledPublishDate;
  TimeOfDay? _scheduledPublishTime;

  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _maxPointsController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignment() async {
    final assignmentProvider = context.read<SimpleAssignmentProvider>();

    try {
      final assignment =
          await assignmentProvider.getAssignmentById(widget.assignmentId);
      if (assignment != null && mounted) {
        setState(() {
          _assignment = assignment;
          _titleController.text = assignment['title'] ?? '';
          _descriptionController.text = assignment['description'] ?? '';
          _instructionsController.text = assignment['instructions'] ?? '';
          _maxPointsController.text = (assignment['maxPoints'] ?? 0).toInt().toString();
          _selectedType = assignment['type'] ?? 'essay';
          _dueDate = _parseDateTime(assignment['dueDate']) ?? DateTime.now().add(const Duration(days: 7));
          _dueTime = TimeOfDay.fromDateTime(_parseDateTime(assignment['dueDate']) ?? DateTime.now());
          _allowLateSubmissions = assignment['allowLateSubmissions'] ?? true;
          _latePenaltyPercentage = assignment['latePenaltyPercentage'] ?? 10;

          if (assignment['publishAt'] != null) {
            _scheduledPublishDate = _parseDateTime(assignment['publishAt']);
            _scheduledPublishTime =
                TimeOfDay.fromDateTime(_parseDateTime(assignment['publishAt']) ?? DateTime.now());
          }

          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment not found'),
            backgroundColor: Colors.red,
          ),
        );
        context.pop();
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
        context.pop();
      }
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _selectDueTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );
    if (picked != null && picked != _dueTime) {
      setState(() {
        _dueTime = picked;
      });
    }
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate() || _assignment == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final assignmentProvider = context.read<SimpleAssignmentProvider>();

      // Determine new publish status and date
      DateTime? newPublishAt = _parseDateTime(_assignment!['publishAt']);
      bool newIsPublished = _assignment!['isPublished'] ?? false;

      if (_updatePublishStatus) {
        if (_publishNow) {
          newIsPublished = true;
          newPublishAt = null;
        } else if (_scheduledPublishDate != null &&
            _scheduledPublishTime != null) {
          newIsPublished = false;
          newPublishAt = _combineDateAndTime(
              _scheduledPublishDate!, _scheduledPublishTime!);
        }
      }

      final updatedData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'type': _selectedType,
        'category': _selectedType.toUpperCase(),
        'maxPoints': double.parse(_maxPointsController.text),
        'totalPoints': double.parse(_maxPointsController.text),
        'dueDate': _combineDateAndTime(_dueDate, _dueTime),
        'allowLateSubmissions': _allowLateSubmissions,
        'latePenaltyPercentage': _latePenaltyPercentage,
        'isPublished': newIsPublished,
        'publishAt': newPublishAt,
      };

      final success =
          await assignmentProvider.updateAssignment(widget.assignmentId, updatedData);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Assignment "${_titleController.text.trim()}" updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
      return const Scaffold(
        body: Center(child: Text('Assignment not found')),
      );
    }

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: AdaptiveLayout(
        title: 'Edit Assignment',
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveChanges,
            icon: const Icon(Icons.save),
            label: const Text('Save Changes'),
          ),
        ],
        body: ResponsiveContainer(
          child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Basic Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basic Information',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Assignment Title',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Brief Description',
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Assignment Type',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: ['essay', 'quiz', 'project', 'lab', 'worksheet', 'other'].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Instructions Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                      TextFormField(
                        controller: _instructionsController,
                        decoration: const InputDecoration(
                          labelText: 'Detailed Instructions',
                          hintText:
                              'Provide clear instructions for students...',
                          prefixIcon: Icon(Icons.article),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please provide instructions';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Grading & Submission Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grading & Submission',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maxPointsController,
                        decoration: const InputDecoration(
                          labelText: 'Maximum Points',
                          prefixIcon: Icon(Icons.score),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter points';
                          }
                          final points = int.tryParse(value);
                          if (points == null || points <= 0) {
                            return 'Invalid points';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectDueDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Due Date',
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  '${_dueDate.month}/${_dueDate.day}/${_dueDate.year}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: _selectDueTime,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Due Time',
                                  prefixIcon: Icon(Icons.access_time),
                                ),
                                child: Text(
                                  _dueTime.format(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Allow Late Submissions'),
                        subtitle: const Text(
                            'Students can submit after due date with penalty'),
                        value: _allowLateSubmissions,
                        onChanged: (value) {
                          setState(() {
                            _allowLateSubmissions = value;
                          });
                        },
                      ),
                      if (_allowLateSubmissions)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Row(
                            children: [
                              const Text('Late Penalty: '),
                              SizedBox(
                                width: 100,
                                child: Slider(
                                  value: _latePenaltyPercentage.toDouble(),
                                  min: 0,
                                  max: 50,
                                  divisions: 10,
                                  label: '$_latePenaltyPercentage%',
                                  onChanged: (value) {
                                    setState(() {
                                      _latePenaltyPercentage = value.round();
                                    });
                                  },
                                ),
                              ),
                              Text('$_latePenaltyPercentage% per day'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Publishing Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Publishing Status',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Switch(
                            value: _updatePublishStatus,
                            onChanged: (value) {
                              setState(() {
                                _updatePublishStatus = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (_assignment!['isPublished'] ?? false)
                            ? 'Currently Published'
                            : _assignment!['publishAt'] != null
                                ? 'Scheduled for ${_formatDateTime(_parseDateTime(_assignment!['publishAt']) ?? DateTime.now())}'
                                : 'Currently Unpublished',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_updatePublishStatus) ...[
                        const SizedBox(height: 16),
                        CustomRadioListTile<bool>(
                          title: const Text('Publish Now'),
                          subtitle: const Text(
                              'Make assignment visible to students immediately'),
                          value: true,
                          groupValue: _publishNow,
                          onChanged: (value) {
                            setState(() {
                              _publishNow = value!;
                            });
                          },
                        ),
                        CustomRadioListTile<bool>(
                          title: const Text('Schedule for Later'),
                          subtitle: const Text(
                              'Set a future date for automatic publication'),
                          value: false,
                          groupValue: _publishNow,
                          onChanged: (value) {
                            setState(() {
                              _publishNow = value!;
                              if (!_publishNow &&
                                  _scheduledPublishDate == null) {
                                _scheduledPublishDate =
                                    DateTime.now().add(const Duration(days: 1));
                                _scheduledPublishTime = TimeOfDay.now();
                              }
                            });
                          },
                        ),
                        if (!_publishNow) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                      context: context,
                                      initialDate: _scheduledPublishDate ??
                                          DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: _dueDate,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _scheduledPublishDate = picked;
                                      });
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Publish Date',
                                      prefixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      _scheduledPublishDate != null
                                          ? '${_scheduledPublishDate!.month}/${_scheduledPublishDate!.day}/${_scheduledPublishDate!.year}'
                                          : 'Select date',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final TimeOfDay? picked =
                                        await showTimePicker(
                                      context: context,
                                      initialTime: _scheduledPublishTime ??
                                          TimeOfDay.now(),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _scheduledPublishTime = picked;
                                      });
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Publish Time',
                                      prefixIcon: Icon(Icons.access_time),
                                    ),
                                    child: Text(
                                      _scheduledPublishTime?.format(context) ??
                                          'Select time',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // Helper function to safely convert Timestamp or DateTime
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDateTime(DateTime date) {
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
    final time = TimeOfDay.fromDateTime(date);
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${time.format(context)}';
  }
}
