import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../student/domain/models/student.dart';
import '../../domain/models/class_model.dart';
import '../providers/class_provider.dart';

class EnrollStudentsDialog extends StatefulWidget {
  final ClassModel classModel;

  const EnrollStudentsDialog({
    super.key,
    required this.classModel,
  });

  @override
  State<EnrollStudentsDialog> createState() => _EnrollStudentsDialogState();
}

class _EnrollStudentsDialogState extends State<EnrollStudentsDialog> {
  final _searchController = TextEditingController();
  final Set<String> _selectedStudentIds = {};
  List<Student> _searchResults = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchStudents() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final classProvider = context.read<ClassProvider>();
      final results = await classProvider.searchAvailableStudents(query);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSearching = false;
      });
    }
  }

  Future<void> _enrollSelectedStudents() async {
    if (_selectedStudentIds.isEmpty) return;

    final classProvider = context.read<ClassProvider>();
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await classProvider.enrollMultipleStudents(
        widget.classModel.id,
        _selectedStudentIds.toList(),
      );

      if (mounted) {
        Navigator.of(context).pop(); // Remove loading dialog
        
        if (success) {
          Navigator.of(context).pop(true); // Close the enroll dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully enrolled ${_selectedStudentIds.length} student(s)'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to enroll students'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Remove loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.person_add),
          const SizedBox(width: 8),
          Text('Add Students to ${widget.classModel.name}'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search students by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchStudents();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => _searchStudents(),
            ),
            const SizedBox(height: 16),
            
            // Selected count
            if (_selectedStudentIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedStudentIds.length} student(s) selected',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            
            // Results list
            Expanded(
              child: _buildResultsList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedStudentIds.isEmpty ? null : _enrollSelectedStudents,
          child: Text('Add ${_selectedStudentIds.length} Student(s)'),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error searching students',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Search for students to add',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Type a student name or email above',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No students found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final student = _searchResults[index];
        final isSelected = _selectedStudentIds.contains(student.id);
        
        return CheckboxListTile(
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedStudentIds.add(student.id);
              } else {
                _selectedStudentIds.remove(student.id);
              }
            });
          },
          title: Text(student.displayName),
          subtitle: Text(student.email),
          secondary: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              student.displayName.isNotEmpty
                  ? student.displayName[0].toUpperCase()
                  : 'S',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}