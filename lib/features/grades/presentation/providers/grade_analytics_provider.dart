import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/models/grade_analytics.dart';
import '../../data/services/grade_analytics_service.dart';

class GradeAnalyticsProvider with ChangeNotifier {
  final GradeAnalyticsService _analyticsService = GradeAnalyticsService();

  // Analytics data by class ID
  final Map<String, GradeAnalytics> _analyticsCache = {};

  // Grade trends by class ID
  final Map<String, List<GradeTrend>> _trendsCache = {};

  // Loading states
  final Map<String, bool> _loadingStates = {};

  // Error states
  final Map<String, String?> _errorStates = {};

  // Selected class for detailed view
  String? _selectedClassId;

  // Time range for trends
  int _trendDays = 30;

  // Getters
  GradeAnalytics? getClassAnalytics(String classId) => _analyticsCache[classId];
  List<GradeTrend>? getClassTrends(String classId) {
    // Generate demo trends if not cached
    if (!_trendsCache.containsKey(classId) &&
        (classId.startsWith('math-') ||
            classId.startsWith('sci-') ||
            classId.startsWith('eng-') ||
            classId.startsWith('hist-'))) {
      _trendsCache[classId] = _generateDemoTrends();
    }
    return _trendsCache[classId];
  }

  bool isLoading(String classId) => _loadingStates[classId] ?? false;
  String? getError(String classId) => _errorStates[classId];
  String? get selectedClassId => _selectedClassId;
  int get trendDays => _trendDays;

  /// Load analytics for a specific class
  Future<void> loadClassAnalytics(
    String classId, {
    bool forceRefresh = false,
  }) async {
    // Check cache
    if (!forceRefresh && _analyticsCache.containsKey(classId)) {
      return;
    }

    // Set loading state
    _loadingStates[classId] = true;
    _errorStates[classId] = null;
    notifyListeners();

    try {
      // Load analytics
      final analytics = await _analyticsService.generateClassAnalytics(classId);
      _analyticsCache[classId] = analytics;

      // Load trends
      final trends = await _analyticsService.getGradeTrends(
        classId,
        days: _trendDays,
      );
      _trendsCache[classId] = trends;

      _loadingStates[classId] = false;
      notifyListeners();
    } catch (e) {
      _loadingStates[classId] = false;
      _errorStates[classId] = e.toString();
      notifyListeners();
    }
  }

  /// Select a class for detailed view
  void selectClass(String classId) {
    _selectedClassId = classId;
    notifyListeners();

    // Load analytics if not already loaded
    if (!_analyticsCache.containsKey(classId)) {
      loadClassAnalytics(classId);
    }
  }

  /// Update trend time range
  void updateTrendDays(int days) {
    _trendDays = days;
    notifyListeners();

    // Reload trends for all cached classes
    _trendsCache.clear();
    for (final classId in _analyticsCache.keys) {
      _loadTrends(classId);
    }
  }

  /// Load trends for a class
  Future<void> _loadTrends(String classId) async {
    try {
      final trends = await _analyticsService.getGradeTrends(
        classId,
        days: _trendDays,
      );
      _trendsCache[classId] = trends;
      notifyListeners();
    } catch (e) {
      // Silently fail for trends
    }
  }

  /// Get all loaded analytics (for overview)
  List<GradeAnalytics> get allAnalytics => _analyticsCache.values.toList();

  /// Get students at risk across all classes
  List<StudentPerformance> getAtRiskStudents() {
    final atRiskStudents = <StudentPerformance>[];

    for (final analytics in _analyticsCache.values) {
      atRiskStudents.addAll(
        analytics.studentPerformances.where((s) => s.riskLevel == 'at-risk'),
      );
    }

    return atRiskStudents;
  }

  /// Get overall statistics across all classes
  Map<String, dynamic> getOverallStats() {
    if (_analyticsCache.isEmpty) return {};

    double totalAverage = 0;
    int totalAssignments = 0;
    int totalGraded = 0;
    int totalPending = 0;
    int totalStudents = 0;

    for (final analytics in _analyticsCache.values) {
      totalAverage += analytics.averageGrade;
      totalAssignments += analytics.totalAssignments;
      totalGraded += analytics.gradedAssignments;
      totalPending += analytics.pendingSubmissions;
      totalStudents += analytics.studentPerformances.length;
    }

    return {
      'averageGrade': totalAverage / _analyticsCache.length,
      'totalAssignments': totalAssignments,
      'totalGraded': totalGraded,
      'totalPending': totalPending,
      'totalStudents': totalStudents,
      'completionRate': totalAssignments > 0
          ? (totalGraded / totalAssignments) * 100
          : 0,
    };
  }

  /// Get top performing students across all classes
  List<StudentPerformance> getTopPerformers({int limit = 10}) {
    final allStudents = <StudentPerformance>[];

    for (final analytics in _analyticsCache.values) {
      allStudents.addAll(analytics.studentPerformances);
    }

    allStudents.sort((a, b) => b.averageGrade.compareTo(a.averageGrade));
    return allStudents.take(limit).toList();
  }

  /// Get most difficult assignments
  List<AssignmentStats> getMostDifficultAssignments({int limit = 10}) {
    final allAssignments = <AssignmentStats>[];

    for (final analytics in _analyticsCache.values) {
      allAssignments.addAll(analytics.assignmentStats);
    }

    allAssignments.sort((a, b) => a.averageScore.compareTo(b.averageScore));
    return allAssignments.take(limit).toList();
  }

  /// Clear cache
  void clearCache() {
    _analyticsCache.clear();
    _trendsCache.clear();
    _loadingStates.clear();
    _errorStates.clear();
    _selectedClassId = null;
    notifyListeners();
  }

  /// Refresh analytics for a specific class
  Future<void> refreshClassAnalytics(String classId) async {
    await loadClassAnalytics(classId, forceRefresh: true);
  }

  /// Refresh all analytics
  Future<void> refreshAllAnalytics() async {
    final classIds = _analyticsCache.keys.toList();

    for (final classId in classIds) {
      await loadClassAnalytics(classId, forceRefresh: true);
    }
  }

  /// Generate demo trends for testing
  List<GradeTrend> _generateDemoTrends() {
    final random = Random();
    final trends = <GradeTrend>[];
    final baseGrade = 75.0 + random.nextDouble() * 10;

    // Generate trends for the last 30 days
    for (int i = 29; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      // Add some variation to make it realistic
      final variation = (random.nextDouble() - 0.5) * 5;
      final trendValue =
          baseGrade + variation + (29 - i) * 0.1; // Slight upward trend

      trends.add(
        GradeTrend(
          date: date,
          averageGrade: trendValue.clamp(60, 95),
          assignmentCount: random.nextInt(3) + 1,
        ),
      );
    }

    return trends;
  }
}
