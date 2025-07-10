/// Service for managing educational classes in Firebase Firestore.
/// 
/// This service handles all CRUD operations for classes, including
/// enrollment management, class queries, and enrollment code generation.
library;

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_model.dart';
import '../core/di/locator.dart';
import 'logger_service.dart';

/// Service class for managing educational classes in Firestore.
/// 
/// Provides functionality for:
/// - Creating and managing classes
/// - Generating unique enrollment codes
/// - Managing student enrollment
/// - Querying classes by various criteria
/// - Handling class updates and archival
class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LoggerService _logger = getIt<LoggerService>();
  
  /// Collection reference for classes in Firestore
  CollectionReference<Map<String, dynamic>> get _classesCollection => 
      _firestore.collection('classes');

  /// Creates a new class in Firestore with a unique enrollment code.
  /// 
  /// Generates a 6-character alphanumeric enrollment code and ensures
  /// it's unique across all classes before creating the class.
  /// 
  /// @param classModel Class data to create
  /// @return Created class with assigned ID and enrollment code
  /// @throws Exception if enrollment code generation fails after max attempts
  Future<ClassModel> createClass(ClassModel classModel) async {
    try {
      // Generate unique enrollment code
      final enrollmentCode = await _generateUniqueEnrollmentCode();
      
      // Create class with enrollment code
      final classWithCode = classModel.copyWith(
        enrollmentCode: enrollmentCode,
        createdAt: DateTime.now(),
      );
      
      // Add to Firestore
      final docRef = await _classesCollection.add(classWithCode.toFirestore());
      
      // Return class with generated ID
      final createdClass = classWithCode.copyWith(id: docRef.id);
      
      _logger.info('Created class: ${createdClass.name} with enrollment code: $enrollmentCode');
      return createdClass;
      
    } catch (e) {
      _logger.error('Error creating class', error: e);
      rethrow;
    }
  }

  /// Updates an existing class in Firestore.
  /// 
  /// Preserves the enrollment code unless explicitly changed.
  /// Updates the updatedAt timestamp automatically.
  /// 
  /// @param classModel Updated class data
  /// @return Updated class model
  Future<ClassModel> updateClass(ClassModel classModel) async {
    try {
      final updatedClass = classModel.copyWith(
        updatedAt: DateTime.now(),
      );
      
      await _classesCollection
          .doc(classModel.id)
          .update(updatedClass.toFirestore());
      
      _logger.info('Updated class: ${classModel.name}');
      return updatedClass;
      
    } catch (e) {
      _logger.error('Error updating class', error: e);
      rethrow;
    }
  }

  /// Deletes a class from Firestore.
  /// 
  /// Consider implementing soft delete by setting isActive to false
  /// instead of hard delete to preserve historical data.
  /// 
  /// @param classId ID of the class to delete
  Future<void> deleteClass(String classId) async {
    try {
      await _classesCollection.doc(classId).delete();
      _logger.info('Deleted class: $classId');
    } catch (e) {
      _logger.error('Error deleting class', error: e);
      rethrow;
    }
  }

  /// Archives a class by setting isActive to false.
  /// 
  /// Preferred over deletion to maintain historical records
  /// and allow for potential restoration.
  /// 
  /// @param classId ID of the class to archive
  Future<void> archiveClass(String classId) async {
    try {
      await _classesCollection.doc(classId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _logger.info('Archived class: $classId');
    } catch (e) {
      _logger.error('Error archiving class', error: e);
      rethrow;
    }
  }

  /// Retrieves a single class by ID.
  /// 
  /// @param classId ID of the class to retrieve
  /// @return Class model if found, null otherwise
  Future<ClassModel?> getClassById(String classId) async {
    try {
      final doc = await _classesCollection.doc(classId).get();
      
      if (!doc.exists) {
        return null;
      }
      
      return ClassModel.fromFirestore(doc);
    } catch (e) {
      _logger.error('Error getting class by ID', error: e);
      rethrow;
    }
  }

  /// Retrieves a class by its enrollment code.
  /// 
  /// Used for student enrollment via code entry.
  /// 
  /// @param enrollmentCode The enrollment code to search for
  /// @return Class model if found, null otherwise
  Future<ClassModel?> getClassByEnrollmentCode(String enrollmentCode) async {
    try {
      final querySnapshot = await _classesCollection
          .where('enrollmentCode', isEqualTo: enrollmentCode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return null;
      }
      
      return ClassModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      _logger.error('Error getting class by enrollment code', error: e);
      rethrow;
    }
  }

  /// Gets all classes for a specific teacher.
  /// 
  /// @param teacherId ID of the teacher
  /// @param includeArchived Whether to include archived classes
  /// @return Stream of classes for the teacher
  Stream<List<ClassModel>> getClassesByTeacher(
    String teacherId, {
    bool includeArchived = false,
  }) {
    try {
      Query<Map<String, dynamic>> query = _classesCollection
          .where('teacherId', isEqualTo: teacherId);
      
      if (!includeArchived) {
        query = query.where('isActive', isEqualTo: true);
      }
      
      return query
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ClassModel.fromFirestore(doc))
              .toList());
    } catch (e) {
      _logger.error('Error getting classes by teacher', error: e);
      rethrow;
    }
  }

  /// Gets all classes a student is enrolled in.
  /// 
  /// @param studentId ID of the student
  /// @param includeArchived Whether to include archived classes
  /// @return Stream of classes the student is enrolled in
  Stream<List<ClassModel>> getClassesByStudent(
    String studentId, {
    bool includeArchived = false,
  }) {
    try {
      Query<Map<String, dynamic>> query = _classesCollection
          .where('studentIds', arrayContains: studentId);
      
      if (!includeArchived) {
        query = query.where('isActive', isEqualTo: true);
      }
      
      return query
          .orderBy('name')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ClassModel.fromFirestore(doc))
              .toList());
    } catch (e) {
      _logger.error('Error getting classes by student', error: e);
      rethrow;
    }
  }

  /// Enrolls a student in a class using an enrollment code.
  /// 
  /// Validates the enrollment code and checks if the class
  /// has capacity before adding the student.
  /// 
  /// @param studentId ID of the student to enroll
  /// @param enrollmentCode The enrollment code for the class
  /// @return The class the student was enrolled in
  /// @throws Exception if enrollment fails
  Future<ClassModel> enrollStudent(String studentId, String enrollmentCode) async {
    try {
      // Find class by enrollment code
      final classModel = await getClassByEnrollmentCode(enrollmentCode);
      
      if (classModel == null) {
        throw Exception('Invalid enrollment code');
      }
      
      // Check if student is already enrolled
      if (classModel.studentIds.contains(studentId)) {
        throw Exception('Student is already enrolled in this class');
      }
      
      // Check if class is full
      if (classModel.isFull) {
        throw Exception('Class is at maximum capacity');
      }
      
      // Add student to class
      final updatedStudentIds = [...classModel.studentIds, studentId];
      final updatedClass = classModel.copyWith(
        studentIds: updatedStudentIds,
        updatedAt: DateTime.now(),
      );
      
      await _classesCollection
          .doc(classModel.id)
          .update({'studentIds': updatedStudentIds});
      
      _logger.info('Enrolled student $studentId in class ${classModel.name}');
      return updatedClass;
      
    } catch (e) {
      _logger.error('Error enrolling student', error: e);
      rethrow;
    }
  }

  /// Removes a student from a class.
  /// 
  /// @param classId ID of the class
  /// @param studentId ID of the student to remove
  Future<void> unenrollStudent(String classId, String studentId) async {
    try {
      final classModel = await getClassById(classId);
      
      if (classModel == null) {
        throw Exception('Class not found');
      }
      
      final updatedStudentIds = classModel.studentIds
          .where((id) => id != studentId)
          .toList();
      
      await _classesCollection.doc(classId).update({
        'studentIds': updatedStudentIds,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      _logger.info('Unenrolled student $studentId from class ${classModel.name}');
    } catch (e) {
      _logger.error('Error unenrolling student', error: e);
      rethrow;
    }
  }

  /// Generates a new unique enrollment code for a class.
  /// 
  /// @param classId ID of the class to generate code for
  /// @return The new enrollment code
  Future<String> regenerateEnrollmentCode(String classId) async {
    try {
      final newCode = await _generateUniqueEnrollmentCode();
      
      await _classesCollection.doc(classId).update({
        'enrollmentCode': newCode,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      _logger.info('Regenerated enrollment code for class $classId');
      return newCode;
      
    } catch (e) {
      _logger.error('Error regenerating enrollment code', error: e);
      rethrow;
    }
  }

  /// Generates a unique 6-character alphanumeric enrollment code.
  /// 
  /// Ensures uniqueness by checking against existing codes.
  /// Uses uppercase letters and numbers, excluding ambiguous characters.
  /// 
  /// @return Unique enrollment code
  /// @throws Exception if unable to generate unique code after max attempts
  Future<String> _generateUniqueEnrollmentCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude I, O, 0, 1
    const codeLength = 6;
    const maxAttempts = 100;
    
    final random = Random();
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // Generate random code
      final code = String.fromCharCodes(
        Iterable.generate(
          codeLength,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ),
      );
      
      // Check if code already exists
      final existing = await getClassByEnrollmentCode(code);
      if (existing == null) {
        return code;
      }
    }
    
    throw Exception('Unable to generate unique enrollment code');
  }

  /// Gets statistics for a teacher's classes.
  /// 
  /// @param teacherId ID of the teacher
  /// @return Map containing total classes, total students, and average class size
  Future<Map<String, dynamic>> getTeacherClassStats(String teacherId) async {
    try {
      final snapshot = await _classesCollection
          .where('teacherId', isEqualTo: teacherId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final classes = snapshot.docs
          .map((doc) => ClassModel.fromFirestore(doc))
          .toList();
      
      int totalStudents = 0;
      for (final classModel in classes) {
        totalStudents += classModel.studentCount;
      }
      
      return {
        'totalClasses': classes.length,
        'totalStudents': totalStudents,
        'averageClassSize': classes.isEmpty 
            ? 0 
            : (totalStudents / classes.length).round(),
      };
      
    } catch (e) {
      _logger.error('Error getting teacher class stats', error: e);
      rethrow;
    }
  }
}