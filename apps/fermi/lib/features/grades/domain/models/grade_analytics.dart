/// Analytics data for grades
class GradeAnalytics {
  final String classId;
  final String className;
  final double averageGrade;
  final double medianGrade;
  final int totalAssignments;
  final int gradedAssignments;
  final int pendingSubmissions;
  final Map<String, int> gradeDistribution; // A: count, B: count, etc.
  final Map<String, double> categoryAverages; // homework: avg, quiz: avg, etc.
  final List<StudentPerformance> studentPerformances;
  final List<AssignmentStats> assignmentStats;
  final DateTime lastUpdated;

  GradeAnalytics({
    required this.classId,
    required this.className,
    required this.averageGrade,
    required this.medianGrade,
    required this.totalAssignments,
    required this.gradedAssignments,
    required this.pendingSubmissions,
    required this.gradeDistribution,
    required this.categoryAverages,
    required this.studentPerformances,
    required this.assignmentStats,
    required this.lastUpdated,
  });

  /// Get grade distribution as percentages
  Map<String, double> get gradeDistributionPercentages {
    final total = gradeDistribution.values.fold(0, (sum, count) => sum + count);
    if (total == 0) return {};

    return gradeDistribution
        .map((grade, count) => MapEntry(grade, (count / total) * 100));
  }

  /// Get completion rate
  double get completionRate {
    if (totalAssignments == 0) return 0;
    return (gradedAssignments / totalAssignments) * 100;
  }

  /// Get letter grade for average
  String get averageLetterGrade => _getLetterGrade(averageGrade);

  /// Convert numeric grade to letter grade
  String _getLetterGrade(double grade) {
    if (grade >= 93) return 'A';
    if (grade >= 90) return 'A-';
    if (grade >= 87) return 'B+';
    if (grade >= 83) return 'B';
    if (grade >= 80) return 'B-';
    if (grade >= 77) return 'C+';
    if (grade >= 73) return 'C';
    if (grade >= 70) return 'C-';
    if (grade >= 67) return 'D+';
    if (grade >= 63) return 'D';
    if (grade >= 60) return 'D-';
    return 'F';
  }
}

/// Individual student performance data
class StudentPerformance {
  final String studentId;
  final String studentName;
  final double averageGrade;
  final int completedAssignments;
  final int missingAssignments;
  final int lateSubmissions;
  final Map<String, double> categoryScores; // category -> average score
  final double trend; // positive or negative trend
  final String letterGrade;

  StudentPerformance({
    required this.studentId,
    required this.studentName,
    required this.averageGrade,
    required this.completedAssignments,
    required this.missingAssignments,
    required this.lateSubmissions,
    required this.categoryScores,
    required this.trend,
    required this.letterGrade,
  });

  /// Risk level for student (at-risk, warning, good)
  String get riskLevel {
    if (averageGrade < 60 || missingAssignments > 3) return 'at-risk';
    if (averageGrade < 70 || missingAssignments > 1) return 'warning';
    return 'good';
  }

  /// Performance compared to class average
  String getPerformanceVsClass(double classAverage) {
    final diff = averageGrade - classAverage;
    if (diff > 5) return 'above';
    if (diff < -5) return 'below';
    return 'average';
  }
}

/// Statistics for individual assignments
class AssignmentStats {
  final String assignmentId;
  final String assignmentTitle;
  final String category;
  final double averageScore;
  final double medianScore;
  final double maxScore;
  final double minScore;
  final int totalSubmissions;
  final int gradedSubmissions;
  final DateTime dueDate;
  final Map<String, int> scoreDistribution; // score ranges -> count

  AssignmentStats({
    required this.assignmentId,
    required this.assignmentTitle,
    required this.category,
    required this.averageScore,
    required this.medianScore,
    required this.maxScore,
    required this.minScore,
    required this.totalSubmissions,
    required this.gradedSubmissions,
    required this.dueDate,
    required this.scoreDistribution,
  });

  /// Completion rate for this assignment
  double get completionRate {
    if (totalSubmissions == 0) return 0;
    return (gradedSubmissions / totalSubmissions) * 100;
  }

  /// Difficulty level based on average score
  String get difficultyLevel {
    if (averageScore >= 85) return 'easy';
    if (averageScore >= 70) return 'medium';
    return 'hard';
  }
}

/// Time-based grade trends
class GradeTrend {
  final DateTime date;
  final double averageGrade;
  final int assignmentCount;

  GradeTrend({
    required this.date,
    required this.averageGrade,
    required this.assignmentCount,
  });
}

/// Category performance breakdown
class CategoryPerformance {
  final String category;
  final double averageScore;
  final int assignmentCount;
  final double weight; // percentage weight in final grade

  CategoryPerformance({
    required this.category,
    required this.averageScore,
    required this.assignmentCount,
    required this.weight,
  });

  /// Weighted score contribution
  double get weightedScore => averageScore * (weight / 100);
}
