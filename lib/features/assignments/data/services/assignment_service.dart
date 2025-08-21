/// Assignment and grade management service for the education platform.
///
/// This service provides comprehensive functionality for managing
/// assignments and grades including CRUD operations, batch processing,
/// and statistical analysis.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teacher_dashboard_flutter/features/assignments/domain/models/assignment.dart';
import 'package:teacher_dashboard_flutter/features/grades/domain/models/grade.dart';
import 'package:teacher_dashboard_flutter/features/notifications/data/services/notification_service.dart';

/// Core service for managing assignments and grades in Firestore.
///
/// This service handles:
/// - Assignment lifecycle management (create, read, update, delete)
/// - Grade management and tracking
/// - Batch operations for efficient bulk processing
/// - Statistical analysis and reporting
/// - Scheduled assignment publishing
/// - Class-wide grade initialization
///
/// The service uses dependency injection for Firestore instance,
/// supporting both production and testing environments.
class AssignmentService {
  /// Firestore database instance for batch operations.
  final FirebaseFirestore _firestore;

  /// Reference to the assignments collection in Firestore.
  final CollectionReference _assignmentsCollection;

  /// Reference to the grades collection in Firestore.
  final CollectionReference _gradesCollection;

  /// Creates an AssignmentService instance.
  ///
  /// Accepts optional [firestore] parameter for dependency injection,
  /// defaulting to the singleton instance if not provided.
  /// This pattern supports both production use and unit testing.
  AssignmentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _assignmentsCollection =
            (firestore ?? FirebaseFirestore.instance).collection('assignments'),
        _gradesCollection =
            (firestore ?? FirebaseFirestore.instance).collection('grades');

  // --- Assignment CRUD Operations ---

  /// Creates a new assignment in Firestore.
  ///
  /// Adds the assignment to the database and returns it with
  /// the generated document ID. The assignment's status and
  /// publication state should be set before calling this method.
  ///
  /// @param assignment Assignment model to create
  /// @return Created assignment with generated ID
  /// @throws Exception if creation fails
  Future<Assignment> createAssignment(Assignment assignment) async {
    try {
      final docRef = await _assignmentsCollection.add(assignment.toFirestore());
      final createdAssignment = assignment.copyWith(id: docRef.id);

      // Schedule notification reminder for due date
      final notificationService = NotificationService();
      await notificationService.scheduleAssignmentReminder(createdAssignment);

      return createdAssignment;
    } catch (e) {
      // Error creating assignment: $e
      rethrow;
    }
  }

  /// Retrieves a single assignment by ID.
  ///
  /// Fetches the assignment document from Firestore and converts
  /// it to an Assignment model. Returns null if the assignment
  /// doesn't exist.
  ///
  /// @param assignmentId Unique identifier of the assignment
  /// @return Assignment instance or null if not found
  /// @throws Exception if retrieval fails
  Future<Assignment?> getAssignment(String assignmentId) async {
    try {
      final doc = await _assignmentsCollection.doc(assignmentId).get();
      if (!doc.exists) {
        return null;
      }
      return Assignment.fromFirestore(doc);
    } catch (e) {
      // Error getting assignment: $e
      rethrow;
    }
  }

  /// Streams published assignments for a specific class.
  ///
  /// Returns a real-time stream of assignments that are:
  /// - Associated with the given class
  /// - Published (visible to students)
  /// - Ordered by due date (earliest first)
  ///
  /// @param classId Class identifier to filter assignments
  /// @return Stream of assignment lists, updated in real-time
  Stream<List<Assignment>> getAssignmentsForClass(String classId) {
    return _assignmentsCollection
        .where('classId', isEqualTo: classId)
        .where('isPublished', isEqualTo: true)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Assignment.fromFirestore(doc)).toList());
  }

  /// Streams all assignments created by a specific teacher.
  ///
  /// Returns a real-time stream of assignments:
  /// - Created by the given teacher
  /// - Ordered by creation date (newest first)
  /// - Including both published and draft assignments
  ///
  /// @param teacherId Teacher identifier to filter assignments
  /// @return Stream of assignment lists for the teacher
  Stream<List<Assignment>> getAssignmentsForTeacher(String teacherId) {
    return _assignmentsCollection
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Assignment.fromFirestore(doc)).toList());
  }

  /// Updates an existing assignment in Firestore.
  ///
  /// Overwrites the entire assignment document with the provided
  /// data. Ensure all required fields are present in the
  /// assignment model before updating.
  ///
  /// @param assignment Assignment model with updated data
  /// @throws Exception if update fails or assignment doesn't exist
  Future<void> updateAssignment(Assignment assignment) async {
    try {
      await _assignmentsCollection
          .doc(assignment.id)
          .update(assignment.toFirestore());
    } catch (e) {
      // Error updating assignment: $e
      rethrow;
    }
  }

  /// Deletes an assignment and all associated grades.
  ///
  /// Performs a cascading delete that:
  /// 1. Finds all grades for the assignment
  /// 2. Deletes all grade documents
  /// 3. Deletes the assignment document
  ///
  /// Uses batch operations for atomicity - either all deletions
  /// succeed or none do.
  ///
  /// @param assignmentId ID of the assignment to delete
  /// @throws Exception if deletion fails
  Future<void> deleteAssignment(String assignmentId) async {
    try {
      // Delete all grades for this assignment first
      final grades = await _gradesCollection
          .where('assignmentId', isEqualTo: assignmentId)
          .get();

      final batch = _firestore.batch();
      for (final doc in grades.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_assignmentsCollection.doc(assignmentId));

      await batch.commit();
    } catch (e) {
      // Error deleting assignment: $e
      rethrow;
    }
  }

  // --- Grade CRUD Operations ---

  /// Creates a new grade record in Firestore.
  ///
  /// Adds the grade to the database and returns it with
  /// the generated document ID. The grade should have all
  /// required fields set before creation.
  ///
  /// @param grade Grade model to create
  /// @return Created grade with generated ID
  /// @throws Exception if creation fails
  Future<Grade> createGrade(Grade grade) async {
    try {
      final docRef = await _gradesCollection.add(grade.toFirestore());
      return grade.copyWith(id: docRef.id);
    } catch (e) {
      // Error creating grade: $e
      rethrow;
    }
  }

  /// Retrieves a single grade by ID.
  ///
  /// Fetches the grade document from Firestore and converts
  /// it to a Grade model. Returns null if the grade
  /// doesn't exist.
  ///
  /// @param gradeId Unique identifier of the grade
  /// @return Grade instance or null if not found
  /// @throws Exception if retrieval fails
  Future<Grade?> getGrade(String gradeId) async {
    try {
      final doc = await _gradesCollection.doc(gradeId).get();
      if (!doc.exists) return null;
      return Grade.fromFirestore(doc);
    } catch (e) {
      // Error getting grade: $e
      rethrow;
    }
  }

  /// Retrieves a grade for a specific student-assignment pair.
  ///
  /// Queries for the unique grade record matching both the
  /// student and assignment IDs. Returns null if no grade
  /// exists (e.g., assignment not yet graded).
  ///
  /// @param studentId ID of the student
  /// @param assignmentId ID of the assignment
  /// @return Grade instance or null if not found
  /// @throws Exception if query fails
  Future<Grade?> getGradeForStudentAndAssignment(
      String studentId, String assignmentId) async {
    try {
      final query = await _gradesCollection
          .where('studentId', isEqualTo: studentId)
          .where('assignmentId', isEqualTo: assignmentId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return Grade.fromFirestore(query.docs.first);
    } catch (e) {
      // Error getting grade: $e
      rethrow;
    }
  }

  /// Streams all grades for a specific assignment.
  ///
  /// Returns a real-time stream of grades for the given
  /// assignment. Useful for teachers viewing all student
  /// grades for an assignment.
  ///
  /// @param assignmentId Assignment to get grades for
  /// @return Stream of grade lists, updated in real-time
  Stream<List<Grade>> getGradesForAssignment(String assignmentId) {
    return _gradesCollection
        .where('assignmentId', isEqualTo: assignmentId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Grade.fromFirestore(doc)).toList());
  }

  /// Streams all grades for a specific student.
  ///
  /// Returns a real-time stream of grades:
  /// - For the given student across all assignments
  /// - Ordered by creation date (newest first)
  /// - Including all grade statuses
  ///
  /// @param studentId Student to get grades for
  /// @return Stream of grade lists for the student
  Stream<List<Grade>> getGradesForStudent(String studentId) {
    return _gradesCollection
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Grade.fromFirestore(doc)).toList());
  }

  /// Updates an existing grade in Firestore.
  ///
  /// Automatically updates the modification timestamp
  /// before saving. All grade fields are overwritten
  /// with the provided data.
  ///
  /// @param grade Grade model with updated data
  /// @throws Exception if update fails
  Future<void> updateGrade(Grade grade) async {
    try {
      grade.updatedAt = DateTime.now();
      await _gradesCollection.doc(grade.id).update(grade.toFirestore());
    } catch (e) {
      // Error updating grade: $e
      rethrow;
    }
  }

  /// Deletes a single grade record.
  ///
  /// Permanently removes the grade from Firestore.
  /// This operation cannot be undone.
  ///
  /// @param gradeId ID of the grade to delete
  /// @throws Exception if deletion fails
  Future<void> deleteGrade(String gradeId) async {
    try {
      await _gradesCollection.doc(gradeId).delete();
    } catch (e) {
      // Error deleting grade: $e
      rethrow;
    }
  }

  // --- Batch Operations ---

  /// Creates multiple grades in a single batch operation.
  ///
  /// Efficiently creates multiple grade records using Firestore
  /// batch writes. Each grade gets a generated document ID.
  /// All writes succeed or fail together (atomic operation).
  ///
  /// @param grades List of Grade models to create
  /// @throws Exception if batch creation fails
  Future<void> bulkCreateGrades(List<Grade> grades) async {
    try {
      final batch = _firestore.batch();

      for (final grade in grades) {
        final docRef = _gradesCollection.doc();
        batch.set(docRef, grade.copyWith(id: docRef.id).toFirestore());
      }

      await batch.commit();
    } catch (e) {
      // Error bulk creating grades: $e
      rethrow;
    }
  }

  /// Updates multiple grades in a single batch operation.
  ///
  /// Efficiently updates multiple grade records using Firestore
  /// batch writes. All grades get the same updated timestamp.
  /// All updates succeed or fail together (atomic operation).
  ///
  /// @param grades List of Grade models with updated data
  /// @throws Exception if batch update fails
  Future<void> bulkUpdateGrades(List<Grade> grades) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      for (final grade in grades) {
        grade.updatedAt = now;
        batch.update(
          _gradesCollection.doc(grade.id),
          grade.toFirestore(),
        );
      }

      await batch.commit();
    } catch (e) {
      // Error bulk updating grades: $e
      rethrow;
    }
  }

  // --- Statistics Operations ---

  /// Calculates statistical summary for an assignment's grades.
  ///
  /// Retrieves all graded submissions for an assignment and
  /// computes statistics including:
  /// - Average, median, highest, lowest scores
  /// - Grade distribution by letter grade
  /// - Total number of graded submissions
  ///
  /// Only includes grades with 'graded' status.
  ///
  /// @param assignmentId Assignment to analyze
  /// @return GradeStatistics with calculated metrics
  /// @throws Exception if calculation fails
  Future<GradeStatistics> calculateAssignmentStatistics(
      String assignmentId) async {
    try {
      final querySnapshot = await _gradesCollection
          .where('assignmentId', isEqualTo: assignmentId)
          .where('status', isEqualTo: GradeStatus.graded.name)
          .get();

      final grades =
          querySnapshot.docs.map((doc) => Grade.fromFirestore(doc)).toList();

      return GradeStatistics.fromGrades(grades);
    } catch (e) {
      // Error calculating statistics: $e
      rethrow;
    }
  }

  /// Calculates statistical summary for a student's grades.
  ///
  /// Computes grade statistics for a student across all
  /// assignments or within a specific class. Includes:
  /// - Overall performance metrics
  /// - Grade distribution
  /// - Progress tracking
  ///
  /// @param studentId Student to analyze
  /// @param classId Optional class filter
  /// @return GradeStatistics with student performance data
  /// @throws Exception if calculation fails
  Future<GradeStatistics> calculateStudentStatistics(String studentId,
      {String? classId}) async {
    try {
      Query query = _gradesCollection
          .where('studentId', isEqualTo: studentId)
          .where('status', isEqualTo: GradeStatus.graded.name);

      if (classId != null) {
        query = query.where('classId', isEqualTo: classId);
      }

      final querySnapshot = await query.get();

      final grades =
          querySnapshot.docs.map((doc) => Grade.fromFirestore(doc)).toList();

      return GradeStatistics.fromGrades(grades);
    } catch (e) {
      // Error calculating student statistics: $e
      rethrow;
    }
  }

  // --- Helper Methods ---

  /// Publishes a draft assignment, making it visible to students.
  ///
  /// Updates the assignment's published status and timestamp.
  /// Once published, students can view and submit work for
  /// the assignment.
  ///
  /// @param assignmentId ID of assignment to publish
  /// @throws Exception if publication fails
  Future<void> publishAssignment(String assignmentId) async {
    try {
      await _assignmentsCollection.doc(assignmentId).update({
        'isPublished': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error publishing assignment: $e
      rethrow;
    }
  }

  /// Unpublishes an assignment, hiding it from students.
  ///
  /// Reverts a published assignment back to draft status.
  /// Students will no longer see the assignment, but existing
  /// submissions and grades are preserved.
  ///
  /// @param assignmentId ID of assignment to unpublish
  /// @throws Exception if unpublishing fails
  Future<void> unpublishAssignment(String assignmentId) async {
    try {
      await _assignmentsCollection.doc(assignmentId).update({
        'isPublished': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error unpublishing assignment: $e
      rethrow;
    }
  }

  /// Publishes assignments scheduled for automatic release.
  ///
  /// Queries for unpublished assignments with publishAt timestamps
  /// in the past and publishes them. This method should be called
  /// periodically (e.g., via cron job or scheduled function).
  ///
  /// Updates assignment status to 'active' and sets publication flag.
  /// Uses batch operations for efficiency when multiple assignments
  /// need publishing.
  ///
  /// @throws Exception if scheduled publishing fails
  Future<void> publishScheduledAssignments() async {
    try {
      final now = DateTime.now();

      // Query for assignments that should be published
      final querySnapshot = await _assignmentsCollection
          .where('isPublished', isEqualTo: false)
          .where('publishAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'isPublished': true,
          'status': AssignmentStatus.active.toString().split('.').last,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      // Published ${querySnapshot.docs.length} scheduled assignments
    } catch (e) {
      // Error publishing scheduled assignments: $e
      rethrow;
    }
  }

  /// Initializes grade records for all students in a class.
  ///
  /// When a new assignment is created, this method creates
  /// placeholder grade records for every student in the class.
  /// Each grade starts with:
  /// - Status: pending
  /// - Points earned: 0
  /// - No feedback or grade assigned
  ///
  /// This ensures every student has a grade entry for tracking
  /// and prevents missing grades in reports.
  ///
  /// @param assignmentId Assignment to create grades for
  /// @param classId Class containing the students
  /// @param teacherId Teacher who owns the assignment
  /// @throws Exception if initialization fails
  Future<void> initializeGradesForAssignment(
      String assignmentId, String classId, String teacherId) async {
    try {
      // Get all students in the class
      final studentsSnapshot = await _firestore
          .collection('students')
          .where('classIds', arrayContains: classId)
          .get();

      final grades = studentsSnapshot.docs.map((studentDoc) {
        final studentData = studentDoc.data();
        final studentName =
            (studentData['displayName'] as String?) ?? 'Unknown Student';
        return Grade(
          id: '', // Will be set during batch creation
          assignmentId: assignmentId,
          studentId: studentDoc.id,
          studentName: studentName,
          teacherId: teacherId,
          classId: classId,
          pointsEarned: 0,
          pointsPossible: 0, // Will be set from assignment
          percentage: 0,
          letterGrade: null,
          feedback: null,
          status: GradeStatus.pending,
          gradedAt: null,
          returnedAt: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          rubricScores: null,
          attachmentUrls: null,
        );
      }).toList();

      await bulkCreateGrades(grades);
    } catch (e) {
      // Error initializing grades: $e
      rethrow;
    }
  }
}
