import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import '../../../calendar/domain/models/calendar_event.dart';
import '../../../assignments/domain/models/assignment.dart';
import '../../domain/models/notification.dart' as app_notification;
import '../../../../shared/services/logger_service.dart';
// Conditional import for web notification permissions
import 'notification_service_stub.dart'
    if (dart.library.html) 'notification_service_web.dart' as platform;

/// Service for managing local notifications and reminders
/// Uses standard push notifications for all platforms
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _notificationPermissionDenied = false;


  // Notification channel IDs
  static const String _channelId = 'teacher_dashboard_calls';
  static const String _channelName = 'Incoming Calls';
  static const String _channelDescription = 'Notifications for incoming calls';

  /// Initialize notification service with full platform support
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();

      // Initialize local notifications for all platforms
      await _initializeLocalNotifications();

      _isInitialized = true;
      LoggerService.info(
        'Notification service initialized. Using standard notifications only.',
        tag: 'NotificationService'
      );
    } catch (e) {
      LoggerService.error('Failed to initialize NotificationService',
          error: e, tag: 'NotificationService');
      // Fallback to basic functionality
      _isInitialized = true;
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) {
        // Request browser notification permissions for web
        return await _requestWebNotificationPermissions();
      } else if (Platform.isAndroid) {
        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true; // Assume granted on other platforms
    } catch (e) {
      LoggerService.error('Failed to request permissions',
          error: e, tag: 'NotificationService');
      return true; // Fallback for compatibility
    }
  }

  /// Request web browser notification permissions
  Future<bool> _requestWebNotificationPermissions() async {
    try {
      if (kIsWeb) {
        // Use the Notification API to request permission
        final permission = await _checkWebNotificationPermission();
        if (permission == 'granted') {
          LoggerService.info('Web notification permission already granted',
              tag: 'NotificationService');
          return true;
        } else if (permission == 'denied') {
          LoggerService.warning('Web notification permission denied by user',
              tag: 'NotificationService');
          // Store denied state for UI feedback
          _notificationPermissionDenied = true;
          _showPermissionDeniedGuidance();
          return false;
        } else {
          // Permission is 'default', we can request it
          final requestResult =
              await _requestWebNotificationPermissionFromBrowser();
          final granted = requestResult == 'granted';

          if (!granted && requestResult == 'denied') {
            _notificationPermissionDenied = true;
            _showPermissionDeniedGuidance();
          }

          LoggerService.info(
              'Web notification permission request result: $requestResult',
              tag: 'NotificationService');
          return granted;
        }
      }
      return true;
    } catch (e) {
      LoggerService.error('Failed to request web notification permissions',
          error: e, tag: 'NotificationService');
      return false;
    }
  }

  /// Check current web notification permission status
  Future<String> _checkWebNotificationPermission() async {
    if (kIsWeb) {
      try {
        // Use platform abstraction to check Notification.permission
        if (platform.WebNotification.supported) {
          final permission = platform.WebNotification.permission ?? 'denied';
          LoggerService.info('Web notification permission status: $permission',
              tag: 'NotificationService');
          return permission;
        } else {
          LoggerService.warning('Web notifications not supported',
              tag: 'NotificationService');
          return 'denied';
        }
      } catch (e) {
        LoggerService.error('Error checking web notification permission',
            error: e, tag: 'NotificationService');
        return 'denied';
      }
    }
    return 'granted';
  }

  /// Request notification permission from browser
  Future<String> _requestWebNotificationPermissionFromBrowser() async {
    if (kIsWeb) {
      try {
        if (platform.WebNotification.supported) {
          // Use platform abstraction to request notification permission
          final permission = await platform.WebNotification.requestPermission();
          LoggerService.info(
              'Browser notification permission requested: $permission',
              tag: 'NotificationService');

          // If permission is still 'default', provide guidance
          if (permission == 'default') {
            _showPermissionPendingGuidance();
          }

          return permission;
        } else {
          LoggerService.warning('Browser notifications not supported',
              tag: 'NotificationService');
          _showBrowserNotSupportedGuidance();
          return 'denied';
        }
      } catch (e) {
        LoggerService.error('Failed to request browser notification permission',
            error: e, tag: 'NotificationService');
        return 'denied';
      }
    }
    return 'granted';
  }

  /// Schedule reminder for calendar event (stub)
  Future<void> scheduleEventReminder(CalendarEvent event) async {
    LoggerService.info('Event reminder scheduled: ${event.title}',
        tag: 'NotificationService');
    // Store notification record only
    await _storeNotificationRecord(
      type: 'eventReminder',
      title: 'Event Reminder',
      message: '${event.title} reminder',
      relatedId: event.id,
      scheduledFor: event.startTime,
    );
  }

  /// Schedule reminder for assignment (stub)
  Future<void> scheduleAssignmentReminder(Assignment assignment) async {
    LoggerService.info('Assignment reminder scheduled: ${assignment.title}',
        tag: 'NotificationService');
    // Store notification record only
    await _storeNotificationRecord(
      type: 'assignmentReminder',
      title: 'Assignment Reminder',
      message: '${assignment.title} is due soon',
      relatedId: assignment.id,
      scheduledFor: assignment.dueDate,
    );
  }

  /// Send immediate notification (stub)
  Future<void> sendImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    LoggerService.info('Immediate notification: $title - $body',
        tag: 'NotificationService');
    // Store notification record only
    await _storeNotificationRecord(
      type: 'immediate',
      title: title,
      message: body,
      relatedId: payload,
      scheduledFor: DateTime.now(),
    );
  }

  /// Cancel scheduled notification (stub)
  Future<void> cancelNotification(int id) async {
    LoggerService.info('Notification cancelled: $id',
        tag: 'NotificationService');
  }

  /// Cancel all notifications (stub)
  Future<void> cancelAllNotifications() async {
    LoggerService.info('All notifications cancelled',
        tag: 'NotificationService');
  }

  /// Get pending notifications (stub)
  Future<List<app_notification.Notification>> getPendingNotifications() async {
    LoggerService.info('Getting pending notifications',
        tag: 'NotificationService');
    return []; // Return empty list for Windows compatibility
  }

  /// Store notification record in Firestore
  Future<void> _storeNotificationRecord({
    required String type,
    required String title,
    required String message,
    String? relatedId,
    required DateTime scheduledFor,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': type,
        'title': title,
        'message': message,
        'relatedId': relatedId,
        'scheduledFor': Timestamp.fromDate(scheduledFor),
        'createdAt': Timestamp.now(),
        'status': 'scheduled',
      });
    } catch (e) {
      LoggerService.error('Failed to store notification record',
          error: e, tag: 'NotificationService');
    }
  }

  // WebRTC Call Notification Methods

  Future<void> _initializeLocalNotifications() async {
    // Android settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // macOS settings (for desktop)
    const macOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Linux settings
    final linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
      defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
    );

    // Windows settings - basic support through flutter_local_notifications
    // Note: Windows notification support is limited compared to other platforms
    // Full action support requires additional platform-specific implementation

    // Combined settings
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOSSettings,
      linux: linuxSettings,
      // Windows uses default initialization
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channel for Android
    if (!kIsWeb && Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }


  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification taps
    if (response.payload != null) {
      LoggerService.info('Notification tapped with payload: ${response.payload}',
          tag: 'NotificationService');
      
      // Parse payload to determine notification type
      try {
        final Map<String, dynamic> data = json.decode(response.payload!);
        final String? type = data['type'];
        final String? id = data['id'];
        
        if (type == 'assignment' && id != null) {
          // Navigate to assignment details
          // Navigation will be handled by the app's router when it implements deep linking
          LoggerService.info('Assignment notification tapped: $id',
              tag: 'NotificationService');
        } else if (type == 'message' && id != null) {
          // Navigate to message/chat
          LoggerService.info('Message notification tapped: $id',
              tag: 'NotificationService');
        }
        // Add more types as needed
      } catch (e) {
        // If payload isn't JSON, just log it
        LoggerService.info('Notification tapped: ${response.payload}',
            tag: 'NotificationService');
      }
    }
  }

  /// Show guidance when notification permission is denied
  void _showPermissionDeniedGuidance() {
    LoggerService.info(
        'Notification permissions denied. User guidance: '
        'To enable notifications, please go to your browser settings and allow notifications for this site.',
        tag: 'NotificationService');
    // In a real implementation, this would trigger UI feedback
    // For now, we log the guidance for the UI layer to handle
  }

  /// Show guidance when permission is pending (default state)
  void _showPermissionPendingGuidance() {
    LoggerService.info(
        'Notification permission pending. User guidance: '
        'Please click "Allow" in the browser permission dialog to enable notifications.',
        tag: 'NotificationService');
    // In a real implementation, this would trigger UI feedback
  }

  /// Show guidance when browser doesn't support notifications
  void _showBrowserNotSupportedGuidance() {
    LoggerService.warning(
        'Browser does not support notifications. User guidance: '
        'Your browser does not support web notifications. Please use a modern browser like Chrome, Firefox, or Safari.',
        tag: 'NotificationService');
    // In a real implementation, this would trigger UI feedback
  }

  /// Get current notification permission status for UI
  bool get isPermissionDenied => _notificationPermissionDenied;

  /// Retry notification permission request
  Future<bool> retryPermissionRequest() async {
    if (_notificationPermissionDenied) {
      LoggerService.info('Retrying notification permission request',
          tag: 'NotificationService');
      _notificationPermissionDenied = false; // Reset the flag
      return await requestPermissions();
    }
    return false;
  }
}