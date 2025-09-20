/// Service for managing assignment submissions in the education platform.
///
/// This service handles all submission-related operations including
/// creation, retrieval, status tracking, and file management for
/// student assignment submissions.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/submission.dart';

/// Core service for handling student assignment submissions.
///
/// This service provides:
/// - Submission creation with duplicate prevention
/// - Submission retrieval and monitoring
/// - Status tracking and grading workflows
/// - File and text submission support
/// - Late submission tracking
/// - Submission counting and analytics
///
/// Ensures each student can only submit once per assignment
/// and tracks submission timestamps for deadline compliance.
class SubmissionService {
  /// Reference to the submissions collection in Firestore.
  final CollectionReference _submissionsCollection;

  /// Creates a SubmissionService instance.
  ///
  /// Accepts optional Firestore instance for dependency injection,
  /// supporting both production use and unit testing.
  ///
  /// @param firestore Optional Firestore instance for testing
  SubmissionService({FirebaseFirestore? firestore})
    : _submissionsCollection = (firestore ?? FirebaseFirestore.instance)
          .collection('submissions');

  /// Creates a new assignment submission.
  ///
  /// Validates that the student hasn't already submitted
  /// for this assignment before creating the submission.
  /// Prevents duplicate submissions at the service level.
  ///
  /// @param submission Submission model to create
  /// @return Created submission with generated ID
  /// @throws Exception if student already submitted
  Future<Submission> createSubmission(Submission submission) async {
    try {
      // Check if student already has a submission for this assignment
      final existing = await getSubmissionForStudentAndAssignment(
        submission.studentId,
        submission.assignmentId,
      );

      if (existing != null) {
        throw Exception('Student has already submitted this assignment');
      }

      final docRef = await _submissionsCollection.add(submission.toFirestore());
      return submission.copyWith(id: docRef.id);
    } catch (e) {
      // Error creating submission: $e
      rethrow;
    }
  }

  /// Retrieves a single submission by ID.
  ///
  /// Fetches the submission document from Firestore.
  /// Returns null if the submission doesn't exist.
  ///
  /// @param submissionId Unique identifier of the submission
  /// @return Submission instance or null if not found
  /// @throws Exception if retrieval fails
  Future<Submission?> getSubmission(String submissionId) async {
    try {
      final doc = await _submissionsCollection.doc(submissionId).get();
      if (!doc.exists) return null;
      return Submission.fromFirestore(doc);
    } catch (e) {
      // Error getting submission: $e
      rethrow;
    }
  }

  /// Retrieves submission for a specific student-assignment pair.
  ///
  /// Queries for the unique submission matching both student
  /// and assignment IDs. Used to check if a student has
  /// already submitted and to retrieve their submission.
  ///
  /// @param studentId ID of the student
  /// @param assignmentId ID of the assignment
  /// @return Submission instance or null if not submitted
  /// @throws Exception if query fails
  Future<Submission?> getSubmissionForStudentAndAssignment(
    String studentId,
    String assignmentId,
  ) async {
    try {
      final query = await _submissionsCollection
          .where('studentId', isEqualTo: studentId)
          .where('assignmentId', isEqualTo: assignmentId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return Submission.fromFirestore(query.docs.first);
    } catch (e) {
      // Error getting submission: $e
      rethrow;
    }
  }

  /// Streams all submissions for a specific assignment.
  ///
  /// Returns a real-time stream of submissions:
  /// - Filtered by assignment ID
  /// - Ordered by submission time (newest first)
  /// - Updates automatically when submissions change
  ///
  /// Useful for teachers viewing all student submissions.
  ///
  /// @param assignmentId Assignment to get submissions for
  /// @return Stream of submission lists
  Stream<List<Submission>> getSubmissionsForAssignment(String assignmentId) {
    return _submissionsCollection
        .where('assignmentId', isEqualTo: assignmentId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          await Future.delayed(Duration.zero);
          return snapshot;
        })
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Submission.fromFirestore(doc))
              .toList(),
        );
  }

  /// Streams all submissions for a specific student.
  ///
  /// Returns a real-time stream of submissions:
  /// - Filtered by student ID
  /// - Ordered by submission time (newest first)
  /// - Across all assignments
  ///
  /// Useful for student submission history views.
  ///
  /// @param studentId Student to get submissions for
  /// @return Stream of submission lists
  Stream<List<Submission>> getSubmissionsForStudent(String studentId) {
    return _submissionsCollection
        .where('studentId', isEqualTo: studentId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          await Future.delayed(Duration.zero);
          return snapshot;
        })
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Submission.fromFirestore(doc))
              .toList(),
        );
  }

  /// Updates an existing submission.
  ///
  /// Primarily used for adding file uploads after initial
  /// submission or updating submission content. Overwrites
  /// all submission fields with provided data.
  ///
  /// @param submission Updated submission model
  /// @throws Exception if update fails
  Future<void> updateSubmission(Submission submission) async {
    try {
      await _submissionsCollection
          .doc(submission.id)
          .update(submission.toFirestore());
    } catch (e) {
      // Error updating submission: $e
      rethrow;
    }
  }

  /// Marks a submission as graded.
  ///
  /// Updates submission status to 'graded' and sets the
  /// graded timestamp. Should be called after a grade
  /// has been assigned through the grading service.
  ///
  /// @param submissionId ID of submission to mark as graded
  /// @throws Exception if update fails
  Future<void> markSubmissionAsGraded(String submissionId) async {
    try {
      await _submissionsCollection.doc(submissionId).update({
        'status': SubmissionStatus.graded.toString().split('.').last,
        'gradedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error marking submission as graded: $e
      rethrow;
    }
  }

  /// Deletes a submission (teachers only).
  ///
  /// Permanently removes the submission from Firestore.
  /// This operation cannot be undone. Should be restricted
  /// to teacher roles in the UI layer.
  ///
  /// @param submissionId ID of submission to delete
  /// @throws Exception if deletion fails
  Future<void> deleteSubmission(String submissionId) async {
    try {
      await _submissionsCollection.doc(submissionId).delete();
    } catch (e) {
      // Error deleting submission: $e
      rethrow;
    }
  }

  /// Gets the total submission count for an assignment.
  ///
  /// Uses Firestore's count aggregation for efficient
  /// counting without loading all submission documents.
  /// Returns 0 if counting fails.
  ///
  /// @param assignmentId Assignment to count submissions for
  /// @return Number of submissions or 0 on error
  Future<int> getSubmissionCountForAssignment(String assignmentId) async {
    try {
      final query = await _submissionsCollection
          .where('assignmentId', isEqualTo: assignmentId)
          .count()
          .get();
      return query.count ?? 0;
    } catch (e) {
      // Error getting submission count: $e
      return 0;
    }
  }

  /// Checks if a student has submitted an assignment.
  ///
  /// Quick check to determine submission status without
  /// loading the full submission data. Useful for UI
  /// state management and submission buttons.
  ///
  /// @param studentId ID of the student to check
  /// @param assignmentId ID of the assignment to check
  /// @return true if submitted, false otherwise or on error
  Future<bool> isAssignmentSubmitted(
    String studentId,
    String assignmentId,
  ) async {
    try {
      final submission = await getSubmissionForStudentAndAssignment(
        studentId,
        assignmentId,
      );
      return submission != null;
    } catch (e) {
      // Error checking submission status: $e
      return false;
    }
  }

  /// Streams real-time submission status for a student-assignment pair.
  ///
  /// Returns a stream that emits true when a submission exists
  /// and false when it doesn't. Updates automatically when
  /// submission status changes.
  ///
  /// @param studentId ID of the student to monitor
  /// @param assignmentId ID of the assignment to monitor
  /// @return Stream of submission existence status
  Stream<bool> watchSubmissionStatus(String studentId, String assignmentId) {
    return _submissionsCollection
        .where('studentId', isEqualTo: studentId)
        .where('assignmentId', isEqualTo: assignmentId)
        .snapshots()
        .asyncMap((snapshot) async {
          await Future.delayed(Duration.zero);
          return snapshot;
        })
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  /// Streams late submissions for an assignment.
  ///
  /// Returns a real-time stream of submissions that were
  /// submitted after the assignment's due date. Useful for
  /// tracking late submission penalties and reports.
  ///
  /// @param assignmentId Assignment to check for late submissions
  /// @param dueDate Assignment's due date for comparison
  /// @return Stream of late submission lists
  Stream<List<Submission>> getLateSubmissionsForAssignment(
    String assignmentId,
    DateTime dueDate,
  ) {
    return _submissionsCollection
        .where('assignmentId', isEqualTo: assignmentId)
        .where('submittedAt', isGreaterThan: Timestamp.fromDate(dueDate))
        .snapshots()
        .asyncMap((snapshot) async {
          await Future.delayed(Duration.zero);
          return snapshot;
        })
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Submission.fromFirestore(doc))
              .toList(),
        );
  }

  /// Submits a text-only assignment response.
  ///
  /// Creates a submission containing only text content without
  /// any file attachments. This method is a convenience wrapper
  /// around createSubmission for text-based assignments.
  ///
  /// Automatically sets submission status to 'submitted' and
  /// captures the current timestamp.
  ///
  /// @param assignmentId ID of the assignment being submitted
  /// @param studentId ID of the submitting student
  /// @param studentName Name of the student for display
  /// @param textContent The text response content
  /// @return Created submission with generated ID
  /// @throws Exception if student already submitted
  Future<Submission> submitTextContent({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String textContent,
  }) async {
    final submission = Submission(
      id: '',
      assignmentId: assignmentId,
      studentId: studentId,
      studentName: studentName,
      textContent: textContent,
      submittedAt: DateTime.now(),
      status: SubmissionStatus.submitted,
    );

    return createSubmission(submission);
  }

  /// Submits a file-based assignment response.
  ///
  /// Creates a submission containing a file attachment with
  /// optional text content. This method is a convenience wrapper
  /// around createSubmission for file-based assignments.
  ///
  /// The file should already be uploaded to Firebase Storage
  /// and the URL provided here. File upload is typically handled
  /// by the UI layer before calling this method.
  ///
  /// @param assignmentId ID of the assignment being submitted
  /// @param studentId ID of the submitting student
  /// @param studentName Name of the student for display
  /// @param fileUrl Firebase Storage URL of the uploaded file
  /// @param fileName Original filename for display purposes
  /// @param textContent Optional text description or notes
  /// @return Created submission with generated ID
  /// @throws Exception if student already submitted
  Future<Submission> submitFile({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String fileUrl,
    required String fileName,
    String? textContent,
  }) async {
    final submission = Submission(
      id: '',
      assignmentId: assignmentId,
      studentId: studentId,
      studentName: studentName,
      fileUrl: fileUrl,
      fileName: fileName,
      textContent: textContent,
      submittedAt: DateTime.now(),
      status: SubmissionStatus.submitted,
    );

    return createSubmission(submission);
  }
}

/// Extension adding immutable update capabilities to Submission.
///
/// Provides a copyWith method following the immutable data pattern
/// commonly used in Flutter applications for state management.
/// This allows creating modified copies of submissions without
/// mutating the original instance.
extension SubmissionExtension on Submission {
  /// Creates a copy of the Submission with updated fields.
  ///
  /// Follows the immutable data pattern for safe state updates.
  /// All parameters are optional - only provided fields will be
  /// updated in the new instance.
  ///
  /// Common uses:
  /// - Adding generated ID after creation
  /// - Updating submission status
  /// - Adding grading timestamp
  /// - Attaching file information
  ///
  /// @param id New submission ID
  /// @param assignmentId New assignment reference
  /// @param studentId New student ID
  /// @param studentName New student display name
  /// @param fileUrl New file attachment URL
  /// @param fileName New file name
  /// @param textContent New text content
  /// @param submittedAt New submission timestamp
  /// @param gradedAt New grading timestamp
  /// @param status New submission status
  /// @return New Submission instance with updated fields
  Submission copyWith({
    String? id,
    String? assignmentId,
    String? studentId,
    String? studentName,
    String? fileUrl,
    String? fileName,
    String? textContent,
    DateTime? submittedAt,
    DateTime? gradedAt,
    SubmissionStatus? status,
  }) {
    return Submission(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      textContent: textContent ?? this.textContent,
      submittedAt: submittedAt ?? this.submittedAt,
      gradedAt: gradedAt ?? this.gradedAt,
      status: status ?? this.status,
    );
  }
}
