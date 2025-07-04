import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/submission.dart';

class SubmissionService {
  final CollectionReference _submissionsCollection;

  SubmissionService({FirebaseFirestore? firestore})
      : _submissionsCollection = (firestore ?? FirebaseFirestore.instance).collection('submissions');

  // Create a new submission
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

  // Get a specific submission
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

  // Get submission for a specific student and assignment
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

  // Stream of submissions for a specific assignment
  Stream<List<Submission>> getSubmissionsForAssignment(String assignmentId) {
    return _submissionsCollection
        .where('assignmentId', isEqualTo: assignmentId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Submission.fromFirestore(doc))
            .toList());
  }

  // Stream of submissions for a specific student
  Stream<List<Submission>> getSubmissionsForStudent(String studentId) {
    return _submissionsCollection
        .where('studentId', isEqualTo: studentId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Submission.fromFirestore(doc))
            .toList());
  }

  // Update submission (mainly for file uploads)
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

  // Mark submission as graded
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

  // Delete submission (teachers only)
  Future<void> deleteSubmission(String submissionId) async {
    try {
      await _submissionsCollection.doc(submissionId).delete();
    } catch (e) {
      // Error deleting submission: $e
      rethrow;
    }
  }

  // Get submission count for an assignment
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

  // Check if assignment is submitted by student
  Future<bool> isAssignmentSubmitted(String studentId, String assignmentId) async {
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

  // Stream to check submission status
  Stream<bool> watchSubmissionStatus(String studentId, String assignmentId) {
    return _submissionsCollection
        .where('studentId', isEqualTo: studentId)
        .where('assignmentId', isEqualTo: assignmentId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // Get late submissions for an assignment
  Stream<List<Submission>> getLateSubmissionsForAssignment(
    String assignmentId,
    DateTime dueDate,
  ) {
    return _submissionsCollection
        .where('assignmentId', isEqualTo: assignmentId)
        .where('submittedAt', isGreaterThan: Timestamp.fromDate(dueDate))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Submission.fromFirestore(doc))
            .toList());
  }

  // Submit text content
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

  // Submit file (URL from Firebase Storage)
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

// Extension to add a copyWith method to Submission
extension SubmissionExtension on Submission {
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