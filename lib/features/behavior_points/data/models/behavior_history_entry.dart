import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for behavior point history entries
///
/// Each entry represents a single behavior point award or deduction,
/// stored as an immutable audit trail for transparency and undo operations.
class BehaviorHistoryEntry {
  final String operationId;
  final String studentId;
  final String studentName;
  final String behaviorId;
  final String behaviorName;
  final String type; // 'positive' or 'negative'
  final int points;
  final String teacherId;
  final String teacherName;
  final DateTime timestamp;
  final String? note;
  final bool isUndone;

  // New fields for enhanced filtering
  final String classId;
  final String? gender;
  final String? gradeLevel;
  final String? studentAvatarUrl;

  BehaviorHistoryEntry({
    required this.operationId,
    required this.studentId,
    required this.studentName,
    required this.behaviorId,
    required this.behaviorName,
    required this.type,
    required this.points,
    required this.teacherId,
    required this.teacherName,
    required this.timestamp,
    this.note,
    this.isUndone = false,
    required this.classId,
    this.gender,
    this.gradeLevel,
    this.studentAvatarUrl,
  });

  factory BehaviorHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['operationId'] = doc.id;
    return BehaviorHistoryEntry.fromMap(data);
  }

  factory BehaviorHistoryEntry.fromMap(Map<String, dynamic> data) {
    // Helper function to safely convert timestamps
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is Map && value['_seconds'] != null) {
        // Handle JavaScript timestamp object
        return DateTime.fromMillisecondsSinceEpoch(
          (value['_seconds'] as int) * 1000 +
          ((value['_nanoseconds'] as int? ?? 0) ~/ 1000000),
        );
      }
      return DateTime.now();
    }

    // Safely parse points
    int parsePoints(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return BehaviorHistoryEntry(
      operationId: data['operationId']?.toString() ?? '',
      studentId: data['studentId']?.toString() ?? '',
      studentName: data['studentName']?.toString() ?? 'Unknown Student',
      behaviorId: data['behaviorId']?.toString() ?? '',
      behaviorName: data['behaviorName']?.toString() ?? 'Unknown Behavior',
      type: data['type']?.toString() ?? (parsePoints(data['points']) > 0 ? 'positive' : 'negative'),
      points: parsePoints(data['points']),
      teacherId: data['teacherId']?.toString() ?? data['awardedBy']?.toString() ?? '',
      teacherName: data['teacherName']?.toString() ?? data['awardedByName']?.toString() ?? 'Unknown Teacher',
      timestamp: data['timestamp'] != null
          ? parseTimestamp(data['timestamp'])
          : parseTimestamp(data['awardedAt']),
      note: data['note']?.toString(),
      isUndone: data['isUndone'] == true,
      classId: data['classId']?.toString() ?? '',
      gender: data['gender']?.toString(),
      gradeLevel: data['gradeLevel']?.toString(),
      studentAvatarUrl: data['studentAvatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'operationId': operationId,
      'studentId': studentId,
      'studentName': studentName,
      'behaviorId': behaviorId,
      'behaviorName': behaviorName,
      'type': type,
      'points': points,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'timestamp': FieldValue.serverTimestamp(),
      'note': note,
      'isUndone': isUndone,
      'classId': classId,
      'gender': gender,
      'gradeLevel': gradeLevel,
      'studentAvatarUrl': studentAvatarUrl,
    };
  }

  BehaviorHistoryEntry copyWith({
    bool? isUndone,
    String? classId,
    String? gender,
    String? gradeLevel,
    String? studentAvatarUrl,
  }) {
    return BehaviorHistoryEntry(
      operationId: operationId,
      studentId: studentId,
      studentName: studentName,
      behaviorId: behaviorId,
      behaviorName: behaviorName,
      type: type,
      points: points,
      teacherId: teacherId,
      teacherName: teacherName,
      timestamp: timestamp,
      note: note,
      isUndone: isUndone ?? this.isUndone,
      classId: classId ?? this.classId,
      gender: gender ?? this.gender,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      studentAvatarUrl: studentAvatarUrl ?? this.studentAvatarUrl,
    );
  }
}