import 'package:flutter/material.dart';
import '../../domain/models/activity_model.dart';
import '../../data/services/dashboard_service.dart';
import '../../../assignments/domain/models/assignment.dart';
import '../../../grades/domain/models/grade.dart';
import '../../../../shared/services/logger_service.dart';

// Helper class to combine Grade with assignment info
class GradeWithAssignment {
  final Grade grade;
  final String assignmentTitle;
  final String category;
  
  GradeWithAssignment({
    required this.grade,
    required this.assignmentTitle,
    required this.category,
  });
}

class DashboardProvider with ChangeNotifier {
  final DashboardService _dashboardService = DashboardService();
  
  // State variables
  List<ActivityModel> _recentActivities = [];
  List<Assignment> _upcomingAssignments = [];
  List<GradeWithAssignment> _recentGrades = [];
  Map<String, int> _stats = {};
  double _studentGPA = 0.0;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<ActivityModel> get recentActivities => _recentActivities;
  List<Assignment> get upcomingAssignments => _upcomingAssignments;
  List<GradeWithAssignment> get recentGrades => _recentGrades;
  Map<String, int> get stats => _stats;
  double get studentGPA => _studentGPA;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Teacher-specific getters
  int get totalAssignments => _stats['totalAssignments'] ?? 0;
  int get assignmentsToGrade => _stats['toGrade'] ?? 0;
  
  // Student-specific getters
  int get studentTotalAssignments => _stats['totalAssignments'] ?? 0;
  int get assignmentsDueSoon => _stats['dueSoon'] ?? 0;
  
  // Load teacher dashboard data
  Future<void> loadTeacherDashboard(String teacherId) async {
    _setLoading(true);
    try {
      // Load activities and stats in parallel
      final results = await Future.wait([
        _dashboardService.getTeacherActivities(teacherId, limit: 5),
        _dashboardService.getTeacherAssignmentStats(teacherId),
      ]);
      
      _recentActivities = results[0] as List<ActivityModel>;
      _stats = results[1] as Map<String, int>;
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error loading teacher dashboard', error: e);
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  // Load student dashboard data
  Future<void> loadStudentDashboard(String studentId, List<String> classIds) async {
    _setLoading(true);
    try {
      // Load all dashboard data in parallel
      final results = await Future.wait([
        _dashboardService.getStudentActivities(studentId, classIds, limit: 5),
        _dashboardService.getStudentAssignmentStats(studentId, classIds),
        _dashboardService.getUpcomingAssignments(studentId, classIds, limit: 3),
        _dashboardService.getRecentGrades(studentId, limit: 3),
        _dashboardService.calculateGPA(studentId),
      ]);
      
      _recentActivities = results[0] as List<ActivityModel>;
      _stats = results[1] as Map<String, int>;
      _upcomingAssignments = results[2] as List<Assignment>;
      
      // Convert grades to GradeWithAssignment (for now, we'll need to fetch assignment titles)
      final grades = results[3] as List<Grade>;
      _recentGrades = grades.map((g) => GradeWithAssignment(
        grade: g,
        assignmentTitle: 'Assignment ${g.assignmentId}', // TODO: Fetch actual title
        category: 'General', // TODO: Fetch actual category
      )).toList();
      
      _studentGPA = results[4] as double;
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error loading student dashboard', error: e);
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  
  
  
  // Log a new activity
  Future<void> logActivity(ActivityModel activity) async {
    try {
      await _dashboardService.logActivity(activity);
      // Add to local list for immediate UI update
      _recentActivities.insert(0, activity);
      if (_recentActivities.length > 10) {
        _recentActivities.removeLast();
      }
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error logging activity', error: e);
    }
  }
  
  // Refresh dashboard data
  Future<void> refreshTeacherDashboard(String teacherId) async {
    await loadTeacherDashboard(teacherId);
  }
  
  Future<void> refreshStudentDashboard(String studentId, List<String> classIds) async {
    await loadStudentDashboard(studentId, classIds);
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
  
  void clearData() {
    _recentActivities = [];
    _upcomingAssignments = [];
    _recentGrades = [];
    _stats = {};
    _studentGPA = 0.0;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}