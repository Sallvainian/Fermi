import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grade.dart';
import '../services/firestore_service.dart';
import '../services/logger_service.dart';
import 'grade_repository.dart';
import 'firestore_repository.dart';

class GradeRepositoryImpl extends FirestoreRepository<Grade> 
    implements GradeRepository {
  final FirebaseFirestore _firestore;
  
  GradeRepositoryImpl(this._firestore)
      : super(
          firestore: _firestore,
          collectionPath: 'grades',
          fromFirestore: (doc) => Grade.fromFirestore(doc),
          toFirestore: (grade) => grade.toFirestore(),
          logTag: 'GradeRepository',
        );
  
  @override
  Future<String> createGrade(Grade grade) async {
    try {
      final gradeWithTimestamp = grade.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        percentage: Grade.calculatePercentage(grade.pointsEarned, grade.pointsPossible),
        letterGrade: grade.letterGrade ?? Grade.calculateLetterGrade(
          Grade.calculatePercentage(grade.pointsEarned, grade.pointsPossible)
        ),
      );
      return await create(gradeWithTimestamp);
    } catch (e) {
      LoggerService.error('Failed to create grade', tag: tag, error: e);
      rethrow;
    }
  }  
  @override
  Future<Grade?> getGrade(String gradeId) => read(gradeId);
  
  @override
  Future<void> updateGrade(String gradeId, Grade grade) async {
    try {
      final updatedGrade = grade.copyWith(
        id: gradeId,
        updatedAt: DateTime.now(),
        percentage: Grade.calculatePercentage(grade.pointsEarned, grade.pointsPossible),
        letterGrade: grade.letterGrade ?? Grade.calculateLetterGrade(
          Grade.calculatePercentage(grade.pointsEarned, grade.pointsPossible)
        ),
      );
      await update(gradeId, updatedGrade);
    } catch (e) {
      LoggerService.error('Failed to update grade', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> deleteGrade(String gradeId) => delete(gradeId);
  
  @override
  Future<Grade?> getStudentAssignmentGrade(String studentId, String assignmentId) async {
    try {
      final grades = await list(
        conditions: [
          QueryCondition(field: 'studentId', isEqualTo: studentId),
          QueryCondition(field: 'assignmentId', isEqualTo: assignmentId),
        ],
        limit: 1,
      );
      return grades.isNotEmpty ? grades.first : null;
    } catch (e) {
      LoggerService.error('Failed to get student assignment grade', tag: tag, error: e);
      rethrow;
    }
  }  
  @override
  Stream<List<Grade>> getAssignmentGrades(String assignmentId) {
    return stream(
      conditions: [
        QueryCondition(field: 'assignmentId', isEqualTo: assignmentId),
      ],
      orderBy: [
        OrderBy(field: 'studentId', descending: false),
      ],
    );
  }
  
  @override
  Stream<List<Grade>> getStudentClassGrades(String studentId, String classId) {
    return stream(
      conditions: [
        QueryCondition(field: 'studentId', isEqualTo: studentId),
        QueryCondition(field: 'classId', isEqualTo: classId),
      ],
      orderBy: [
        OrderBy(field: 'createdAt', descending: true),
      ],
    );
  }
  
  @override
  Stream<List<Grade>> getStudentGrades(String studentId) {
    return stream(
      conditions: [
        QueryCondition(field: 'studentId', isEqualTo: studentId),
      ],
      orderBy: [
        OrderBy(field: 'createdAt', descending: true),
      ],
    );
  }  
  @override
  Future<void> submitGrade(Grade grade) async {
    try {
      final submittedGrade = grade.copyWith(
        status: GradeStatus.graded,
        gradedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      if (grade.id.isEmpty) {
        await createGrade(submittedGrade);
      } else {
        await updateGrade(grade.id, submittedGrade);
      }
    } catch (e) {
      LoggerService.error('Failed to submit grade', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> returnGrades(List<String> gradeIds) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (final gradeId in gradeIds) {
        final gradeRef = _firestore.collection('grades').doc(gradeId);
        batch.update(gradeRef, {
          'status': GradeStatus.returned.name,
          'returnedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      }
      
      await batch.commit();
      LoggerService.info('Returned ${gradeIds.length} grades', tag: tag);
    } catch (e) {
      LoggerService.error('Failed to return grades', tag: tag, error: e);
      rethrow;
    }
  }  
  
  @override
  Future<void> returnGrade(String gradeId) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('grades').doc(gradeId).update({
        'status': GradeStatus.returned.name,
        'returnedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      LoggerService.info('Returned grade $gradeId', tag: tag);
    } catch (e) {
      LoggerService.error('Failed to return grade', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Stream<List<Grade>> getClassGrades(String classId) {
    return stream(
      conditions: [
        QueryCondition(field: 'classId', isEqualTo: classId),
      ],
      orderBy: [
        OrderBy(field: 'createdAt', descending: true),
      ],
    );
  }
  
  @override
  Future<GradeStatistics> getAssignmentStatistics(String assignmentId) async {
    try {
      final grades = await list(
        conditions: [
          QueryCondition(field: 'assignmentId', isEqualTo: assignmentId),
          QueryCondition(field: 'status', whereIn: [
            GradeStatus.graded.name,
            GradeStatus.returned.name,
          ]),
        ],
      );
      return GradeStatistics.fromGrades(grades);
    } catch (e) {
      LoggerService.error('Failed to get assignment statistics', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<GradeStatistics> getStudentClassStatistics(String studentId, String classId) async {
    try {
      final grades = await list(
        conditions: [
          QueryCondition(field: 'studentId', isEqualTo: studentId),
          QueryCondition(field: 'classId', isEqualTo: classId),
          QueryCondition(field: 'status', whereIn: [
            GradeStatus.graded.name,
            GradeStatus.returned.name,
          ]),
        ],
      );
      return GradeStatistics.fromGrades(grades);
    } catch (e) {
      LoggerService.error('Failed to get student class statistics', tag: tag, error: e);
      rethrow;
    }
  }  
  @override
  Future<GradeStatistics> getClassStatistics(String classId) async {
    try {
      final grades = await list(
        conditions: [
          QueryCondition(field: 'classId', isEqualTo: classId),
          QueryCondition(field: 'status', whereIn: [
            GradeStatus.graded.name,
            GradeStatus.returned.name,
          ]),
        ],
      );
      return GradeStatistics.fromGrades(grades);
    } catch (e) {
      LoggerService.error('Failed to get class statistics', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> batchUpdateGrades(Map<String, Grade> grades) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      grades.forEach((gradeId, grade) {
        final gradeRef = _firestore.collection('grades').doc(gradeId);
        final updatedGrade = grade.copyWith(
          updatedAt: now,
          percentage: Grade.calculatePercentage(grade.pointsEarned, grade.pointsPossible),
          letterGrade: grade.letterGrade ?? Grade.calculateLetterGrade(
            Grade.calculatePercentage(grade.pointsEarned, grade.pointsPossible)
          ),
        );
        batch.update(gradeRef, updatedGrade.toFirestore());
      });
      
      await batch.commit();
      LoggerService.info('Batch updated ${grades.length} grades', tag: tag);
    } catch (e) {
      LoggerService.error('Failed to batch update grades', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> initializeGradesForAssignment(
    String assignmentId,
    String classId,
    String teacherId,
    double totalPoints,
  ) async {
    try {
      // Get all students in the class
      final studentQuery = await _firestore
          .collection('students')
          .where('classIds', arrayContains: classId)
          .get();
      
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (final studentDoc in studentQuery.docs) {
        final studentId = studentDoc.id;
        final studentData = studentDoc.data();
        final studentName = studentData['displayName'] ?? 'Unknown Student';
        
        // Create a new grade for each student
        final gradeRef = _firestore.collection('grades').doc();
        final grade = Grade(
          id: gradeRef.id,
          studentId: studentId,
          studentName: studentName,
          assignmentId: assignmentId,
          teacherId: teacherId,
          classId: classId,
          pointsEarned: 0,
          pointsPossible: totalPoints,
          percentage: 0,
          letterGrade: 'F',
          feedback: '',
          status: GradeStatus.notSubmitted,
          createdAt: now,
          updatedAt: now,
        );
        
        batch.set(gradeRef, grade.toFirestore());
      }
      
      await batch.commit();
      LoggerService.info(
        'Initialized grades for ${studentQuery.docs.length} students in assignment $assignmentId',
        tag: tag,
      );
    } catch (e) {
      LoggerService.error('Failed to initialize grades for assignment', tag: tag, error: e);
      rethrow;
    }
  }
}