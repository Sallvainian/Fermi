import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/services/logger_service.dart';

class BulkImportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  static const int _batchSize = 500;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  Future<BulkImportResult> bulkImportStudents(List<Map<String, dynamic>> students) async {
    final result = BulkImportResult();
    final batches = _createBatches(students, _batchSize);
    
    for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      LoggerService.info('Processing student batch ${batchIndex + 1} of ${batches.length}', tag: 'BulkImportService');
      
      for (final studentData in batch) {
        try {
          final username = studentData['username']?.toString() ?? '';
          
          if (await _checkUsernameExists(username)) {
            result.addError(username, 'Username already exists');
            continue;
          }
          
          final password = _generateStudentPassword();
          
          final callable = _functions.httpsCallable('createStudentAccount');
          final response = await _retryOperation(() => callable.call({
            'username': username,
            'displayName': studentData['displayName'],
            'gradeLevel': studentData['gradeLevel'],
            'password': password,
            'parentEmail': studentData['parentEmail'],
            'classIds': studentData['classIds'] ?? [],
          }));
          
          result.addSuccess({
            'uid': response.data['uid'],
            'username': username,
            'displayName': studentData['displayName'],
            'temporaryPassword': password,
          });
          
        } catch (e) {
          LoggerService.error('Failed to create student: $e', tag: 'BulkImportService');
          result.addError(
            studentData['username']?.toString() ?? 'Unknown',
            e.toString(),
          );
        }
      }
      
      if (batchIndex < batches.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    await _logBulkImportActivity('student', result);
    return result;
  }

  Future<BulkImportResult> bulkImportTeachers(List<Map<String, dynamic>> teachers) async {
    final result = BulkImportResult();
    final batches = _createBatches(teachers, _batchSize);
    
    for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      LoggerService.info('Processing teacher batch ${batchIndex + 1} of ${batches.length}', tag: 'BulkImportService');
      
      for (final teacherData in batch) {
        try {
          final email = teacherData['email']?.toString() ?? '';
          
          if (await _checkEmailExists(email)) {
            result.addError(email, 'Email already exists');
            continue;
          }
          
          final callable = _functions.httpsCallable('createTeacherAccount');
          final response = await _retryOperation(() => callable.call({
            'email': email,
            'password': teacherData['password'],
            'displayName': teacherData['displayName'],
            'subjects': teacherData['subjects'] ?? [],
          }));
          
          result.addSuccess({
            'uid': response.data['uid'],
            'email': email,
            'displayName': teacherData['displayName'],
          });
          
        } catch (e) {
          LoggerService.error('Failed to create teacher: $e', tag: 'BulkImportService');
          result.addError(
            teacherData['email']?.toString() ?? 'Unknown',
            e.toString(),
          );
        }
      }
      
      if (batchIndex < batches.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    await _logBulkImportActivity('teacher', result);
    return result;
  }

  Future<void> bulkAssignToClasses(List<String> studentIds, List<String> classIds) async {
    if (studentIds.isEmpty || classIds.isEmpty) return;
    
    final batches = _createBatches(studentIds, _batchSize);
    
    for (final batch in batches) {
      final writeBatch = _firestore.batch();
      
      for (final studentId in batch) {
        final studentRef = _firestore.collection('students').doc(studentId);
        writeBatch.update(studentRef, {
          'classIds': FieldValue.arrayUnion(classIds),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        for (final classId in classIds) {
          final classRef = _firestore.collection('classes').doc(classId);
          writeBatch.update(classRef, {
            'studentIds': FieldValue.arrayUnion([studentId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      await writeBatch.commit();
    }
  }

  Future<Map<String, dynamic>> validateBulkData(
    List<Map<String, dynamic>> data,
    String type,
  ) async {
    final validationResult = {
      'valid': <Map<String, dynamic>>[],
      'invalid': <Map<String, dynamic>>[],
      'errors': <String, String>{},
    };
    
    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      final errors = <String>[];
      
      if (type == 'student') {
        final username = row['username']?.toString() ?? '';
        if (username.isEmpty) {
          errors.add('Username is required');
        } else if (!_isValidUsername(username)) {
          errors.add('Invalid username format');
        } else if (await _checkUsernameExists(username)) {
          errors.add('Username already exists');
        }
        
        if (row['displayName']?.toString().isEmpty ?? true) {
          errors.add('Display name is required');
        }
        
        final gradeLevel = row['gradeLevel'];
        if (gradeLevel == null) {
          errors.add('Grade level is required');
        } else if (gradeLevel is! int || gradeLevel < 1 || gradeLevel > 12) {
          errors.add('Invalid grade level (must be 1-12)');
        }
        
        final parentEmail = row['parentEmail']?.toString();
        if (parentEmail != null && parentEmail.isNotEmpty && !_isValidEmail(parentEmail)) {
          errors.add('Invalid parent email format');
        }
      } else if (type == 'teacher') {
        final email = row['email']?.toString() ?? '';
        if (email.isEmpty) {
          errors.add('Email is required');
        } else if (!_isValidEmail(email)) {
          errors.add('Invalid email format');
        } else if (await _checkEmailExists(email)) {
          errors.add('Email already exists');
        }
        
        if (row['displayName']?.toString().isEmpty ?? true) {
          errors.add('Display name is required');
        }
        
        final password = row['password']?.toString() ?? '';
        if (password.isEmpty) {
          errors.add('Password is required');
        } else if (password.length < 6) {
          errors.add('Password must be at least 6 characters');
        }
      }
      
      if (errors.isEmpty) {
        (validationResult['valid'] as List).add(row);
      } else {
        (validationResult['invalid'] as List).add(row);
        final identifier = type == 'student' 
            ? row['username']?.toString() ?? 'Row $i'
            : row['email']?.toString() ?? 'Row $i';
        (validationResult['errors'] as Map<String, String>)[identifier] = errors.join(', ');
      }
    }
    
    return validationResult;
  }

  Future<bool> _checkUsernameExists(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      LoggerService.error('Error checking username existence: $e', tag: 'BulkImportService');
      return false;
    }
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      LoggerService.error('Error checking email existence: $e', tag: 'BulkImportService');
      return false;
    }
  }

  String _generateStudentPassword() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(9000) + 1000;
    return 'Student\$${timestamp % 10000}\$$randomNum';
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username) && 
           username.length >= 3 && 
           username.length <= 20;
  }

  List<List<T>> _createBatches<T>(List<T> items, int batchSize) {
    final batches = <List<T>>[];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(_retryDelay * attempts);
      }
    }
    throw Exception('Operation failed after $_maxRetries retries');
  }

  Future<void> _logBulkImportActivity(String type, BulkImportResult result) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await _firestore.collection('activities').add({
        'type': 'bulk_import',
        'accountType': type,
        'performedBy': user.uid,
        'performedByEmail': user.email,
        'successCount': result.successes.length,
        'errorCount': result.errors.length,
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'successfulAccounts': result.successes.take(10).map((s) => 
            type == 'student' ? s['username'] : s['email']
          ).toList(),
          'errors': result.errors.take(10).map((e) => 
            '${e.identifier}: ${e.message}'
          ).toList(),
        },
      });
    } catch (e) {
      LoggerService.error('Failed to log bulk import activity: $e', tag: 'BulkImportService');
    }
  }
}

class BulkImportResult {
  final List<Map<String, dynamic>> successes = [];
  final List<BulkImportError> errors = [];
  
  void addSuccess(Map<String, dynamic> data) {
    successes.add(data);
  }
  
  void addError(String identifier, String message) {
    errors.add(BulkImportError(identifier: identifier, message: message));
  }
  
  bool get hasErrors => errors.isNotEmpty;
  int get totalProcessed => successes.length + errors.length;
  double get successRate => totalProcessed == 0 ? 0 : successes.length / totalProcessed;
}

class BulkImportError {
  final String identifier;
  final String message;
  
  BulkImportError({
    required this.identifier,
    required this.message,
  });
}