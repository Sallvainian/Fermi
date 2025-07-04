import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../models/grade.dart';
import '../services/firestore_service.dart';
import '../services/logger_service.dart';
import 'student_repository.dart';
import 'firestore_repository.dart';

class StudentRepositoryImpl extends FirestoreRepository<Student> implements StudentRepository {
  static const String _tag = 'StudentRepository';
  final FirebaseFirestore _firestore;

  StudentRepositoryImpl(this._firestore)
      : super(
          firestore: _firestore,
          collectionPath: 'students',
          fromFirestore: (doc) => Student.fromFirestore(doc),
          toFirestore: (student) => student.toFirestore(),
          logTag: _tag,
        );

  @override
  Future<String> createStudent(Student student) async {
    try {
      // Update timestamp
      final studentToCreate = student.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return await create(studentToCreate);
    } catch (e) {
      LoggerService.error('Failed to create student', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<Student?> getStudent(String id) => read(id);

  @override
  Future<Student?> getStudentByUserId(String userId) async {
    try {
      final students = await list(
        conditions: [
          QueryCondition(field: 'userId', isEqualTo: userId),
        ],
        limit: 1,
      );
      return students.isEmpty ? null : students.first;
    } catch (e) {
      LoggerService.error('Failed to get student by user ID', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> updateStudent(String id, Student student) async {
    try {
      // Update timestamp
      final studentToUpdate = student.copyWith(
        updatedAt: DateTime.now(),
      );
      await update(id, studentToUpdate);
    } catch (e) {
      LoggerService.error('Failed to update student', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteStudent(String id) => delete(id);

  @override
  Future<void> enrollInClass(String studentId, String classId) async {
    try {
      await _firestore.collection('students').doc(studentId).update({
        'classIds': FieldValue.arrayUnion([classId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Student $studentId enrolled in class $classId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to enroll student in class', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> unenrollFromClass(String studentId, String classId) async {
    try {
      await _firestore.collection('students').doc(studentId).update({
        'classIds': FieldValue.arrayRemove([classId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Student $studentId unenrolled from class $classId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to unenroll student from class', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> enrollInMultipleClasses(String studentId, List<String> classIds) async {
    try {
      await _firestore.collection('students').doc(studentId).update({
        'classIds': FieldValue.arrayUnion(classIds),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Student $studentId enrolled in ${classIds.length} classes', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to enroll student in multiple classes', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Stream<List<Student>> getClassStudents(String classId) {
    return stream(
      conditions: [
        QueryCondition(field: 'classIds', arrayContains: classId),
        QueryCondition(field: 'isActive', isEqualTo: true),
      ],
      orderBy: [OrderBy(field: 'lastName'), OrderBy(field: 'firstName')],
    );
  }

  @override
  Stream<List<Student>> getActiveStudents() {
    return stream(
      conditions: [
        QueryCondition(field: 'isActive', isEqualTo: true),
      ],
      orderBy: [OrderBy(field: 'lastName'), OrderBy(field: 'firstName')],
    );
  }

  @override
  Stream<List<Student>> getStudentsByGradeLevel(int gradeLevel) {
    return stream(
      conditions: [
        QueryCondition(field: 'gradeLevel', isEqualTo: gradeLevel),
        QueryCondition(field: 'isActive', isEqualTo: true),
      ],
      orderBy: [OrderBy(field: 'lastName'), OrderBy(field: 'firstName')],
    );
  }

  @override
  Future<List<Student>> searchStudents(String query) async {
    try {
      final lowercaseQuery = query.toLowerCase();
      
      // This is a simple implementation. For better search, consider using
      // a search service like Algolia or implementing full-text search
      final allStudents = await list(
        conditions: [
          QueryCondition(field: 'isActive', isEqualTo: true),
        ],
      );
      
      return allStudents.where((student) {
        return student.firstName.toLowerCase().contains(lowercaseQuery) ||
               student.lastName.toLowerCase().contains(lowercaseQuery) ||
               student.email.toLowerCase().contains(lowercaseQuery) ||
               student.displayName.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      LoggerService.error('Failed to search students', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<GradeStatistics?> getStudentOverallStatistics(String studentId) async {
    try {
      final gradesSnapshot = await _firestore
          .collection('grades')
          .where('studentId', isEqualTo: studentId)
          .where('status', whereIn: [
            GradeStatus.graded.name,
            GradeStatus.returned.name,
          ])
          .get();
      
      if (gradesSnapshot.docs.isEmpty) return null;
      
      final grades = gradesSnapshot.docs
          .map((doc) => Grade.fromFirestore(doc))
          .toList();
      
      return GradeStatistics.fromGrades(grades);
    } catch (e) {
      LoggerService.error('Failed to get student overall statistics', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<Map<String, GradeStatistics>> getStudentStatisticsByClass(String studentId) async {
    try {
      final gradesSnapshot = await _firestore
          .collection('grades')
          .where('studentId', isEqualTo: studentId)
          .where('status', whereIn: [
            GradeStatus.graded.name,
            GradeStatus.returned.name,
          ])
          .get();
      
      if (gradesSnapshot.docs.isEmpty) return {};
      
      final grades = gradesSnapshot.docs
          .map((doc) => Grade.fromFirestore(doc))
          .toList();
      
      // Group grades by class
      final gradesByClass = <String, List<Grade>>{};
      for (final grade in grades) {
        gradesByClass.putIfAbsent(grade.classId, () => []).add(grade);
      }
      
      // Calculate statistics for each class
      final statisticsByClass = <String, GradeStatistics>{};
      gradesByClass.forEach((classId, classGrades) {
        statisticsByClass[classId] = GradeStatistics.fromGrades(classGrades);
      });
      
      return statisticsByClass;
    } catch (e) {
      LoggerService.error('Failed to get student statistics by class', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Stream<List<Student>> getStudentsByParentEmail(String parentEmail) {
    return stream(
      conditions: [
        QueryCondition(field: 'parentEmail', isEqualTo: parentEmail),
        QueryCondition(field: 'isActive', isEqualTo: true),
      ],
      orderBy: [OrderBy(field: 'lastName'), OrderBy(field: 'firstName')],
    );
  }

  @override
  Future<void> batchCreateStudents(List<Student> students) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (final student in students) {
        final ref = _firestore.collection('students').doc();
        final studentToCreate = student.copyWith(
          id: ref.id,
          createdAt: now,
          updatedAt: now,
        );
        batch.set(ref, studentToCreate.toFirestore());
      }
      
      await batch.commit();
      LoggerService.info('Batch created ${students.length} students', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to batch create students', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> batchUpdateStudents(Map<String, Student> students) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      students.forEach((studentId, student) {
        final ref = _firestore.collection('students').doc(studentId);
        final studentToUpdate = student.copyWith(
          updatedAt: now,
        );
        batch.update(ref, studentToUpdate.toFirestore());
      });
      
      await batch.commit();
      LoggerService.info('Batch updated ${students.length} students', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to batch update students', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<bool> isEmailAvailable(String email) async {
    try {
      final existing = await list(
        conditions: [
          QueryCondition(field: 'email', isEqualTo: email),
        ],
        limit: 1,
      );
      return existing.isEmpty;
    } catch (e) {
      LoggerService.error('Failed to check email availability', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<bool> isStudentEnrolledInClass(String studentId, String classId) async {
    try {
      final student = await read(studentId);
      return student?.classIds.contains(classId) ?? false;
    } catch (e) {
      LoggerService.error('Failed to check student enrollment', tag: _tag, error: e);
      rethrow;
    }
  }
}