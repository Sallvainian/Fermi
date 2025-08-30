import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/grade.dart';
import '../../../../shared/services/firestore_repository.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/services/retry_service.dart';

/// Refactored service for managing student grades.
///
/// This implementation delegates all generic CRUD operations to the
/// reusable [FirestoreRepository], avoiding duplication of Firestore
/// interaction code. It exposes higher level domain operations such
/// as bulk grading and statistics while remaining focused on grade-
/// specific logic.
class GradeService {
  final FirestoreRepository<Grade> _repository;

  GradeService({
    FirebaseFirestore? firestore,
  }) : _repository = FirestoreRepository<Grade>(
          collectionPath: 'grades',
          firestore: firestore,
          fromFirestore: (doc) => Grade.fromFirestore(doc),
          toFirestore: (model) => model.toFirestore(),
        );

  /// Creates a new grade record
  Future<Grade> createGrade(Grade grade) async {
    return await RetryService.withRetry(
      () async {
        final id = await _repository.create(grade.toFirestore());
        final createdGrade = grade.copyWith(id: id);
        
        LoggerService.info(
            'Created grade for student ${grade.studentId} on assignment ${grade.assignmentId}');
        return createdGrade;
      },
      config: RetryConfigs.standard,
    );
  }

  /// Retrieves a single grade by ID
  Future<Grade?> getGrade(String gradeId) async {
    return await _repository.get(gradeId);
  }

  /// Updates an existing grade
  Future<void> updateGrade(Grade grade) async {
    await RetryService.withRetry(
      () async {
        final data = grade.toFirestore();
        data['updatedAt'] = FieldValue.serverTimestamp();
        await _repository.update(grade.id, data);
        LoggerService.info('Updated grade: ${grade.id}');
      },
      config: RetryConfigs.standard,
    );
  }

  /// Deletes a grade record
  Future<void> deleteGrade(String gradeId) async {
    await _repository.delete(gradeId);
    LoggerService.info('Deleted grade: $gradeId');
  }

  /// Gets grade for a specific student and assignment
  Future<Grade?> getGradeForStudentAndAssignment(
      String studentId, String assignmentId) async {
    final grades = await _repository.getList((col) => col
        .where('studentId', isEqualTo: studentId)
        .where('assignmentId', isEqualTo: assignmentId)
        .limit(1));
    
    return grades.isNotEmpty ? grades.first : null;
  }

  /// Streams grades for a specific assignment
  Stream<List<Grade>> getGradesForAssignment(String assignmentId) {
    return _repository.streamList((col) => col
        .where('assignmentId', isEqualTo: assignmentId)
        .orderBy('studentName'));
  }

  /// Streams grades for a specific student
  Stream<List<Grade>> getGradesForStudent(String studentId) {
    return _repository.streamList((col) => col
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true));
  }

  /// Streams grades for a specific class
  Stream<List<Grade>> getGradesForClass(String classId) {
    return _repository.streamList((col) => col
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true));
  }

  /// Gets grades for a teacher across all their classes
  Future<List<Grade>> getGradesForTeacher(String teacherId) async {
    return await _repository.getList((col) => col
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true));
  }

  /// Bulk creates grades for multiple students
  Future<void> bulkCreateGrades(List<Grade> grades) async {
    if (grades.isEmpty) return;
    
    await RetryService.withRetry(
      () async {
        final batch = _repository.firestore.batch();
        
        for (final grade in grades) {
          final docRef = _repository.collection.doc();
          batch.set(docRef, grade.copyWith(id: docRef.id).toFirestore());
        }
        
        await batch.commit();
        LoggerService.info('Bulk created ${grades.length} grades');
      },
      config: RetryConfigs.aggressive,  // More retries for bulk operations
      onRetry: (attempt, delay, error) {
        LoggerService.warning(
            'Retrying bulk grade creation (attempt $attempt): ${error.toString()}');
      },
    );
  }

  /// Bulk updates grades
  Future<void> bulkUpdateGrades(List<Grade> grades) async {
    if (grades.isEmpty) return;
    
    await RetryService.withRetry(
      () async {
        final batch = _repository.firestore.batch();
        
        for (final grade in grades) {
          final data = grade.toFirestore();
          data['updatedAt'] = FieldValue.serverTimestamp();
          batch.update(_repository.collection.doc(grade.id), data);
        }
        
        await batch.commit();
        LoggerService.info('Bulk updated ${grades.length} grades');
      },
      config: RetryConfigs.aggressive,  // More retries for bulk operations
      onRetry: (attempt, delay, error) {
        LoggerService.warning(
            'Retrying bulk grade update (attempt $attempt): ${error.toString()}');
      },
    );
  }

  /// Marks grades as returned to students
  Future<void> returnGrades(List<String> gradeIds) async {
    if (gradeIds.isEmpty) return;
    
    await RetryService.withRetry(
      () async {
        final batch = _repository.firestore.batch();
        
        for (final gradeId in gradeIds) {
          batch.update(_repository.collection.doc(gradeId), {
            'status': GradeStatus.returned.name,
            'returnedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        
        await batch.commit();
        LoggerService.info('Returned ${gradeIds.length} grades to students');
      },
      config: RetryConfigs.standard,
    );
  }

  /// Gets grade statistics for an assignment
  Future<GradeStatistics> getAssignmentStatistics(String assignmentId) async {
    final grades = await _repository.getList((col) => col
        .where('assignmentId', isEqualTo: assignmentId)
        .where('status', whereIn: [
          GradeStatus.graded.name,
          GradeStatus.returned.name,
          GradeStatus.revised.name,
        ]));
    
    return GradeStatistics.fromGrades(grades);
  }

  /// Gets grade statistics for a student
  Future<GradeStatistics> getStudentStatistics(
      String studentId, {String? classId}) async {
    var query = _repository.collection
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: [
          GradeStatus.graded.name,
          GradeStatus.returned.name,
          GradeStatus.revised.name,
        ]);
    
    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }
    
    final grades = await query.get();
    final gradeList = grades.docs.map((doc) => Grade.fromFirestore(doc)).toList();
    
    return GradeStatistics.fromGrades(gradeList);
  }

  /// Gets grade statistics for a class
  Future<GradeStatistics> getClassStatistics(String classId) async {
    final grades = await _repository.getList((col) => col
        .where('classId', isEqualTo: classId)
        .where('status', whereIn: [
          GradeStatus.graded.name,
          GradeStatus.returned.name,
          GradeStatus.revised.name,
        ]));
    
    return GradeStatistics.fromGrades(grades);
  }

  /// Gets pending grades for a teacher
  Future<List<Grade>> getPendingGrades(String teacherId) async {
    return await _repository.getList((col) => col
        .where('teacherId', isEqualTo: teacherId)
        .where('status', isEqualTo: GradeStatus.pending.name)
        .orderBy('createdAt'));
  }

  /// Gets recent grades for a teacher
  Future<List<Grade>> getRecentGrades(String teacherId, {int days = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    return await _repository.getList((col) => col
        .where('teacherId', isEqualTo: teacherId)
        .where('gradedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
        .orderBy('gradedAt', descending: true));
  }

  /// Archives old grades
  Future<void> archiveOldGrades({int daysOld = 180}) async {
    await RetryService.withRetry(
      () async {
        final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
        
        final grades = await _repository.getList((col) => col
            .where('status', isEqualTo: GradeStatus.returned.name)
            .where('returnedAt', isLessThan: Timestamp.fromDate(cutoffDate)));
        
        if (grades.isEmpty) return;
        
        final batch = _repository.firestore.batch();
        
        for (final grade in grades) {
          // Move to archived collection
          batch.set(_repository.firestore.collection('archived_grades').doc(grade.id), 
              grade.toFirestore());
          batch.delete(_repository.collection.doc(grade.id));
        }
        
        await batch.commit();
        LoggerService.info('Archived ${grades.length} old grades');
      },
      config: RetryConfigs.standard,
    );
  }

  /// Calculates grade summary for a teacher's dashboard
  Future<Map<String, dynamic>> getTeacherGradeSummary(String teacherId) async {
    final grades = await _repository.getList((col) => col
        .where('teacherId', isEqualTo: teacherId));
    
    int pendingCount = 0;
    int gradedCount = 0;
    int returnedCount = 0;
    double totalPoints = 0;
    double earnedPoints = 0;
    
    for (final grade in grades) {
      switch (grade.status) {
        case GradeStatus.pending:
        case GradeStatus.notSubmitted:
          pendingCount++;
          break;
        case GradeStatus.graded:
        case GradeStatus.revised:
          gradedCount++;
          totalPoints += grade.pointsPossible;
          earnedPoints += grade.pointsEarned;
          break;
        case GradeStatus.returned:
          returnedCount++;
          totalPoints += grade.pointsPossible;
          earnedPoints += grade.pointsEarned;
          break;
        default:
          break;
      }
    }
    
    return {
      'totalGrades': grades.length,
      'pendingGrades': pendingCount,
      'gradedGrades': gradedCount,
      'returnedGrades': returnedCount,
      'averagePercentage': totalPoints > 0 ? (earnedPoints / totalPoints) * 100 : 0,
    };
  }
}