import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assignment.dart';
import '../models/grade.dart';

class AssignmentService {
  final FirebaseFirestore _firestore;
  final CollectionReference _assignmentsCollection;
  final CollectionReference _gradesCollection;

  AssignmentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _assignmentsCollection = (firestore ?? FirebaseFirestore.instance).collection('assignments'),
        _gradesCollection = (firestore ?? FirebaseFirestore.instance).collection('grades');

  // --- Assignment CRUD Operations ---

  Future<Assignment> createAssignment(Assignment assignment) async {
    try {
      final docRef = await _assignmentsCollection.add(assignment.toFirestore());
      return assignment.copyWith(id: docRef.id);
    } catch (e) {
      // Error creating assignment: $e
      rethrow;
    }
  }

  Future<Assignment?> getAssignment(String assignmentId) async {
    try {
      final doc = await _assignmentsCollection.doc(assignmentId).get();
      if (!doc.exists) return null;
      return Assignment.fromFirestore(doc);
    } catch (e) {
      // Error getting assignment: $e
      rethrow;
    }
  }

  Stream<List<Assignment>> getAssignmentsForClass(String classId) {
    return _assignmentsCollection
        .where('classId', isEqualTo: classId)
        .where('isPublished', isEqualTo: true)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Assignment.fromFirestore(doc))
            .toList());
  }

  Stream<List<Assignment>> getAssignmentsForTeacher(String teacherId) {
    return _assignmentsCollection
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Assignment.fromFirestore(doc))
            .toList());
  }

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

  Future<Grade> createGrade(Grade grade) async {
    try {
      final docRef = await _gradesCollection.add(grade.toFirestore());
      return grade.copyWith(id: docRef.id);
    } catch (e) {
      // Error creating grade: $e
      rethrow;
    }
  }

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

  Future<Grade?> getGradeForStudentAndAssignment(String studentId, String assignmentId) async {
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

  Stream<List<Grade>> getGradesForAssignment(String assignmentId) {
    return _gradesCollection
        .where('assignmentId', isEqualTo: assignmentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Grade.fromFirestore(doc))
            .toList());
  }

  Stream<List<Grade>> getGradesForStudent(String studentId) {
    return _gradesCollection
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Grade.fromFirestore(doc))
            .toList());
  }

  Future<void> updateGrade(Grade grade) async {
    try {
      grade.updatedAt = DateTime.now();
      await _gradesCollection
          .doc(grade.id)
          .update(grade.toFirestore());
    } catch (e) {
      // Error updating grade: $e
      rethrow;
    }
  }

  Future<void> deleteGrade(String gradeId) async {
    try {
      await _gradesCollection.doc(gradeId).delete();
    } catch (e) {
      // Error deleting grade: $e
      rethrow;
    }
  }

  // --- Batch Operations ---

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

  Future<GradeStatistics> calculateAssignmentStatistics(String assignmentId) async {
    try {
      final querySnapshot = await _gradesCollection
          .where('assignmentId', isEqualTo: assignmentId)
          .where('status', isEqualTo: GradeStatus.graded.name)
          .get();

      final grades = querySnapshot.docs
          .map((doc) => Grade.fromFirestore(doc))
          .toList();

      return GradeStatistics.fromGrades(grades);
    } catch (e) {
      // Error calculating statistics: $e
      rethrow;
    }
  }

  Future<GradeStatistics> calculateStudentStatistics(String studentId, {String? classId}) async {
    try {
      Query query = _gradesCollection
          .where('studentId', isEqualTo: studentId)
          .where('status', isEqualTo: GradeStatus.graded.name);
      
      if (classId != null) {
        query = query.where('classId', isEqualTo: classId);
      }

      final querySnapshot = await query.get();

      final grades = querySnapshot.docs
          .map((doc) => Grade.fromFirestore(doc))
          .toList();

      return GradeStatistics.fromGrades(grades);
    } catch (e) {
      // Error calculating student statistics: $e
      rethrow;
    }
  }

  // --- Helper Methods ---

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

  // Check and publish scheduled assignments
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

  // Initialize grades for all students in a class when an assignment is created
  Future<void> initializeGradesForAssignment(String assignmentId, String classId, String teacherId) async {
    try {
      // Get all students in the class
      final studentsSnapshot = await _firestore
          .collection('students')
          .where('classIds', arrayContains: classId)
          .get();

      final grades = studentsSnapshot.docs.map((studentDoc) {
        final studentData = studentDoc.data();
        final studentName = studentData['displayName'] ?? 'Unknown Student';
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