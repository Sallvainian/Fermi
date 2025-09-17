import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/utils/firestore_batch_query.dart';
import '../../domain/models/student.dart';

/// Simplified student provider with direct Firestore access
class SimpleStudentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Student> _students = [];
  Map<String, dynamic>? _currentStudent;
  bool _isLoading = false;
  String? _error;

  List<Student> get students => _students;
  Map<String, dynamic>? get currentStudent => _currentStudent;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all students (for admin)
  Future<void> loadAllStudents() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .orderBy('lastName')
          .orderBy('firstName')
          .get();

      _students = snapshot.docs.map((doc) {
        final data = doc.data();
        // Parse displayName into first and last name if needed
        String firstName = data['firstName'] ?? '';
        String lastName = data['lastName'] ?? '';
        if (firstName.isEmpty && lastName.isEmpty && data['displayName'] != null) {
          final parts = (data['displayName'] as String).split(' ');
          firstName = parts.isNotEmpty ? parts.first : '';
          lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }

        return Student(
          id: doc.id,
          uid: data['uid'] ?? doc.id,
          username: data['username'] ?? data['email']?.split('@').first ?? '',
          firstName: firstName,
          lastName: lastName,
          displayName:
              data['displayName'] ??
              '${firstName} ${lastName}',
          email: data['email'],
          parentEmail: data['parentEmail'],
          backupEmail: data['backupEmail'],
          gradeLevel: int.tryParse(data['gradeLevel']?.toString() ?? '9') ?? 9,
          classIds: List<String>.from(data['classIds'] ?? []),
          accountClaimed: data['accountClaimed'] ?? false,
          passwordChanged: data['passwordChanged'] ?? false,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt:
              (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      _error = null;
    } catch (e) {
      _error = e.toString();
      _students = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load students for a teacher's classes
  Future<void> loadTeacherStudents(List<dynamic> teacherClasses) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (teacherClasses.isEmpty) {
        _students = [];
        return;
      }

      // Get all student IDs from teacher's classes
      Set<String> studentIds = {};
      for (var classModel in teacherClasses) {
        if (classModel.studentIds != null) {
          studentIds.addAll(classModel.studentIds);
        }
      }

      if (studentIds.isEmpty) {
        _students = [];
        return;
      }

      // Query students by IDs using batch query to handle > 30 students
      final docs = await FirestoreBatchQuery.batchWhereInDocumentId(
        collection: _firestore.collection('users'),
        documentIds: studentIds.toList(),
      );

      _students = docs.map((doc) {
        final data = doc.data();
        // Parse displayName into first and last name if needed
        String firstName = data['firstName'] ?? '';
        String lastName = data['lastName'] ?? '';
        if (firstName.isEmpty && lastName.isEmpty && data['displayName'] != null) {
          final parts = (data['displayName'] as String).split(' ');
          firstName = parts.isNotEmpty ? parts.first : '';
          lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }

        return Student(
          id: doc.id,
          uid: data['uid'] ?? doc.id,
          username: data['username'] ?? data['email']?.split('@').first ?? '',
          firstName: firstName,
          lastName: lastName,
          displayName:
              data['displayName'] ??
              '${firstName} ${lastName}',
          email: data['email'],
          parentEmail: data['parentEmail'],
          backupEmail: data['backupEmail'],
          gradeLevel: int.tryParse(data['gradeLevel']?.toString() ?? '9') ?? 9,
          classIds: List<String>.from(data['classIds'] ?? []),
          accountClaimed: data['accountClaimed'] ?? false,
          passwordChanged: data['passwordChanged'] ?? false,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt:
              (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      _error = null;
    } catch (e) {
      _error = e.toString();
      _students = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load students by IDs
  Future<List<Student>> loadStudentsByIds(List<String> studentIds) async {
    if (studentIds.isEmpty) return [];

    try {
      print('Looking for ${studentIds.length} students in users collection');

      // Use batch query to handle > 30 students
      final docs = await FirestoreBatchQuery.batchWhereInDocumentId(
        collection: _firestore.collection('users'),
        documentIds: studentIds,
      );

      debugPrint('Found ${docs.length} student documents');

      return docs.map((doc) {
        final data = doc.data();
        // Parse displayName into first and last name if needed
        String firstName = data['firstName'] ?? '';
        String lastName = data['lastName'] ?? '';
        if (firstName.isEmpty && lastName.isEmpty && data['displayName'] != null) {
          final parts = (data['displayName'] as String).split(' ');
          firstName = parts.isNotEmpty ? parts.first : '';
          lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }

        return Student(
          id: doc.id,
          uid: data['uid'] ?? doc.id,
          username: data['username'] ?? data['email']?.split('@').first ?? '',
          firstName: firstName,
          lastName: lastName,
          displayName:
              data['displayName'] ??
              '${firstName} ${lastName}',
          email: data['email'],
          parentEmail: data['parentEmail'],
          backupEmail: data['backupEmail'],
          gradeLevel: int.tryParse(data['gradeLevel']?.toString() ?? '9') ?? 9,
          classIds: List<String>.from(data['classIds'] ?? []),
          accountClaimed: data['accountClaimed'] ?? false,
          passwordChanged: data['passwordChanged'] ?? false,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt:
              (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  /// Create a new student
  Future<bool> createStudent({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required int gradeLevel,
    String? parentEmail,
  }) async {
    try {
      // Create auth user
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: _generateTempPassword(),
          );

      // Create user document
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'parentEmail': parentEmail,
        'gradeLevel': gradeLevel,
        'role': 'student',
        'accountClaimed': false,
        'passwordChanged': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send password reset email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      await loadAllStudents(); // Reload
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update student information
  Future<bool> updateStudent(
    String studentId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection('users').doc(studentId).update(updates);
      await loadAllStudents(); // Reload
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a student
  Future<bool> deleteStudent(String studentId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('users').doc(studentId).delete();

      // Note: Deleting from Firebase Auth requires admin SDK
      // For now, just disable the account
      await updateStudent(studentId, {'disabled': true});

      await loadAllStudents(); // Reload
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Add student to class
  Future<bool> addStudentToClass(String studentId, String classId) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': FieldValue.arrayUnion([studentId]),
        'studentCount': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Remove student from class
  Future<bool> removeStudentFromClass(String studentId, String classId) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': FieldValue.arrayRemove([studentId]),
        'studentCount': FieldValue.increment(-1),
      });
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Generate temporary password
  String _generateTempPassword() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    String password = '';
    for (int i = 0; i < 12; i++) {
      password += chars[(random + i) % chars.length];
    }
    return password;
  }

  /// Load students (generic method)
  Future<void> loadStudents() async {
    await loadAllStudents();
  }
}
