import 'dart:async';
import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../models/grade.dart';
import '../services/assignment_service.dart';

class AssignmentProvider with ChangeNotifier {
  final AssignmentService _assignmentService = AssignmentService();
  
  // State variables
  List<Assignment> _assignments = [];
  List<Assignment> _teacherAssignments = [];
  List<Grade> _grades = [];
  bool _isLoading = false;
  String? _error;
  
  // Selected assignment for detail view
  Assignment? _selectedAssignment;
  
  // Stream subscriptions to prevent memory leaks
  StreamSubscription<List<Assignment>>? _classAssignmentsSubscription;
  StreamSubscription<List<Assignment>>? _teacherAssignmentsSubscription;
  StreamSubscription<List<Grade>>? _gradesSubscription;
  
  // Getters
  List<Assignment> get assignments => _assignments;
  List<Assignment> get teacherAssignments => _teacherAssignments;
  List<Grade> get grades => _grades;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Assignment? get selectedAssignment => _selectedAssignment;
  
  // Get assignments by status
  List<Assignment> getAssignmentsByStatus(AssignmentStatus status) {
    return _teacherAssignments.where((a) => a.status == status).toList();
  }
  
  // Get upcoming assignments (due in next 7 days)
  List<Assignment> get upcomingAssignments {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    return _assignments
        .where((a) => a.dueDate.isAfter(now) && a.dueDate.isBefore(weekFromNow))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }
  
  // Get overdue assignments
  List<Assignment> get overdueAssignments {
    final now = DateTime.now();
    return _assignments
        .where((a) => a.dueDate.isBefore(now) && a.status != AssignmentStatus.completed)
        .toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
  }
  
  // Load assignments for a specific class (student view)
  Future<void> loadAssignmentsForClass(String classId) async {
    _setLoading(true);
    try {
      // Cancel existing subscription before creating new one
      _classAssignmentsSubscription?.cancel();
      
      // Store the subscription
      _classAssignmentsSubscription = _assignmentService.getAssignmentsForClass(classId).listen(
        (assignmentList) {
          _assignments = assignmentList;
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError(error.toString());
          _setLoading(false);
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  // Load assignments for a teacher
  Future<void> loadAssignmentsForTeacher(String teacherId) async {
    _setLoading(true);
    try {
      // Cancel existing subscription before creating new one
      _teacherAssignmentsSubscription?.cancel();
      
      // Store the subscription
      _teacherAssignmentsSubscription = _assignmentService.getAssignmentsForTeacher(teacherId).listen(
        (assignmentList) {
          _teacherAssignments = assignmentList;
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError(error.toString());
          _setLoading(false);
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  // Load grades for a specific assignment
  Future<void> loadGradesForAssignment(String assignmentId) async {
    _setLoading(true);
    try {
      // Cancel existing subscription before creating new one
      _gradesSubscription?.cancel();
      
      // Store the subscription
      _gradesSubscription = _assignmentService.getGradesForAssignment(assignmentId).listen(
        (gradeList) {
          _grades = gradeList;
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError(error.toString());
          _setLoading(false);
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  // Create a new assignment
  Future<bool> createAssignment(Assignment assignment) async {
    _setLoading(true);
    try {
      final createdAssignment = await _assignmentService.createAssignment(assignment);
      
      // Initialize grades for all students if published
      if (createdAssignment.isPublished) {
        await _assignmentService.initializeGradesForAssignment(
          createdAssignment.id,
          createdAssignment.classId,
          createdAssignment.teacherId,
        );
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Update an existing assignment
  Future<bool> updateAssignment(Assignment assignment) async {
    _setLoading(true);
    try {
      await _assignmentService.updateAssignment(assignment);
      
      // Update local list
      final index = _teacherAssignments.indexWhere((a) => a.id == assignment.id);
      if (index != -1) {
        _teacherAssignments[index] = assignment;
        notifyListeners();
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Delete an assignment
  Future<bool> deleteAssignment(String assignmentId) async {
    _setLoading(true);
    try {
      await _assignmentService.deleteAssignment(assignmentId);
      
      // Remove from local list
      _teacherAssignments.removeWhere((a) => a.id == assignmentId);
      notifyListeners();
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Publish/Unpublish assignment
  Future<bool> togglePublishStatus(String assignmentId, bool publish) async {
    _setLoading(true);
    try {
      if (publish) {
        await _assignmentService.publishAssignment(assignmentId);
      } else {
        await _assignmentService.unpublishAssignment(assignmentId);
      }
      
      // Update local list
      final index = _teacherAssignments.indexWhere((a) => a.id == assignmentId);
      if (index != -1) {
        _teacherAssignments[index] = _teacherAssignments[index].copyWith(
          isPublished: publish,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Grade management
  Future<bool> updateGrade(Grade grade) async {
    _setLoading(true);
    try {
      await _assignmentService.updateGrade(grade);
      
      // Update local list
      final index = _grades.indexWhere((g) => g.id == grade.id);
      if (index != -1) {
        _grades[index] = grade;
        notifyListeners();
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Bulk grade update
  Future<bool> bulkUpdateGrades(List<Grade> grades) async {
    _setLoading(true);
    try {
      await _assignmentService.bulkUpdateGrades(grades);
      
      // Update local list
      for (final grade in grades) {
        final index = _grades.indexWhere((g) => g.id == grade.id);
        if (index != -1) {
          _grades[index] = grade;
        }
      }
      notifyListeners();
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Get grade statistics
  Future<GradeStatistics?> getAssignmentStatistics(String assignmentId) async {
    try {
      return await _assignmentService.calculateAssignmentStatistics(assignmentId);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }
  
  // Set selected assignment
  void setSelectedAssignment(Assignment? assignment) {
    _selectedAssignment = assignment;
    notifyListeners();
  }
  
  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Clear all data (useful for logout)
  void clearData() {
    _assignments = [];
    _teacherAssignments = [];
    _grades = [];
    _selectedAssignment = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    // Cancel all stream subscriptions
    _classAssignmentsSubscription?.cancel();
    _teacherAssignmentsSubscription?.cancel();
    _gradesSubscription?.cancel();
    super.dispose();
  }
}