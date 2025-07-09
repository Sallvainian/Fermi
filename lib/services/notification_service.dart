import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_event.dart';
import '../models/assignment.dart';
import '../models/notification.dart' as app_notification;
import '../core/service_locator.dart';
import '../services/logger_service.dart';

/// Service for managing local notifications and reminders
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isInitialized = false;
  
  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone
    tz.initializeTimeZones();
    final localTimeZone = tz.local;
    tz.setLocalLocation(localTimeZone);
    
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // Initialize
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    _isInitialized = true;
  }
  
  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final result = await androidImplementation.requestNotificationsPermission();
        return result ?? false;
      }
    }
    return true;
  }
  
  /// Schedule reminder for calendar event
  Future<void> scheduleEventReminder(CalendarEvent event) async {
    if (!event.hasReminder || event.reminderMinutes == null) return;
    
    final scheduledDate = event.startTime.subtract(
      Duration(minutes: event.reminderMinutes!),
    );
    
    // Don't schedule if in the past
    if (scheduledDate.isBefore(DateTime.now())) return;
    
    await _scheduleNotification(
      id: event.id.hashCode,
      title: 'Event Reminder',
      body: '${event.title} starts in ${_formatReminderTime(event.reminderMinutes!)}',
      scheduledDate: scheduledDate,
      payload: 'event:${event.id}',
    );
    
    // Store notification record
    await _storeNotificationRecord(
      type: 'eventReminder',
      title: 'Event Reminder',
      message: '${event.title} starts in ${_formatReminderTime(event.reminderMinutes!)}',
      relatedId: event.id,
      scheduledFor: scheduledDate,
    );
  }
  
  /// Schedule reminder for assignment due date
  Future<void> scheduleAssignmentReminder(Assignment assignment) async {
    final reminderTime = assignment.dueDate.subtract(const Duration(hours: 24));
    
    // Don't schedule if in the past
    if (reminderTime.isBefore(DateTime.now())) return;
    
    await _scheduleNotification(
      id: assignment.id.hashCode,
      title: 'Assignment Due Tomorrow',
      body: '${assignment.title} is due tomorrow at ${_formatTime(assignment.dueDate)}',
      scheduledDate: reminderTime,
      payload: 'assignment:${assignment.id}',
    );
    
    // Store notification record
    await _storeNotificationRecord(
      type: 'assignmentReminder',
      title: 'Assignment Due Tomorrow',
      message: '${assignment.title} is due tomorrow at ${_formatTime(assignment.dueDate)}',
      relatedId: assignment.id,
      scheduledFor: reminderTime,
    );
  }
  
  /// Cancel scheduled notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
  
  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
  
  /// Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
  
  /// Private method to schedule notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }
  
  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;
    
    final parts = response.payload!.split(':');
    if (parts.length != 2) return;
    
    final type = parts[0];
    final id = parts[1];
    
    // Handle navigation based on type
    // This would be implemented to navigate to the appropriate screen
    LoggerService.info('Notification tapped: $type with id: $id', 
        tag: 'NotificationService');
  }
  
  /// Store notification record in Firestore
  Future<void> _storeNotificationRecord({
    required String type,
    required String title,
    required String message,
    required String relatedId,
    required DateTime scheduledFor,
  }) async {
    // Get current user from auth service
    final authService = getIt.authService;
    final currentUser = authService.currentUser;
    if (currentUser == null) return;
    
    final userId = currentUser.uid;
    
    final notification = app_notification.Notification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      type: type,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      read: false,
      relatedId: relatedId,
      metadata: {
        'scheduledFor': scheduledFor.toIso8601String(),
      },
    );
    
    await _firestore
        .collection('notifications')
        .doc(notification.id)
        .set(notification.toFirestore());
  }
  
  /// Format reminder time for display
  String _formatReminderTime(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    } else {
      final days = minutes ~/ 1440;
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
  }
  
  /// Format time for display
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}