/// Submission repository interface for assignment submission management.
/// 
/// This module defines the contract for submission operations in the
/// education platform, supporting file uploads, text submissions,
/// grading workflows, and submission tracking.
library;

import '../models/submission.dart';
import '../../../../shared/repositories/base_repository.dart';

/// Abstract repository defining submission management operations.
/// 
/// This interface provides a comprehensive contract for submission
/// implementations, supporting:
/// - Multiple submission types (text, file, link)
/// - Submission status tracking and workflow
/// - Grading and feedback integration
/// - Statistical analysis for completion rates
/// - Real-time submission monitoring
/// - Batch operations for efficiency
/// 
/// Concrete implementations handle the actual submission
/// storage and business logic.
abstract class SubmissionRepository extends BaseRepository {
  // CRUD operations
  
  /// Creates a new submission record.
  /// 
  /// Initializes a submission with content, metadata, and
  /// timestamps. Returns the generated submission ID.
  /// 
  /// @param submission Submission model with content and metadata
  /// @return Generated unique submission ID
  /// @throws Exception if creation fails
  Future<String> createSubmission(Submission submission);
  
  /// Retrieves a submission by its unique identifier.
  /// 
  /// Fetches complete submission details including content,
  /// metadata, and grading information.
  /// 
  /// @param id Unique submission identifier
  /// @return Submission instance or null if not found
  /// @throws Exception if retrieval fails
  Future<Submission?> getSubmission(String id);
  
  /// Retrieves a student's submission for a specific assignment.
  /// 
  /// Queries for the unique submission matching both student
  /// and assignment. Returns null if not yet submitted.
  /// 
  /// @param assignmentId Assignment identifier
  /// @param studentId Student identifier
  /// @return Submission instance or null if not submitted
  /// @throws Exception if retrieval fails
  Future<Submission?> getStudentSubmission(String assignmentId, String studentId);
  
  /// Updates an existing submission.
  /// 
  /// Modifies submission content, status, or metadata.
  /// Typically used for resubmissions or status updates.
  /// 
  /// @param id Submission ID to update
  /// @param submission Updated submission information
  /// @throws Exception if update fails
  Future<void> updateSubmission(String id, Submission submission);
  
  /// Permanently deletes a submission.
  /// 
  /// Removes the submission record and associated files.
  /// This operation cannot be undone.
  /// 
  /// @param id Submission ID to delete
  /// @throws Exception if deletion fails
  Future<void> deleteSubmission(String id);
  
  // Specialized submission methods
  
  /// Creates a text-based submission.
  /// 
  /// Convenience method for submitting written responses,
  /// essays, or code. Automatically sets submission type
  /// and formats content appropriately.
  /// 
  /// @param assignmentId Target assignment
  /// @param studentId Submitting student
  /// @param studentName Student's display name
  /// @param textContent Written response content
  /// @return Created submission with generated ID
  /// @throws Exception if submission fails
  Future<Submission> submitTextContent({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String textContent,
  });
  
  /// Creates a file-based submission.
  /// 
  /// Convenience method for submitting documents, images,
  /// or other file attachments. Records file metadata
  /// and storage location.
  /// 
  /// @param assignmentId Target assignment
  /// @param studentId Submitting student
  /// @param studentName Student's display name
  /// @param fileUrl URL of uploaded file
  /// @param fileName Original file name
  /// @return Created submission with generated ID
  /// @throws Exception if submission fails
  Future<Submission> submitFile({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String fileUrl,
    required String fileName,
  });
  
  /// Updates the status of a submission.
  /// 
  /// Transitions submission through workflow states:
  /// submitted -> graded -> returned.
  /// May trigger notifications to students.
  /// 
  /// @param id Submission to update
  /// @param status New submission status
  /// @throws Exception if status update fails
  Future<void> updateSubmissionStatus(String id, SubmissionStatus status);
  
  // Query and streaming operations
  
  /// Streams all submissions for an assignment.
  /// 
  /// Returns real-time updates of student submissions,
  /// useful for grading dashboards and progress tracking.
  /// 
  /// @param assignmentId Assignment to monitor
  /// @return Stream of submission lists
  Stream<List<Submission>> getAssignmentSubmissions(String assignmentId);
  
  /// Streams all submissions by a specific student.
  /// 
  /// Returns comprehensive submission history across
  /// all assignments and classes.
  /// 
  /// @param studentId Student to monitor
  /// @return Stream of submission lists
  Stream<List<Submission>> getStudentSubmissions(String studentId);
  
  /// Streams submissions for a student in a specific class.
  /// 
  /// Filters submissions to show only those related to
  /// assignments in the specified class.
  /// 
  /// @param studentId Student to monitor
  /// @param classId Class context
  /// @return Stream of class-specific submissions
  Stream<List<Submission>> getStudentClassSubmissions(String studentId, String classId);
  
  /// Calculates submission statistics for an assignment.
  /// 
  /// Aggregates data to show:
  /// - Total expected submissions
  /// - Number submitted
  /// - Number graded
  /// - Submission rate percentage
  /// - Latest submission timestamp
  /// 
  /// @param assignmentId Assignment to analyze
  /// @return Statistical summary of submissions
  /// @throws Exception if calculation fails
  Future<SubmissionStatistics> getAssignmentSubmissionStatistics(String assignmentId);
  
  // Grading operations
  
  /// Marks a submission as graded.
  /// 
  /// Updates status to 'graded' and records grading
  /// timestamp. Should be called after grade entry.
  /// 
  /// @param id Submission to mark as graded
  /// @throws Exception if marking fails
  Future<void> markAsGraded(String id);
  
  /// Adds teacher feedback to a submission.
  /// 
  /// Records qualitative feedback along with grades.
  /// Updates submission timestamp to reflect changes.
  /// 
  /// @param id Submission to add feedback to
  /// @param feedback Teacher's comments and suggestions
  /// @throws Exception if feedback addition fails
  Future<void> addFeedback(String id, String feedback);
  
  // Batch operations
  
  /// Creates multiple submissions in one atomic operation.
  /// 
  /// Efficient bulk import for programmatic submission
  /// creation or migration. All creates succeed or fail together.
  /// 
  /// @param submissions List of submissions to create
  /// @throws Exception if batch creation fails
  Future<void> batchCreateSubmissions(List<Submission> submissions);
  
  /// Updates multiple submissions in one atomic operation.
  /// 
  /// Efficient bulk update for status changes or
  /// batch grading operations.
  /// 
  /// @param submissions Map of submission IDs to updated data
  /// @throws Exception if batch update fails
  Future<void> batchUpdateSubmissions(Map<String, Submission> submissions);
}

/// Statistical summary of assignment submissions.
/// 
/// This model aggregates submission data to provide
/// insights into assignment completion rates and
/// student engagement.
class SubmissionStatistics {
  /// Total number of expected submissions.
  final int total;
  
  /// Number of submissions received.
  final int submitted;
  
  /// Number of submissions graded.
  final int graded;
  
  /// Number of submissions pending grading.
  final int pending;
  
  /// Percentage of students who submitted (0.0-1.0).
  final double submissionRate;
  
  /// Timestamp of most recent submission.
  final DateTime? lastSubmissionAt;
  
  /// Creates a submission statistics summary.
  /// 
  /// All counts are required for accurate reporting.
  /// Submission rate should be pre-calculated as
  /// submitted/total.
  SubmissionStatistics({
    required this.total,
    required this.submitted,
    required this.graded,
    required this.pending,
    required this.submissionRate,
    this.lastSubmissionAt,
  });
}