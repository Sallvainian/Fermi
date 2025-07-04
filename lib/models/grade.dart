import 'package:cloud_firestore/cloud_firestore.dart';

enum GradeStatus {
  draft,
  pending,
  graded,
  returned,
  revised
}

class Grade {
  final String id;
  final String assignmentId;
  final String studentId;
  final String teacherId;
  final String classId;
  final double pointsEarned;
  final double pointsPossible;
  final double percentage;
  final String? letterGrade;
  final String? feedback;
  final GradeStatus status;
  final DateTime? gradedAt;
  final DateTime? returnedAt;
  final DateTime createdAt;
  DateTime updatedAt;
  final Map<String, dynamic>? rubricScores;
  final List<String>? attachmentUrls;

  Grade({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.teacherId,
    required this.classId,
    required this.pointsEarned,
    required this.pointsPossible,
    required this.percentage,
    this.letterGrade,
    this.feedback,
    required this.status,
    this.gradedAt,
    this.returnedAt,
    required this.createdAt,
    required this.updatedAt,
    this.rubricScores,
    this.attachmentUrls,
  });

  factory Grade.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Grade(
      id: doc.id,
      assignmentId: data['assignmentId'] ?? '',
      studentId: data['studentId'] ?? '',
      teacherId: data['teacherId'] ?? '',
      classId: data['classId'] ?? '',
      pointsEarned: (data['pointsEarned'] ?? 0).toDouble(),
      pointsPossible: (data['pointsPossible'] ?? 0).toDouble(),
      percentage: (data['percentage'] ?? 0).toDouble(),
      letterGrade: data['letterGrade'],
      feedback: data['feedback'],
      status: GradeStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => GradeStatus.pending,
      ),
      gradedAt: data['gradedAt'] != null 
          ? (data['gradedAt'] as Timestamp).toDate() 
          : null,
      returnedAt: data['returnedAt'] != null 
          ? (data['returnedAt'] as Timestamp).toDate() 
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      rubricScores: data['rubricScores'] as Map<String, dynamic>?,
      attachmentUrls: data['attachmentUrls'] != null 
          ? List<String>.from(data['attachmentUrls']) 
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'assignmentId': assignmentId,
      'studentId': studentId,
      'teacherId': teacherId,
      'classId': classId,
      'pointsEarned': pointsEarned,
      'pointsPossible': pointsPossible,
      'percentage': percentage,
      'letterGrade': letterGrade,
      'feedback': feedback,
      'status': status.name,
      'gradedAt': gradedAt != null ? Timestamp.fromDate(gradedAt!) : null,
      'returnedAt': returnedAt != null ? Timestamp.fromDate(returnedAt!) : null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'rubricScores': rubricScores,
      'attachmentUrls': attachmentUrls,
    };
  }

  Grade copyWith({
    String? id,
    String? assignmentId,
    String? studentId,
    String? teacherId,
    String? classId,
    double? pointsEarned,
    double? pointsPossible,
    double? percentage,
    String? letterGrade,
    String? feedback,
    GradeStatus? status,
    DateTime? gradedAt,
    DateTime? returnedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? rubricScores,
    List<String>? attachmentUrls,
  }) {
    return Grade(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      classId: classId ?? this.classId,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      pointsPossible: pointsPossible ?? this.pointsPossible,
      percentage: percentage ?? this.percentage,
      letterGrade: letterGrade ?? this.letterGrade,
      feedback: feedback ?? this.feedback,
      status: status ?? this.status,
      gradedAt: gradedAt ?? this.gradedAt,
      returnedAt: returnedAt ?? this.returnedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rubricScores: rubricScores ?? this.rubricScores,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
    );
  }

  // Calculate letter grade based on percentage
  static String calculateLetterGrade(double percentage) {
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }

  // Calculate percentage from points
  static double calculatePercentage(double earned, double possible) {
    if (possible == 0) return 0;
    return (earned / possible) * 100;
  }
}

// Grade statistics for a class or student
class GradeStatistics {
  final double average;
  final double median;
  final double highest;
  final double lowest;
  final int totalGrades;
  final Map<String, int> letterGradeDistribution;

  GradeStatistics({
    required this.average,
    required this.median,
    required this.highest,
    required this.lowest,
    required this.totalGrades,
    required this.letterGradeDistribution,
  });

  factory GradeStatistics.fromGrades(List<Grade> grades) {
    if (grades.isEmpty) {
      return GradeStatistics(
        average: 0,
        median: 0,
        highest: 0,
        lowest: 0,
        totalGrades: 0,
        letterGradeDistribution: {},
      );
    }

    // Sort grades by percentage
    final sortedGrades = List<Grade>.from(grades)
      ..sort((a, b) => a.percentage.compareTo(b.percentage));

    // Calculate average
    final sum = grades.fold<double>(
      0, 
      (prev, grade) => prev + grade.percentage
    );
    final average = sum / grades.length;

    // Calculate median
    final middle = grades.length ~/ 2;
    final median = grades.length % 2 == 0
        ? (sortedGrades[middle - 1].percentage + sortedGrades[middle].percentage) / 2
        : sortedGrades[middle].percentage;

    // Get highest and lowest
    final highest = sortedGrades.last.percentage;
    final lowest = sortedGrades.first.percentage;

    // Count letter grades
    final letterGradeDistribution = <String, int>{};
    for (final grade in grades) {
      final letter = grade.letterGrade ?? Grade.calculateLetterGrade(grade.percentage);
      letterGradeDistribution[letter] = (letterGradeDistribution[letter] ?? 0) + 1;
    }

    return GradeStatistics(
      average: average,
      median: median,
      highest: highest,
      lowest: lowest,
      totalGrades: grades.length,
      letterGradeDistribution: letterGradeDistribution,
    );
  }
}