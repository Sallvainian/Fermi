/// Grade model for managing student assessment scores and feedback.
///
/// This module contains data models for grades and grade statistics,
/// supporting comprehensive grade management in the education platform.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Enumeration representing the lifecycle states of a grade.
///
/// Each grade progresses through various states:
/// - [draft]: Grade is being prepared but not finalized
/// - [pending]: Awaiting grading (submission received)
/// - [graded]: Grade has been assigned
/// - [returned]: Grade has been shared with student
/// - [revised]: Grade has been updated after initial grading
/// - [notSubmitted]: No submission received (grade placeholder)
enum GradeStatus { draft, pending, graded, returned, revised, notSubmitted }

/// Extension methods for GradeStatus to handle state transitions.
///
/// Provides validation and execution of status transitions following
/// the grading lifecycle rules. Valid transitions are:
/// - draft → pending, graded, notSubmitted
/// - pending → graded, notSubmitted
/// - graded → returned, revised
/// - returned → revised
/// - revised → returned
/// - notSubmitted → pending (if submission received), graded (direct grading)
extension GradeStatusTransition on GradeStatus {
  /// Checks if this status can transition to the target status.
  ///
  /// Validates transitions based on the grading lifecycle rules.
  ///
  /// @param target The desired status to transition to
  /// @return true if the transition is valid, false otherwise
  bool canTransitionTo(GradeStatus target) {
    switch (this) {
      case GradeStatus.draft:
        // Draft can go to pending (submission received), graded (direct grading), or notSubmitted
        return target == GradeStatus.pending ||
            target == GradeStatus.graded ||
            target == GradeStatus.notSubmitted;

      case GradeStatus.pending:
        // Pending can be graded or marked as not submitted
        return target == GradeStatus.graded ||
            target == GradeStatus.notSubmitted;

      case GradeStatus.graded:
        // Graded can be returned to student or revised
        return target == GradeStatus.returned || target == GradeStatus.revised;

      case GradeStatus.returned:
        // Returned grades can be revised
        return target == GradeStatus.revised;

      case GradeStatus.revised:
        // Revised grades can be returned again
        return target == GradeStatus.returned;

      case GradeStatus.notSubmitted:
        // Not submitted can transition to pending (late submission) or graded (override)
        return target == GradeStatus.pending || target == GradeStatus.graded;
    }
  }

  /// Attempts to transition to the target status.
  ///
  /// Returns the target status if the transition is valid,
  /// otherwise returns the current status unchanged.
  ///
  /// @param target The desired status to transition to
  /// @return The resulting status after transition attempt
  GradeStatus transitionTo(GradeStatus target) {
    if (canTransitionTo(target)) {
      return target;
    }
    return this;
  }

  /// Gets a list of valid target statuses from the current status.
  ///
  /// Useful for UI elements that need to show available actions.
  ///
  /// @return List of statuses this status can transition to
  List<GradeStatus> get validTransitions {
    switch (this) {
      case GradeStatus.draft:
        return [
          GradeStatus.pending,
          GradeStatus.graded,
          GradeStatus.notSubmitted,
        ];

      case GradeStatus.pending:
        return [GradeStatus.graded, GradeStatus.notSubmitted];

      case GradeStatus.graded:
        return [GradeStatus.returned, GradeStatus.revised];

      case GradeStatus.returned:
        return [GradeStatus.revised];

      case GradeStatus.revised:
        return [GradeStatus.returned];

      case GradeStatus.notSubmitted:
        return [GradeStatus.pending, GradeStatus.graded];
    }
  }

  /// Gets a human-readable description of invalid transition attempts.
  ///
  /// Useful for providing feedback when a transition is not allowed.
  ///
  /// @param target The attempted target status
  /// @return Error message explaining why the transition is invalid
  String getTransitionError(GradeStatus target) {
    if (canTransitionTo(target)) {
      return '';
    }

    switch (this) {
      case GradeStatus.draft:
        return 'Draft grades can only transition to pending, graded, or not submitted';

      case GradeStatus.pending:
        return 'Pending grades can only be graded or marked as not submitted';

      case GradeStatus.graded:
        return 'Graded work can only be returned to students or revised';

      case GradeStatus.returned:
        return 'Returned grades can only be revised';

      case GradeStatus.revised:
        return 'Revised grades can only be returned to students';

      case GradeStatus.notSubmitted:
        return 'Not submitted status can only transition to pending or graded';
    }
  }

  /// Checks if this status represents a finalized grade.
  ///
  /// Finalized grades are those that have been assigned a score.
  ///
  /// @return true if the grade has been finalized with a score
  bool get isFinalized {
    return this == GradeStatus.graded ||
        this == GradeStatus.returned ||
        this == GradeStatus.revised;
  }

  /// Checks if this status allows editing the grade score.
  ///
  /// Score can be edited in draft, graded, and revised states.
  ///
  /// @return true if the grade score can be modified
  bool get canEditScore {
    return this == GradeStatus.draft ||
        this == GradeStatus.graded ||
        this == GradeStatus.revised;
  }
}

/// Core grade model representing student assessment results.
///
/// This model encapsulates comprehensive grading data including:
/// - Score information (points earned, percentage, letter grade)
/// - Teacher feedback and comments
/// - Rubric-based scoring details
/// - Grade lifecycle tracking
/// - Attachment support for annotated work
///
/// Grades are linked to specific assignments, students, and classes,
/// providing a complete assessment record for academic tracking.
class Grade {
  /// Unique identifier for the grade record
  final String id;

  /// ID of the assignment being graded
  final String assignmentId;

  /// ID of the student receiving the grade
  final String studentId;

  /// Cached student name for display purposes
  final String studentName;

  /// ID of the teacher who assigned the grade
  final String teacherId;

  /// ID of the class this grade belongs to
  final String classId;

  /// Points earned by the student
  final double pointsEarned;

  /// Total points possible for the assignment
  final double pointsPossible;

  /// Calculated percentage score (0-100)
  final double percentage;

  /// Optional letter grade representation (A, B, C, D, F)
  final String? letterGrade;

  /// Teacher's feedback and comments on the submission
  final String? feedback;

  /// Current status in the grading lifecycle
  final GradeStatus status;

  /// Timestamp when the grade was assigned
  final DateTime? gradedAt;

  /// Timestamp when the grade was returned to student
  final DateTime? returnedAt;

  /// Timestamp when the grade record was created
  final DateTime createdAt;

  /// Timestamp of last modification (mutable for updates)
  DateTime updatedAt;

  /// Optional rubric scores as key-value pairs (criterion -> score)
  final Map<String, dynamic>? rubricScores;

  /// URLs to attached files (annotated submissions, feedback docs)
  final List<String>? attachmentUrls;

  Grade({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
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

  /// Factory constructor to create Grade from Firestore document.
  ///
  /// Handles comprehensive data parsing including:
  /// - Timestamp conversions for date fields
  /// - Numeric type casting with safe defaults
  /// - Status enum parsing using enum name matching
  /// - Complex type handling (maps, lists)
  ///
  /// @param doc Firestore document snapshot containing grade data
  /// @return Parsed Grade instance
  factory Grade.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Grade(
      id: doc.id,
      assignmentId: data['assignmentId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
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

  /// Converts the Grade instance to a Map for Firestore storage.
  ///
  /// Serializes all grade data with special handling for:
  /// - DateTime fields to Firestore Timestamps
  /// - Status enum to string using .name property
  /// - Server timestamps for created/updated fields
  /// - Preservation of complex types (maps, lists)
  ///
  /// @return Map containing all grade data for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'assignmentId': assignmentId,
      'studentId': studentId,
      'studentName': studentName,
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

  /// Creates a copy of the Grade with updated fields.
  ///
  /// Follows immutable data pattern for state management.
  /// Useful for:
  /// - Updating scores after revision
  /// - Adding teacher feedback
  /// - Changing grade status
  /// - Attaching rubric scores
  ///
  /// All parameters are optional - only provided fields will be updated.
  ///
  /// @return New Grade instance with updated fields
  Grade copyWith({
    String? id,
    String? assignmentId,
    String? studentId,
    String? studentName,
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
      studentName: studentName ?? this.studentName,
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

  /// Calculates letter grade based on percentage score.
  ///
  /// Uses standard grading scale:
  /// - A: 90% and above
  /// - B: 80-89%
  /// - C: 70-79%
  /// - D: 60-69%
  /// - F: Below 60%
  ///
  /// @param percentage Score as a percentage (0-100)
  /// @return Letter grade (A, B, C, D, or F)
  static String calculateLetterGrade(double percentage) {
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }

  /// Calculates percentage score from points earned and possible.
  ///
  /// Handles division by zero safely by returning 0 when
  /// points possible is 0.
  ///
  /// @param earned Points earned by student
  /// @param possible Total points possible
  /// @return Percentage score (0-100)
  static double calculatePercentage(double earned, double possible) {
    if (possible == 0) return 0;
    return (earned / possible) * 100;
  }
}

/// Statistical analysis model for grade collections.
///
/// This model provides comprehensive statistics for a set of grades,
/// useful for:
/// - Class performance analysis
/// - Student progress tracking
/// - Grade distribution visualization
/// - Academic reporting
///
/// Calculates common statistical measures and provides
/// letter grade distribution for visual representation.
class GradeStatistics {
  /// Average (mean) percentage of all grades
  final double average;

  /// Median percentage (middle value when sorted)
  final double median;

  /// Highest percentage score in the set
  final double highest;

  /// Lowest percentage score in the set
  final double lowest;

  /// Total number of grades analyzed
  final int totalGrades;

  /// Distribution of letter grades (letter -> count)
  final Map<String, int> letterGradeDistribution;

  GradeStatistics({
    required this.average,
    required this.median,
    required this.highest,
    required this.lowest,
    required this.totalGrades,
    required this.letterGradeDistribution,
  });

  /// Factory constructor to calculate statistics from a list of grades.
  ///
  /// Performs comprehensive statistical analysis including:
  /// - Mean calculation
  /// - Median determination (handles even/odd counts)
  /// - Range identification (highest/lowest)
  /// - Letter grade distribution counting
  ///
  /// Returns zero-valued statistics for empty grade lists.
  ///
  /// @param grades List of Grade objects to analyze
  /// @return Calculated GradeStatistics instance
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
      (prev, grade) => prev + grade.percentage,
    );
    final average = sum / grades.length;

    // Calculate median
    final middle = grades.length ~/ 2;
    final median = grades.length % 2 == 0
        ? (sortedGrades[middle - 1].percentage +
                  sortedGrades[middle].percentage) /
              2
        : sortedGrades[middle].percentage;

    // Get highest and lowest
    final highest = sortedGrades.last.percentage;
    final lowest = sortedGrades.first.percentage;

    // Count letter grades
    final letterGradeDistribution = <String, int>{};
    for (final grade in grades) {
      final letter =
          grade.letterGrade ?? Grade.calculateLetterGrade(grade.percentage);
      letterGradeDistribution[letter] =
          (letterGradeDistribution[letter] ?? 0) + 1;
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
