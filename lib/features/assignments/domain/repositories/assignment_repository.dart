/// Assignment repository interface for academic task management.
/// 
/// This module defines the contract for assignment operations
/// in the education platform, supporting creation, management,
/// and tracking of academic assignments.
library;

import '../models/assignment.dart';
import '../../../../shared/repositories/base_repository.dart';

/// Abstract repository defining assignment management operations.
/// 
/// This interface provides a comprehensive contract for assignment
/// implementations, supporting:
/// - CRUD operations for assignments
/// - Class and teacher-based assignment queries
/// - Assignment state management (publish/archive)
/// - Due date tracking and filtering
/// - Statistical analysis of assignments
/// - Real-time assignment updates
/// 
/// Concrete implementations handle the actual data persistence
/// and retrieval logic with specific data sources.
abstract class AssignmentRepository extends BaseRepository {
  /// Creates a new assignment in the system.
  /// 
  /// Creates an assignment with all required metadata including
  /// title, description, due date, and associated class.
  /// 
  /// @param assignment Assignment model to create
  /// @return Generated assignment ID
  /// @throws Exception if creation fails
  Future<String> createAssignment(Assignment assignment);
  
  /// Retrieves a single assignment by ID.
  /// 
  /// Fetches the complete assignment details including
  /// all metadata, attachments, and settings.
  /// 
  /// @param assignmentId Unique assignment identifier
  /// @return Assignment instance or null if not found
  /// @throws Exception if retrieval fails
  Future<Assignment?> getAssignment(String assignmentId);
  
  /// Updates an existing assignment.
  /// 
  /// Modifies assignment details such as title, description,
  /// due date, or instructions. Cannot change the associated
  /// class after creation.
  /// 
  /// @param assignmentId ID of assignment to update
  /// @param assignment Updated assignment model
  /// @throws Exception if update fails or assignment not found
  Future<void> updateAssignment(String assignmentId, Assignment assignment);
  
  /// Permanently deletes an assignment.
  /// 
  /// Removes the assignment and all associated data.
  /// This operation cannot be undone. Consider archiving
  /// instead for recoverable deletion.
  /// 
  /// @param assignmentId ID of assignment to delete
  /// @throws Exception if deletion fails
  Future<void> deleteAssignment(String assignmentId);
  
  /// Streams all assignments for a specific class.
  /// 
  /// Returns a real-time stream of assignments associated
  /// with the given class. Updates automatically when
  /// assignments are added, modified, or removed.
  /// 
  /// @param classId Class identifier
  /// @return Stream of assignment lists
  Stream<List<Assignment>> getClassAssignments(String classId);
  
  /// Streams all assignments created by a teacher.
  /// 
  /// Returns assignments across all classes taught by
  /// the specified teacher. Useful for teacher dashboards
  /// and cross-class assignment management.
  /// 
  /// @param teacherId Teacher's user ID
  /// @return Stream of assignment lists
  Stream<List<Assignment>> getTeacherAssignments(String teacherId);
  
  /// Streams assignments for multiple classes.
  /// 
  /// Aggregates assignments from multiple classes into a
  /// single stream. Useful for students enrolled in multiple
  /// classes or teachers viewing all their assignments.
  /// 
  /// @param classIds List of class identifiers
  /// @return Stream of combined assignment lists
  Stream<List<Assignment>> getClassAssignmentsForMultipleClasses(List<String> classIds);
  
  /// Retrieves upcoming assignments for a class.
  /// 
  /// Fetches assignments with due dates in the future,
  /// sorted by due date (earliest first). Useful for
  /// showing upcoming work in dashboards.
  /// 
  /// @param classId Class identifier
  /// @param limit Maximum number of assignments to return
  /// @return List of upcoming assignments
  /// @throws Exception if query fails
  Future<List<Assignment>> getUpcomingAssignments(String classId, {int limit = 5});
  
  /// Retrieves overdue assignments for a class.
  /// 
  /// Fetches assignments with due dates in the past that
  /// may still accept late submissions. Useful for tracking
  /// missing work and sending reminders.
  /// 
  /// @param classId Class identifier
  /// @return List of overdue assignments
  /// @throws Exception if query fails
  Future<List<Assignment>> getOverdueAssignments(String classId);
  
  /// Publishes a draft assignment to students.
  /// 
  /// Makes the assignment visible to students and starts
  /// accepting submissions. Sets the published timestamp
  /// and sends notifications if configured.
  /// 
  /// @param assignmentId ID of assignment to publish
  /// @throws Exception if publishing fails
  Future<void> publishAssignment(String assignmentId);
  
  /// Archives an assignment.
  /// 
  /// Moves the assignment to archived state, hiding it
  /// from active lists while preserving all data. Can
  /// be restored later if needed.
  /// 
  /// @param assignmentId ID of assignment to archive
  /// @throws Exception if archiving fails
  Future<void> archiveAssignment(String assignmentId);
  
  /// Unpublishes a published assignment.
  /// 
  /// Reverts assignment to draft state, hiding it from
  /// students. Existing submissions are preserved but
  /// new submissions are blocked.
  /// 
  /// @param assignmentId ID of assignment to unpublish
  /// @throws Exception if unpublishing fails
  Future<void> unpublishAssignment(String assignmentId);
  
  /// Restores an archived assignment.
  /// 
  /// Returns the assignment to its previous state before
  /// archiving. The assignment becomes visible again in
  /// active lists.
  /// 
  /// @param assignmentId ID of assignment to restore
  /// @throws Exception if restoration fails
  Future<void> restoreAssignment(String assignmentId);
  
  /// Calculates assignment statistics for a class.
  /// 
  /// Generates aggregate statistics including:
  /// - Total assignments
  /// - Active vs archived counts
  /// - Average completion rates
  /// - Submission statistics
  /// - Grade distributions
  /// 
  /// @param classId Class identifier
  /// @return Map of statistical data
  /// @throws Exception if calculation fails
  Future<Map<String, dynamic>> getAssignmentStats(String classId);
}