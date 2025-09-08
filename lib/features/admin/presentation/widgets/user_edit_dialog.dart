import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/services/user_management_service.dart';

class UserEditDialog extends StatefulWidget {
  final UserModel user;

  const UserEditDialog({
    super.key,
    required this.user,
  });

  @override
  State<UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<UserEditDialog> {
  final UserManagementService _userService = UserManagementService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _displayNameController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _parentEmailController;
  late TextEditingController _gradeLevelController;
  
  late String _selectedRole;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.user.displayName);
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _emailController = TextEditingController(text: widget.user.email);
    _usernameController = TextEditingController(text: widget.user.username);
    _parentEmailController = TextEditingController(text: widget.user.parentEmail);
    _gradeLevelController = TextEditingController(text: widget.user.gradeLevel);
    _selectedRole = widget.user.role?.name ?? 'student';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _parentEmailController.dispose();
    _gradeLevelController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = <String, dynamic>{};
      
      if (_displayNameController.text != widget.user.displayName) {
        updates['displayName'] = _displayNameController.text;
      }
      if (_firstNameController.text != widget.user.firstName) {
        updates['firstName'] = _firstNameController.text.isEmpty ? null : _firstNameController.text;
      }
      if (_lastNameController.text != widget.user.lastName) {
        updates['lastName'] = _lastNameController.text.isEmpty ? null : _lastNameController.text;
      }
      if (_emailController.text != widget.user.email) {
        updates['email'] = _emailController.text;
      }
      if (_usernameController.text != widget.user.username) {
        updates['username'] = _usernameController.text.isEmpty ? null : _usernameController.text;
      }
      if (_parentEmailController.text != widget.user.parentEmail) {
        updates['parentEmail'] = _parentEmailController.text.isEmpty ? null : _parentEmailController.text;
      }
      if (_gradeLevelController.text != widget.user.gradeLevel) {
        updates['gradeLevel'] = _gradeLevelController.text.isEmpty ? null : _gradeLevelController.text;
      }
      
      if (updates.isNotEmpty) {
        final success = await _userService.updateUser(widget.user.uid, updates);
        if (!success) throw Exception('Failed to update user');
      }
      
      if (_selectedRole != widget.user.role?.name) {
        final success = await _userService.updateUserRole(widget.user.uid, _selectedRole);
        if (!success) throw Exception('Failed to update role');
      }
      
      if (!mounted) return;
      Navigator.pop(context, true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStudent = _selectedRole == 'student';
    
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      widget.user.displayName?.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit User',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'UID: ${widget.user.uid}',
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
            
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role Selection
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'student', child: Text('Student')),
                          DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedRole = value!);
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Display Name
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Display Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Display name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // First and Last Name
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'First Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Last Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_selectedRole != 'student' && (value == null || value.isEmpty)) {
                            return 'Email is required for teachers and admins';
                          }
                          if (value != null && value.isNotEmpty) {
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Username (for students)
                      if (isStudent) ...[
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (isStudent && (value == null || value.isEmpty)) {
                              return 'Username is required for students';
                            }
                            if (value != null && value.isNotEmpty) {
                              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                                return 'Username can only contain letters, numbers, and underscores';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Grade Level (for students)
                      if (isStudent) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _gradeLevelController,
                                decoration: const InputDecoration(
                                  labelText: 'Grade Level',
                                  border: OutlineInputBorder(),
                                  hintText: 'K, 1-12',
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[K0-9]')),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _parentEmailController,
                                decoration: const InputDecoration(
                                  labelText: 'Parent Email',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Account Status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Information',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Created: ${widget.user.createdAt != null ? '${widget.user.createdAt!.month}/${widget.user.createdAt!.day}/${widget.user.createdAt!.year}' : 'Unknown'}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Last Active: ${widget.user.lastActive != null ? _formatLastActive(widget.user.lastActive!) : 'Never'}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            if (widget.user.needsPasswordReset == true) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.warning, size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Password reset required',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(26),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${lastActive.month}/${lastActive.day}/${lastActive.year}';
    }
  }
}