/// Grade repository interface for academic assessment management.
/// 
/// This module defines the contract for grade operations in the
/// education platform, supporting grade creation, tracking,
/// statistics, and batch operations.
library;

import '../models/grade.dart';
import '../../../../shared/repositories/base_repository.dart';

/// Abstract repository defining grade management operations.
/// 
/// This interface provides a comprehensive contract for grade
/// implementations, supporting:
/// - CRUD operations for individual grades
/// - Student-assignment grade associations
/// - Grade submission and return workflows
/// - Statistical analysis at multiple levels
/// - Batch operations for efficiency
/// - Real-time grade streaming
/// - Initialization for new assignments
/// 
/// Concrete implementations handle the actual grade
/// calculation and persistence logic.
abstract class GradeRepository extends BaseRepository {
  /// Creates a new grade entry in the system.
  /// 
  /// Initializes a grade with score, feedback, and metadata.
  /// Returns the generated grade ID for reference.
  /// 
  /// @param grade Grade model with score and details
  /// @return Generated unique grade ID
  /// @throws Exception if creation fails
  Future<String> createGrade(Grade grade);
  
  /// Retrieves a grade by its unique identifier.
  /// 
  /// Fetches complete grade details including score,
  /// feedback, and submission status.
  /// 
  /// @param gradeId Unique grade identifier
  /// @return Grade instance or null if not found
  /// @throws Exception if retrieval fails
  Future<Grade?> getGrade(String gradeId);
  
  /// Updates an existing grade.
  /// 
  /// Modifies grade details such as score, feedback,
  /// or status. Typically used for re-grading.
  /// 
  /// @param gradeId ID of grade to update
  /// @param grade Updated grade information
  /// @throws Exception if update fails
  Future<void> updateGrade(String gradeId, Grade grade);
  
  /// Permanently deletes a grade.
  /// 
  /// Removes the grade record completely. This operation
  /// cannot be undone and should be used cautiously.
  /// 
  /// @param gradeId ID of grade to delete
  /// @throws Exception if deletion fails
  Future<void> deleteGrade(String gradeId);
  
  /// Retrieves the grade for a specific student-assignment pair.
  /// 
  /// Fetches the grade a student received for a particular
  /// assignment. Useful for individual grade lookup.
  /// 
  /// @param studentId Student's unique identifier
  /// @param assignmentId Assignment's unique identifier
  /// @return Grade instance or null if not graded
  /// @throws Exception if retrieval fails
  Future<Grade?> getStudentAssignmentGrade(String studentId, String assignmentId);
  
  /// Streams all grades for a specific assignment.
  /// 
  /// Returns real-time updates of all student grades
  /// for an assignment. Useful for grading dashboards.
  /// 
  /// @param assignmentId Assignment to get grades for
  /// @return Stream of grade lists
  Stream<List<Grade>> getAssignmentGrades(String assignmentId);
  
  /// Streams all grades for a student in a specific class.
  /// 
  /// Returns real-time updates of a student's grades
  /// across all assignments in a class.
  /// 
  /// @param studentId Student's unique identifier
  /// @param classId Class identifier
  /// @return Stream of student's grades in the class
  Stream<List<Grade>> getStudentClassGrades(String studentId, String classId);
  
  /// Streams all grades for a student across all classes.
  /// 
  /// Returns comprehensive grade history for a student.
  /// Useful for transcript generation.
  /// 
  /// @param studentId Student's unique identifier
  /// @return Stream of all student grades
  Stream<List<Grade>> getStudentGrades(String studentId);
  
  /// Submits a grade for an assignment.
  /// 
  /// Records the grade and updates submission status.
  /// May trigger notifications to the student.
  /// 
  /// @param grade Grade to submit with score and feedback
  /// @throws Exception if submission fails
  Future<void> submitGrade(Grade grade);
  
  /// Returns multiple grades to students.
  /// 
  /// Batch operation to make grades visible to students.
  /// Updates status and may send notifications.
  /// 
  /// @param gradeIds List of grade IDs to return
  /// @throws Exception if return operation fails
  Future<void> returnGrades(List<String> gradeIds);
  
  /// Returns a single grade to a student.
  /// 
  /// Makes the grade visible to the student and
  /// updates the return status.
  /// 
  /// @param gradeId Grade ID to return
  /// @throws Exception if return fails
  Future<void> returnGrade(String gradeId);
  
  /// Streams all grades for an entire class.
  /// 
  /// Returns real-time updates of all grades across
  /// all assignments and students in a class.
  /// 
  /// @param classId Class identifier
  /// @return Stream of all grades in the class
  Stream<List<Grade>> getClassGrades(String classId);
  
  /// Calculates grade statistics for an assignment.
  /// 
  /// Generates aggregate data including:
  /// - Average, median, and mode scores
  /// - Grade distribution
  /// - Completion rates
  /// - Standard deviation
  /// 
  /// @param assignmentId Assignment to analyze
  /// @return Statistical summary of grades
  /// @throws Exception if calculation fails
  Future<GradeStatistics> getAssignmentStatistics(String assignmentId);
  
  /// Calculates grade statistics for a student in a class.
  /// 
  /// Generates student performance metrics including:
  /// - Overall average
  /// - Assignment completion rate
  /// - Grade trends
  /// - Performance relative to class
  /// 
  /// @param studentId Student to analyze
  /// @param classId Class context
  /// @return Student's statistical summary
  /// @throws Exception if calculation fails
  Future<GradeStatistics> getStudentClassStatistics(String studentId, String classId);
  
  /// Calculates overall grade statistics for a class.
  /// 
  /// Generates class-wide metrics including:
  /// - Class average across all assignments
  /// - Grade distribution patterns
  /// - Assignment difficulty indicators
  /// - Student performance rankings
  /// 
  /// @param classId Class to analyze
  /// @return Class statistical summary
  /// @throws Exception if calculation fails
  Future<GradeStatistics> getClassStatistics(String classId);
  
  /// Updates multiple grades in a single operation.
  /// 
  /// Efficient batch update for grading multiple
  /// submissions at once. All updates succeed or
  /// fail together for consistency.
  /// 
  /// @param grades Map of grade IDs to updated grades
  /// @throws Exception if batch update fails
  Future<void> batchUpdateGrades(Map<String, Grade> grades);
  
  /// Initializes grade records for a new assignment.
  /// 
  /// Creates placeholder grade entries for all students
  /// in a class when a new assignment is created. This
  /// allows tracking of missing submissions.
  /// 
  /// @param assignmentId New assignment identifier
  /// @param classId Class with enrolled students
  /// @param teacherId Teacher creating the assignment
  /// @param totalPoints Maximum possible score
  /// @throws Exception if initialization fails
  Future<void> initializeGradesForAssignment(
    String assignmentId,
    String classId,
    String teacherId,
    double totalPoints,
  );
}