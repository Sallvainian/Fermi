import '../models/submission.dart';
import 'base_repository.dart';

abstract class SubmissionRepository extends BaseRepository {
  // Create a new submission
  Future<String> createSubmission(Submission submission);
  
  // Get submission by ID
  Future<Submission?> getSubmission(String id);
  
  // Get submission by assignment and student
  Future<Submission?> getStudentSubmission(String assignmentId, String studentId);
  
  // Update a submission
  Future<void> updateSubmission(String id, Submission submission);
  
  // Delete a submission
  Future<void> deleteSubmission(String id);
  
  // Submit text content
  Future<Submission> submitTextContent({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String textContent,
  });
  
  // Submit file
  Future<Submission> submitFile({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String fileUrl,
    required String fileName,
  });
  
  // Update submission status
  Future<void> updateSubmissionStatus(String id, SubmissionStatus status);
  
  // Stream of submissions for an assignment
  Stream<List<Submission>> getAssignmentSubmissions(String assignmentId);
  
  // Stream of submissions for a student
  Stream<List<Submission>> getStudentSubmissions(String studentId);
  
  // Stream of submissions for a student in a class
  Stream<List<Submission>> getStudentClassSubmissions(String studentId, String classId);
  
  // Get submission statistics for an assignment
  Future<SubmissionStatistics> getAssignmentSubmissionStatistics(String assignmentId);
  
  // Mark submission as graded
  Future<void> markAsGraded(String id);
  
  // Add feedback to submission
  Future<void> addFeedback(String id, String feedback);
  
  // Batch operations
  Future<void> batchCreateSubmissions(List<Submission> submissions);
  Future<void> batchUpdateSubmissions(Map<String, Submission> submissions);
}

// Submission statistics model
class SubmissionStatistics {
  final int total;
  final int submitted;
  final int graded;
  final int pending;
  final double submissionRate;
  final DateTime? lastSubmissionAt;
  
  SubmissionStatistics({
    required this.total,
    required this.submitted,
    required this.graded,
    required this.pending,
    required this.submissionRate,
    this.lastSubmissionAt,
  });
}