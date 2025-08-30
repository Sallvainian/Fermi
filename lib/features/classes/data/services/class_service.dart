import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/class_model.dart';
import '../../../../shared/services/firestore_repository.dart';
import '../../../../shared/services/logger_service.dart';

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
    final enrollmentCode = await _generateUniqueEnrollmentCode();
    final now = DateTime.now();
    final modelWithCode = classModel.copyWith(
      enrollmentCode: enrollmentCode,
      createdAt: now,
      updatedAt: now,
    );
    
    final id = await _repository.create(modelWithCode.toFirestore());
    final createdClass = modelWithCode.copyWith(id: id);
    
    LoggerService.info(
        'Created class: ${createdClass.name} with enrollment code: $enrollmentCode');
    return createdClass;
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
    final updated = classModel.copyWith(updatedAt: DateTime.now());
    await _repository.update(updated.id, updated.toFirestore());
    LoggerService.info('Updated class: ${classModel.name}');
    return updated;
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
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    LoggerService.info('Archived class: $id');
  }

  /// Stream classes by teacher
  Stream<List<ClassModel>> getClassesByTeacher(String teacherId,
      {bool includeArchived = false}) {
    return _repository.streamList((col) {
      Query<Map<String, dynamic>> query = 
          col.where('teacherId', isEqualTo: teacherId);
      
      if (!includeArchived) {
        query = query.where('isActive', isEqualTo: true);
      }
      
      return query.orderBy('createdAt', descending: true);
    });
  }

  /// Stream classes by student
  Stream<List<ClassModel>> getClassesByStudent(String studentId,
      {bool includeArchived = false}) {
    return _repository.streamList((col) {
      Query<Map<String, dynamic>> query =
          col.where('studentIds', arrayContains: studentId);
      
      if (!includeArchived) {
        query = query.where('isActive', isEqualTo: true);
      }
      
      return query.orderBy('name');
    });
  }

  /// Get class by enrollment code
  Future<ClassModel?> getClassByEnrollmentCode(String code) async {
    final results = await _repository.getList((col) => col
        .where('enrollmentCode', isEqualTo: code)
        .where('isActive', isEqualTo: true)
        .limit(1));
    
    return results.isEmpty ? null : results.first;
  }

  /// Enroll a student in a class
  Future<ClassModel> enrollStudent(String studentId, String enrollmentCode) async {
    final classModel = await getClassByEnrollmentCode(enrollmentCode);
    
    if (classModel == null) {
      throw Exception('Invalid enrollment code');
    }
    
    if (classModel.studentIds.contains(studentId)) {
      throw Exception('Student is already enrolled in this class');
    }
    
    if (classModel.maxStudents != null && 
        classModel.studentIds.length >= classModel.maxStudents!) {
      throw Exception('Class is at maximum capacity');
    }
    
    final updatedIds = [...classModel.studentIds, studentId];
    final updatedClass = classModel.copyWith(
      studentIds: updatedIds,
      updatedAt: DateTime.now(),
    );
    
    await _repository.collection.doc(classModel.id).update({
      'studentIds': updatedIds,
      'updatedAt': Timestamp.fromDate(updatedClass.updatedAt!),
    });
    
    LoggerService.info(
        'Enrolled student $studentId in class ${classModel.name}');
    return updatedClass;
  }

  /// Unenroll a student from a class
  Future<void> unenrollStudent(String classId, String studentId) async {
    final classModel = await getClassById(classId);
    
    if (classModel == null) {
      throw Exception('Class not found');
    }
    
    final updatedIds =
        classModel.studentIds.where((id) => id != studentId).toList();
    
    await _repository.collection.doc(classId).update({
      'studentIds': updatedIds,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    
    LoggerService.info(
        'Unenrolled student $studentId from class ${classModel.name}');
  }

  /// Regenerate enrollment code for a class
  Future<String> regenerateEnrollmentCode(String classId) async {
    final newCode = await _generateUniqueEnrollmentCode();
    
    await _repository.collection.doc(classId).update({
      'enrollmentCode': newCode,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    
    LoggerService.info('Regenerated enrollment code for class $classId');
    return newCode;
  }

  /// Get teacher's class statistics
  Future<Map<String, dynamic>> getTeacherClassStats(String teacherId) async {
    final classes = await _repository.getList((col) => col
        .where('teacherId', isEqualTo: teacherId)
        .where('isActive', isEqualTo: true));
    
    final totalStudents = classes.fold<int>(
        0, (total, cls) => total + cls.studentIds.length);
    
    return {
      'totalClasses': classes.length,
      'totalStudents': totalStudents,
      'averageClassSize':
          classes.isEmpty ? 0 : (totalStudents / classes.length).round(),
    };
  }

  /// Generate a unique enrollment code
  Future<String> _generateUniqueEnrollmentCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    const codeLength = 6;
    const maxAttempts = 100;
    final random = Random();
    
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final code = String.fromCharCodes(Iterable.generate(
          codeLength,
          (_) => chars.codeUnitAt(random.nextInt(chars.length))));
      
      final existing = await getClassByEnrollmentCode(code);
      if (existing == null) {
        return code;
      }
    }
    
    throw Exception('Unable to generate unique enrollment code');
  }
}