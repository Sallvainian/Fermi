import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'notification_service.dart';
import '../../../../shared/services/logger_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  LoggerService.info('Handling background message: ${message.messageId}');
  // Handle standard push notifications only
}

/// Firebase Cloud Messaging service for push notifications
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  /// Navigation callback for handling navigation from notifications
  void Function(String route, {Map<String, dynamic>? params})?
      _navigationCallback;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitialized = false;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  // Callbacks
  Function(RemoteMessage)? onMessage;

  /// Initialize Firebase Messaging
  Future<void> initialize() async {
    if (kIsWeb) return; // do nothing on web

    if (_isInitialized) return;

    try {
      // Force token refresh to drop old queues
      await _messaging.deleteToken();
      LoggerService.info('Deleted old FCM token',
          tag: 'FirebaseMessagingService');

      // Request permissions
      await _requestPermissions();

      // Configure message handlers
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      _foregroundMessageSubscription =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle when app is opened from notification
      _messageOpenedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Get initial message if app was launched from notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Set foreground notification presentation options for iOS
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get and save FCM token
      await _updateFCMToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveFCMToken);

      _isInitialized = true;
      LoggerService.info('Firebase Messaging initialized',
          tag: 'FirebaseMessagingService');
    } catch (e) {
      LoggerService.error('Failed to initialize Firebase Messaging',
          error: e, tag: 'FirebaseMessagingService');
    }
  }

  /// Set navigation callback for handling navigation from notifications
  void setNavigationCallback(
      void Function(String route, {Map<String, dynamic>? params}) callback) {
    _navigationCallback = callback;
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      // Web doesn't support all permission types
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      // iOS/macOS require explicit permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      LoggerService.info(
          'User granted permission: ${settings.authorizationStatus}',
          tag: 'FirebaseMessagingService');
    }
    // Android permissions are handled at runtime when showing notifications
  }

  /// Update FCM token in Firestore
  Future<void> _updateFCMToken() async {
    try {
      String? token;

      if (kIsWeb) {
        // Web requires VAPID key - get from .env file or environment variable
        // First try .env file (for local development)
        String? vapidKey = dotenv.env['FIREBASE_VAPID_KEY'];

        // If not in .env, try compile-time environment variable (for CI/CD)
        if (vapidKey == null || vapidKey.isEmpty) {
          vapidKey = const String.fromEnvironment('FIREBASE_VAPID_KEY');
        }

        if (vapidKey.isEmpty || vapidKey == 'your_vapid_key_here') {
          LoggerService.warning(
              'FIREBASE_VAPID_KEY not configured - attempting fallback',
              tag: 'FirebaseMessagingService');
          LoggerService.info(
              'To fix: Add your VAPID key to .env file or set FIREBASE_VAPID_KEY environment variable',
              tag: 'FirebaseMessagingService');
          LoggerService.info(
              'Get key from: Firebase Console > Project Settings > Cloud Messaging > Web Push certificates',
              tag: 'FirebaseMessagingService');
          // Try without VAPID key for development
          try {
            token = await _messaging.getToken();
            LoggerService.info(
                'FCM token generated without VAPID key (development mode)',
                tag: 'FirebaseMessagingService');
          } catch (e) {
            LoggerService.error('Failed to get FCM token without VAPID key: $e',
                tag: 'FirebaseMessagingService');
            return;
          }
        } else {
          try {
            // Use VAPID key for web FCM token generation
            token = await _messaging.getToken(vapidKey: vapidKey);
            LoggerService.info(
                'FCM token generated successfully with VAPID key',
                tag: 'FirebaseMessagingService');
          } catch (e) {
            LoggerService.error('Failed to get FCM token with VAPID key: $e',
                tag: 'FirebaseMessagingService');
            // Fallback: try without VAPID key for development
            try {
              token = await _messaging.getToken();
              LoggerService.warning(
                  'Using FCM token without VAPID key (fallback)',
                  tag: 'FirebaseMessagingService');
            } catch (fallbackError) {
              LoggerService.error(
                  'Failed to get FCM token completely: $fallbackError',
                  tag: 'FirebaseMessagingService');
            }
          }
        }
      } else {
        token = await _messaging.getToken();
      }

      if (token != null) {
        await _saveFCMToken(token);
      }
    } catch (e) {
      LoggerService.error('Failed to get FCM token',
          error: e, tag: 'FirebaseMessagingService');
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Save to user document
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': _getPlatformString(),
      });

      // Also save in a separate tokens collection for easier querying
      await _firestore.collection('fcm_tokens').doc(userId).set({
        'token': token,
        'userId': userId,
        'platform': _getPlatformString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggerService.info('FCM token saved', tag: 'FirebaseMessagingService');
    } catch (e) {
      LoggerService.error('Failed to save FCM token',
          error: e, tag: 'FirebaseMessagingService');
    }
  }

  /// Get platform string
  String _getPlatformString() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    LoggerService.info('Received foreground message: ${message.messageId}',
        tag: 'FirebaseMessagingService');

    // Handle standard message types
    onMessage?.call(message);

    // Show local notification for messages
    if (message.notification != null) {
      final notificationService = NotificationService();
      notificationService.sendImmediateNotification(
        title: message.notification!.title ?? 'New Message',
        body: message.notification!.body ?? '',
        payload: message.data['payload'],
      );
    }
  }

  /// Handle when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    LoggerService.info('App opened from notification: ${message.messageId}',
        tag: 'FirebaseMessagingService');

    // Navigate based on notification type
    if (message.data['type'] == 'chat') {
      // Navigate to chat screen
      final chatRoomId = message.data['chatRoomId'];
      if (chatRoomId != null && _navigationCallback != null) {
        LoggerService.info('Navigate to chat: $chatRoomId',
            tag: 'FirebaseMessagingService');
        _navigationCallback!('/messages/chat/$chatRoomId',
            params: {'chatRoomId': chatRoomId});
      }
    }
  }

  /// Get current FCM token
  Future<String?> getCurrentToken() async {
    try {
      if (kIsWeb) {
        // Use VAPID key for web
        const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

        if (vapidKey.isNotEmpty) {
          try {
            return await _messaging.getToken(vapidKey: vapidKey);
          } catch (e) {
            LoggerService.warning(
                'Failed to get current token with VAPID key: $e',
                tag: 'FirebaseMessagingService');
            // Fallback without VAPID key
          }
        }
        // Try without VAPID key as fallback or when not provided
        try {
          return await _messaging.getToken();
        } catch (fallbackError) {
          LoggerService.error(
              'Failed to get current token completely: $fallbackError',
              tag: 'FirebaseMessagingService');
          return null;
        }
      } else {
        return await _messaging.getToken();
      }
    } catch (e) {
      LoggerService.error('Failed to get current token',
          error: e, tag: 'FirebaseMessagingService');
      return null;
    }
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();

      // Remove from Firestore
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.delete(),
        });

        await _firestore.collection('fcm_tokens').doc(userId).delete();
      }

      LoggerService.info('FCM token deleted', tag: 'FirebaseMessagingService');
    } catch (e) {
      LoggerService.error('Failed to delete token',
          error: e, tag: 'FirebaseMessagingService');
    }
  }

  /// Dispose of resources
  void dispose() {
    _foregroundMessageSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
  }
}