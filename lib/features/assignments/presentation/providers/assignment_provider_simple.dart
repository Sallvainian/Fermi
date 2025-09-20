import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simplified assignment provider with direct Firestore access
class SimpleAssignmentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get assignments => _assignments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load teacher's assignments
  Future<void> loadAssignments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _assignments = [];
        return;
      }

      // Query assignments created by this teacher
      final snapshot = await _firestore
          .collection('assignments')
          .where('teacherId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      _assignments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _error = null;
    } catch (e) {
      _error = e.toString();
      _assignments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create new assignment
  Future<bool> createAssignment(Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      data['teacherId'] = user.uid;
      data['createdAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('assignments').add(data);
      await loadAssignments(); // Reload to show new assignment
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Load assignments for a specific class
  Future<void> loadClassAssignments(String classId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('assignments')
          .where('classId', isEqualTo: classId)
          .orderBy('dueDate')
          .get();

      _assignments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _error = null;
    } catch (e) {
      _error = e.toString();
      _assignments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get assignments stream
  Stream<List<Map<String, dynamic>>> get assignmentsStream {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('assignments')
        .where('teacherId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
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

  /// Get teacher assignments - for compatibility
  List<Map<String, dynamic>> get teacherAssignments => _assignments;

  /// Load assignments for teacher - for compatibility
  Future<void> loadAssignmentsForTeacher() async {
    await loadAssignments();
  }

  /// Get assignment by ID
  Future<Map<String, dynamic>?> getAssignmentById(String assignmentId) async {
    try {
      final doc = await _firestore
          .collection('assignments')
          .doc(assignmentId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Selected assignment for detail view
  Map<String, dynamic>? _selectedAssignment;
  Map<String, dynamic>? get selectedAssignment => _selectedAssignment;

  /// Set selected assignment
  void setSelectedAssignment(Map<String, dynamic>? assignment) {
    _selectedAssignment = assignment;
    notifyListeners();
  }

  /// Update assignment
  Future<bool> updateAssignment(
    String assignmentId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection('assignments')
          .doc(assignmentId)
          .update(updates);

      // Update local list
      final index = _assignments.indexWhere((a) => a['id'] == assignmentId);
      if (index != -1) {
        _assignments[index] = {..._assignments[index], ...updates};
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete assignment
  Future<bool> deleteAssignment(String assignmentId) async {
    try {
      await _firestore.collection('assignments').doc(assignmentId).delete();

      // Update local list
      _assignments.removeWhere((a) => a['id'] == assignmentId);
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggle publish status
  Future<bool> togglePublishStatus(String assignmentId) async {
    try {
      final doc = await _firestore
          .collection('assignments')
          .doc(assignmentId)
          .get();

      if (doc.exists) {
        final isPublished = doc.data()?['isPublished'] ?? false;
        await updateAssignment(assignmentId, {'isPublished': !isPublished});
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update assignment status
  Future<bool> updateAssignmentStatus(
    String assignmentId,
    String status,
  ) async {
    return await updateAssignment(assignmentId, {'status': status});
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Load assignments for a specific class - for compatibility
  Future<void> loadAssignmentsForClass(String classId) async {
    await loadClassAssignments(classId);
  }

  /// Get assignments for a specific class
  List<Map<String, dynamic>> getAssignmentsForClass(String classId) {
    return _assignments.where((a) => a['classId'] == classId).toList();
  }
}
