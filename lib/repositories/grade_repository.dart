import '../models/grade.dart';
import 'base_repository.dart';

abstract class GradeRepository extends BaseRepository {
  /// Create a new grade
  Future<String> createGrade(Grade grade);
  
  /// Get grade by ID
  Future<Grade?> getGrade(String gradeId);
  
  /// Update a grade
  Future<void> updateGrade(String gradeId, Grade grade);
  
  /// Delete a grade
  Future<void> deleteGrade(String gradeId);
  
  /// Get grade for a specific student and assignment
  Future<Grade?> getStudentAssignmentGrade(String studentId, String assignmentId);
  
  /// Get all grades for an assignment
  Stream<List<Grade>> getAssignmentGrades(String assignmentId);
  
  /// Get all grades for a student in a class
  Stream<List<Grade>> getStudentClassGrades(String studentId, String classId);
  
  /// Get all grades for a student
  Stream<List<Grade>> getStudentGrades(String studentId);
  
  /// Submit a grade
  Future<void> submitGrade(Grade grade);
  
  /// Return grades to students
  Future<void> returnGrades(List<String> gradeIds);
  
  /// Return a single grade to student
  Future<void> returnGrade(String gradeId);
  
  /// Get all grades for a class
  Stream<List<Grade>> getClassGrades(String classId);
  
  /// Get grade statistics for an assignment
  Future<GradeStatistics> getAssignmentStatistics(String assignmentId);
  
  /// Get grade statistics for a student in a class
  Future<GradeStatistics> getStudentClassStatistics(String studentId, String classId);
  
  /// Get grade statistics for a class
  Future<GradeStatistics> getClassStatistics(String classId);
  
  /// Batch update grades
  Future<void> batchUpdateGrades(Map<String, Grade> grades);
  
  /// Initialize grades for all students in a class for a new assignment
  Future<void> initializeGradesForAssignment(
    String assignmentId,
    String classId,
    String teacherId,
    double totalPoints,
  );
}