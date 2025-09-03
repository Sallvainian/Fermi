import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/common/confirmation_dialog.dart';
import '../../domain/models/class_model.dart';
import '../providers/class_provider.dart';

class EditClassDialog extends StatefulWidget {
  final ClassModel classModel;

  const EditClassDialog({super.key, required this.classModel});

  @override
  State<EditClassDialog> createState() => _EditClassDialogState();
}

class _EditClassDialogState extends State<EditClassDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _gradeLevelController;
  late final TextEditingController _roomController;
  late final TextEditingController _scheduleController;
  late final TextEditingController _maxStudentsController;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.classModel.name);
    _subjectController = TextEditingController(text: widget.classModel.subject);
    _gradeLevelController = TextEditingController(
      text: widget.classModel.gradeLevel,
    );
    _roomController = TextEditingController(text: widget.classModel.room ?? '');
    _scheduleController = TextEditingController(
      text: widget.classModel.schedule ?? '',
    );
    _maxStudentsController = TextEditingController(
      text: widget.classModel.maxStudents?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _gradeLevelController.dispose();
    _roomController.dispose();
    _scheduleController.dispose();
    _maxStudentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Edit Class'),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: _handleDelete,
            tooltip: 'Delete Class',
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Class Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name',
                  hintText: 'e.g., Math 101',
                  prefixIcon: Icon(Icons.class_),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a class name';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Subject
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g., Mathematics',
                  prefixIcon: Icon(Icons.subject),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Grade Level
              TextFormField(
                controller: _gradeLevelController,
                decoration: const InputDecoration(
                  labelText: 'Grade Level',
                  hintText: 'e.g., 10th Grade',
                  prefixIcon: Icon(Icons.grade),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a grade level';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Room (Optional)
              TextFormField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: 'Room (Optional)',
                  hintText: 'e.g., Room 201',
                  prefixIcon: Icon(Icons.room),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Schedule (Optional)
              TextFormField(
                controller: _scheduleController,
                decoration: const InputDecoration(
                  labelText: 'Schedule (Optional)',
                  hintText: 'e.g., Mon, Wed, Fri 10:00 AM',
                  prefixIcon: Icon(Icons.schedule),
                ),
              ),
              const SizedBox(height: 16),

              // Max Students (Optional)
              TextFormField(
                controller: _maxStudentsController,
                decoration: const InputDecoration(
                  labelText: 'Max Students (Optional)',
                  hintText: 'e.g., 30',
                  prefixIcon: Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final number = int.tryParse(value);
                    if (number == null || number <= 0) {
                      return 'Please enter a valid number';
                    }
                    if (number < widget.classModel.studentCount) {
                      return 'Cannot be less than current students (${widget.classModel.studentCount})';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Enrollment Code (Read-only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.qr_code,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enrollment Code',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            widget.classModel.enrollmentCode ?? 'No Code',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () => _copyEnrollmentCode(context),
                      tooltip: 'Copy Code',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleUpdate,
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  void _copyEnrollmentCode(BuildContext context) {
    final code = widget.classModel.enrollmentCode;
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

  Future<void> _handleUpdate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final classProvider = context.read<ClassProvider>();
      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Create updated class model
      final updatedClass = widget.classModel.copyWith(
        name: _nameController.text.trim(),
        subject: _subjectController.text.trim(),
        gradeLevel: _gradeLevelController.text.trim(),
        room: _roomController.text.trim().isEmpty
            ? null
            : _roomController.text.trim(),
        schedule: _scheduleController.text.trim().isEmpty
            ? null
            : _scheduleController.text.trim(),
        maxStudents: _maxStudentsController.text.trim().isEmpty
            ? null
            : int.tryParse(_maxStudentsController.text.trim()),
      );

      await classProvider.updateClass(widget.classModel.id, updatedClass);

      if (mounted) {
        navigator.pop(true);
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Class updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating class: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    // Show confirmation dialog
    // ignore: use_build_context_synchronously
    final confirmed = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (BuildContext dialogContext) {
        return ConfirmationDialog(
          title: 'Delete Class',
          content:
              'Are you sure you want to delete "${widget.classModel.name}"? '
              'This action cannot be undone.',
          confirmText: 'Delete',
          confirmColor: Theme.of(dialogContext).colorScheme.error,
          isDestructive: true,
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ignore: use_build_context_synchronously
      final classProvider = context.read<ClassProvider>();
      await classProvider.deleteClass(widget.classModel.id);

      if (mounted) {
        Navigator.of(context).pop(true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Class "${widget.classModel.name}" deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting class: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
