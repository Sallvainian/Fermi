/// Dialog widget for creating a new class.
/// 
/// This widget provides a form for teachers to create new classes
/// with all required information including enrollment code generation.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Dialog for creating a new class with form validation.
/// 
/// Features:
/// - Subject selection from predefined list
/// - Grade level selection
/// - Schedule input
/// - Room location
/// - Academic year and semester
/// - Optional student capacity limit
/// - Auto-generated enrollment code
class CreateClassDialog extends StatefulWidget {
  const CreateClassDialog({super.key});

  @override
  State<CreateClassDialog> createState() => _CreateClassDialogState();
}

class _CreateClassDialogState extends State<CreateClassDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _roomController = TextEditingController();
  final _periodController = TextEditingController();
  
  String _selectedGradeLevel = '6th Grade';
  
  bool _isLoading = false;
  
  // Grade levels
  final List<String> _gradeLevels = [
    '6th Grade',
    '7th Grade', 
    '8th Grade',
  ];
  
  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _roomController.dispose();
    _periodController.dispose();
    super.dispose();
  }
  
  String _getCurrentAcademicYear() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    
    // If it's after July, we're in the next academic year
    if (month >= 7) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }
  
  Future<void> _createClass() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final classProvider = context.read<ClassProvider>();
      final authProvider = context.read<AuthProvider>();
      final teacherId = authProvider.userModel?.uid;
      
      if (teacherId == null) {
        throw Exception('No teacher ID found');
      }
      
      final success = await classProvider.createClassFromParams(
        name: _nameController.text.trim(),
        subject: _nameController.text.trim(), // Use class name as subject
        gradeLevel: _selectedGradeLevel,
        description: _schoolController.text.trim().isEmpty 
            ? null 
            : 'School: ${_schoolController.text.trim()}',
        room: _roomController.text.trim().isEmpty 
            ? null 
            : _roomController.text.trim(),
        schedule: _periodController.text.trim().isEmpty 
            ? null 
            : 'Period ${_periodController.text.trim()}',
        academicYear: _getCurrentAcademicYear(),
        teacherId: teacherId,
      );
      
      if (mounted && success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating class: ${e.toString()}'),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = screenHeight * 0.95; // Use 95% of screen height max
    
    final isWeb = Theme.of(context).platform == TargetPlatform.windows || 
                   Theme.of(context).platform == TargetPlatform.macOS || 
                   Theme.of(context).platform == TargetPlatform.linux;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Make dialog wider on web - 800px or 80% of screen width
    final dialogWidth = isWeb 
        ? (screenWidth > 1000 ? 800.0 : screenWidth * 0.8)
        : (screenWidth > 500 ? 500.0 : screenWidth * 0.9);
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWeb ? 40 : 16, 
        vertical: 16
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight,
          maxWidth: dialogWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Create New Class',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Class Name
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Class Name*',
                            hintText: 'e.g., Advanced Mathematics',
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
                        const SizedBox(height: 12),
                        
                        // School and Grade Level
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _schoolController,
                                decoration: const InputDecoration(
                                  labelText: 'School',
                                  hintText: 'e.g., Lincoln Middle School',
                                  prefixIcon: Icon(Icons.school),
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedGradeLevel,
                                decoration: const InputDecoration(
                                  labelText: 'Grade Level*',
                                  prefixIcon: Icon(Icons.grade),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                isExpanded: true,
                                items: _gradeLevels.map((grade) {
                                  return DropdownMenuItem(
                                    value: grade,
                                    child: Text(
                                      grade,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => _selectedGradeLevel = value!);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Room and Period
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _roomController,
                                decoration: const InputDecoration(
                                  labelText: 'Room Number',
                                  hintText: 'e.g., 204',
                                  prefixIcon: Icon(Icons.room),
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _periodController,
                                decoration: const InputDecoration(
                                  labelText: 'Period',
                                  hintText: 'e.g., 3',
                                  prefixIcon: Icon(Icons.schedule),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Info box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'An enrollment code will be automatically generated for students to join this class.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Actions
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isLoading ? null : _createClass,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Class'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}