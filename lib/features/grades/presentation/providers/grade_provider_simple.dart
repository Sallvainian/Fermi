import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/utils/firestore_batch_query.dart';

/// Simplified grade provider with direct Firestore access
class SimpleGradeProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _grades = [];
  Map<String, dynamic>? _currentGrade;
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get grades => _grades;
  Map<String, dynamic>? get currentGrade => _currentGrade;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Additional getters for compatibility
  List<Map<String, dynamic>> get studentGrades => _grades;
  List<Map<String, dynamic>> get classGrades => _grades;
  Map<String, dynamic> get classStatistics => {
    'average': 0.0,
    'highest': 0.0,
    'lowest': 0.0,
    'totalStudents': 0,
    'submitted': 0,
  };

  /// Load teacher's grades
  Future<void> loadTeacherGrades() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _grades = [];
        return;
      }

      // Query grades for assignments created by this teacher
      final assignmentsSnapshot = await _firestore
          .collection('assignments')
          .where('teacherId', isEqualTo: user.uid)
          .get();

      final assignmentIds = assignmentsSnapshot.docs
          .map((doc) => doc.id)
          .toList();

      if (assignmentIds.isEmpty) {
        _grades = [];
        _error = null;
        return;
      }

      // Query submissions for these assignments (batch if >30)
      List<QueryDocumentSnapshot<Map<String, dynamic>>> submissionDocs = [];

      if (assignmentIds.length <= 30) {
        // Direct query if 30 or fewer assignments
        final submissionsSnapshot = await _firestore
            .collection('submissions')
            .where('assignmentId', whereIn: assignmentIds)
            .get();
        submissionDocs = submissionsSnapshot.docs;
      } else {
        // Use batch query for more than 30 assignments
        submissionDocs = await FirestoreBatchQuery.batchWhereIn(
          collection: _firestore.collection('submissions'),
          field: 'assignmentId',
          values: assignmentIds,
        );
      }

      _grades = submissionDocs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _error = null;
    } catch (e) {
      _error = e.toString();
      _grades = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load student's grades
  Future<void> loadStudentGrades(String studentId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Query submissions for this student
      final snapshot = await _firestore
          .collection('submissions')
          .where('studentId', isEqualTo: studentId)
          .where('grade', isNotEqualTo: null)
          .get();

      _grades = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _error = null;
    } catch (e) {
      _error = e.toString();
      _grades = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Grade a submission
  Future<bool> gradeSubmission({
    required String submissionId,
    required double points,
    required double maxPoints,
    required String feedback,
  }) async {
    try {
      final percentage = (points / maxPoints) * 100;
      final letterGrade = _getLetterGrade(percentage);

      await _firestore.collection('submissions').doc(submissionId).update({
        'grade': {
          'points': points,
          'maxPoints': maxPoints,
          'percentage': percentage,
          'letter': letterGrade,
          'feedback': feedback,
          'gradedAt': FieldValue.serverTimestamp(),
          'gradedBy': _auth.currentUser?.uid,
        },
      });

      await loadTeacherGrades(); // Reload grades
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get grades by class
  Future<List<Map<String, dynamic>>> getClassGrades(String classId) async {
    try {
      // Get assignments for this class
      final assignmentsSnapshot = await _firestore
          .collection('assignments')
          .where('classId', isEqualTo: classId)
          .get();

      final assignmentIds = assignmentsSnapshot.docs
          .map((doc) => doc.id)
          .toList();

      if (assignmentIds.isEmpty) return [];

      // Get submissions for these assignments (batch if >30)
      List<QueryDocumentSnapshot<Map<String, dynamic>>> submissionDocs = [];

      if (assignmentIds.length <= 30) {
        // Direct query if 30 or fewer assignments
        final submissionsSnapshot = await _firestore
            .collection('submissions')
            .where('assignmentId', whereIn: assignmentIds)
            .get();
        submissionDocs = submissionsSnapshot.docs;
      } else {
        // Use batch query for more than 30 assignments
        submissionDocs = await FirestoreBatchQuery.batchWhereIn(
          collection: _firestore.collection('submissions'),
          field: 'assignmentId',
          values: assignmentIds,
        );
      }

      return submissionDocs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  /// Get grades stream
  Stream<List<Map<String, dynamic>>> get gradesStream {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('submissions')
        .where('grade', isNotEqualTo: null)
        .snapshots()
        .asyncMap((snapshot) async {
          await Future.delayed(Duration.zero);
          return snapshot;
        })
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// Helper to calculate letter grade
  String _getLetterGrade(double percentage) {
    if (percentage >= 93) return 'A';
    if (percentage >= 90) return 'A-';
    if (percentage >= 87) return 'B+';
    if (percentage >= 83) return 'B';
    if (percentage >= 80) return 'B-';
    if (percentage >= 77) return 'C+';
    if (percentage >= 73) return 'C';
    if (percentage >= 70) return 'C-';
    if (percentage >= 67) return 'D+';
    if (percentage >= 63) return 'D';
    if (percentage >= 60) return 'D-';
    return 'F';
  }

  /// Load grades (generic method)
  Future<void> loadGrades() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Determine if teacher or student based on role
    // For now, assume teacher
    await loadTeacherGrades();
  }

  /// Load grades for a specific class
  Future<void> loadClassGrades(String classId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Stub implementation - would filter by classId
      await loadTeacherGrades();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load student grades for a specific class
  Future<void> loadStudentClassGrades(String studentId, String classId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final submissionsSnapshot = await _firestore
          .collection('submissions')
          .where('studentId', isEqualTo: studentId)
          .get();

      _grades = submissionsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _error = e.toString();
      _grades = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
