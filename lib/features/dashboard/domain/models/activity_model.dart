import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType {
  assignmentSubmitted,
  assignmentGraded,
  messageReceived,
  assignmentCreated,
  studentJoined,
  upcomingDeadline,
  classCreated,
  announcement,
}

class ActivityModel {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? userId;
  final String? userName;
  final String? classId;
  final String? className;
  final String? assignmentId;
  final Map<String, dynamic>? metadata;
  final bool isRead;

  ActivityModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.userId,
    this.userName,
    this.classId,
    this.className,
    this.assignmentId,
    this.metadata,
    this.isRead = false,
  });

  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityModel(
      id: doc.id,
      type: ActivityType.values.firstWhere(
        (e) => e.toString() == 'ActivityType.${data['type']}',
        orElse: () => ActivityType.announcement,
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'],
      userName: data['userName'],
      classId: data['classId'],
      className: data['className'],
      assignmentId: data['assignmentId'],
      metadata: data['metadata'] as Map<String, dynamic>?,
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
      'userName': userName,
      'classId': classId,
      'className': className,
      'assignmentId': assignmentId,
      'metadata': metadata,
      'isRead': isRead,
    };
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return '${(difference.inDays / 7).round()} ${(difference.inDays / 7).round() == 1 ? 'week' : 'weeks'} ago';
    }
  }
}
