import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simplified student assignment provider with direct Firestore access
class SimpleStudentAssignmentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _assignments = [];
  Map<String, dynamic>? _currentAssignment;
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get assignments => _assignments;
  Map<String, dynamic>? get currentAssignment => _currentAssignment;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load student assignments from Firestore
  Future<void> loadStudentAssignments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _assignments = [];
        return;
      }

      // First, get all classes the student is enrolled in
      final classesSnapshot = await _firestore
          .collection('classes')
          .where('studentIds', arrayContains: user.uid)
          .get();

      if (classesSnapshot.docs.isEmpty) {
        _assignments = [];
        _error = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get all class IDs
      final classIds = classesSnapshot.docs.map((doc) => doc.id).toList();

      // Query assignments for those classes
      final snapshot = await _firestore
          .collection('assignments')
          .where('classId', whereIn: classIds)
          .orderBy('dueDate')
          .get();

      _assignments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Add computed fields
        final dueDate = data['dueDate'];
        data['isOverdue'] =
            dueDate != null &&
            (dueDate is Timestamp ? dueDate.toDate() : dueDate as DateTime)
                .isBefore(DateTime.now());
        data['isSubmitted'] = false; // Will check submissions collection
        data['isGraded'] = false;
        return data;
      }).toList();

      // Check for submissions
      for (var assignment in _assignments) {
        final submissionSnapshot = await _firestore
            .collection('submissions')
            .where('assignmentId', isEqualTo: assignment['id'])
            .where('studentId', isEqualTo: user.uid)
            .get();

        if (submissionSnapshot.docs.isNotEmpty) {
          final submission = submissionSnapshot.docs.first.data();
          assignment['isSubmitted'] = true;
          assignment['submission'] = submission;
          assignment['isGraded'] = submission['grade'] != null;
          if (submission['grade'] != null) {
            assignment['earnedPoints'] = submission['grade']['points'];
            assignment['percentage'] = submission['grade']['percentage'];
            assignment['letterGrade'] = submission['grade']['letter'];
            assignment['feedback'] = submission['grade']['feedback'];
          }
        }
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
      _assignments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load details for a specific assignment
  Future<void> loadAssignmentDetails(String assignmentId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('assignments')
          .doc(assignmentId)
          .get();

      if (doc.exists) {
        _currentAssignment = doc.data()!;
        _currentAssignment!['id'] = doc.id;
        _currentAssignment!['assignment'] =
            _currentAssignment; // Nested reference

        // Check for submission
        final user = _auth.currentUser;
        if (user != null) {
          final submissionSnapshot = await _firestore
              .collection('submissions')
              .where('assignmentId', isEqualTo: assignmentId)
              .where('studentId', isEqualTo: user.uid)
              .get();

          if (submissionSnapshot.docs.isNotEmpty) {
            final submission = submissionSnapshot.docs.first.data();
            _currentAssignment!['isSubmitted'] = true;
            _currentAssignment!['submission'] = submission;
            _currentAssignment!['isGraded'] = submission['grade'] != null;
            if (submission['grade'] != null) {
              _currentAssignment!['earnedPoints'] =
                  submission['grade']['points'];
              _currentAssignment!['percentage'] =
                  submission['grade']['percentage'];
              _currentAssignment!['letterGrade'] =
                  submission['grade']['letter'];
              _currentAssignment!['feedback'] = submission['grade']['feedback'];
            }
          } else {
            _currentAssignment!['isSubmitted'] = false;
            _currentAssignment!['isGraded'] = false;
          }

          final dueDate = _currentAssignment!['dueDate'];
          _currentAssignment!['isOverdue'] =
              dueDate != null &&
              (dueDate is Timestamp ? dueDate.toDate() : dueDate as DateTime)
                  .isBefore(DateTime.now());
        }
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentAssignment = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get assignment by ID
  Map<String, dynamic>? getAssignmentById(String id) {
    return _currentAssignment;
  }

  /// Submit assignment with proper parameters
  Future<bool> submitAssignment({
    required String assignmentId,
    required String studentName,
    required String textContent,
    dynamic file,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('submissions').add({
        'assignmentId': assignmentId,
        'studentId': user.uid,
        'studentName': studentName,
        'textContent': textContent,
        'submittedAt': FieldValue.serverTimestamp(),
        'fileUrl': file?.path, // Handle file upload separately
      });

      // Reload assignment to reflect submission
      await loadAssignmentDetails(assignmentId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Refresh assignments
  Future<void> refresh() async {
    await loadStudentAssignments();
  }

  /// Initialize for student
  Future<void> initializeForStudent(String studentId) async {
    await loadStudentAssignments();
  }

  /// Load assignments for student - compatibility method
  Future<void> loadAssignmentsForStudent(String studentId) async {
    await loadStudentAssignments();
  }

  /// Get assignments stream
  Stream<List<Map<String, dynamic>>> get assignmentsStream {
    // Return a stream that emits current assignments
    return Stream.value(_assignments);
  }
}
