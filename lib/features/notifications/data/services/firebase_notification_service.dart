import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/notification_model.dart';

class FirebaseNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get notifications collection reference
  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('notifications');

  // Stream of notifications for current user
  Stream<List<NotificationModel>> getUserNotifications({
    bool includeRead = true,
    NotificationType? filterType,
    int? limit,
  }) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    Query<Map<String, dynamic>> query = _notificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    // Filter by read status
    if (!includeRead) {
      query = query.where('isRead', isEqualTo: false);
    }

    // Filter by type
    if (filterType != null) {
      query = query.where('type', isEqualTo: filterType.name);
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .where((notification) {
        // Filter out expired notifications
        if (notification.isExpired) return false;
        // Filter out scheduled notifications not yet due
        if (notification.isScheduled) return false;
        return true;
      }).toList();
    });
  }

  // Get academic notifications (grades, assignments, submissions)
  Stream<List<NotificationModel>> getAcademicNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('type', whereIn: [
          NotificationType.grade.name,
          NotificationType.assignment.name,
          NotificationType.submission.name,
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .where((notification) {
            if (notification.isExpired) return false;
            if (notification.isScheduled) return false;
            return true;
          }).toList();
        });
  }

  // Get unread notifications count
  Stream<int> getUnreadNotificationCount() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(0);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .where((notification) {
        if (notification.isExpired) return false;
        if (notification.isScheduled) return false;
        return true;
      }).length;
    });
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _notificationsCollection.doc(notificationId).update({
      'isRead': true,
    });
  }

  // Mark notification as unread
  Future<void> markAsUnread(String notificationId) async {
    await _notificationsCollection.doc(notificationId).update({
      'isRead': false,
    });
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final batch = _firestore.batch();
    final unreadNotifications = await _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in unreadNotifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationsCollection.doc(notificationId).delete();
  }

  // Delete all read notifications
  Future<void> deleteAllRead() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final batch = _firestore.batch();
    final readNotifications = await _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: true)
        .get();

    for (final doc in readNotifications.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Create a new notification
  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? actionData,
    String? imageUrl,
    String? category,
    DateTime? scheduledFor,
    DateTime? expiresAt,
  }) async {
    final notification = NotificationModel(
      id: '', // Will be set by Firestore
      userId: userId,
      type: type,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      priority: priority,
      actionData: actionData,
      imageUrl: imageUrl,
      category: category,
      scheduledFor: scheduledFor,
      expiresAt: expiresAt,
    );

    await _notificationsCollection.add(notification.toFirestore());
  }

  // Create notification for grade update
  Future<void> createGradeNotification({
    required String studentId,
    required String courseName,
    required String assignmentName,
    required String grade,
    required String courseId,
    required String assignmentId,
  }) async {
    await createNotification(
      userId: studentId,
      type: NotificationType.grade,
      title: 'New Grade Posted',
      message:
          'Your grade for $assignmentName in $courseName has been posted: $grade',
      priority: NotificationPriority.normal,
      actionData: {
        'courseId': courseId,
        'assignmentId': assignmentId,
        'grade': grade,
      },
    );
  }

  // Create notification for assignment
  Future<void> createAssignmentNotification({
    required String studentId,
    required String courseName,
    required String assignmentName,
    required DateTime dueDate,
    required String assignmentId,
    NotificationPriority priority = NotificationPriority.medium,
  }) async {
    final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
    String message;

    if (daysUntilDue == 0) {
      message = '$assignmentName in $courseName is due today!';
      priority = NotificationPriority.high;
    } else if (daysUntilDue == 1) {
      message = '$assignmentName in $courseName is due tomorrow';
      priority = NotificationPriority.high;
    } else {
      message = '$assignmentName in $courseName is due in $daysUntilDue days';
    }

    await createNotification(
      userId: studentId,
      type: NotificationType.assignment,
      title: 'Assignment Due',
      message: message,
      priority: priority,
      actionData: {
        'assignmentId': assignmentId,
        'dueDate': dueDate.toIso8601String(),
      },
    );
  }

  // Create notification for new message
  Future<void> createMessageNotification({
    required String receiverId,
    required String senderName,
    required String messagePreview,
    required String chatRoomId,
    String? senderPhotoUrl,
  }) async {
    await createNotification(
      userId: receiverId,
      type: NotificationType.message,
      title: 'New Message from $senderName',
      message: messagePreview,
      priority: NotificationPriority.normal,
      actionData: {
        'chatRoomId': chatRoomId,
        'senderName': senderName,
      },
      imageUrl: senderPhotoUrl,
    );
  }

  // Create system notification
  Future<void> createSystemNotification({
    required List<String> userIds,
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.normal,
    DateTime? expiresAt,
  }) async {
    final batch = _firestore.batch();

    for (final userId in userIds) {
      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: userId,
        type: NotificationType.system,
        title: title,
        message: message,
        createdAt: DateTime.now(),
        priority: priority,
        expiresAt: expiresAt,
      );

      batch.set(notificationRef, notification.toFirestore());
    }

    await batch.commit();
  }

  // Get notification settings (could be extended with user preferences)
  Future<Map<String, bool>> getNotificationSettings() async {
    // For now, return default settings
    // In future, could store these in user document
    return {
      'pushNotifications': true,
      'emailNotifications': true,
      'gradeNotifications': true,
      'assignmentNotifications': true,
      'messageNotifications': true,
      'systemNotifications': true,
    };
  }

  // Update notification settings
  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    // For now, this is a placeholder
    // In future, would store these in user document
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Could store in users collection
    // await _firestore.collection('users').doc(userId).update({
    //   'notificationSettings': settings,
    // });
  }
}
