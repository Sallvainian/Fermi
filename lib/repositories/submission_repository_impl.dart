import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/submission.dart';
import '../services/firestore_service.dart';
import '../services/logger_service.dart';
import 'submission_repository.dart';
import 'firestore_repository.dart';

class SubmissionRepositoryImpl extends FirestoreRepository<Submission> implements SubmissionRepository {
  static const String _tag = 'SubmissionRepository';
  final FirebaseFirestore _firestore;

  SubmissionRepositoryImpl(this._firestore)
      : super(
          firestore: _firestore,
          collectionPath: 'submissions',
          fromFirestore: (doc) => Submission.fromFirestore(doc),
          toFirestore: (submission) => submission.toFirestore(),
          logTag: _tag,
        );

  @override
  Future<String> createSubmission(Submission submission) async {
    try {
      // Update timestamp
      final submissionToCreate = submission.copyWith(
        submittedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return await create(submissionToCreate);
    } catch (e) {
      LoggerService.error('Failed to create submission', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<Submission?> getSubmission(String id) => read(id);

  @override
  Future<Submission?> getStudentSubmission(String assignmentId, String studentId) async {
    try {
      final submissions = await list(
        conditions: [
          QueryCondition(field: 'assignmentId', isEqualTo: assignmentId),
          QueryCondition(field: 'studentId', isEqualTo: studentId),
        ],
        limit: 1,
      );
      return submissions.isEmpty ? null : submissions.first;
    } catch (e) {
      LoggerService.error('Failed to get student submission', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> updateSubmission(String id, Submission submission) async {
    try {
      // Update timestamp
      final submissionToUpdate = submission.copyWith(
        updatedAt: DateTime.now(),
      );
      await update(id, submissionToUpdate);
    } catch (e) {
      LoggerService.error('Failed to update submission', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteSubmission(String id) => delete(id);

  @override
  Future<Submission> submitTextContent({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String textContent,
  }) async {
    try {
      // Check if submission already exists
      final existing = await getStudentSubmission(assignmentId, studentId);
      
      if (existing != null) {
        // Update existing submission
        final updated = existing.copyWith(
          textContent: textContent,
          status: SubmissionStatus.submitted,
          submittedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await updateSubmission(existing.id, updated);
        return updated;
      } else {
        // Create new submission
        final submission = Submission(
          id: '',
          assignmentId: assignmentId,
          studentId: studentId,
          studentName: studentName,
          textContent: textContent,
          status: SubmissionStatus.submitted,
          submittedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final id = await createSubmission(submission);
        return submission.copyWith(id: id);
      }
    } catch (e) {
      LoggerService.error('Failed to submit text content', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<Submission> submitFile({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String fileUrl,
    required String fileName,
  }) async {
    try {
      // Check if submission already exists
      final existing = await getStudentSubmission(assignmentId, studentId);
      
      if (existing != null) {
        // Update existing submission
        final updated = existing.copyWith(
          fileUrl: fileUrl,
          fileName: fileName,
          status: SubmissionStatus.submitted,
          submittedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await updateSubmission(existing.id, updated);
        return updated;
      } else {
        // Create new submission
        final submission = Submission(
          id: '',
          assignmentId: assignmentId,
          studentId: studentId,
          studentName: studentName,
          fileUrl: fileUrl,
          fileName: fileName,
          status: SubmissionStatus.submitted,
          submittedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final id = await createSubmission(submission);
        return submission.copyWith(id: id);
      }
    } catch (e) {
      LoggerService.error('Failed to submit file', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> updateSubmissionStatus(String id, SubmissionStatus status) async {
    try {
      await _firestore.collection('submissions').doc(id).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Updated submission status to ${status.name}', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to update submission status', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Stream<List<Submission>> getAssignmentSubmissions(String assignmentId) {
    return stream(
      conditions: [
        QueryCondition(field: 'assignmentId', isEqualTo: assignmentId),
      ],
      orderBy: [OrderBy(field: 'submittedAt', descending: true)],
    );
  }

  @override
  Stream<List<Submission>> getStudentSubmissions(String studentId) {
    return stream(
      conditions: [
        QueryCondition(field: 'studentId', isEqualTo: studentId),
      ],
      orderBy: [OrderBy(field: 'submittedAt', descending: true)],
    );
  }

  @override
  Stream<List<Submission>> getStudentClassSubmissions(String studentId, String classId) {
    // Note: This requires joining with assignments to filter by classId
    // For now, returning student submissions and filtering will be done in the provider
    return getStudentSubmissions(studentId);
  }

  @override
  Future<SubmissionStatistics> getAssignmentSubmissionStatistics(String assignmentId) async {
    try {
      // Get all submissions for the assignment
      final submissions = await list(
        conditions: [
          QueryCondition(field: 'assignmentId', isEqualTo: assignmentId),
        ],
      );
      
      // Get total students count from assignment's class
      // This would require joining with assignments and classes
      // For now, we'll use submissions count as total
      final total = submissions.length;
      final submitted = submissions.where((s) => 
        s.status == SubmissionStatus.submitted || 
        s.status == SubmissionStatus.graded
      ).length;
      final graded = submissions.where((s) => s.status == SubmissionStatus.graded).length;
      final pending = total - submitted;
      
      DateTime? lastSubmissionAt;
      if (submissions.isNotEmpty) {
        submissions.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
        lastSubmissionAt = submissions.first.submittedAt;
      }
      
      return SubmissionStatistics(
        total: total,
        submitted: submitted,
        graded: graded,
        pending: pending,
        submissionRate: total > 0 ? (submitted / total) : 0,
        lastSubmissionAt: lastSubmissionAt,
      );
    } catch (e) {
      LoggerService.error('Failed to get submission statistics', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> markAsGraded(String id) async {
    try {
      await updateSubmissionStatus(id, SubmissionStatus.graded);
    } catch (e) {
      LoggerService.error('Failed to mark submission as graded', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> addFeedback(String id, String feedback) async {
    try {
      await _firestore.collection('submissions').doc(id).update({
        'feedback': feedback,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggerService.info('Added feedback to submission', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to add feedback', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> batchCreateSubmissions(List<Submission> submissions) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (final submission in submissions) {
        final ref = _firestore.collection('submissions').doc();
        final submissionToCreate = submission.copyWith(
          id: ref.id,
          submittedAt: now,
          updatedAt: now,
        );
        batch.set(ref, submissionToCreate.toFirestore());
      }
      
      await batch.commit();
      LoggerService.info('Batch created ${submissions.length} submissions', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to batch create submissions', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> batchUpdateSubmissions(Map<String, Submission> submissions) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      submissions.forEach((submissionId, submission) {
        final ref = _firestore.collection('submissions').doc(submissionId);
        final submissionToUpdate = submission.copyWith(
          updatedAt: now,
        );
        batch.update(ref, submissionToUpdate.toFirestore());
      });
      
      await batch.commit();
      LoggerService.info('Batch updated ${submissions.length} submissions', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to batch update submissions', tag: _tag, error: e);
      rethrow;
    }
  }
}