/// Grade state management provider.
///
/// This module manages grade state for the education platform,
/// handling teacher grading workflows, student grade viewing,
/// statistical analysis, and batch operations.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/grade.dart';
import '../../domain/repositories/grade_repository.dart';
import '../../../assignments/domain/repositories/assignment_repository.dart';
import '../../../../shared/core/service_locator.dart';

/// Provider managing grade state and operations.
///
/// This provider serves as the central state manager for grades,
/// coordinating between grade and assignment repositories. Key features:
/// - Real-time grade updates for assignments, students, and classes
/// - Grade submission and feedback management
/// - Batch grading operations for efficiency
/// - Statistical analysis and performance metrics
/// - Grade status workflows (pending, graded, returned)
/// - Automatic percentage and letter grade calculation
///
/// Maintains separate grade lists for different contexts with
/// automatic stream management and statistics calculation.
class GradeProvider with ChangeNotifier {
  /// Repository for grade data operations.
  late final GradeRepository _gradeRepository;

  /// Repository for assignment data operations.
  late final AssignmentRepository _assignmentRepository;

  // State variables

  /// Grades for a specific assignment (teacher view).
  List<Grade> _assignmentGrades = [];

  /// Grades for a specific student.
  List<Grade> _studentGrades = [];

  /// All grades for a class.
  List<Grade> _classGrades = [];

  /// Statistical analysis for assignment grades.
  GradeStatistics? _assignmentStatistics;

  /// Statistical analysis for student performance.
  GradeStatistics? _studentStatistics;

  /// Statistical analysis for class performance.
  GradeStatistics? _classStatistics;

  /// Loading state for async operations.
  bool _isLoading = false;

  /// Latest error message for UI display.
  String? _error;

  /// Selected grade for detail view.
  Grade? _selectedGrade;

  // Stream subscriptions

  /// Subscription for assignment grade updates.
  StreamSubscription<List<Grade>>? _assignmentGradesSubscription;

  /// Subscription for student grade updates.
  StreamSubscription<List<Grade>>? _studentGradesSubscription;

  /// Subscription for class grade updates.
  StreamSubscription<List<Grade>>? _classGradesSubscription;

  /// Creates grade provider with repository dependencies.
  ///
  /// Retrieves repositories from dependency injection container.
  GradeProvider() {
    _gradeRepository = getIt<GradeRepository>();
    _assignmentRepository = getIt<AssignmentRepository>();
  }

  // Getters

  /// Grades for the selected assignment.
  List<Grade> get assignmentGrades => _assignmentGrades;

  /// Grades for the selected student.
  List<Grade> get studentGrades => _studentGrades;

  /// All grades for the selected class.
  List<Grade> get classGrades => _classGrades;

  /// Statistics for assignment performance.
  GradeStatistics? get assignmentStatistics => _assignmentStatistics;

  /// Statistics for student performance.
  GradeStatistics? get studentStatistics => _studentStatistics;

  /// Statistics for class performance.
  GradeStatistics? get classStatistics => _classStatistics;

  /// Whether an operation is in progress.
  bool get isLoading => _isLoading;

  /// Latest error message or null.
  String? get error => _error;

  /// Currently selected grade or null.
  Grade? get selectedGrade => _selectedGrade;

  /// Filters assignment grades by status.
  ///
  /// Useful for categorized grading views.
  ///
  /// @param status Grade status to filter by
  /// @return List of grades with matching status
  List<Grade> getGradesByStatus(GradeStatus status) {
    return _assignmentGrades.where((g) => g.status == status).toList();
  }

  /// Gets count of ungraded submissions.
  ///
  /// Shows number of assignments awaiting grading.
  int get pendingGradesCount {
    return _assignmentGrades
        .where((g) => g.status == GradeStatus.pending)
        .length;
  }

  /// Loads and subscribes to grades for an assignment.
  ///
  /// Sets up real-time stream for grade updates and
  /// automatically calculates assignment statistics.
  /// Used in teacher grading views.
  ///
  /// @param assignmentId Assignment to load grades for
  /// @throws Exception if loading fails
  Future<void> loadAssignmentGrades(String assignmentId) async {
    _setLoading(true);
    try {
      _assignmentGradesSubscription?.cancel();

      _assignmentGradesSubscription =
          _gradeRepository.getAssignmentGrades(assignmentId).listen(
        (gradeList) {
          _assignmentGrades = gradeList;
          _loadAssignmentStatistics(assignmentId);
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

  /// Loads and subscribes to all grades for a student.
  ///
  /// Sets up real-time stream for student's grades
  /// across all classes and assignments.
  ///
  /// @param studentId Student to load grades for
  /// @throws Exception if loading fails
  Future<void> loadStudentGrades(String studentId) async {
    _setLoading(true);
    try {
      _studentGradesSubscription?.cancel();

      _studentGradesSubscription =
          _gradeRepository.getStudentGrades(studentId).listen(
        (gradeList) {
          _studentGrades = gradeList;
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

  /// Loads grades for a student in a specific class.
  ///
  /// Sets up real-time stream and calculates student's
  /// performance statistics within the class context.
  ///
  /// @param studentId Student identifier
  /// @param classId Class identifier
  /// @throws Exception if loading fails
  Future<void> loadStudentClassGrades(String studentId, String classId) async {
    _setLoading(true);
    try {
      _studentGradesSubscription?.cancel();

      _studentGradesSubscription =
          _gradeRepository.getStudentClassGrades(studentId, classId).listen(
        (gradeList) {
          _studentGrades = gradeList;
          _loadStudentClassStatistics(studentId, classId);
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

  /// Loads all grades for all students in a class.
  ///
  /// Sets up real-time stream for comprehensive class
  /// performance monitoring and statistics calculation.
  ///
  /// @param classId Class to load grades for
  /// @throws Exception if loading fails
  Future<void> loadClassGrades(String classId) async {
    _setLoading(true);
    try {
      _classGradesSubscription?.cancel();

      _classGradesSubscription =
          _gradeRepository.getClassGrades(classId).listen(
        (gradeList) {
          _classGrades = gradeList;
          _loadClassStatistics(classId);
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

  /// Creates a new grade record.
  ///
  /// Typically used when manually adding grades or
  /// for late submissions not auto-initialized.
  ///
  /// @param grade Grade data to create
  /// @return true if creation successful
  Future<bool> createGrade(Grade grade) async {
    _setLoading(true);
    try {
      await _gradeRepository.createGrade(grade);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Updates an existing grade record.
  ///
  /// Modifies grade in Firestore and updates local cache
  /// for immediate UI response. Recalculates statistics.
  ///
  /// @param gradeId Grade to update
  /// @param grade Updated grade data
  /// @return true if update successful
  Future<bool> updateGrade(String gradeId, Grade grade) async {
    _setLoading(true);
    try {
      await _gradeRepository.updateGrade(gradeId, grade);

      // Update local lists
      _updateLocalGrade(gradeId, grade);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Submits a grade with points and optional feedback.
  ///
  /// Automatically:
  /// - Calculates percentage and letter grade
  /// - Updates grade status to 'graded'
  /// - Records grading timestamp
  /// - Updates local cache and statistics
  ///
  /// @param gradeId Grade to submit
  /// @param pointsEarned Points awarded
  /// @param feedback Optional teacher feedback
  /// @return true if submission successful
  Future<bool> submitGrade(
      String gradeId, double pointsEarned, String? feedback) async {
    _setLoading(true);
    try {
      final grade = _findGradeById(gradeId);
      if (grade == null) {
        throw Exception('Grade not found');
      }

      // Update local grade
      final updatedGrade = grade.copyWith(
        pointsEarned: pointsEarned,
        percentage:
            Grade.calculatePercentage(pointsEarned, grade.pointsPossible),
        letterGrade: Grade.calculateLetterGrade(
            Grade.calculatePercentage(pointsEarned, grade.pointsPossible)),
        feedback: feedback,
        status: GradeStatus.graded,
        gradedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _gradeRepository.submitGrade(updatedGrade);

      _updateLocalGrade(gradeId, updatedGrade);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Returns a graded assignment to student.
  ///
  /// Changes status from 'graded' to 'returned',
  /// making the grade visible to the student.
  /// Records return timestamp.
  ///
  /// @param gradeId Grade to return
  /// @return true if return successful
  Future<bool> returnGrade(String gradeId) async {
    _setLoading(true);
    try {
      await _gradeRepository.returnGrade(gradeId);

      // Update local grade
      final grade = _findGradeById(gradeId);
      if (grade != null) {
        final updatedGrade = grade.copyWith(
          status: GradeStatus.returned,
          returnedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _updateLocalGrade(gradeId, updatedGrade);
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
  /// Efficient batch grading for bulk operations.
  /// All updates succeed or fail together.
  /// Updates local cache after successful operation.
  ///
  /// @param grades Map of grade IDs to updated grade objects
  /// @return true if batch update successful
  Future<bool> batchUpdateGrades(Map<String, Grade> grades) async {
    _setLoading(true);
    try {
      await _gradeRepository.batchUpdateGrades(grades);

      // Update local grades
      grades.forEach((gradeId, grade) {
        _updateLocalGrade(gradeId, grade);
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Creates grade records for all students in a class.
  ///
  /// Called when publishing an assignment to pre-create
  /// grade records with 'pending' status. Ensures all
  /// students have grade entries for the assignment.
  ///
  /// @param assignmentId Assignment requiring grades
  /// @param classId Class containing students
  /// @param teacherId Teacher creating assignment
  /// @param pointsPossible Maximum points for assignment
  /// @return true if initialization successful
  Future<bool> initializeGradesForAssignment(
    String assignmentId,
    String classId,
    String teacherId,
    double pointsPossible,
  ) async {
    _setLoading(true);
    try {
      await _gradeRepository.initializeGradesForAssignment(
        assignmentId,
        classId,
        teacherId,
        pointsPossible,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Loads statistical analysis for an assignment.
  ///
  /// Calculates average, median, distribution, etc.
  /// Fails silently to not interrupt grade display.
  ///
  /// @param assignmentId Assignment to analyze
  Future<void> _loadAssignmentStatistics(String assignmentId) async {
    try {
      _assignmentStatistics =
          await _gradeRepository.getAssignmentStatistics(assignmentId);
      notifyListeners();
    } catch (e) {
      // Silently fail for statistics
    }
  }

  /// Loads statistical analysis for student in a class.
  ///
  /// Calculates student's performance metrics within
  /// the class context. Fails silently.
  ///
  /// @param studentId Student to analyze
  /// @param classId Class context
  Future<void> _loadStudentClassStatistics(
      String studentId, String classId) async {
    try {
      _studentStatistics =
          await _gradeRepository.getStudentClassStatistics(studentId, classId);
      notifyListeners();
    } catch (e) {
      // Silently fail for statistics
    }
  }

  /// Loads statistical analysis for entire class.
  ///
  /// Calculates class-wide performance metrics.
  /// Fails silently to not interrupt display.
  ///
  /// @param classId Class to analyze
  Future<void> _loadClassStatistics(String classId) async {
    try {
      _classStatistics = await _gradeRepository.getClassStatistics(classId);
      notifyListeners();
    } catch (e) {
      // Silently fail for statistics
    }
  }

  /// Sets the currently selected grade.
  ///
  /// Used for detail views and context-aware operations.
  ///
  /// @param grade Grade to select or null to clear
  void setSelectedGrade(Grade? grade) {
    _selectedGrade = grade;
    notifyListeners();
  }

  // Helper methods

  /// Searches for a grade across all loaded lists.
  ///
  /// @param gradeId Grade identifier to find
  /// @return Grade instance or null if not found
  Grade? _findGradeById(String gradeId) {
    // Search in all grade lists
    final allGrades = [
      ..._assignmentGrades,
      ..._studentGrades,
      ..._classGrades
    ];
    try {
      return allGrades.firstWhere((g) => g.id == gradeId);
    } catch (e) {
      return null;
    }
  }

  /// Updates a grade in all local caches.
  ///
  /// Searches through assignment, student, and class grade
  /// lists to update the grade instance. Also updates
  /// selected grade if it matches.
  ///
  /// @param gradeId Grade identifier to update
  /// @param grade New grade data
  void _updateLocalGrade(String gradeId, Grade grade) {
    // Update in assignment grades
    final assignmentIndex =
        _assignmentGrades.indexWhere((g) => g.id == gradeId);
    if (assignmentIndex != -1) {
      _assignmentGrades[assignmentIndex] = grade;
    }

    // Update in student grades
    final studentIndex = _studentGrades.indexWhere((g) => g.id == gradeId);
    if (studentIndex != -1) {
      _studentGrades[studentIndex] = grade;
    }

    // Update in class grades
    final classIndex = _classGrades.indexWhere((g) => g.id == gradeId);
    if (classIndex != -1) {
      _classGrades[classIndex] = grade;
    }

    // Update selected grade
    if (_selectedGrade?.id == gradeId) {
      _selectedGrade = grade;
    }

    notifyListeners();
  }

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

  /// Clears all cached grade data.
  ///
  /// Resets provider to initial state.
  /// Useful for user logout or role switch.
  void clearData() {
    _assignmentGrades = [];
    _studentGrades = [];
    _classGrades = [];
    _assignmentStatistics = null;
    _studentStatistics = null;
    _classStatistics = null;
    _selectedGrade = null;
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
    // Cancel subscriptions
    _assignmentGradesSubscription?.cancel();
    _studentGradesSubscription?.cancel();
    _classGradesSubscription?.cancel();

    // Dispose repositories
    _gradeRepository.dispose();
    _assignmentRepository.dispose();

    super.dispose();
  }
}
