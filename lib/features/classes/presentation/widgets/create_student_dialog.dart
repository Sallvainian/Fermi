import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../../../student/domain/models/student.dart';
import '../../domain/models/class_model.dart';

class CreateStudentDialog extends StatefulWidget {
  final ClassModel classModel;

  const CreateStudentDialog({
    super.key,
    required this.classModel,
  });

  @override
  State<CreateStudentDialog> createState() => _CreateStudentDialogState();
}

class _CreateStudentDialogState extends State<CreateStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _parentEmailController = TextEditingController();
  String _selectedGrade = '9';
  bool _isLoading = false;
  String? _error;
  String? _generatedUsername;
  String? _generatedPassword;

  final List<String> _grades = [
    '9', '10', '11', '12'
  ];

  @override
  void initState() {
    super.initState();
    // Generate credentials when dialog opens
    _generateCredentials();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  void _generateCredentials() {
    // Generate username from name (will be updated when name is entered)
    _updateUsername();
    
    // Generate a random temporary password
    _generatedPassword = _generatePassword();
  }

  void _updateUsername() {
    final firstName = _firstNameController.text.trim().toLowerCase();
    final lastName = _lastNameController.text.trim().toLowerCase();
    
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      // Create username from first initial + last name + random number
      final random = Random();
      final number = random.nextInt(100);
      setState(() {
        _generatedUsername = '${firstName[0]}$lastName${number.toString().padLeft(2, '0')}';
      });
    }
  }

  String _generatePassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _createAndEnrollStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_generatedUsername == null || _generatedPassword == null) {
      setState(() {
        _error = 'Please enter student name to generate username';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final parentEmail = _parentEmailController.text.trim();
      final gradeLevel = _selectedGrade;
      final displayName = '$firstName $lastName';
      
      // Generate a unique student ID
      final studentId = FirebaseFirestore.instance.collection('students').doc().id;
      
      // Create student document directly in Firestore
      final student = Student(
        id: studentId,
        uid: studentId, // Use same ID for uid since no Firebase Auth user yet
        username: _generatedUsername!,
        temporaryPassword: _generatedPassword,
        accountClaimed: false,
        passwordChanged: false,
        backupEmail: null,
        email: null, // Will be set when student claims account
        firstName: firstName,
        lastName: lastName,
        displayName: displayName,
        gradeLevel: int.parse(gradeLevel),
        parentEmail: parentEmail.isNotEmpty ? parentEmail : null,
        classIds: [widget.classModel.id], // Add to this class
        photoURL: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        metadata: null,
      );

      // Save to Firestore students collection
      await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .set(student.toFirestore());

      // Update class document to add this student
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classModel.id)
          .update({
        'studentIds': FieldValue.arrayUnion([studentId]),
        'studentCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
        
      if (mounted) {
        // Show success dialog with credentials
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Student Created Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student: $displayName'),
                const SizedBox(height: 16),
                const Text('Login Credentials:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText('Username: $_generatedUsername'),
                SelectableText('Temporary Password: $_generatedPassword'),
                const SizedBox(height: 16),
                const Text(
                  'Please save these credentials and provide them to the student.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Student'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _updateUsername(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _updateUsername(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedGrade,
                decoration: const InputDecoration(
                  labelText: 'Grade Level',
                  border: OutlineInputBorder(),
                ),
                items: _grades.map((grade) {
                  return DropdownMenuItem(
                    value: grade,
                    child: Text('Grade $grade'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGrade = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _parentEmailController,
                decoration: const InputDecoration(
                  labelText: 'Parent Email (Optional)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && !value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              
              if (_generatedUsername != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generated Username',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _generatedUsername!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
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
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _createAndEnrollStudent,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Student'),
        ),
      ],
    );
  }
}