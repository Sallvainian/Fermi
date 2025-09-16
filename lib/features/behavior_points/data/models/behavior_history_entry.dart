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
  });

  factory BehaviorHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BehaviorHistoryEntry(
      operationId: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? 'Unknown Student',
      behaviorId: data['behaviorId'] ?? '',
      behaviorName: data['behaviorName'] ?? 'Unknown Behavior',
      type: data['type'] ?? 'positive',
      points: data['points'] ?? 0,
      teacherId: data['teacherId'] ?? '',
      teacherName: data['teacherName'] ?? 'Unknown Teacher',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'],
      isUndone: data['isUndone'] ?? false,
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
    };
  }

  BehaviorHistoryEntry copyWith({
    bool? isUndone,
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
    );
  }
}