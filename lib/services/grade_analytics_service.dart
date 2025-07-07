import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grade_analytics.dart';
import '../models/grade.dart';
import '../models/assignment.dart';
import '../models/student.dart';
import '../models/submission.dart';

class GradeAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate analytics for a specific class
  Future<GradeAnalytics> generateClassAnalytics(String classId) async {
    // Demo data for testing
    if (classId.startsWith('math-') || classId.startsWith('sci-') || 
        classId.startsWith('eng-') || classId.startsWith('hist-')) {
      return _generateDemoAnalytics(classId);
    }
    try {
      // Get class info
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (!classDoc.exists) {
        throw Exception('Class not found');
      }
      final className = classDoc.data()?['name'] ?? 'Unknown Class';

      // Get all assignments for the class
      final assignmentsSnapshot = await _firestore
          .collection('assignments')
          .where('classId', isEqualTo: classId)
          .get();

      final assignments = assignmentsSnapshot.docs
          .map((doc) => Assignment.fromFirestore(doc))
          .toList();

      // Get all students in the class
      final studentIds = List<String>.from(classDoc.data()?['students'] ?? []);
      final students = <Student>[];
      
      for (final studentId in studentIds) {
        final studentDoc = await _firestore.collection('users').doc(studentId).get();
        if (studentDoc.exists) {
          students.add(Student.fromFirestore(studentDoc));
        }
      }

      // Get all submissions and grades
      final allGrades = <Grade>[];
      final submissionsByStudent = <String, List<Submission>>{};
      final gradesByStudent = <String, List<Grade>>{};

      for (final assignment in assignments) {
        final submissionsSnapshot = await _firestore
            .collection('submissions')
            .where('assignmentId', isEqualTo: assignment.id)
            .get();

        for (final submissionDoc in submissionsSnapshot.docs) {
          final submission = Submission.fromFirestore(submissionDoc);
          final studentId = submission.studentId;
          
          submissionsByStudent[studentId] ??= [];
          submissionsByStudent[studentId]!.add(submission);

          // Get grade if exists
          final gradeSnapshot = await submissionDoc.reference
              .collection('grades')
              .orderBy('gradedAt', descending: true)
              .limit(1)
              .get();

          if (gradeSnapshot.docs.isNotEmpty) {
            final grade = Grade.fromFirestore(gradeSnapshot.docs.first);
            allGrades.add(grade);
            gradesByStudent[studentId] ??= [];
            gradesByStudent[studentId]!.add(grade);
          }
        }
      }

      // Calculate analytics
      final analytics = _calculateAnalytics(
        classId: classId,
        className: className,
        assignments: assignments,
        students: students,
        allGrades: allGrades,
        submissionsByStudent: submissionsByStudent,
        gradesByStudent: gradesByStudent,
      );

      return analytics;
    } catch (e) {
      throw Exception('Failed to generate analytics: $e');
    }
  }

  /// Calculate analytics from raw data
  GradeAnalytics _calculateAnalytics({
    required String classId,
    required String className,
    required List<Assignment> assignments,
    required List<Student> students,
    required List<Grade> allGrades,
    required Map<String, List<Submission>> submissionsByStudent,
    required Map<String, List<Grade>> gradesByStudent,
  }) {
    // Calculate overall statistics
    final gradeValues = allGrades.map((g) => g.percentage).toList();
    final averageGrade = gradeValues.isEmpty ? 0.0 : 
        gradeValues.reduce((a, b) => a + b) / gradeValues.length;
    
    final medianGrade = _calculateMedian(gradeValues);
    
    // Calculate grade distribution
    final gradeDistribution = _calculateGradeDistribution(gradeValues);
    
    // Calculate category averages
    final categoryAverages = _calculateCategoryAverages(assignments, allGrades);
    
    // Calculate student performances
    final studentPerformances = _calculateStudentPerformances(
      students: students,
      assignments: assignments,
      submissionsByStudent: submissionsByStudent,
      gradesByStudent: gradesByStudent,
    );
    
    // Calculate assignment statistics
    final assignmentStats = _calculateAssignmentStats(
      assignments: assignments,
      allGrades: allGrades,
      submissionsByStudent: submissionsByStudent,
    );

    // Count pending submissions
    int pendingSubmissions = 0;
    for (final submissions in submissionsByStudent.values) {
      pendingSubmissions += submissions.where((s) => 
        s.status == SubmissionStatus.submitted && 
        !gradesByStudent.containsKey(s.studentId)
      ).length;
    }

    return GradeAnalytics(
      classId: classId,
      className: className,
      averageGrade: averageGrade,
      medianGrade: medianGrade,
      totalAssignments: assignments.length,
      gradedAssignments: allGrades.length,
      pendingSubmissions: pendingSubmissions,
      gradeDistribution: gradeDistribution,
      categoryAverages: categoryAverages,
      studentPerformances: studentPerformances,
      assignmentStats: assignmentStats,
      lastUpdated: DateTime.now(),
    );
  }

  /// Calculate median value
  double _calculateMedian(List<double> values) {
    if (values.isEmpty) return 0;
    
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    
    if (sorted.length % 2 == 0) {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    } else {
      return sorted[middle];
    }
  }

  /// Calculate grade distribution (A, B, C, etc.)
  Map<String, int> _calculateGradeDistribution(List<double> gradeValues) {
    final distribution = <String, int>{
      'A': 0, 'A-': 0, 'B+': 0, 'B': 0, 'B-': 0,
      'C+': 0, 'C': 0, 'C-': 0, 'D+': 0, 'D': 0, 'D-': 0, 'F': 0,
    };

    for (final grade in gradeValues) {
      final letterGrade = _getLetterGrade(grade);
      distribution[letterGrade] = (distribution[letterGrade] ?? 0) + 1;
    }

    return distribution;
  }

  /// Get letter grade from percentage
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

  /// Calculate average grades by category
  Map<String, double> _calculateCategoryAverages(
    List<Assignment> assignments,
    List<Grade> grades,
  ) {
    final categoryGrades = <String, List<double>>{};
    
    for (final grade in grades) {
      final assignment = assignments.firstWhere(
        (a) => a.id == grade.assignmentId,
        orElse: () => assignments.first,
      );
      
      categoryGrades[assignment.category] ??= [];
      categoryGrades[assignment.category]!.add(grade.percentage);
    }
    
    final categoryAverages = <String, double>{};
    categoryGrades.forEach((category, grades) {
      if (grades.isNotEmpty) {
        categoryAverages[category] = grades.reduce((a, b) => a + b) / grades.length;
      }
    });
    
    return categoryAverages;
  }

  /// Calculate individual student performances
  List<StudentPerformance> _calculateStudentPerformances({
    required List<Student> students,
    required List<Assignment> assignments,
    required Map<String, List<Submission>> submissionsByStudent,
    required Map<String, List<Grade>> gradesByStudent,
  }) {
    final performances = <StudentPerformance>[];
    
    for (final student in students) {
      final studentGrades = gradesByStudent[student.id] ?? [];
      final studentSubmissions = submissionsByStudent[student.id] ?? [];
      
      if (studentGrades.isEmpty && studentSubmissions.isEmpty) continue;
      
      // Calculate average grade
      final gradeValues = studentGrades.map((g) => g.percentage).toList();
      final averageGrade = gradeValues.isEmpty ? 0.0 :
          gradeValues.reduce((a, b) => a + b) / gradeValues.length;
      
      // Count missing assignments
      final submittedAssignmentIds = studentSubmissions.map((s) => s.assignmentId).toSet();
      final missingAssignments = assignments.where((a) => 
        !submittedAssignmentIds.contains(a.id) &&
        a.dueDate.isBefore(DateTime.now())
      ).length;
      
      // Count late submissions
      final lateSubmissions = studentSubmissions.where((s) {
        final assignment = assignments.firstWhere(
          (a) => a.id == s.assignmentId,
          orElse: () => assignments.first,
        );
        return s.submittedAt.isAfter(assignment.dueDate);
      }).length;
      
      // Calculate category scores
      final categoryScores = _calculateStudentCategoryScores(
        studentGrades,
        assignments,
      );
      
      // Calculate trend (simplified - comparing last 3 grades to overall average)
      final trend = _calculateStudentTrend(studentGrades);
      
      performances.add(StudentPerformance(
        studentId: student.id,
        studentName: student.displayName,
        averageGrade: averageGrade,
        completedAssignments: studentGrades.length,
        missingAssignments: missingAssignments,
        lateSubmissions: lateSubmissions,
        categoryScores: categoryScores,
        trend: trend,
        letterGrade: _getLetterGrade(averageGrade),
      ));
    }
    
    return performances;
  }

  /// Calculate student's average score by category
  Map<String, double> _calculateStudentCategoryScores(
    List<Grade> grades,
    List<Assignment> assignments,
  ) {
    final categoryGrades = <String, List<double>>{};
    
    for (final grade in grades) {
      final assignment = assignments.firstWhere(
        (a) => a.id == grade.assignmentId,
        orElse: () => assignments.first,
      );
      
      categoryGrades[assignment.category] ??= [];
      categoryGrades[assignment.category]!.add(grade.percentage);
    }
    
    final categoryScores = <String, double>{};
    categoryGrades.forEach((category, grades) {
      if (grades.isNotEmpty) {
        categoryScores[category] = grades.reduce((a, b) => a + b) / grades.length;
      }
    });
    
    return categoryScores;
  }

  /// Calculate student's grade trend
  double _calculateStudentTrend(List<Grade> grades) {
    if (grades.length < 2) return 0;
    
    // Sort by date, filtering out grades without gradedAt
    final sortedGrades = List<Grade>.from(
      grades.where((g) => g.gradedAt != null)
    )..sort((a, b) => a.gradedAt!.compareTo(b.gradedAt!));
    
    // Compare last 3 grades to first 3 grades
    final recentCount = sortedGrades.length < 3 ? sortedGrades.length : 3;
    final earlyCount = sortedGrades.length < 3 ? sortedGrades.length : 3;
    
    final recentAvg = sortedGrades
        .skip(sortedGrades.length - recentCount)
        .map((g) => g.percentage)
        .reduce((a, b) => a + b) / recentCount;
    
    final earlyAvg = sortedGrades
        .take(earlyCount)
        .map((g) => g.percentage)
        .reduce((a, b) => a + b) / earlyCount;
    
    return recentAvg - earlyAvg;
  }

  /// Calculate assignment statistics
  List<AssignmentStats> _calculateAssignmentStats({
    required List<Assignment> assignments,
    required List<Grade> allGrades,
    required Map<String, List<Submission>> submissionsByStudent,
  }) {
    final stats = <AssignmentStats>[];
    
    for (final assignment in assignments) {
      final assignmentGrades = allGrades
          .where((g) => g.assignmentId == assignment.id)
          .toList();
      
      if (assignmentGrades.isEmpty) continue;
      
      final scores = assignmentGrades.map((g) => g.percentage).toList();
      final averageScore = scores.reduce((a, b) => a + b) / scores.length;
      final medianScore = _calculateMedian(scores);
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final minScore = scores.reduce((a, b) => a < b ? a : b);
      
      // Count total submissions for this assignment
      int totalSubmissions = 0;
      for (final submissions in submissionsByStudent.values) {
        totalSubmissions += submissions
            .where((s) => s.assignmentId == assignment.id)
            .length;
      }
      
      // Calculate score distribution
      final scoreDistribution = _calculateScoreDistribution(scores);
      
      stats.add(AssignmentStats(
        assignmentId: assignment.id,
        assignmentTitle: assignment.title,
        category: assignment.category,
        averageScore: averageScore,
        medianScore: medianScore,
        maxScore: maxScore,
        minScore: minScore,
        totalSubmissions: totalSubmissions,
        gradedSubmissions: assignmentGrades.length,
        dueDate: assignment.dueDate,
        scoreDistribution: scoreDistribution,
      ));
    }
    
    return stats;
  }

  /// Calculate score distribution for an assignment
  Map<String, int> _calculateScoreDistribution(List<double> scores) {
    final distribution = <String, int>{
      '90-100': 0,
      '80-89': 0,
      '70-79': 0,
      '60-69': 0,
      '0-59': 0,
    };
    
    for (final score in scores) {
      if (score >= 90) {
        distribution['90-100'] = (distribution['90-100'] ?? 0) + 1;
      } else if (score >= 80) {
        distribution['80-89'] = (distribution['80-89'] ?? 0) + 1;
      } else if (score >= 70) {
        distribution['70-79'] = (distribution['70-79'] ?? 0) + 1;
      } else if (score >= 60) {
        distribution['60-69'] = (distribution['60-69'] ?? 0) + 1;
      } else {
        distribution['0-59'] = (distribution['0-59'] ?? 0) + 1;
      }
    }
    
    return distribution;
  }

  /// Get grade trends over time for a class
  Future<List<GradeTrend>> getGradeTrends(String classId, {int days = 30}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    
    final gradesSnapshot = await _firestore
        .collectionGroup('grades')
        .where('classId', isEqualTo: classId)
        .where('gradedAt', isGreaterThanOrEqualTo: startDate)
        .orderBy('gradedAt')
        .get();
    
    final gradesByDate = <DateTime, List<double>>{};
    
    for (final doc in gradesSnapshot.docs) {
      final grade = Grade.fromFirestore(doc);
      if (grade.gradedAt == null) continue;
      
      final dateKey = DateTime(
        grade.gradedAt!.year,
        grade.gradedAt!.month,
        grade.gradedAt!.day,
      );
      
      gradesByDate[dateKey] ??= [];
      gradesByDate[dateKey]!.add(grade.percentage);
    }
    
    final trends = <GradeTrend>[];
    gradesByDate.forEach((date, grades) {
      final average = grades.reduce((a, b) => a + b) / grades.length;
      trends.add(GradeTrend(
        date: date,
        averageGrade: average,
        assignmentCount: grades.length,
      ));
    });
    
    return trends;
  }
  
  /// Generate demo analytics for testing
  GradeAnalytics _generateDemoAnalytics(String classId) {
    final random = Random();
    final className = _getClassNameFromId(classId);
    
    // Generate student performances
    final studentPerformances = List.generate(15, (index) {
      final avgGrade = 65 + random.nextDouble() * 35; // 65-100
      return StudentPerformance(
        studentId: 'student-$index',
        studentName: 'Student ${index + 1}',
        averageGrade: avgGrade,
        completedAssignments: 8 + random.nextInt(5),
        missingAssignments: random.nextInt(3),
        lateSubmissions: random.nextInt(2),
        categoryScores: {
          'Homework': avgGrade + random.nextDouble() * 10 - 5,
          'Quizzes': avgGrade + random.nextDouble() * 10 - 5,
          'Tests': avgGrade + random.nextDouble() * 10 - 5,
          'Projects': avgGrade + random.nextDouble() * 10 - 5,
        },
        trend: random.nextDouble() * 10 - 5, // -5 to +5
        letterGrade: _getLetterGrade(avgGrade),
      );
    });
    
    // Generate assignment stats
    final assignmentStats = List.generate(10, (index) {
      final avgScore = 70 + random.nextDouble() * 20;
      return AssignmentStats(
        assignmentId: 'assignment-$index',
        assignmentTitle: 'Assignment ${index + 1}',
        category: ['Homework', 'Quiz', 'Test', 'Project'][random.nextInt(4)],
        averageScore: avgScore,
        medianScore: avgScore + random.nextDouble() * 5 - 2.5,
        maxScore: 95 + random.nextDouble() * 5,
        minScore: 50 + random.nextDouble() * 20,
        totalSubmissions: 15,
        gradedSubmissions: 13 + random.nextInt(3),
        dueDate: DateTime.now().subtract(Duration(days: random.nextInt(30))),
        scoreDistribution: {
          'A': random.nextInt(5),
          'B': random.nextInt(5),
          'C': random.nextInt(4),
          'D': random.nextInt(2),
          'F': random.nextInt(2),
        },
      );
    });
    
    // Calculate averages
    final overallAvg = studentPerformances.map((s) => s.averageGrade)
        .reduce((a, b) => a + b) / studentPerformances.length;
    
    return GradeAnalytics(
      classId: classId,
      className: className,
      averageGrade: overallAvg,
      medianGrade: overallAvg - 2, // Simplified
      totalAssignments: 12,
      gradedAssignments: 10,
      pendingSubmissions: 8,
      gradeDistribution: {
        'A': 3,
        'B': 5,
        'C': 4,
        'D': 2,
        'F': 1,
      },
      categoryAverages: {
        'Homework': overallAvg + 2,
        'Quizzes': overallAvg - 1,
        'Tests': overallAvg - 3,
        'Projects': overallAvg + 1,
      },
      studentPerformances: studentPerformances,
      assignmentStats: assignmentStats,
      lastUpdated: DateTime.now(),
    );
  }
  
  String _getClassNameFromId(String classId) {
    final classNames = {
      'math-101': 'Mathematics 101',
      'sci-202': 'Science 202',
      'eng-303': 'English 303',
      'hist-404': 'History 404',
    };
    return classNames[classId] ?? 'Unknown Class';
  }
}