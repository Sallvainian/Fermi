/// Notification model for push notifications and alerts.
///
/// This module defines the notification structure for the educational platform,
/// supporting various notification types like assignment deadlines, messages,
/// grades, and system alerts with Firebase integration.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Enumeration of available notification types.
enum NotificationType {
  /// Assignment-related notifications
  assignment('Assignment'),

  /// Grade-related notifications
  grade('Grade'),

  /// Message notifications
  message('Message'),

  /// Event reminder notifications
  eventReminder('Event Reminder'),

  /// Assignment reminder notifications
  assignmentReminder('Assignment Reminder'),

  /// System notifications
  system('System'),

  /// General notifications
  general('General');

  /// Display name for the notification type
  final String displayName;

  const NotificationType(this.displayName);

  /// Creates NotificationType from string value
  static NotificationType fromString(String value) {
    // Convert snake_case or space-separated to camelCase
    final camelCase = value
        .toLowerCase()
        .split(RegExp(r'[_\s]+'))
        .asMap()
        .entries
        .map((entry) {
          if (entry.key == 0) return entry.value;
          return entry.value[0].toUpperCase() + entry.value.substring(1);
        })
        .join('');

    return NotificationType.values.firstWhere(
      (type) => type.name == camelCase,
      orElse: () => NotificationType.general,
    );
  }
}

/// Notification model representing user notifications.
///
/// This model supports various notification types with features:
/// - Multiple notification types (assignments, grades, messages, etc.)
/// - Read/unread status tracking
/// - Related entity linking (assignment, grade, message, etc.)
/// - Rich metadata for notification details
/// - Action buttons for quick responses
///
/// Notifications are used to keep users informed about important
/// events and updates in the educational platform.
class Notification {
  /// Unique identifier for the notification
  final String id;

  /// User ID who receives the notification
  final String userId;

  /// Notification category type
  final String type;

  /// Notification title
  final String title;

  /// Notification message/body
  final String message;

  /// Whether the notification has been read
  final bool read;

  /// Related entity ID (assignment, grade, message, etc.)
  final String? relatedId;

  /// Related entity type for navigation
  final String? relatedType;

  /// Action to take when notification is tapped
  final String? actionUrl;

  /// Additional metadata for extensibility
  final Map<String, dynamic>? metadata;

  /// Creation timestamp
  final DateTime createdAt;

  /// Read timestamp (when user marked as read)
  final DateTime? readAt;

  /// Creates a notification instance.
  Notification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.read = false,
    this.relatedId,
    this.relatedType,
    this.actionUrl,
    this.metadata,
    required this.createdAt,
    this.readAt,
  });

  /// Creates a Notification from Firestore document.
  factory Notification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Notification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'general',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      read: data['read'] ?? false,
      relatedId: data['relatedId'],
      relatedType: data['relatedType'],
      actionUrl: data['actionUrl'],
      metadata: data['metadata'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Converts Notification to Firestore document format.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'read': read,
      'relatedId': relatedId,
      'relatedType': relatedType,
      'actionUrl': actionUrl,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  /// Creates a copy with optional field updates.
  Notification copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    bool? read,
    String? relatedId,
    String? relatedType,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      read: read ?? this.read,
      relatedId: relatedId ?? this.relatedId,
      relatedType: relatedType ?? this.relatedType,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  /// Marks the notification as read with current timestamp.
  Notification markAsRead() {
    return copyWith(read: true, readAt: DateTime.now());
  }

  /// Gets notification type enum from string type.
  NotificationType get notificationType => NotificationType.fromString(type);

  /// Checks if the notification is unread.
  bool get isUnread => !read;

  /// Gets a display icon based on notification type.
  String get displayIcon {
    switch (notificationType) {
      case NotificationType.assignment:
      case NotificationType.assignmentReminder:
        return '📝';
      case NotificationType.grade:
        return '📊';
      case NotificationType.message:
        return '💬';
      case NotificationType.eventReminder:
        return '📅';
      case NotificationType.system:
        return '⚙️';
      case NotificationType.general:
        return '📢';
    }
  }
}
