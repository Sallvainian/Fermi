import 'package:cloud_firestore/cloud_firestore.dart';

/// Aggregate model for student behavior points
///
/// This model represents the running totals and statistics for a student's
/// behavior points within a class. It uses Firestore atomic operations
/// for consistency and provides O(1) read performance.
class StudentPointsAggregate {
  final String studentId;
  final String studentName;
  final String classId;
  final int totalPoints;
  final int positivePoints;
  final int negativePoints;
  final Map<String, int> behaviorCounts;
  final DateTime lastUpdated;
  final String? lastBehaviorName;
  final int? lastPoints;

  StudentPointsAggregate({
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.totalPoints,
    required this.positivePoints,
    required this.negativePoints,
    required this.behaviorCounts,
    required this.lastUpdated,
    this.lastBehaviorName,
    this.lastPoints,
  });

  factory StudentPointsAggregate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentPointsAggregate(
      studentId: data['studentId'] ?? doc.id,
      studentName: data['studentName'] ?? 'Unknown Student',
      classId: data['classId'] ?? '',
      totalPoints: data['totalPoints'] ?? 0,
      positivePoints: data['positivePoints'] ?? 0,
      negativePoints: data['negativePoints'] ?? 0,
      behaviorCounts: Map<String, int>.from(data['behaviorCounts'] ?? {}),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastBehaviorName: data['lastBehaviorName'],
      lastPoints: data['lastPoints'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'totalPoints': totalPoints,
      'positivePoints': positivePoints,
      'negativePoints': negativePoints,
      'behaviorCounts': behaviorCounts,
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastBehaviorName': lastBehaviorName,
      'lastPoints': lastPoints,
    };
  }

  /// Creates update data for atomic operations
  static Map<String, dynamic> createIncrementUpdate({
    required String studentId,
    required String studentName,
    required String classId,
    required String behaviorId,
    required String behaviorName,
    required int points,
  }) {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'totalPoints': FieldValue.increment(points),
      'positivePoints': points > 0 ? FieldValue.increment(points) : FieldValue.increment(0),
      'negativePoints': points < 0 ? FieldValue.increment(points.abs()) : FieldValue.increment(0),
      'behaviorCounts.$behaviorId': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastBehaviorName': behaviorName,
      'lastPoints': points,
    };
  }

  /// Creates update data for undo operations
  static Map<String, dynamic> createUndoUpdate({
    required String behaviorId,
    required int points,
  }) {
    return {
      'totalPoints': FieldValue.increment(-points),
      'positivePoints': points > 0 ? FieldValue.increment(-points) : FieldValue.increment(0),
      'negativePoints': points < 0 ? FieldValue.increment(-points.abs()) : FieldValue.increment(0),
      'behaviorCounts.$behaviorId': FieldValue.increment(-1),
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}