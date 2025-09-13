import 'package:flutter/material.dart';
import '../../data/services/user_management_service.dart';

class ClassAssignmentDialog extends StatefulWidget {
  final List<String> userIds;

  const ClassAssignmentDialog({
    super.key,
    required this.userIds,
  });

  @override
  State<ClassAssignmentDialog> createState() => _ClassAssignmentDialogState();
}

class _ClassAssignmentDialogState extends State<ClassAssignmentDialog> {
  final UserManagementService _userService = UserManagementService();
  final Set<String> _selectedClassIds = {};
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _availableClasses = [];
  List<Map<String, dynamic>> _filteredClasses = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await _userService.getAvailableClasses();
      setState(() {
        _availableClasses = classes;
        _filteredClasses = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading classes: $e')),
      );
    }
  }

  void _filterClasses(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredClasses = _availableClasses;
      } else {
        final searchLower = query.toLowerCase();
        _filteredClasses = _availableClasses.where((classData) {
          final name = (classData['name'] as String).toLowerCase();
          final description = (classData['description'] as String).toLowerCase();
          return name.contains(searchLower) || description.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _assignToClasses() async {
    if (_selectedClassIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one class')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await _userService.bulkAssignToClasses(
        widget.userIds,
        _selectedClassIds.toList(),
      );
      
      if (!success) throw Exception('Failed to assign users to classes');
      
      if (!mounted) return;
      Navigator.pop(context, true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully assigned ${widget.userIds.length} user(s) to ${_selectedClassIds.length} class(es)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning to classes: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.class_, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign to Classes',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Assigning ${widget.userIds.length} user(s)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search classes...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: _filterClasses,
              ),
            ),
            
            // Classes List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredClasses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.class_outlined,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _availableClasses.isEmpty
                                    ? 'No classes available'
                                    : 'No classes match your search',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredClasses.length,
                          itemBuilder: (context, index) {
                            final classData = _filteredClasses[index];
                            final classId = classData['id'] as String;
                            final isSelected = _selectedClassIds.contains(classId);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedClassIds.add(classId);
                                    } else {
                                      _selectedClassIds.remove(classId);
                                    }
                                  });
                                },
                                title: Text(classData['name'] as String),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((classData['description'] as String).isNotEmpty)
                                      Text(
                                        classData['description'] as String,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.people,
                                          size: 14,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${classData['studentCount']} students',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                secondary: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withOpacity(0.1)
                                        : theme.colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.class_,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            
            // Selected Count
            if (_selectedClassIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedClassIds.length} class(es) selected',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving || _selectedClassIds.isEmpty
                        ? null
                        : _assignToClasses,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.assignment_turned_in),
                    label: Text(
                      _isSaving
                          ? 'Assigning...'
                          : 'Assign to ${_selectedClassIds.length} Class(es)',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}