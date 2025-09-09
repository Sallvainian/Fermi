/// Behavior point model for tracking individual behavior instances and point awards.
///
/// This module contains the data model for behavior points used to
/// record when students earn or lose points for specific behaviors.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'behavior.dart';

/// Core behavior point model representing individual behavior point awards.
///
/// Behavior points track specific instances when students demonstrate
/// behaviors, including:
/// - The student and behavior involved
/// - Point value awarded or deducted
/// - Timestamp and context information
/// - Optional notes from the teacher
/// - Teacher and class identification
///
/// These records form the basis for calculating student point totals
/// and generating behavior reports.
class BehaviorPoint {
  /// Unique identifier for the behavior point record
  final String id;

  /// ID of the student who earned/lost the points
  final String studentId;

  /// Cached name of the student for display purposes
  final String studentName;

  /// ID of the teacher who awarded the points
  final String teacherId;

  /// ID of the class where the behavior occurred
  final String classId;

  /// ID of the behavior that was demonstrated
  final String behaviorId;

  /// Cached name of the behavior for display purposes
  final String behaviorName;

  /// Point value awarded (positive or negative)
  final int points;

  /// Type of behavior (positive or negative)
  final BehaviorType type;

  /// Timestamp when the behavior point was recorded
  final DateTime timestamp;

  /// Optional note from the teacher about this specific instance
  final String? note;

  BehaviorPoint({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.classId,
    required this.behaviorId,
    required this.behaviorName,
    required this.points,
    required this.type,
    required this.timestamp,
    this.note,
  });

  /// Factory constructor to create BehaviorPoint from Firestore document.
  ///
  /// Handles data parsing including:
  /// - Timestamp to DateTime conversions
  /// - Enum parsing with fallback defaults
  /// - Null safety for optional fields
  /// - Type casting for numeric values
  ///
  /// @param doc Firestore document snapshot containing behavior point data
  /// @return Parsed BehaviorPoint instance
  factory BehaviorPoint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return BehaviorPoint(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      teacherId: data['teacherId'] ?? '',
      classId: data['classId'] ?? '',
      behaviorId: data['behaviorId'] ?? '',
      behaviorName: data['behaviorName'] ?? '',
      points: data['points'] ?? 0,
      type: BehaviorType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => BehaviorType.positive,
      ),
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      note: data['note'],
    );
  }

  /// Alternative factory constructor to create BehaviorPoint from Map data.
  ///
  /// Similar to fromFirestore but accepts ID separately, useful for:
  /// - Creating behavior points from cached data
  /// - Testing with mock data
  /// - Data transformations
  ///
  /// @param id BehaviorPoint identifier
  /// @param data Map containing behavior point fields
  /// @return Parsed BehaviorPoint instance
  factory BehaviorPoint.fromMap(String id, Map<String, dynamic> data) {
    return BehaviorPoint(
      id: id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      teacherId: data['teacherId'] ?? '',
      classId: data['classId'] ?? '',
      behaviorId: data['behaviorId'] ?? '',
      behaviorName: data['behaviorName'] ?? '',
      points: data['points'] ?? 0,
      type: BehaviorType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => BehaviorType.positive,
      ),
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      note: data['note'],
    );
  }

  /// Converts the BehaviorPoint instance to a Map for Firestore storage.
  ///
  /// Serializes all behavior point data including:
  /// - DateTime fields to Firestore Timestamps
  /// - Enum values to string representations
  /// - Null checks for optional fields
  /// - All cached display names for efficient queries
  ///
  /// @return Map containing all behavior point data ready for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'teacherId': teacherId,
      'classId': classId,
      'behaviorId': behaviorId,
      'behaviorName': behaviorName,
      'points': points,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'note': note,
    };
  }

  /// Converts the BehaviorPoint instance to a JSON-compatible Map.
  ///
  /// Similar to toFirestore but uses ISO string format for timestamps,
  /// making it suitable for JSON serialization and API responses.
  ///
  /// @return Map containing behavior point data in JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'teacherId': teacherId,
      'classId': classId,
      'behaviorId': behaviorId,
      'behaviorName': behaviorName,
      'points': points,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
    };
  }

  /// Creates a BehaviorPoint from JSON data.
  ///
  /// Useful for deserializing API responses or cached JSON data.
  ///
  /// @param json Map containing behavior point data in JSON format
  /// @return Parsed BehaviorPoint instance
  factory BehaviorPoint.fromJson(Map<String, dynamic> json) {
    return BehaviorPoint(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      teacherId: json['teacherId'] ?? '',
      classId: json['classId'] ?? '',
      behaviorId: json['behaviorId'] ?? '',
      behaviorName: json['behaviorName'] ?? '',
      points: json['points'] ?? 0,
      type: BehaviorType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BehaviorType.positive,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      note: json['note'],
    );
  }

  /// Creates a copy of the BehaviorPoint with updated fields.
  ///
  /// Follows the immutable data pattern, allowing selective field updates
  /// while preserving all other values. Useful for:
  /// - Adding or updating teacher notes
  /// - Correcting point values
  /// - Updating cached display names
  ///
  /// All parameters are optional - only provided fields will be updated.
  ///
  /// @return New BehaviorPoint instance with updated fields
  BehaviorPoint copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? teacherId,
    String? classId,
    String? behaviorId,
    String? behaviorName,
    int? points,
    BehaviorType? type,
    DateTime? timestamp,
    String? note,
  }) {
    return BehaviorPoint(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      teacherId: teacherId ?? this.teacherId,
      classId: classId ?? this.classId,
      behaviorId: behaviorId ?? this.behaviorId,
      behaviorName: behaviorName ?? this.behaviorName,
      points: points ?? this.points,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
    );
  }

  /// Checks if this behavior point is positive (earning points)
  bool get isPositive => points > 0;

  /// Checks if this behavior point is negative (losing points)
  bool get isNegative => points < 0;

  /// Gets a formatted string representation of the point value
  String get formattedPoints {
    if (points > 0) {
      return '+$points';
    } else {
      return points.toString();
    }
  }

  /// Gets a user-friendly description of this behavior point
  String get description {
    final pointText = isPositive ? 'earned' : 'lost';
    final pointValue = points.abs();
    return '$studentName $pointText $pointValue point${pointValue == 1 ? '' : 's'} for $behaviorName';
  }
}