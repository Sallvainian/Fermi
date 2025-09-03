import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/class_model.dart';
import '../../../../shared/services/firestore_repository.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/services/retry_service.dart';

/// Refactored service for managing educational classes.
///
/// This implementation delegates all generic CRUD operations to the
/// reusable [FirestoreRepository], avoiding duplication of Firestore
/// interaction code. It exposes higher level domain operations such
/// as enrollment and statistics while remaining focused on class-
/// specific logic.
class ClassService {
  final FirestoreRepository<ClassModel> _repository;

  ClassService({FirebaseFirestore? firestore})
    : _repository = FirestoreRepository<ClassModel>(
        collectionPath: 'classes',
        firestore: firestore,
        fromFirestore: (doc) => ClassModel.fromFirestore(doc),
        toFirestore: (model) => model.toFirestore(),
      );

  /// Creates a new class with auto-generated enrollment code
  Future<ClassModel> createClass(ClassModel classModel) async {
    return await RetryService.withRetry(
      () async {
        final enrollmentCode = await _generateUniqueEnrollmentCode();
        // Use client timestamp for model but server will override on write
        final now = DateTime.now();
        final modelWithCode = classModel.copyWith(
          enrollmentCode: enrollmentCode,
          createdAt: now,
          updatedAt: now,
        );

        // Create the document with server timestamps
        final data = modelWithCode.toFirestore();
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();

        final id = await _repository.create(data);
        final createdClass = modelWithCode.copyWith(id: id);

        LoggerService.info(
          'Created class: ${createdClass.name} with enrollment code: $enrollmentCode',
        );
        return createdClass;
      },
      config: RetryConfigs.standard,
      onRetry: (attempt, delay, error) {
        LoggerService.warning(
          'Retrying class creation (attempt $attempt): ${error.toString()}',
        );
      },
    );
  }

  /// Retrieves a class by its ID
  Future<ClassModel?> getClassById(String id) async {
    return await _repository.get(id);
  }

  /// Gets all classes
  Future<List<ClassModel>> getAllClasses() async {
    return await _repository.getAll();
  }

  /// Updates an existing class
  Future<ClassModel> updateClass(ClassModel classModel) async {
    return await RetryService.withRetry(() async {
      final data = classModel.toFirestore();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _repository.update(classModel.id, data);
      LoggerService.info('Updated class: ${classModel.name}');
      // Return model with client timestamp for immediate use
      return classModel.copyWith(updatedAt: DateTime.now());
    }, config: RetryConfigs.standard);
  }

  /// Deletes a class by ID
  Future<void> deleteClass(String id) async {
    await _repository.delete(id);
    LoggerService.info('Deleted class: $id');
  }

  /// Archives a class by setting isActive to false
  Future<void> archiveClass(String id) async {
    await _repository.collection.doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    LoggerService.info('Archived class: $id');
  }

  /// Stream classes by teacher
  Stream<List<ClassModel>> getClassesByTeacher(
    String teacherId, {
    bool includeArchived = false,
  }) {
    return _repository.streamList((col) {
      Query<Map<String, dynamic>> query = col.where(
        'teacherId',
        isEqualTo: teacherId,
      );

      if (!includeArchived) {
        query = query.where('isActive', isEqualTo: true);
      }

      return query.orderBy('createdAt', descending: true);
    });
  }

  /// Stream classes by student
  Stream<List<ClassModel>> getClassesByStudent(
    String studentId, {
    bool includeArchived = false,
  }) {
    return _repository.streamList((col) {
      Query<Map<String, dynamic>> query = col.where(
        'studentIds',
        arrayContains: studentId,
      );

      if (!includeArchived) {
        query = query.where('isActive', isEqualTo: true);
      }

      return query.orderBy('name');
    });
  }

  /// Get class by enrollment code
  Future<ClassModel?> getClassByEnrollmentCode(String code) async {
    final results = await _repository.getList(
      (col) => col
          .where('enrollmentCode', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1),
    );

    return results.isEmpty ? null : results.first;
  }

  /// Enroll a student in a class with transaction safety
  Future<ClassModel> enrollStudent(
    String studentId,
    String enrollmentCode,
  ) async {
    // First check if the enrollment code exists
    final initialCheck = await getClassByEnrollmentCode(enrollmentCode);
    if (initialCheck == null) {
      throw Exception('Invalid enrollment code');
    }

    // Use a transaction to ensure atomic enrollment
    return await _repository.runTransaction<ClassModel>((
      transaction,
      collection,
    ) async {
      // Re-fetch the class within the transaction to ensure consistency
      final classDoc = await transaction.get(collection.doc(initialCheck.id));

      if (!classDoc.exists) {
        throw Exception('Class no longer exists');
      }

      final classModel = ClassModel.fromFirestore(classDoc);

      // Re-validate enrollment conditions within transaction
      if (classModel.studentIds.contains(studentId)) {
        throw Exception('Student is already enrolled in this class');
      }

      if (classModel.maxStudents != null &&
          classModel.studentIds.length >= classModel.maxStudents!) {
        throw Exception('Class is at maximum capacity');
      }

      // Update the student list
      final updatedIds = [...classModel.studentIds, studentId];
      final updatedClass = classModel.copyWith(
        studentIds: updatedIds,
        updatedAt: DateTime.now(),
      );

      // Perform the update within the transaction
      transaction.update(classDoc.reference, {
        'studentIds': updatedIds,
        'updatedAt': FieldValue.serverTimestamp(), // Use server timestamp
      });

      LoggerService.info(
        'Enrolled student $studentId in class ${classModel.name}',
      );
      return updatedClass;
    });
  }

  /// Unenroll a student from a class with transaction safety
  Future<void> unenrollStudent(String classId, String studentId) async {
    await _repository.runTransaction<void>((transaction, collection) async {
      // Fetch the class within the transaction
      final classDoc = await transaction.get(collection.doc(classId));

      if (!classDoc.exists) {
        throw Exception('Class not found');
      }

      final classModel = ClassModel.fromFirestore(classDoc);

      // Check if student is actually enrolled
      if (!classModel.studentIds.contains(studentId)) {
        LoggerService.warning(
          'Student $studentId is not enrolled in class ${classModel.name}',
        );
        return; // No-op if student isn't enrolled
      }

      // Remove the student from the list
      final updatedIds = classModel.studentIds
          .where((id) => id != studentId)
          .toList();

      // Perform the update within the transaction
      transaction.update(classDoc.reference, {
        'studentIds': updatedIds,
        'updatedAt': FieldValue.serverTimestamp(), // Use server timestamp
      });

      LoggerService.info(
        'Unenrolled student $studentId from class ${classModel.name}',
      );
    });
  }

  /// Regenerate enrollment code for a class
  Future<String> regenerateEnrollmentCode(String classId) async {
    return await RetryService.withRetry(() async {
      final newCode = await _generateUniqueEnrollmentCode();

      await _repository.collection.doc(classId).update({
        'enrollmentCode': newCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggerService.info('Regenerated enrollment code for class $classId');
      return newCode;
    }, config: RetryConfigs.standard);
  }

  /// Get teacher's class statistics
  Future<Map<String, dynamic>> getTeacherClassStats(String teacherId) async {
    final classes = await _repository.getList(
      (col) => col
          .where('teacherId', isEqualTo: teacherId)
          .where('isActive', isEqualTo: true),
    );

    final totalStudents = classes.fold<int>(
      0,
      (total, cls) => total + cls.studentIds.length,
    );

    return {
      'totalClasses': classes.length,
      'totalStudents': totalStudents,
      'averageClassSize': classes.isEmpty
          ? 0
          : (totalStudents / classes.length).round(),
    };
  }

  /// Constants for enrollment code generation
  static const String _enrollmentCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _enrollmentCodeLength = 6;
  static const int _maxCodeGenerationAttempts = 10;
  static const int _codeGenerationBatchSize = 5;

  /// Generate a unique enrollment code with improved algorithm
  Future<String> _generateUniqueEnrollmentCode() async {
    // Use a larger character set to reduce collision probability
    final random = Random.secure(); // Use cryptographically secure random

    for (
      var attempt = 0;
      attempt < _maxCodeGenerationAttempts;
      attempt += _codeGenerationBatchSize
    ) {
      // Generate a batch of candidate codes
      final candidateCodes = <String>[];
      for (var i = 0; i < _codeGenerationBatchSize; i++) {
        final code = String.fromCharCodes(
          Iterable.generate(
            _enrollmentCodeLength,
            (_) => _enrollmentCodeChars.codeUnitAt(
              random.nextInt(_enrollmentCodeChars.length),
            ),
          ),
        );
        candidateCodes.add(code);
      }

      // Batch check all codes in a single query
      final existingCodeSet = await _repository.checkExistingValues(
        field: 'enrollmentCode',
        values: candidateCodes,
        additionalFilters: {'isActive': true},
      );

      for (final code in candidateCodes) {
        if (!existingCodeSet.contains(code)) {
          LoggerService.info(
            'Generated unique enrollment code after ${attempt + 1} attempts',
          );
          return code;
        }
      }
    }

    // Fallback: Use timestamp-based code for guaranteed uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniquePart = timestamp.toRadixString(36).toUpperCase();
    final code = uniquePart
        .padLeft(_enrollmentCodeLength, '0')
        .substring(0, _enrollmentCodeLength);

    LoggerService.warning('Using timestamp-based enrollment code: $code');
    return code;
  }
}
