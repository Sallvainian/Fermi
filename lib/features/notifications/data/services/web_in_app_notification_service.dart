import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/services/logger_service.dart';

/// Service for handling in-app notifications on web (no push/background)
class WebInAppNotificationService {
  static final WebInAppNotificationService _instance =
      WebInAppNotificationService._internal();
  factory WebInAppNotificationService() => _instance;
  WebInAppNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _notificationSubscription;
  Function(String title, String body, Map<String, dynamic>? data)?
      onNotificationReceived;

  /// Start listening for in-app notifications (web only)
  void startWebInAppNotifications() {
    if (!kIsWeb) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      LoggerService.warning(
          'No user logged in - cannot start web notifications',
          tag: 'WebInAppNotification');
      return;
    }

    // Cancel any existing subscription
    _notificationSubscription?.cancel();

    // Listen for new notifications in Firestore
    _notificationSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;

            // Extract notification details
            final title = data['title'] as String? ?? 'New notification';
            final body = data['body'] as String? ?? '';
            final notificationData = data['data'] as Map<String, dynamic>?;

            // Trigger the callback to show in-app toast/snackbar
            onNotificationReceived?.call(title, body, notificationData);

            // Mark as delivered (not read, just delivered)
            _markAsDelivered(change.doc.id);

            LoggerService.info('Web in-app notification received: $title',
                tag: 'WebInAppNotification');
          }
        }
      },
      onError: (error) {
        LoggerService.error('Error listening to notifications',
            error: error, tag: 'WebInAppNotification');
      },
    );

    LoggerService.info('Started web in-app notifications for user: $userId',
        tag: 'WebInAppNotification');
  }

  /// Stop listening for in-app notifications
  void stopWebInAppNotifications() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    LoggerService.info('Stopped web in-app notifications',
        tag: 'WebInAppNotification');
  }

  /// Mark a notification as delivered
  Future<void> _markAsDelivered(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'deliveredAt': FieldValue.serverTimestamp(),
        'delivered': true,
      });
    } catch (e) {
      LoggerService.error('Failed to mark notification as delivered',
          error: e, tag: 'WebInAppNotification');
    }
  }

  /// Create a test notification (for debugging)
  Future<void> createTestNotification() async {
    if (!kIsWeb) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Test Notification',
        'body': 'This is a test notification for web in-app display',
        'type': 'test',
        'read': false,
        'delivered': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'testData': 'This is test data',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });

      LoggerService.debug('Test notification created',
          tag: 'WebInAppNotification');
    } catch (e) {
      LoggerService.error('Failed to create test notification',
          error: e, tag: 'WebInAppNotification');
    }
  }

  /// Dispose of resources
  void dispose() {
    stopWebInAppNotifications();
  }
}
