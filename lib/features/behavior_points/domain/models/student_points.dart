/// Student points model for aggregating and tracking student behavior point totals.
///
/// This module contains the data model for student point summaries,
/// providing aggregated views of student behavior performance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'behavior_point.dart';

/// Core student points model representing aggregated behavior point data.
///
/// Student points provide a comprehensive view of a student's behavior
/// performance, including:
/// - Total point calculations (positive, negative, overall)
/// - Recent behavior history for context
/// - Visual representation through avatar colors
/// - Performance trends and analytics
/// - Quick access to recent behavior patterns
///
/// This model is typically used for dashboards, leaderboards,
/// and student behavior reports.
class StudentPoints {
  /// ID of the student these points belong to
  final String studentId;

  /// Cached name of the student for display purposes
  final String studentName;

  /// Total points accumulated by the student
  final int totalPoints;

  /// Total positive points earned by the student
  final int positivePoints;

  /// Total negative points (point deductions) for the student
  final int negativePoints;

  /// List of recent behavior points for context and trends
  final List<BehaviorPoint> recentBehaviors;

  /// Avatar color representing the student's current performance level
  final Color avatarColor;

  /// Timestamp when these points were last calculated/updated
  final DateTime lastUpdated;

  /// ID of the class these points are associated with
  final String classId;

  /// Optional rank of the student within their class (1 = highest points)
  final int? classRank;

  /// Total number of positive behavior instances
  final int positiveBehaviorCount;

  /// Total number of negative behavior instances
  final int negativeBehaviorCount;

  StudentPoints({
    required this.studentId,
    required this.studentName,
    required this.totalPoints,
    required this.positivePoints,
    required this.negativePoints,
    required this.recentBehaviors,
    required this.avatarColor,
    required this.lastUpdated,
    required this.classId,
    this.classRank,
    required this.positiveBehaviorCount,
    required this.negativeBehaviorCount,
  });

  /// Factory constructor to create StudentPoints from Firestore document.
  ///
  /// Handles data parsing including:
  /// - Timestamp to DateTime conversions
  /// - Color conversion from hex string
  /// - Recent behaviors list deserialization
  /// - Null safety for optional fields
  /// - Default values for missing data
  ///
  /// @param doc Firestore document snapshot containing student points data
  /// @return Parsed StudentPoints instance
  factory StudentPoints.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse recent behaviors list
    final recentBehaviorsData = data['recentBehaviors'] as List<dynamic>? ?? [];
    final recentBehaviors = recentBehaviorsData
        .map((item) => BehaviorPoint.fromMap('', item as Map<String, dynamic>))
        .toList();

    // Parse avatar color from hex string
    final colorHex = data['avatarColorHex'] as String?;
    Color avatarColor = Colors.blue; // default color
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        avatarColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      } catch (e) {
        avatarColor = Colors.blue; // fallback to default
      }
    }

    return StudentPoints(
      studentId: doc.id,
      studentName: data['studentName'] ?? '',
      totalPoints: data['totalPoints'] ?? 0,
      positivePoints: data['positivePoints'] ?? 0,
      negativePoints: data['negativePoints'] ?? 0,
      recentBehaviors: recentBehaviors,
      avatarColor: avatarColor,
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      classId: data['classId'] ?? '',
      classRank: data['classRank'],
      positiveBehaviorCount: data['positiveBehaviorCount'] ?? 0,
      negativeBehaviorCount: data['negativeBehaviorCount'] ?? 0,
    );
  }

  /// Alternative factory constructor to create StudentPoints from Map data.
  ///
  /// @param studentId Student identifier
  /// @param data Map containing student points fields
  /// @return Parsed StudentPoints instance
  factory StudentPoints.fromMap(String studentId, Map<String, dynamic> data) {
    // Parse recent behaviors list
    final recentBehaviorsData = data['recentBehaviors'] as List<dynamic>? ?? [];
    final recentBehaviors = recentBehaviorsData
        .map((item) => BehaviorPoint.fromMap('', item as Map<String, dynamic>))
        .toList();

    // Parse avatar color from hex string
    final colorHex = data['avatarColorHex'] as String?;
    Color avatarColor = Colors.blue; // default color
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        avatarColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      } catch (e) {
        avatarColor = Colors.blue; // fallback to default
      }
    }

    return StudentPoints(
      studentId: studentId,
      studentName: data['studentName'] ?? '',
      totalPoints: data['totalPoints'] ?? 0,
      positivePoints: data['positivePoints'] ?? 0,
      negativePoints: data['negativePoints'] ?? 0,
      recentBehaviors: recentBehaviors,
      avatarColor: avatarColor,
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      classId: data['classId'] ?? '',
      classRank: data['classRank'],
      positiveBehaviorCount: data['positiveBehaviorCount'] ?? 0,
      negativeBehaviorCount: data['negativeBehaviorCount'] ?? 0,
    );
  }

  /// Converts the StudentPoints instance to a Map for Firestore storage.
  ///
  /// Serializes all student points data including:
  /// - DateTime fields to Firestore Timestamps
  /// - Color to hex string representation
  /// - Recent behaviors list serialization
  /// - All calculated totals and counts
  ///
  /// @return Map containing all student points data ready for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'studentName': studentName,
      'totalPoints': totalPoints,
      'positivePoints': positivePoints,
      'negativePoints': negativePoints,
      'recentBehaviors': recentBehaviors
          .map((behavior) => behavior.toFirestore())
          .toList(),
      'avatarColorHex': '#${avatarColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'classId': classId,
      'classRank': classRank,
      'positiveBehaviorCount': positiveBehaviorCount,
      'negativeBehaviorCount': negativeBehaviorCount,
    };
  }

  /// Converts the StudentPoints instance to a JSON-compatible Map.
  ///
  /// Similar to toFirestore but uses ISO string format for timestamps,
  /// making it suitable for JSON serialization and API responses.
  ///
  /// @return Map containing student points data in JSON format
  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'totalPoints': totalPoints,
      'positivePoints': positivePoints,
      'negativePoints': negativePoints,
      'recentBehaviors': recentBehaviors
          .map((behavior) => behavior.toJson())
          .toList(),
      'avatarColorHex': '#${avatarColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'lastUpdated': lastUpdated.toIso8601String(),
      'classId': classId,
      'classRank': classRank,
      'positiveBehaviorCount': positiveBehaviorCount,
      'negativeBehaviorCount': negativeBehaviorCount,
    };
  }

  /// Creates a StudentPoints from JSON data.
  ///
  /// @param json Map containing student points data in JSON format
  /// @return Parsed StudentPoints instance
  factory StudentPoints.fromJson(Map<String, dynamic> json) {
    // Parse recent behaviors list
    final recentBehaviorsData = json['recentBehaviors'] as List<dynamic>? ?? [];
    final recentBehaviors = recentBehaviorsData
        .map((item) => BehaviorPoint.fromJson(item as Map<String, dynamic>))
        .toList();

    // Parse avatar color from hex string
    final colorHex = json['avatarColorHex'] as String?;
    Color avatarColor = Colors.blue; // default color
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        avatarColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      } catch (e) {
        avatarColor = Colors.blue; // fallback to default
      }
    }

    return StudentPoints(
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      totalPoints: json['totalPoints'] ?? 0,
      positivePoints: json['positivePoints'] ?? 0,
      negativePoints: json['negativePoints'] ?? 0,
      recentBehaviors: recentBehaviors,
      avatarColor: avatarColor,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
      classId: json['classId'] ?? '',
      classRank: json['classRank'],
      positiveBehaviorCount: json['positiveBehaviorCount'] ?? 0,
      negativeBehaviorCount: json['negativeBehaviorCount'] ?? 0,
    );
  }

  /// Creates a copy of the StudentPoints with updated fields.
  ///
  /// Follows the immutable data pattern, allowing selective field updates
  /// while preserving all other values. Useful for:
  /// - Updating point totals after new behavior points
  /// - Refreshing recent behaviors list
  /// - Updating class rankings
  /// - Changing avatar colors based on performance
  ///
  /// All parameters are optional - only provided fields will be updated.
  ///
  /// @return New StudentPoints instance with updated fields
  StudentPoints copyWith({
    String? studentId,
    String? studentName,
    int? totalPoints,
    int? positivePoints,
    int? negativePoints,
    List<BehaviorPoint>? recentBehaviors,
    Color? avatarColor,
    DateTime? lastUpdated,
    String? classId,
    int? classRank,
    int? positiveBehaviorCount,
    int? negativeBehaviorCount,
  }) {
    return StudentPoints(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      totalPoints: totalPoints ?? this.totalPoints,
      positivePoints: positivePoints ?? this.positivePoints,
      negativePoints: negativePoints ?? this.negativePoints,
      recentBehaviors: recentBehaviors ?? this.recentBehaviors,
      avatarColor: avatarColor ?? this.avatarColor,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      classId: classId ?? this.classId,
      classRank: classRank ?? this.classRank,
      positiveBehaviorCount: positiveBehaviorCount ?? this.positiveBehaviorCount,
      negativeBehaviorCount: negativeBehaviorCount ?? this.negativeBehaviorCount,
    );
  }

  /// Gets the total number of behavior instances (positive + negative)
  int get totalBehaviorCount => positiveBehaviorCount + negativeBehaviorCount;

  /// Gets the percentage of positive behaviors out of total behaviors
  double get positiveBehaviorPercentage {
    if (totalBehaviorCount == 0) return 0.0;
    return (positiveBehaviorCount / totalBehaviorCount) * 100;
  }

  /// Gets the percentage of negative behaviors out of total behaviors
  double get negativeBehaviorPercentage {
    if (totalBehaviorCount == 0) return 0.0;
    return (negativeBehaviorCount / totalBehaviorCount) * 100;
  }

  /// Gets a performance level based on total points
  String get performanceLevel {
    if (totalPoints >= 50) return 'Excellent';
    if (totalPoints >= 25) return 'Good';
    if (totalPoints >= 0) return 'Satisfactory';
    if (totalPoints >= -25) return 'Needs Improvement';
    return 'Concerning';
  }

  /// Gets a suggested avatar color based on performance level
  Color get suggestedAvatarColor {
    if (totalPoints >= 50) return Colors.green;
    if (totalPoints >= 25) return Colors.blue;
    if (totalPoints >= 0) return Colors.orange;
    if (totalPoints >= -25) return Colors.red;
    return Colors.red.shade800;
  }

  /// Gets a formatted string representation of total points
  String get formattedTotalPoints {
    if (totalPoints > 0) {
      return '+$totalPoints';
    } else {
      return totalPoints.toString();
    }
  }

  /// Gets the most recent behavior point, or null if no behaviors exist
  BehaviorPoint? get mostRecentBehavior {
    if (recentBehaviors.isEmpty) return null;
    return recentBehaviors.first;
  }

  /// Gets recent positive behaviors only
  List<BehaviorPoint> get recentPositiveBehaviors {
    return recentBehaviors.where((b) => b.isPositive).toList();
  }

  /// Gets recent negative behaviors only
  List<BehaviorPoint> get recentNegativeBehaviors {
    return recentBehaviors.where((b) => b.isNegative).toList();
  }

  /// Checks if the student has any recent concerning behavior patterns
  bool get hasRecentConcerns {
    if (recentBehaviors.length < 3) return false;
    
    // Check if more than 60% of recent behaviors are negative
    final recentNegativeCount = recentNegativeBehaviors.length;
    return (recentNegativeCount / recentBehaviors.length) > 0.6;
  }

  /// Gets a trend indicator based on recent behavior patterns
  String get behaviorTrend {
    if (recentBehaviors.length < 3) return 'Insufficient Data';
    
    final recentPositiveCount = recentPositiveBehaviors.length;
    final recentNegativeCount = recentNegativeBehaviors.length;
    
    if (recentPositiveCount > recentNegativeCount * 1.5) {
      return 'Improving';
    } else if (recentNegativeCount > recentPositiveCount * 1.5) {
      return 'Declining';
    } else {
      return 'Stable';
    }
  }
}