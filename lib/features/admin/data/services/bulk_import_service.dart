import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/services/logger_service.dart';
import '../../constants/bulk_import_constants.dart';

class BulkImportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-east4');
  
  static const int _batchSize = BulkImportConstants.batchSize;
  static const int _maxRetries = BulkImportConstants.maxRetries;
  static const Duration _retryDelay = BulkImportConstants.retryDelay;

  Future<BulkImportResult> bulkImportStudents(List<Map<String, dynamic>> students) async {
    final result = BulkImportResult();

    if (students.isEmpty) {
      LoggerService.info('No students to import', tag: 'BulkImportService');
      return result;
    }

    // Process in batches using the new bulk import Cloud Function
    // The Cloud Function can handle up to 1000 users per batch
    const cloudFunctionBatchSize = 1000;
    final batches = _createBatches(students, cloudFunctionBatchSize);

    for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      LoggerService.info('Processing student batch ${batchIndex + 1} of ${batches.length} (${batch.length} students)', tag: 'BulkImportService');

      try {
        // Prepare users for bulk import
        final usersToImport = batch.map((studentData) {
          final Map<String, dynamic> user = {
            'email': studentData['email']?.toString() ?? '',
            'displayName': studentData['displayName']?.toString() ?? '',
            'gradeLevel': studentData['gradeLevel']?.toString(),
            'parentEmail': studentData['parentEmail']?.toString(),
            'isGoogleAuth': studentData['isGoogleAuth'] == true ||
                           studentData['isGoogleAuth']?.toString().toLowerCase() == 'true',
          };

          // Add classIds if present (for JSON import)
          if (studentData['classIds'] != null && studentData['classIds'] is List) {
            user['classIds'] = studentData['classIds'];
          }
          // Add enrollmentCode if present (for CSV import with enrollment codes)
          else if (studentData['enrollmentCode'] != null) {
            user['enrollmentCode'] = studentData['enrollmentCode'].toString();
          }
          // Legacy support for className field
          else if (studentData['className'] != null) {
            user['className'] = studentData['className'].toString();
          }

          // Add student ID if present
          if (studentData['studentId'] != null) {
            user['studentId'] = studentData['studentId'].toString();
          }

          return user;
        }).toList();

        // Call the new bulk import Cloud Function
        final callable = _functions.httpsCallable('bulkImportStudents');
        final response = await _retryOperation(() => callable.call({
          'users': usersToImport,
          'sendPasswordResetEmails': true,
        }));

        // Process the response
        final data = response.data as Map<String, dynamic>;

        // Add successful imports
        if (data['imported'] != null) {
          for (var imported in data['imported']) {
            result.addSuccess({
              'uid': imported['uid'],
              'email': imported['email'],
              'displayName': imported['displayName'] ?? '',
              'temporaryPassword': null,  // Password reset emails are sent by Cloud Function
              'isGoogleAuth': imported['isGoogleAuth'] ?? false,
            });
          }
        }

        // Add failed imports
        if (data['failed'] != null) {
          for (var failed in data['failed']) {
            result.addError(
              failed['email'] ?? 'Unknown',
              failed['error'] ?? 'Import failed',
            );
          }
        }

        // Add already existing users as errors
        if (data['alreadyExisting'] != null) {
          for (var existing in data['alreadyExisting']) {
            result.addError(
              existing,
              BulkImportConstants.emailExistsError,
            );
          }
        }

        LoggerService.info(
          'Batch ${batchIndex + 1} completed: ${data['summary']?['imported'] ?? 0} imported, '
          '${data['summary']?['failed'] ?? 0} failed, '
          '${data['summary']?['alreadyExisting'] ?? 0} already existing',
          tag: 'BulkImportService'
        );

      } catch (e) {
        LoggerService.error('Failed to process batch ${batchIndex + 1}: $e', tag: 'BulkImportService');

        // Add all students in the failed batch as errors
        for (final studentData in batch) {
          result.addError(
            studentData['email']?.toString() ?? 'Unknown',
            'Batch processing failed: ${e.toString()}',
          );
        }
      }

      // Add delay between batches if there are more to process
      if (batchIndex < batches.length - 1) {
        await Future.delayed(BulkImportConstants.batchDelay);
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
            result.addError(email, BulkImportConstants.emailExistsError);
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
        await Future.delayed(BulkImportConstants.batchDelay);
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
        // Validate email field instead of username
        final email = row['email']?.toString() ?? '';
        if (email.isEmpty) {
          errors.add('Email is required');
        } else if (!_isValidEmail(email)) {
          errors.add('Invalid email format');
        } else if (!email.toLowerCase().endsWith('@rosellestudent.com') && 
                   !email.toLowerCase().endsWith('@rosellestudent.org')) {
          errors.add('Email must be from @rosellestudent.com or @rosellestudent.org domain');
        } else if (await _checkEmailExists(email)) {
          errors.add('Email already exists');
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
        
        // Validate isGoogleAuth flag if present
        final isGoogleAuth = row['isGoogleAuth']?.toString();
        if (isGoogleAuth != null && isGoogleAuth.isNotEmpty &&
            isGoogleAuth.toLowerCase() != 'true' && isGoogleAuth.toLowerCase() != 'false') {
          errors.add('isGoogleAuth must be true or false');
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
            ? row['email']?.toString() ?? 'Row $i'
            : row['email']?.toString() ?? 'Row $i';
        (validationResult['errors'] as Map<String, String>)[identifier] = errors.join(', ');
      }
    }
    
    return validationResult;
  }

  Future<bool> _checkUsernameExists(String username) async {
    try {
      // This method is now deprecated - we use email instead
      // Keeping for backward compatibility if needed
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
    const charset = BulkImportConstants.passwordCharset;
    const length = BulkImportConstants.passwordLength;
    
    // Generate password using cryptographically secure random selection from charset
    String password = List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
    
    // Ensure password has at least one of each required character type
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#\$%^&*]').hasMatch(password);
    
    if (!hasUpper || !hasLower || !hasNumber || !hasSpecial) {
      // Recursively generate a new password if requirements aren't met
      return _generateStudentPassword();
    }
    
    return password;
  }

  bool _isValidEmail(String email) {
    return BulkImportConstants.emailPattern.hasMatch(email);
  }

  bool _isValidUsername(String username) {
    return BulkImportConstants.usernamePattern.hasMatch(username);
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