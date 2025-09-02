import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../features/auth/data/services/username_auth_service.dart';
import '../../../../shared/models/user_model.dart';

class ManageStudentAccountsScreen extends StatefulWidget {
  const ManageStudentAccountsScreen({super.key});

  @override
  State<ManageStudentAccountsScreen> createState() => _ManageStudentAccountsScreenState();
}

class _ManageStudentAccountsScreenState extends State<ManageStudentAccountsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameAuthService = UsernameAuthService();
  
  bool _isLoading = false;
  bool _obscurePassword = false;
  String? _generatedUsername;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _generateUsername() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    
    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter first and last name')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Generate base username
      final baseUsername = _usernameAuthService.generateUsername(firstName, lastName);
      
      // Get next available username
      final username = await _usernameAuthService.getNextAvailableUsername(baseUsername);
      
      setState(() {
        _generatedUsername = username;
        _usernameController.text = username;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating username: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _generatePassword() {
    // Secure password generation using cryptographically secure random
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final password = List.generate(8, (_) {
      return chars[random.nextInt(chars.length)];
    }).join();
    
    _passwordController.text = password;
  }

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      
      await authProvider.createStudentAccount(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      
      if (mounted) {
        // Show success dialog with credentials
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Student Account Created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account created successfully!'),
                const SizedBox(height: 16),
                SelectableText('Username: ${_usernameController.text}'),
                SelectableText('Password: ${_passwordController.text}'),
                const SizedBox(height: 16),
                const Text('Save these credentials for the student.', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Copy to clipboard
                  Clipboard.setData(ClipboardData(
                    text: 'Username: ${_usernameController.text}\nPassword: ${_passwordController.text}',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Credentials copied to clipboard')),
                  );
                },
                child: const Text('Copy'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Clear form
                  _formKey.currentState!.reset();
                  _firstNameController.clear();
                  _lastNameController.clear();
                  _usernameController.clear();
                  _passwordController.clear();
                  _generatedUsername = null;
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating student: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Student Accounts'),
      ),
      body: Row(
        children: [
          // Create Student Form
          Expanded(
            flex: 2,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Student Account',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      
                      // Name fields
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'First Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Last Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Username field with generate button
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.account_circle_outlined),
                                helperText: _generatedUsername != null 
                                  ? 'Generated username' 
                                  : 'Enter manually or generate',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (!_usernameAuthService.isValidUsername(value)) {
                                  return 'Invalid username format';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: _isLoading ? null : _generateUsername,
                            child: const Text('Generate'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Password field with generate button
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword 
                                    ? Icons.visibility_outlined 
                                    : Icons.visibility_off_outlined),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (value.length < 6) {
                                  return 'Minimum 6 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: _generatePassword,
                            child: const Text('Generate'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Create button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _createStudent,
                          child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create Student Account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Existing Students List
          Expanded(
            flex: 3,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Existing Students',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'student')
                          .where('teacherId', isEqualTo: context.read<AuthProvider>().userModel?.uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('No students created yet'),
                          );
                        }
                        
                        final students = snapshot.data!.docs;
                        
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final data = students[index].data() as Map<String, dynamic>;
                            final student = UserModel.fromFirestore(data);
                            
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    '${student.firstName?[0] ?? ''}${student.lastName?[0] ?? ''}'.toUpperCase(),
                                  ),
                                ),
                                title: Text('${student.firstName} ${student.lastName}'),
                                subtitle: Text('Username: ${student.username ?? 'N/A'}'),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'reset',
                                      child: Text('Reset Password'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete Account'),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    // TODO: Implement password reset and delete
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$value not yet implemented'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}