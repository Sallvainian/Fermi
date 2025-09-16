import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../providers/assignment_provider_simple.dart';
import '../../../../../shared/widgets/custom_radio_list_tile.dart';
import '../../../../../shared/models/user_model.dart';
import '../../../domain/models/assignment.dart';

class AssignmentCreateScreen extends StatefulWidget {
  final String? classId;

  const AssignmentCreateScreen({super.key, this.classId});

  @override
  State<AssignmentCreateScreen> createState() => _AssignmentCreateScreenState();
}

class _AssignmentCreateScreenState extends State<AssignmentCreateScreen> 
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _maxPointsController = TextEditingController(text: '100');

  late TabController _tabController;
  
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _dueTime = const TimeOfDay(hour: 23, minute: 59);
  AssignmentType _selectedType = AssignmentType.homework;
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
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _maxPointsController.dispose();
    _tabController.dispose();
    super.dispose();
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

  IconData _getTypeIcon(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return Icons.home_work;
      case AssignmentType.quiz:
        return Icons.quiz;
      case AssignmentType.test:
        return Icons.assignment;
      case AssignmentType.project:
        return Icons.architecture;
      case AssignmentType.lab:
        return Icons.science;
      case AssignmentType.classwork:
        return Icons.school;
      case AssignmentType.activity:
        return Icons.sports_handball;
    }
  }

  Color _getTypeColor(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return Colors.blue;
      case AssignmentType.quiz:
        return Colors.purple;
      case AssignmentType.test:
        return Colors.red;
      case AssignmentType.project:
        return Colors.green;
      case AssignmentType.lab:
        return Colors.orange;
      case AssignmentType.classwork:
        return Colors.teal;
      case AssignmentType.activity:
        return Colors.pink;
    }
  }

  String _getTypeLabel(AssignmentType type) {
    switch (type) {
      case AssignmentType.homework:
        return 'Homework';
      case AssignmentType.quiz:
        return 'Quiz';
      case AssignmentType.test:
        return 'Test';
      case AssignmentType.project:
        return 'Project';
      case AssignmentType.lab:
        return 'Lab';
      case AssignmentType.classwork:
        return 'Classwork';
      case AssignmentType.activity:
        return 'Activity';
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _getTypeColor(_selectedType),
            ),
          ),
          child: child!,
        );
      },
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _getTypeColor(_selectedType),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dueTime) {
      setState(() {
        _dueTime = picked;
      });
    }
  }

  Future<void> _createAssignment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final assignmentProvider = context.read<SimpleAssignmentProvider>();
      final user = authProvider.userModel;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Determine publish at date based on publish option
      DateTime? publishAt;
      
      if (_publishOption == 1) {
        // Publish immediately
        publishAt = null;
        _isPublished = true;
        _selectedStatus = AssignmentStatus.active;
      } else if (_publishOption == 2) {
        // Scheduled publishing
        publishAt = _combineDateAndTime(_publishDate, _publishTime);
        _isPublished = false;
        _selectedStatus = AssignmentStatus.draft;
      } else {
        // Save as draft
        _isPublished = false;
        _selectedStatus = AssignmentStatus.draft;
      }

      final assignment = {
        'id': '',
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'type': _selectedType.name,
        'status': _selectedStatus.name,
        'category': _getTypeLabel(_selectedType).toUpperCase(),
        'classId': widget.classId ?? '',
        'teacherId': user.uid,
        'teacherName': user.displayNameOrFallback,
        'totalPoints': double.parse(_maxPointsController.text),
        'maxPoints': double.parse(_maxPointsController.text),
        'dueDate': _combineDateAndTime(_dueDate, _dueTime),
        'isPublished': _isPublished,
        'allowLateSubmissions': _allowLateSubmissions,
        'latePenaltyPercentage': _latePenaltyPercentage,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'publishAt': publishAt,
      };

      final success = await assignmentProvider.createAssignment(assignment);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assignment "${assignment['title']}" created successfully',
            ),
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
    final isDesktop = MediaQuery.of(context).size.width > 1200;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: theme.scaffoldBackgroundColor,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/teacher/assignments');
              }
            },
            tooltip: 'Cancel',
          ),
          title: Row(
            children: [
              Icon(
                _getTypeIcon(_selectedType),
                color: _getTypeColor(_selectedType),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('New Assignment'),
            ],
          ),
          actions: [
            FilledButton.icon(
              onPressed: _isLoading ? null : _createAssignment,
              icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish),
              label: Text(_publishOption == 1 ? 'Publish' : 'Save'),
              style: FilledButton.styleFrom(
                backgroundColor: _getTypeColor(_selectedType),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    color: theme.colorScheme.surface,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: _getTypeColor(_selectedType),
                      labelColor: _getTypeColor(_selectedType),
                      tabs: const [
                        Tab(text: 'DETAILS', icon: Icon(Icons.edit)),
                        Tab(text: 'GRADING', icon: Icon(Icons.grade)),
                        Tab(text: 'SETTINGS', icon: Icon(Icons.settings)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Details Tab
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            // Assignment Type Selection
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Assignment Type',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: AssignmentType.values.map((type) {
                                        final isSelected = _selectedType == type;
                                        return ChoiceChip(
                                          avatar: Icon(
                                            _getTypeIcon(type),
                                            size: 18,
                                            color: isSelected 
                                              ? Colors.white 
                                              : _getTypeColor(type),
                                          ),
                                          label: Text(_getTypeLabel(type)),
                                          selected: isSelected,
                                          selectedColor: _getTypeColor(type),
                                          backgroundColor: _getTypeColor(type).withOpacity(0.1),
                                          labelStyle: TextStyle(
                                            color: isSelected 
                                              ? Colors.white 
                                              : _getTypeColor(type),
                                            fontWeight: isSelected 
                                              ? FontWeight.bold 
                                              : FontWeight.normal,
                                          ),
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedType = type;
                                              });
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Title and Description
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Basic Information',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _titleController,
                                      decoration: InputDecoration(
                                        labelText: 'Assignment Title',
                                        hintText: 'Enter a clear, descriptive title',
                                        prefixIcon: Icon(
                                          Icons.title,
                                          color: _getTypeColor(_selectedType),
                                        ),
                                        border: const OutlineInputBorder(),
                                      ),
                                      textInputAction: TextInputAction.next,
                                      textCapitalization: TextCapitalization.sentences,
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
                                      decoration: InputDecoration(
                                        labelText: 'Brief Description',
                                        hintText: 'What is this assignment about?',
                                        prefixIcon: Icon(
                                          Icons.description,
                                          color: _getTypeColor(_selectedType),
                                        ),
                                        border: const OutlineInputBorder(),
                                      ),
                                      maxLines: 3,
                                      textInputAction: TextInputAction.next,
                                      textCapitalization: TextCapitalization.sentences,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a description';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _instructionsController,
                                      decoration: InputDecoration(
                                        labelText: 'Detailed Instructions',
                                        hintText: 'Step-by-step instructions for students...',
                                        prefixIcon: Icon(
                                          Icons.list_alt,
                                          color: _getTypeColor(_selectedType),
                                        ),
                                        border: const OutlineInputBorder(),
                                      ),
                                      maxLines: 5,
                                      textCapitalization: TextCapitalization.sentences,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Due Date and Time
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Due Date & Time',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: _selectDueDate,
                                            borderRadius: BorderRadius.circular(8),
                                            child: InputDecorator(
                                              decoration: InputDecoration(
                                                labelText: 'Due Date',
                                                prefixIcon: Icon(
                                                  Icons.calendar_today,
                                                  color: _getTypeColor(_selectedType),
                                                ),
                                                border: const OutlineInputBorder(),
                                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                              ),
                                              child: Text(
                                                '${_dueDate.month}/${_dueDate.day}/${_dueDate.year}',
                                                style: theme.textTheme.bodyLarge,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: InkWell(
                                            onTap: _selectDueTime,
                                            borderRadius: BorderRadius.circular(8),
                                            child: InputDecorator(
                                              decoration: InputDecoration(
                                                labelText: 'Due Time',
                                                prefixIcon: Icon(
                                                  Icons.access_time,
                                                  color: _getTypeColor(_selectedType),
                                                ),
                                                border: const OutlineInputBorder(),
                                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                              ),
                                              child: Text(
                                                _dueTime.format(context),
                                                style: theme.textTheme.bodyLarge,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 16,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Students will have until ${_dueTime.format(context)} on ${_dueDate.month}/${_dueDate.day}/${_dueDate.year} to submit',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Grading Tab
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Points Configuration',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _maxPointsController,
                                      decoration: InputDecoration(
                                        labelText: 'Total Points',
                                        hintText: '100',
                                        prefixIcon: Icon(
                                          Icons.star,
                                          color: _getTypeColor(_selectedType),
                                        ),
                                        border: const OutlineInputBorder(),
                                        suffixText: 'points',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter total points';
                                        }
                                        final points = int.tryParse(value);
                                        if (points == null || points <= 0) {
                                          return 'Please enter a valid number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Late Submission Policy',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SwitchListTile(
                                      title: const Text('Allow Late Submissions'),
                                      subtitle: const Text('Students can submit after the due date with penalty'),
                                      value: _allowLateSubmissions,
                                      activeColor: _getTypeColor(_selectedType),
                                      onChanged: (value) {
                                        setState(() {
                                          _allowLateSubmissions = value;
                                        });
                                      },
                                    ),
                                    if (_allowLateSubmissions) ...[
                                      const Divider(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Late Penalty: $_latePenaltyPercentage% per day',
                                              style: theme.textTheme.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Slider(
                                              value: _latePenaltyPercentage.toDouble(),
                                              min: 0,
                                              max: 50,
                                              divisions: 10,
                                              label: '$_latePenaltyPercentage%',
                                              activeColor: _getTypeColor(_selectedType),
                                              onChanged: (value) {
                                                setState(() {
                                                  _latePenaltyPercentage = value.round();
                                                });
                                              },
                                            ),
                                            Text(
                                              'Students will lose $_latePenaltyPercentage% of their score for each day late',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Settings Tab
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Publishing Options',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    RadioListTile<int>(
                                      title: const Text('Save as Draft'),
                                      subtitle: const Text('Assignment will not be visible to students'),
                                      value: 0,
                                      groupValue: _publishOption,
                                      activeColor: _getTypeColor(_selectedType),
                                      onChanged: (value) {
                                        setState(() {
                                          _publishOption = value!;
                                        });
                                      },
                                    ),
                                    RadioListTile<int>(
                                      title: const Text('Publish Immediately'),
                                      subtitle: const Text('Students can see and submit the assignment now'),
                                      value: 1,
                                      groupValue: _publishOption,
                                      activeColor: _getTypeColor(_selectedType),
                                      onChanged: (value) {
                                        setState(() {
                                          _publishOption = value!;
                                        });
                                      },
                                    ),
                                    RadioListTile<int>(
                                      title: const Text('Schedule for Later'),
                                      subtitle: const Text('Assignment becomes visible at a future date'),
                                      value: 2,
                                      groupValue: _publishOption,
                                      activeColor: _getTypeColor(_selectedType),
                                      onChanged: (value) {
                                        setState(() {
                                          _publishOption = value!;
                                        });
                                      },
                                    ),
                                    if (_publishOption == 2) ...[
                                      const Divider(),
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
                                              borderRadius: BorderRadius.circular(8),
                                              child: InputDecorator(
                                                decoration: InputDecoration(
                                                  labelText: 'Publish Date',
                                                  prefixIcon: Icon(
                                                    Icons.event,
                                                    color: _getTypeColor(_selectedType),
                                                  ),
                                                  border: const OutlineInputBorder(),
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
                                              borderRadius: BorderRadius.circular(8),
                                              child: InputDecorator(
                                                decoration: InputDecoration(
                                                  labelText: 'Publish Time',
                                                  prefixIcon: Icon(
                                                    Icons.schedule,
                                                    color: _getTypeColor(_selectedType),
                                                  ),
                                                  border: const OutlineInputBorder(),
                                                ),
                                                child: Text(_publishTime.format(context)),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}