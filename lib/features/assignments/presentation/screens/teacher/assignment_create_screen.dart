import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/models/assignment.dart';
import '../../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../../../../shared/widgets/custom_radio_list_tile.dart';

class AssignmentCreateScreen extends StatefulWidget {
  final String? classId;
  
  const AssignmentCreateScreen({
    super.key,
    this.classId,
  });

  @override
  State<AssignmentCreateScreen> createState() => _AssignmentCreateScreenState();
}

class _AssignmentCreateScreenState extends State<AssignmentCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _maxPointsController = TextEditingController();
  
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _dueTime = const TimeOfDay(hour: 23, minute: 59);
  AssignmentType _selectedType = AssignmentType.essay;
  AssignmentStatus _selectedStatus = AssignmentStatus.draft;
  bool _isPublished = false;
  bool _allowLateSubmissions = true;
  int _latePenaltyPercentage = 10;
  bool _isLoading = false;
  
  // Scheduled publishing
  int _publishOption = 0; // 0: draft, 1: immediate, 2: scheduled
  DateTime _publishDate = DateTime.now();
  TimeOfDay _publishTime = TimeOfDay.now();


  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _maxPointsController.dispose();
    super.dispose();
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

  DateTime _combineDateAndTime() {
    return DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );
  }

  Future<void> _createAssignment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }


    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final assignmentProvider = context.read<AssignmentProvider>();
      final user = authProvider.userModel;
      
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Determine publish at date based on publish option
      DateTime? publishAt;
      
      if (_publishOption == 1) {
        // Publish immediately
        publishAt = null;
      } else if (_publishOption == 2) {
        // Scheduled publishing
        publishAt = DateTime(
          _publishDate.year,
          _publishDate.month,
          _publishDate.day,
          _publishTime.hour,
          _publishTime.minute,
        );
      }
      
      final assignment = Assignment(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        instructions: _instructionsController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        category: _selectedType.name.toUpperCase(),
        classId: widget.classId ?? '',
        teacherId: user.uid,
        teacherName: user.displayName ?? 'Unknown Teacher',
        totalPoints: double.parse(_maxPointsController.text),
        maxPoints: double.parse(_maxPointsController.text),
        dueDate: _combineDateAndTime(),
        isPublished: _isPublished,
        allowLateSubmissions: _allowLateSubmissions,
        latePenaltyPercentage: _latePenaltyPercentage,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        publishAt: publishAt,
      );

      final success = await assignmentProvider.createAssignment(assignment);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment "${assignment.title}" created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/teacher/assignments');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Create Assignment'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _createAssignment,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basic Information',
                      style: theme.textTheme.titleLarge,
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
                    DropdownButtonFormField<AssignmentType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Assignment Type',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: AssignmentType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.name.toUpperCase()),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Detailed Instructions',
                        hintText: 'Provide clear instructions for students...',
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grading & Submission',
                      style: theme.textTheme.titleLarge,
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
                      subtitle: const Text('Students can submit after due date with penalty'),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Publishing Options',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    CustomRadioListTile<int>(
                      title: const Text('Save as Draft'),
                      subtitle: const Text('Assignment will not be visible to students'),
                      value: 0,
                      groupValue: _publishOption,
                      onChanged: (value) {
                        setState(() {
                          _publishOption = value!;
                          _isPublished = false;
                          _selectedStatus = AssignmentStatus.draft;
                        });
                      },
                    ),
                    CustomRadioListTile<int>(
                      title: const Text('Publish Immediately'),
                      subtitle: const Text('Students can see and submit the assignment'),
                      value: 1,
                      groupValue: _publishOption,
                      onChanged: (value) {
                        setState(() {
                          _publishOption = value!;
                          _isPublished = true;
                          _selectedStatus = AssignmentStatus.active;
                        });
                      },
                    ),
                    CustomRadioListTile<int>(
                      title: const Text('Schedule for Later'),
                      subtitle: const Text('Assignment will become visible at a future date'),
                      value: 2,
                      groupValue: _publishOption,
                      onChanged: (value) {
                        setState(() {
                          _publishOption = value!;
                          _isPublished = false;
                          _selectedStatus = AssignmentStatus.draft;
                        });
                      },
                    ),
                    if (_publishOption == 2) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _publishDate,
                                  firstDate: DateTime.now(),
                                  lastDate: _dueDate,
                                );
                                if (picked != null) {
                                  setState(() {
                                    _publishDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Publish Date',
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  '${_publishDate.month}/${_publishDate.day}/${_publishDate.year}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: _publishTime,
                                );
                                if (picked != null) {
                                  setState(() {
                                    _publishTime = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Publish Time',
                                  prefixIcon: Icon(Icons.access_time),
                                ),
                                child: Text(
                                  _publishTime.format(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}