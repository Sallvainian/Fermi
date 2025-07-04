import 'dart:async';
import 'package:flutter/material.dart';
import '../models/grade.dart';
import '../repositories/grade_repository.dart';
import '../repositories/assignment_repository.dart';
import '../core/service_locator.dart';

class GradeProvider with ChangeNotifier {
  late final GradeRepository _gradeRepository;
  late final AssignmentRepository _assignmentRepository;
  
  // State variables
  List<Grade> _assignmentGrades = [];
  List<Grade> _studentGrades = [];
  List<Grade> _classGrades = [];
  GradeStatistics? _assignmentStatistics;
  GradeStatistics? _studentStatistics;
  GradeStatistics? _classStatistics;
  bool _isLoading = false;
  String? _error;
  
  // Selected grade for detail view
  Grade? _selectedGrade;
  
  // Stream subscriptions
  StreamSubscription<List<Grade>>? _assignmentGradesSubscription;
  StreamSubscription<List<Grade>>? _studentGradesSubscription;
  StreamSubscription<List<Grade>>? _classGradesSubscription;
  
  // Constructor
  GradeProvider() {
    _gradeRepository = getIt<GradeRepository>();
    _assignmentRepository = getIt<AssignmentRepository>();
  }
  
  // Getters
  List<Grade> get assignmentGrades => _assignmentGrades;
  List<Grade> get studentGrades => _studentGrades;
  List<Grade> get classGrades => _classGrades;
  GradeStatistics? get assignmentStatistics => _assignmentStatistics;
  GradeStatistics? get studentStatistics => _studentStatistics;
  GradeStatistics? get classStatistics => _classStatistics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Grade? get selectedGrade => _selectedGrade;
  
  // Get grades by status
  List<Grade> getGradesByStatus(GradeStatus status) {
    return _assignmentGrades.where((g) => g.status == status).toList();
  }
  
  // Get pending grades count
  int get pendingGradesCount {
    return _assignmentGrades.where((g) => g.status == GradeStatus.pending).length;
  }
  
  // Load grades for an assignment
  Future<void> loadAssignmentGrades(String assignmentId) async {
    _setLoading(true);
    try {
      _assignmentGradesSubscription?.cancel();
      
      _assignmentGradesSubscription = _gradeRepository.getAssignmentGrades(assignmentId).listen(
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
  
  // Load grades for a student
  Future<void> loadStudentGrades(String studentId) async {
    _setLoading(true);
    try {
      _studentGradesSubscription?.cancel();
      
      _studentGradesSubscription = _gradeRepository.getStudentGrades(studentId).listen(
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
  
  // Load grades for a student in a specific class
  Future<void> loadStudentClassGrades(String studentId, String classId) async {
    _setLoading(true);
    try {
      _studentGradesSubscription?.cancel();
      
      _studentGradesSubscription = _gradeRepository.getStudentClassGrades(studentId, classId).listen(
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
  
  // Load all grades for a class
  Future<void> loadClassGrades(String classId) async {
    _setLoading(true);
    try {
      _classGradesSubscription?.cancel();
      
      _classGradesSubscription = _gradeRepository.getClassGrades(classId).listen(
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
  
  // Create a grade
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
  
  // Update a grade
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
  
  // Submit a grade (with feedback)
  Future<bool> submitGrade(String gradeId, double pointsEarned, String? feedback) async {
    _setLoading(true);
    try {
      final grade = _findGradeById(gradeId);
      if (grade == null) {
        throw Exception('Grade not found');
      }
      
      // Update local grade
      final updatedGrade = grade.copyWith(
        pointsEarned: pointsEarned,
        percentage: Grade.calculatePercentage(pointsEarned, grade.pointsPossible),
        letterGrade: Grade.calculateLetterGrade(
          Grade.calculatePercentage(pointsEarned, grade.pointsPossible)
        ),
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
  
  // Return a grade to student
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
  
  // Batch update grades
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
  
  // Initialize grades for an assignment
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
  
  // Load statistics
  Future<void> _loadAssignmentStatistics(String assignmentId) async {
    try {
      _assignmentStatistics = await _gradeRepository.getAssignmentStatistics(assignmentId);
      notifyListeners();
    } catch (e) {
      // Silently fail for statistics
    }
  }
  
  Future<void> _loadStudentClassStatistics(String studentId, String classId) async {
    try {
      _studentStatistics = await _gradeRepository.getStudentClassStatistics(studentId, classId);
      notifyListeners();
    } catch (e) {
      // Silently fail for statistics
    }
  }
  
  Future<void> _loadClassStatistics(String classId) async {
    try {
      _classStatistics = await _gradeRepository.getClassStatistics(classId);
      notifyListeners();
    } catch (e) {
      // Silently fail for statistics
    }
  }
  
  // Set selected grade
  void setSelectedGrade(Grade? grade) {
    _selectedGrade = grade;
    notifyListeners();
  }
  
  // Helper methods
  Grade? _findGradeById(String gradeId) {
    // Search in all grade lists
    final allGrades = [..._assignmentGrades, ..._studentGrades, ..._classGrades];
    try {
      return allGrades.firstWhere((g) => g.id == gradeId);
    } catch (e) {
      return null;
    }
  }
  
  void _updateLocalGrade(String gradeId, Grade grade) {
    // Update in assignment grades
    final assignmentIndex = _assignmentGrades.indexWhere((g) => g.id == gradeId);
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
  
  // Clear all data
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