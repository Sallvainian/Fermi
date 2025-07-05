/// Assignment state management provider.
/// 
/// This module manages assignment and grade state for the education platform,
/// handling teacher assignment creation, student submissions, grading workflows,
/// and real-time updates through stream subscriptions.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../models/grade.dart';
import '../repositories/assignment_repository.dart';
import '../repositories/grade_repository.dart';
import '../core/service_locator.dart';

/// Provider managing assignment and grade state.
/// 
/// This provider serves as the central state manager for assignments,
/// coordinating between assignment and grade repositories. Key features:
/// - Real-time assignment updates for teachers and students
/// - Grade management and bulk grading operations
/// - Assignment status workflows (draft, active, completed, archived)
/// - Publishing/unpublishing controls
/// - Automatic grade initialization for published assignments
/// - Statistical analysis for grading insights
/// 
/// Maintains separate lists for teacher-created and class-specific
/// assignments with automatic stream management.
class AssignmentProvider with ChangeNotifier {
  /// Repository for assignment data operations.
  late final AssignmentRepository _assignmentRepository;
  
  /// Repository for grade data operations.
  late final GradeRepository _gradeRepository;
  
  // State variables
  
  /// Assignments for a specific class (student view).
  List<Assignment> _assignments = [];
  
  /// All assignments created by the teacher.
  List<Assignment> _teacherAssignments = [];
  
  /// Grades for the selected assignment.
  List<Grade> _grades = [];
  
  /// Loading state for async operations.
  bool _isLoading = false;
  
  /// Latest error message for UI display.
  String? _error;
  
  /// Selected assignment for detail view.
  Assignment? _selectedAssignment;
  
  // Stream subscriptions
  
  /// Subscription for class assignment updates.
  StreamSubscription<List<Assignment>>? _classAssignmentsSubscription;
  
  /// Subscription for teacher assignment updates.
  StreamSubscription<List<Assignment>>? _teacherAssignmentsSubscription;
  
  /// Subscription for grade updates.
  StreamSubscription<List<Grade>>? _gradesSubscription;
  
  /// Creates assignment provider with repository dependencies.
  /// 
  /// Retrieves repositories from dependency injection container.
  AssignmentProvider() {
    _assignmentRepository = getIt<AssignmentRepository>();
    _gradeRepository = getIt<GradeRepository>();
  }
  
  // Getters
  
  /// Class-specific assignments (student view).
  List<Assignment> get assignments => _assignments;
  
  /// All assignments created by teacher.
  List<Assignment> get teacherAssignments => _teacherAssignments;
  
  /// Grades for selected assignment.
  List<Grade> get grades => _grades;
  
  /// Whether an operation is in progress.
  bool get isLoading => _isLoading;
  
  /// Latest error message or null.
  String? get error => _error;
  
  /// Currently selected assignment or null.
  Assignment? get selectedAssignment => _selectedAssignment;
  
  /// Filters teacher's assignments by status.
  /// 
  /// Useful for categorized views (drafts, active, archived).
  /// 
  /// @param status Status to filter by
  /// @return List of assignments with matching status
  List<Assignment> getAssignmentsByStatus(AssignmentStatus status) {
    return _teacherAssignments.where((a) => a.status == status).toList();
  }
  
  /// Gets assignments due within the next 7 days.
  /// 
  /// Filters active assignments with upcoming due dates
  /// and sorts by soonest first for priority display.
  /// 
  /// @return List of upcoming assignments
  List<Assignment> get upcomingAssignments {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    return _assignments
        .where((a) => a.dueDate.isAfter(now) && a.dueDate.isBefore(weekFromNow))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }
  
  /// Gets assignments past their due date.
  /// 
  /// Filters incomplete assignments with past due dates
  /// and sorts by most recently overdue first.
  /// 
  /// @return List of overdue assignments
  List<Assignment> get overdueAssignments {
    final now = DateTime.now();
    return _assignments
        .where((a) => a.dueDate.isBefore(now) && a.status != AssignmentStatus.completed)
        .toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
  }
  
  /// Loads and subscribes to assignments for a class.
  /// 
  /// Sets up real-time stream for assignment updates.
  /// Used in student views to show class-specific assignments.
  /// Cancels any existing subscription before creating new one.
  /// 
  /// @param classId Class to load assignments from
  /// @throws Exception if loading fails
  Future<void> loadAssignmentsForClass(String classId) async {
    _setLoading(true);
    try {
      // Cancel existing subscription before creating new one
      _classAssignmentsSubscription?.cancel();
      
      // Store the subscription
      _classAssignmentsSubscription = _assignmentRepository.getClassAssignments(classId).listen(
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
  
  /// Loads and subscribes to all teacher's assignments.
  /// 
  /// Sets up real-time stream for teacher's assignments
  /// across all classes. Used in teacher dashboard views.
  /// Cancels any existing subscription before creating new one.
  /// 
  /// @param teacherId Teacher's unique identifier
  /// @throws Exception if loading fails
  Future<void> loadAssignmentsForTeacher(String teacherId) async {
    _setLoading(true);
    try {
      // Cancel existing subscription before creating new one
      _teacherAssignmentsSubscription?.cancel();
      
      // Store the subscription
      _teacherAssignmentsSubscription = _assignmentRepository.getTeacherAssignments(teacherId).listen(
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
  
  /// Loads and subscribes to grades for an assignment.
  /// 
  /// Sets up real-time stream for grade updates.
  /// Used in grading views to show all student grades.
  /// Cancels any existing subscription before creating new one.
  /// 
  /// @param assignmentId Assignment to load grades for
  /// @throws Exception if loading fails
  Future<void> loadGradesForAssignment(String assignmentId) async {
    _setLoading(true);
    try {
      // Cancel existing subscription before creating new one
      _gradesSubscription?.cancel();
      
      // Store the subscription
      _gradesSubscription = _gradeRepository.getAssignmentGrades(assignmentId).listen(
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
  
  /// Creates a new assignment in the system.
  /// 
  /// Process:
  /// 1. Creates assignment in Firestore
  /// 2. If published, initializes grade records for all students
  /// 3. Updates local state through stream subscription
  /// 
  /// @param assignment Assignment data to create
  /// @return true if creation successful
  Future<bool> createAssignment(Assignment assignment) async {
    _setLoading(true);
    try {
      final assignmentId = await _assignmentRepository.createAssignment(assignment);
      
      // Initialize grades for all students if published
      if (assignment.isPublished) {
        await _gradeRepository.initializeGradesForAssignment(
          assignmentId,
          assignment.classId,
          assignment.teacherId,
          assignment.totalPoints,
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
  
  /// Updates existing assignment information.
  /// 
  /// Modifies assignment in Firestore and updates local cache
  /// for immediate UI response. Does not affect existing grades.
  /// 
  /// @param assignment Updated assignment data with ID
  /// @return true if update successful
  Future<bool> updateAssignment(Assignment assignment) async {
    _setLoading(true);
    try {
      await _assignmentRepository.updateAssignment(assignment.id, assignment);
      
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
  
  /// Permanently deletes an assignment.
  /// 
  /// Removes assignment from Firestore and local cache.
  /// This operation cannot be undone. Consider archiving instead.
  /// 
  /// @param assignmentId Assignment to delete
  /// @return true if deletion successful
  Future<bool> deleteAssignment(String assignmentId) async {
    _setLoading(true);
    try {
      await _assignmentRepository.deleteAssignment(assignmentId);
      
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
  
  /// Toggles assignment publication status.
  /// 
  /// Publishing:
  /// - Makes assignment visible to students
  /// - Initializes grade records for all enrolled students
  /// - Allows submission acceptance
  /// 
  /// Unpublishing:
  /// - Hides assignment from students
  /// - Reverts to draft status
  /// - Preserves existing grades
  /// 
  /// @param assignmentId Assignment to toggle
  /// @param publish true to publish, false to unpublish
  /// @return true if toggle successful
  Future<bool> togglePublishStatus(String assignmentId, bool publish) async {
    _setLoading(true);
    try {
      if (publish) {
        final assignment = await _assignmentRepository.getAssignment(assignmentId);
        if (assignment != null) {
          await _assignmentRepository.publishAssignment(assignmentId);
          
          // Initialize grades for all students
          await _gradeRepository.initializeGradesForAssignment(
            assignmentId,
            assignment.classId,
            assignment.teacherId,
            assignment.totalPoints,
          );
        }
      } else {
        await _assignmentRepository.unpublishAssignment(assignmentId);
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
  
  /// Updates a single grade entry.
  /// 
  /// Modifies grade in Firestore and updates local cache
  /// for immediate UI response. Recalculates percentage
  /// and letter grade automatically.
  /// 
  /// @param grade Updated grade data with ID
  /// @return true if update successful
  Future<bool> updateGrade(Grade grade) async {
    _setLoading(true);
    try {
      await _gradeRepository.updateGrade(grade.id, grade);
      
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
  
  /// Updates multiple grades in one atomic operation.
  /// 
  /// Efficient batch update for grading multiple submissions.
  /// All updates succeed or fail together. Updates local cache
  /// after successful batch operation.
  /// 
  /// @param grades Map of grade IDs to updated grade objects
  /// @return true if batch update successful
  Future<bool> bulkUpdateGrades(Map<String, Grade> grades) async {
    _setLoading(true);
    try {
      await _gradeRepository.batchUpdateGrades(grades);
      
      // Update local list
      grades.forEach((gradeId, grade) {
        final index = _grades.indexWhere((g) => g.id == gradeId);
        if (index != -1) {
          _grades[index] = grade;
        }
      });
      notifyListeners();
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Retrieves statistical analysis for an assignment.
  /// 
  /// Calculates aggregate statistics including:
  /// - Average, median, and mode scores
  /// - Grade distribution
  /// - Completion rates
  /// - Performance metrics
  /// 
  /// @param assignmentId Assignment to analyze
  /// @return Grade statistics or null if error
  Future<GradeStatistics?> getAssignmentStatistics(String assignmentId) async {
    try {
      return await _gradeRepository.getAssignmentStatistics(assignmentId);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }
  
  /// Archives an assignment to hide from active lists.
  /// 
  /// Archived assignments:
  /// - No longer accept submissions
  /// - Hidden from student views
  /// - Preserved for historical records
  /// - Can be restored later
  /// 
  /// @param assignmentId Assignment to archive
  /// @return true if archiving successful
  Future<bool> archiveAssignment(String assignmentId) async {
    _setLoading(true);
    try {
      await _assignmentRepository.archiveAssignment(assignmentId);
      
      // Update local list
      final index = _teacherAssignments.indexWhere((a) => a.id == assignmentId);
      if (index != -1) {
        _teacherAssignments[index] = _teacherAssignments[index].copyWith(
          status: AssignmentStatus.archived,
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
  
  /// Restores an archived assignment to draft status.
  /// 
  /// Allows reactivation of archived assignments for:
  /// - Reuse in new terms
  /// - Template creation
  /// - Error correction
  /// 
  /// Restored assignments must be republished to
  /// become visible to students again.
  /// 
  /// @param assignmentId Assignment to restore
  /// @return true if restoration successful
  Future<bool> restoreAssignment(String assignmentId) async {
    _setLoading(true);
    try {
      await _assignmentRepository.restoreAssignment(assignmentId);
      
      // Update local list
      final index = _teacherAssignments.indexWhere((a) => a.id == assignmentId);
      if (index != -1) {
        _teacherAssignments[index] = _teacherAssignments[index].copyWith(
          status: AssignmentStatus.draft,
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
  
  /// Sets the currently selected assignment.
  /// 
  /// Used for detail views and context-aware operations.
  /// 
  /// @param assignment Assignment to select or null to clear
  void setSelectedAssignment(Assignment? assignment) {
    _selectedAssignment = assignment;
    notifyListeners();
  }
  
  // Helper methods
  
  /// Sets loading state and notifies listeners.
  /// 
  /// @param loading New loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Sets error message and notifies listeners.
  /// 
  /// @param error Error description or null
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  /// Clears error message and notifies UI.
  /// 
  /// Called after user acknowledges error.
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Clears all cached data.
  /// 
  /// Resets provider to initial state.
  /// Useful for user logout or role switch.
  void clearData() {
    _assignments = [];
    _teacherAssignments = [];
    _grades = [];
    _selectedAssignment = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
  
  /// Cleans up resources when provider is disposed.
  /// 
  /// Cancels all stream subscriptions and disposes
  /// repositories to prevent memory leaks.
  @override
  void dispose() {
    // Cancel all stream subscriptions
    _classAssignmentsSubscription?.cancel();
    _teacherAssignmentsSubscription?.cancel();
    _gradesSubscription?.cancel();
    
    // Dispose repositories
    _assignmentRepository.dispose();
    _gradeRepository.dispose();
    
    super.dispose();
  }
}