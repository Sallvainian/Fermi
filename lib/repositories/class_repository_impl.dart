import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/logger_service.dart';
import 'class_repository.dart';
import 'firestore_repository.dart';

class ClassRepositoryImpl extends FirestoreRepository<ClassModel> 
    implements ClassRepository {
  final FirebaseFirestore _firestore;
  
  ClassRepositoryImpl(this._firestore)
      : super(
          firestore: _firestore,
          collectionPath: 'classes',
          fromFirestore: (doc) => ClassModel.fromFirestore(doc),
          toFirestore: (classModel) => classModel.toFirestore(),
          logTag: 'ClassRepository',
        );
  
  @override
  Future<String> createClass(ClassModel classModel) async {
    try {
      final classWithTimestamp = classModel.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        studentIds: [],
      );
      return await create(classWithTimestamp);
    } catch (e) {
      LoggerService.error('Failed to create class', tag: tag, error: e);
      rethrow;
    }
  }  
  @override
  Future<ClassModel?> getClass(String classId) => read(classId);
  
  @override
  Future<void> updateClass(String classId, ClassModel classModel) async {
    try {
      final updatedClass = classModel.copyWith(
        id: classId,
        updatedAt: DateTime.now(),
      );
      await update(classId, updatedClass);
    } catch (e) {
      LoggerService.error('Failed to update class', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> deleteClass(String classId) => delete(classId);
  
  @override
  Stream<List<ClassModel>> getTeacherClasses(String teacherId) {
    return stream(
      conditions: [
        QueryCondition(field: 'teacherId', isEqualTo: teacherId),
      ],
      orderBy: [
        OrderBy(field: 'name', descending: false),
      ],
    );
  }  
  @override
  Stream<List<ClassModel>> getStudentClasses(String studentId) {
    return stream(
      conditions: [
        QueryCondition(field: 'studentIds', arrayContains: studentId),
        QueryCondition(field: 'isActive', isEqualTo: true),
      ],
      orderBy: [
        OrderBy(field: 'name', descending: false),
      ],
    );
  }
  
  @override
  Future<void> addStudent(String classId, String studentId) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': FieldValue.arrayUnion([studentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Added student $studentId to class $classId', tag: tag);
    } catch (e) {
      LoggerService.error('Failed to add student to class', tag: tag, error: e);
      rethrow;
    }
  }  
  @override
  Future<void> removeStudent(String classId, String studentId) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': FieldValue.arrayRemove([studentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Removed student $studentId from class $classId', tag: tag);
    } catch (e) {
      LoggerService.error('Failed to remove student from class', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<List<UserModel>> getClassStudents(String classId) async {
    try {
      final classModel = await getClass(classId);
      if (classModel == null || classModel.studentIds.isEmpty) {
        return [];
      }
      
      final studentDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: classModel.studentIds)
          .get();
      
      return studentDocs.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user.role == UserRole.student)
          .toList();
    } catch (e) {
      LoggerService.error('Failed to get class students', tag: tag, error: e);
      rethrow;
    }
  }  
  @override
  Future<bool> isStudentEnrolled(String classId, String studentId) async {
    try {
      final classModel = await getClass(classId);
      return classModel?.studentIds.contains(studentId) ?? false;
    } catch (e) {
      LoggerService.error('Failed to check student enrollment', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<Map<String, dynamic>> getClassStats(String classId) async {
    try {
      final classModel = await getClass(classId);
      if (classModel == null) {
        return {};
      }
      
      // Get assignment count
      final assignmentCount = await _firestore
          .collection('assignments')
          .where('classId', isEqualTo: classId)
          .count()
          .get();
      
      // Get average grade (if grades are available)
      // This is a simplified version - you might want to implement more complex logic
      
      return {
        'studentCount': classModel.studentCount,
        'assignmentCount': assignmentCount.count,
        'isActive': classModel.isActive,
        'isFull': classModel.isFull,
        'capacity': classModel.maxStudents ?? 'Unlimited',
      };
    } catch (e) {
      LoggerService.error('Failed to get class stats', tag: tag, error: e);
      rethrow;
    }
  }  
  @override
  Future<void> archiveClass(String classId) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Archived class $classId', tag: tag);
    } catch (e) {
      LoggerService.error('Failed to archive class', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<List<ClassModel>> getActiveClasses(String teacherId, String academicYear) async {
    return await list(
      conditions: [
        QueryCondition(field: 'teacherId', isEqualTo: teacherId),
        QueryCondition(field: 'academicYear', isEqualTo: academicYear),
        QueryCondition(field: 'isActive', isEqualTo: true),
      ],
      orderBy: [
        OrderBy(field: 'name', descending: false),
      ],
    );
  }
  
  @override
  Future<void> restoreClass(String classId) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Restored class $classId', tag: tag);
    } catch (e) {
      LoggerService.error('Failed to restore class', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> enrollStudent(String classId, String studentId) async {
    try {
      await addStudent(classId, studentId);
    } catch (e) {
      LoggerService.error('Failed to enroll student', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> unenrollStudent(String classId, String studentId) async {
    try {
      await removeStudent(classId, studentId);
    } catch (e) {
      LoggerService.error('Failed to unenroll student', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> enrollMultipleStudents(String classId, List<String> studentIds) async {
    try {
      final batch = _firestore.batch();
      
      // Update class document
      final classRef = _firestore.collection('classes').doc(classId);
      batch.update(classRef, {
        'studentIds': FieldValue.arrayUnion(studentIds),
        'studentCount': FieldValue.increment(studentIds.length),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update each student document
      for (final studentId in studentIds) {
        final studentRef = _firestore.collection('students').doc(studentId);
        batch.update(studentRef, {
          'classIds': FieldValue.arrayUnion([classId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      LoggerService.info('Enrolled ${studentIds.length} students in class $classId', tag: tag);
    } catch (e) {
      LoggerService.error('Failed to enroll multiple students', tag: tag, error: e);
      rethrow;
    }
  }
}