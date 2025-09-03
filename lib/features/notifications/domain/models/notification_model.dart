import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  grade,
  assignment,
  message,
  system,
  calendar,
  announcement,
  discussion,
  submission,
}

enum NotificationPriority { low, normal, medium, high, urgent }

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final NotificationPriority priority;
  final Map<String, dynamic>? actionData;
  final String? imageUrl;
  final String? category;
  final DateTime? scheduledFor;
  final DateTime? expiresAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.priority = NotificationPriority.normal,
    this.actionData,
    this.imageUrl,
    this.category,
    this.scheduledFor,
    this.expiresAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.system,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      actionData: data['actionData'] as Map<String, dynamic>?,
      imageUrl: data['imageUrl'],
      category: data['category'],
      scheduledFor: data['scheduledFor'] != null
          ? (data['scheduledFor'] as Timestamp).toDate()
          : null,
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'priority': priority.name,
      'actionData': actionData,
      'imageUrl': imageUrl,
      'category': category,
      'scheduledFor': scheduledFor != null
          ? Timestamp.fromDate(scheduledFor!)
          : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    NotificationPriority? priority,
    Map<String, dynamic>? actionData,
    String? imageUrl,
    String? category,
    DateTime? scheduledFor,
    DateTime? expiresAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
      actionData: actionData ?? this.actionData,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // Helper method to get display icon based on type
  String get typeIcon {
    switch (type) {
      case NotificationType.grade:
        return '📊';
      case NotificationType.assignment:
        return '📝';
      case NotificationType.message:
        return '💬';
      case NotificationType.system:
        return 'ℹ️';
      case NotificationType.calendar:
        return '📅';
      case NotificationType.announcement:
        return '📢';
      case NotificationType.discussion:
        return '💭';
      case NotificationType.submission:
        return '📤';
    }
  }

  // Helper method to check if notification has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // Helper method to check if notification is scheduled for future
  bool get isScheduled {
    if (scheduledFor == null) return false;
    return DateTime.now().isBefore(scheduledFor!);
  }
}
