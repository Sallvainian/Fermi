import '../models/assignment.dart';
import 'base_repository.dart';

abstract class AssignmentRepository extends BaseRepository {
  /// Create a new assignment
  Future<String> createAssignment(Assignment assignment);
  
  /// Get assignment by ID
  Future<Assignment?> getAssignment(String assignmentId);
  
  /// Update an assignment
  Future<void> updateAssignment(String assignmentId, Assignment assignment);
  
  /// Delete an assignment
  Future<void> deleteAssignment(String assignmentId);
  
  /// Get assignments for a class
  Stream<List<Assignment>> getClassAssignments(String classId);
  
  /// Get assignments for a teacher
  Stream<List<Assignment>> getTeacherAssignments(String teacherId);
  
  /// Get assignments for multiple classes
  Stream<List<Assignment>> getClassAssignmentsForMultipleClasses(List<String> classIds);
  
  /// Get upcoming assignments for a class
  Future<List<Assignment>> getUpcomingAssignments(String classId, {int limit = 5});
  
  /// Get overdue assignments for a class
  Future<List<Assignment>> getOverdueAssignments(String classId);
  
  /// Publish an assignment
  Future<void> publishAssignment(String assignmentId);
  
  /// Archive an assignment
  Future<void> archiveAssignment(String assignmentId);
  
  /// Unpublish an assignment
  Future<void> unpublishAssignment(String assignmentId);
  
  /// Restore an assignment from archive
  Future<void> restoreAssignment(String assignmentId);
  
  /// Get assignment statistics for a class
  Future<Map<String, dynamic>> getAssignmentStats(String classId);
}