# Push Notifications and In-App Notifications Implementation

## Overview

The Fermi notification system provides comprehensive real-time and scheduled notification delivery across multiple channels including Firebase Cloud Messaging (FCM) push notifications, in-app notifications, email notifications, and SMS alerts. Built with Firebase backend and Flutter frontend supporting cross-platform delivery.

## Technical Architecture

### Core Components

#### Notification Architecture Pattern
- **Push Notifications**: Firebase Cloud Messaging (FCM) for real-time delivery
- **In-App Notifications**: Real-time Firestore listeners with local display
- **Notification Queue**: Scheduled and batch notification processing
- **Preference Management**: User-configurable notification settings
- **Analytics**: Delivery tracking and engagement metrics

#### Key Implementation Files (11 Files)
```
lib/features/notifications/
├── data/
│   ├── repositories/
│   │   └── notification_repository.dart      # Notification CRUD operations
│   └── services/
│       ├── fcm_service.dart                  # Firebase Cloud Messaging
│       ├── local_notification_service.dart   # Local notification handling
│       └── notification_analytics_service.dart # Analytics tracking
├── domain/
│   ├── models/
│   │   ├── notification.dart                 # Notification domain model
│   │   ├── notification_preference.dart      # User preference model
│   │   └── notification_analytics.dart       # Analytics model
│   └── repositories/
│       └── notification_repository_interface.dart # Repository contracts
└── presentation/
    ├── screens/
    │   ├── notifications_screen.dart          # Notification center
    │   ├── notification_settings_screen.dart  # User preferences
    │   └── notification_detail_screen.dart    # Individual notification view
    ├── widgets/
    │   ├── notification_tile.dart             # Notification list item
    │   ├── notification_badge.dart            # Unread count badge
    │   └── notification_permission_dialog.dart # Permission request
    └── providers/
        └── notification_provider.dart         # Notification state management
```

## Data Flow Architecture

### Notification Delivery Flow
```
Event Trigger → Notification Service → FCM/Local Processing → Device Delivery → User Interaction → Analytics
```

### Detailed Notification Flow Sequence
1. **Event Trigger**
   - System events (new assignment, grade posted, message received)
   - Scheduled events (due date reminders, class announcements)
   - User actions (mentions, replies, direct messages)

2. **Notification Processing**
   - Event data validation and processing
   - User preference checking and filtering
   - Template selection and content generation
   - Target audience determination

3. **Delivery Channel Selection**
   - Push notification via FCM
   - In-app notification display
   - Email delivery (if configured)
   - SMS delivery (for critical notifications)

4. **Device Delivery**
   - FCM handles push notification routing
   - Local notification service displays notifications
   - Background processing for app state management
   - Notification persistence and queuing

5. **User Interaction Tracking**
   - Open/click tracking
   - Dismissal tracking
   - Action button interactions
   - Analytics data collection

## Database Schema

### Firestore Collections

#### notifications Collection
```typescript
interface NotificationDocument {
  id: string;                               // Unique notification identifier
  recipientId: string;                      // Target user UID
  senderId?: string;                        // Sender UID (for user-generated notifications)
  type: 'system' | 'assignment' | 'grade' | 'message' | 'reminder' | 'announcement';
  category: 'academic' | 'social' | 'administrative' | 'alert';
  priority: 'low' | 'medium' | 'high' | 'critical';
  
  // Content
  title: string;                            // Notification title
  body: string;                             // Notification body text
  summary?: string;                         // Short summary for badges
  imageUrl?: string;                        // Optional image URL
  iconUrl?: string;                         // Optional icon URL
  
  // Targeting & Context
  classId?: string;                         // Related class identifier
  assignmentId?: string;                    // Related assignment identifier
  chatRoomId?: string;                      // Related chat room identifier
  contextType?: string;                     // Context type identifier
  contextId?: string;                       // Context-specific ID
  
  // Delivery Configuration
  channels: Array<'push' | 'inapp' | 'email' | 'sms'>;
  deliveryMethod: 'immediate' | 'scheduled' | 'batch';
  scheduledFor?: Timestamp;                 // Scheduled delivery time
  batchId?: string;                         // Batch processing identifier
  
  // Actions & Deep Linking
  actions: Array<{
    id: string;                             // Action identifier
    title: string;                          // Action button text
    type: 'navigation' | 'api_call' | 'dismiss';
    payload: any;                           // Action-specific data
  }>;
  deepLink?: string;                        // Deep link URL for navigation
  
  // Status & Tracking
  status: 'pending' | 'sent' | 'delivered' | 'read' | 'dismissed' | 'failed';
  createdAt: Timestamp;                     // Creation timestamp
  sentAt?: Timestamp;                       // Delivery timestamp
  readAt?: Timestamp;                       // Read timestamp
  dismissedAt?: Timestamp;                  // Dismissal timestamp
  
  // Delivery Tracking
  deliveryAttempts: number;                 // Number of delivery attempts
  lastDeliveryAttempt?: Timestamp;          // Last delivery attempt time
  deliveryErrors: Array<{
    timestamp: Timestamp;                   // Error occurrence time
    error: string;                          // Error message
    channel: string;                        // Failed delivery channel
  }>;
  
  // Engagement Analytics
  analytics: {
    delivered: boolean;                     // Successfully delivered
    opened: boolean;                        // User opened notification
    clicked: boolean;                       // User clicked notification
    actionTaken?: string;                   // Specific action taken
    engagementScore: number;                // Calculated engagement score (0-100)
    timeToOpen?: number;                    // Seconds from delivery to open
    deviceType?: string;                    // Device type when opened
    platform?: string;                     // Platform (iOS, Android, Web)
  };
  
  // Metadata
  metadata: {
    templateId?: string;                    // Notification template used
    campaignId?: string;                    // Marketing campaign identifier
    tags: string[];                         // Classification tags
    customData: any;                        // Additional custom data
    originalLanguage: string;               // Original content language
    translatedLanguages: string[];          // Available translations
  };
}
```

#### notification_preferences Collection
```typescript
interface NotificationPreferenceDocument {
  id: string;                               // User UID
  userId: string;                           // User identifier
  classId?: string;                         // Class-specific preferences (optional)
  
  // Global Settings
  globalSettings: {
    enabled: boolean;                       // Master notification toggle
    quietHours: {
      enabled: boolean;                     // Quiet hours feature
      startTime: string;                    // Start time (HH:mm format)
      endTime: string;                      // End time (HH:mm format)
      timezone: string;                     // User timezone
    };
    batchDelivery: {
      enabled: boolean;                     // Batch notifications
      frequency: 'hourly' | 'daily' | 'weekly'; // Batch frequency
      time: string;                         // Preferred delivery time
    };
  };
  
  // Channel Preferences
  channelPreferences: {
    push: {
      enabled: boolean;                     // Push notifications enabled
      critical: boolean;                    // Critical notifications only
      soundEnabled: boolean;                // Sound enabled
      vibrationEnabled: boolean;            // Vibration enabled
      badgeEnabled: boolean;                // Badge count enabled
    };
    inApp: {
      enabled: boolean;                     // In-app notifications enabled
      position: 'top' | 'bottom';          // Display position
      duration: number;                     // Display duration (seconds)
      animationEnabled: boolean;            // Animation enabled
    };
    email: {
      enabled: boolean;                     // Email notifications enabled
      frequency: 'immediate' | 'daily' | 'weekly'; // Email frequency
      digestEnabled: boolean;               // Digest emails enabled
      htmlEnabled: boolean;                 // HTML emails vs plain text
    };
    sms: {
      enabled: boolean;                     // SMS notifications enabled
      critical: boolean;                    // Critical notifications only
      phoneNumber?: string;                 // SMS phone number
      verified: boolean;                    // Phone number verified
    };
  };
  
  // Category Preferences
  categoryPreferences: {
    academic: {
      enabled: boolean;                     // Academic notifications enabled
      channels: string[];                   // Preferred delivery channels
      priority: 'low' | 'medium' | 'high'; // Priority threshold
      keywords: string[];                   // Keyword filters
    };
    social: {
      enabled: boolean;                     // Social notifications enabled
      channels: string[];                   // Preferred delivery channels
      priority: 'low' | 'medium' | 'high'; // Priority threshold
      friendsOnly: boolean;                 // Friends/classmates only
    };
    administrative: {
      enabled: boolean;                     // Admin notifications enabled
      channels: string[];                   // Preferred delivery channels
      priority: 'low' | 'medium' | 'high'; // Priority threshold
    };
    alert: {
      enabled: boolean;                     // Alert notifications enabled
      channels: string[];                   // Preferred delivery channels
      critical: boolean;                    // Critical alerts only
    };
  };
  
  // Specific Notification Types
  typePreferences: {
    assignments: {
      newAssignment: boolean;               // New assignment notifications
      dueReminder: boolean;                 // Due date reminders
      graded: boolean;                      // Grading notifications
      reminderDaysBefore: number;           // Days before due date to remind
    };
    messages: {
      directMessages: boolean;              // Direct message notifications
      groupMessages: boolean;               // Group message notifications
      mentions: boolean;                    // @ mention notifications
      replies: boolean;                     // Reply notifications
    };
    grades: {
      newGrade: boolean;                    // New grade notifications
      gradeUpdated: boolean;                // Grade change notifications
      finalGrade: boolean;                  // Final grade notifications
      honorRoll: boolean;                   // Honor roll notifications
    };
    calendar: {
      eventReminder: boolean;               // Calendar event reminders
      eventChange: boolean;                 // Event change notifications
      reminderMinutesBefore: number;        // Minutes before event to remind
    };
  };
  
  // Device Tokens
  deviceTokens: Array<{
    token: string;                          // FCM device token
    platform: 'ios' | 'android' | 'web';   // Device platform
    deviceId: string;                       // Unique device identifier
    lastUsed: Timestamp;                    // Last token usage
    active: boolean;                        // Token status
  }>;
  
  // Metadata
  createdAt: Timestamp;
  updatedAt: Timestamp;
  version: number;                          // Preference schema version
}
```

#### notification_analytics Collection
```typescript
interface NotificationAnalyticsDocument {
  id: string;                               // Analytics record identifier
  userId?: string;                          // User-specific analytics (optional)
  classId?: string;                         // Class-specific analytics (optional)
  date: string;                             // Date in YYYY-MM-DD format
  period: 'daily' | 'weekly' | 'monthly';   // Analytics period
  
  // Delivery Metrics
  deliveryMetrics: {
    totalSent: number;                      // Total notifications sent
    totalDelivered: number;                 // Total successfully delivered
    totalFailed: number;                    // Total failed deliveries
    deliveryRate: number;                   // Delivery success rate (percentage)
    
    // By Channel
    channelMetrics: {
      [channel: string]: {
        sent: number;                       // Sent via this channel
        delivered: number;                  // Delivered via this channel
        failed: number;                     // Failed via this channel
        rate: number;                       // Success rate for this channel
      };
    };
    
    // By Type
    typeMetrics: {
      [type: string]: {
        sent: number;                       // Sent of this type
        delivered: number;                  // Delivered of this type
        engagementRate: number;             // Engagement rate for this type
      };
    };
  };
  
  // Engagement Metrics
  engagementMetrics: {
    totalOpened: number;                    // Total notifications opened
    totalClicked: number;                   // Total notifications clicked
    totalDismissed: number;                 // Total notifications dismissed
    openRate: number;                       // Open rate percentage
    clickRate: number;                      // Click-through rate percentage
    dismissalRate: number;                  // Dismissal rate percentage
    
    // Timing Analytics
    averageTimeToOpen: number;              // Average seconds to open
    averageEngagementTime: number;          // Average engagement duration
    peakEngagementHours: number[];          // Hours with highest engagement
    
    // Device & Platform
    platformMetrics: {
      [platform: string]: {
        delivered: number;                  // Delivered to this platform
        opened: number;                     // Opened on this platform
        engagementRate: number;             // Engagement rate for platform
      };
    };
  };
  
  // Content Performance
  contentAnalytics: {
    topPerformingTitles: Array<{
      title: string;                        // Notification title
      engagementRate: number;               // Engagement rate
      openRate: number;                     // Open rate
    }>;
    topPerformingTypes: Array<{
      type: string;                         // Notification type
      count: number;                        // Number sent
      engagementRate: number;               // Engagement rate
    }>;
    lowPerformingContent: Array<{
      title: string;                        // Low-performing title
      engagementRate: number;               // Poor engagement rate
      suggestions: string[];                // Improvement suggestions
    }>;
  };
  
  // User Behavior Insights
  userInsights: {
    preferredChannels: string[];            // User's preferred channels
    preferredTimes: string[];               // Preferred notification times
    engagementPatterns: {
      weekdayEngagement: number;            // Weekday engagement rate
      weekendEngagement: number;            // Weekend engagement rate
      morningEngagement: number;            // Morning engagement rate
      eveningEngagement: number;            // Evening engagement rate
    };
    optOutTrends: {
      totalOptOuts: number;                 // Total opt-outs in period
      optOutReasons: {
        [reason: string]: number;           // Opt-out reason counts
      };
    };
  };
  
  // Performance Benchmarks
  benchmarks: {
    industryAverageOpenRate: number;        // Industry benchmark open rate
    industryAverageClickRate: number;       // Industry benchmark click rate
    performanceScore: number;               // Overall performance score (0-100)
    recommendedImprovements: string[];      // Actionable recommendations
  };
}
```

## API Implementation

### NotificationProvider Core Methods

#### Notification Management
```dart
class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();
  final LocalNotificationService _localNotificationService = LocalNotificationService();
  final NotificationAnalyticsService _analyticsService = NotificationAnalyticsService();
  
  List<NotificationModel> _notifications = [];
  NotificationPreference? _preferences;
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  
  // Send notification
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    String? senderId,
    required NotificationType type,
    NotificationCategory category = NotificationCategory.academic,
    NotificationPriority priority = NotificationPriority.medium,
    List<NotificationChannel> channels = const [NotificationChannel.push, NotificationChannel.inApp],
    Map<String, dynamic>? payload,
    DateTime? scheduledFor,
    String? imageUrl,
    List<NotificationAction>? actions,
    String? deepLink,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Check user preferences
      final userPreferences = await _getUserPreferences(recipientId);
      final filteredChannels = _filterChannelsByPreferences(
        channels, 
        userPreferences, 
        type, 
        category, 
        priority,
      );
      
      if (filteredChannels.isEmpty) {
        // User has opted out of all notification channels for this type
        return;
      }
      
      // Create notification document
      final notification = NotificationModel(
        id: _firestore.collection('notifications').doc().id,
        recipientId: recipientId,
        senderId: senderId,
        type: type,
        category: category,
        priority: priority,
        title: title,
        body: body,
        channels: filteredChannels,
        deliveryMethod: scheduledFor != null 
            ? NotificationDeliveryMethod.scheduled 
            : NotificationDeliveryMethod.immediate,
        scheduledFor: scheduledFor,
        actions: actions ?? [],
        deepLink: deepLink,
        status: NotificationStatus.pending,
        createdAt: DateTime.now(),
        analytics: NotificationAnalytics.initial(),
        metadata: NotificationMetadata(
          customData: payload,
          tags: _generateTags(type, category, priority),
        ),
      );
      
      // Save notification to Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
      
      // Handle delivery based on method
      if (notification.deliveryMethod == NotificationDeliveryMethod.immediate) {
        await _deliverNotification(notification);
      } else {
        await _scheduleNotification(notification);
      }
      
      // Track analytics
      await _analyticsService.trackNotificationSent(
        notification,
        filteredChannels,
      );
      
    } catch (e) {
      _setError('Failed to send notification: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // Deliver notification through specified channels
  Future<void> _deliverNotification(NotificationModel notification) async {
    final deliveryResults = <NotificationChannel, bool>{};
    final deliveryErrors = <NotificationDeliveryError>[];
    
    for (final channel in notification.channels) {
      try {
        bool success = false;
        
        switch (channel) {
          case NotificationChannel.push:
            success = await _deliverPushNotification(notification);
            break;
            
          case NotificationChannel.inApp:
            success = await _deliverInAppNotification(notification);
            break;
            
          case NotificationChannel.email:
            success = await _deliverEmailNotification(notification);
            break;
            
          case NotificationChannel.sms:
            success = await _deliverSMSNotification(notification);
            break;
        }
        
        deliveryResults[channel] = success;
        
      } catch (e) {
        deliveryResults[channel] = false;
        deliveryErrors.add(NotificationDeliveryError(
          timestamp: DateTime.now(),
          error: e.toString(),
          channel: channel.name,
        ));
      }
    }
    
    // Update notification status
    final hasSuccessfulDelivery = deliveryResults.values.any((success) => success);
    final updatedNotification = notification.copyWith(
      status: hasSuccessfulDelivery 
          ? NotificationStatus.delivered 
          : NotificationStatus.failed,
      sentAt: DateTime.now(),
      deliveryAttempts: notification.deliveryAttempts + 1,
      lastDeliveryAttempt: DateTime.now(),
      deliveryErrors: [...notification.deliveryErrors, ...deliveryErrors],
      analytics: notification.analytics.copyWith(
        delivered: hasSuccessfulDelivery,
      ),
    );
    
    await _updateNotificationStatus(updatedNotification);
  }
  
  // Push notification delivery via FCM
  Future<bool> _deliverPushNotification(NotificationModel notification) async {
    try {
      // Get user device tokens
      final userPreferences = await _getUserPreferences(notification.recipientId);
      final activeTokens = userPreferences?.deviceTokens
          .where((token) => token.active)
          .map((token) => token.token)
          .toList() ?? [];
      
      if (activeTokens.isEmpty) {
        throw Exception('No active device tokens found');
      }
      
      // Prepare FCM message
      final fcmMessage = FCMMessage(
        tokens: activeTokens,
        notification: FCMNotificationPayload(
          title: notification.title,
          body: notification.body,
          imageUrl: notification.imageUrl,
        ),
        data: {
          'notificationId': notification.id,
          'type': notification.type.name,
          'category': notification.category.name,
          'priority': notification.priority.name,
          'deepLink': notification.deepLink ?? '',
          'payload': jsonEncode(notification.metadata.customData ?? {}),
        },
        androidConfig: FCMAndroidConfig(
          priority: notification.priority == NotificationPriority.critical
              ? AndroidMessagePriority.high
              : AndroidMessagePriority.normal,
          notification: FCMAndroidNotification(
            channelId: _getAndroidChannelId(notification.category),
            sound: userPreferences?.channelPreferences.push.soundEnabled ?? true
                ? 'default'
                : null,
            vibrationPattern: userPreferences?.channelPreferences.push.vibrationEnabled ?? true
                ? [0, 250, 250, 250]
                : null,
          ),
        ),
        iosConfig: FCMIOSConfig(
          payload: FCMIOSPayload(
            sound: userPreferences?.channelPreferences.push.soundEnabled ?? true
                ? 'default'
                : null,
            badge: userPreferences?.channelPreferences.push.badgeEnabled ?? true
                ? await _getUnreadCount(notification.recipientId) + 1
                : null,
          ),
        ),
      );
      
      // Send via FCM
      final response = await _fcmService.send(fcmMessage);
      
      // Handle token cleanup for invalid tokens
      await _handleInvalidTokens(response.failedTokens, notification.recipientId);
      
      return response.successCount > 0;
      
    } catch (e) {
      throw Exception('Push notification delivery failed: $e');
    }
  }
  
  // In-app notification delivery
  Future<bool> _deliverInAppNotification(NotificationModel notification) async {
    try {
      // Add to local in-app notifications list
      _notifications.insert(0, notification);
      
      // Update unread count
      if (notification.recipientId == _currentUserId) {
        _unreadCount++;
      }
      
      // Show local notification if app is in foreground
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await _localNotificationService.showInAppNotification(
          notification,
          userPreferences: await _getUserPreferences(notification.recipientId),
        );
      }
      
      notifyListeners();
      return true;
      
    } catch (e) {
      throw Exception('In-app notification delivery failed: $e');
    }
  }
  
  // Load user notifications with pagination
  Future<void> loadNotifications({
    String? userId,
    bool loadMore = false,
    int limit = 20,
  }) async {
    try {
      _setLoading(true);
      
      final targetUserId = userId ?? _currentUserId;
      if (targetUserId == null) {
        throw Exception('User not authenticated');
      }
      
      Query query = _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: targetUserId)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      
      if (loadMore && _notifications.isNotEmpty) {
        final lastDoc = await _firestore
            .collection('notifications')
            .doc(_notifications.last.id)
            .get();
        query = query.startAfterDocument(lastDoc);
      }
      
      final snapshot = await query.get();
      final newNotifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      
      if (loadMore) {
        _notifications.addAll(newNotifications);
      } else {
        _notifications = newNotifications;
      }
      
      // Calculate unread count
      _unreadCount = _notifications
          .where((n) => n.readAt == null)
          .length;
      
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to load notifications: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final now = DateTime.now();
      
      // Update in Firestore
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'readAt': Timestamp.fromDate(now),
        'status': NotificationStatus.read.name,
        'analytics.opened': true,
        'analytics.timeToOpen': FieldValue.serverTimestamp(),
      });
      
      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(
          readAt: now,
          status: NotificationStatus.read,
          analytics: _notifications[index].analytics.copyWith(opened: true),
        );
        _unreadCount = (_unreadCount - 1).clamp(0, _notifications.length);
      }
      
      // Track analytics
      await _analyticsService.trackNotificationOpened(
        notificationId,
        _currentUserId!,
      );
      
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to mark notification as read: $e');
    }
  }
  
  // Bulk operations
  Future<void> markAllAsRead({String? userId}) async {
    try {
      _setLoading(true);
      
      final targetUserId = userId ?? _currentUserId;
      final batch = _firestore.batch();
      
      // Get unread notifications
      final unreadNotifications = _notifications
          .where((n) => n.readAt == null)
          .toList();
      
      // Update in batch
      for (final notification in unreadNotifications) {
        batch.update(
          _firestore.collection('notifications').doc(notification.id),
          {
            'readAt': FieldValue.serverTimestamp(),
            'status': NotificationStatus.read.name,
            'analytics.opened': true,
          },
        );
      }
      
      await batch.commit();
      
      // Update local state
      final now = DateTime.now();
      _notifications = _notifications.map((n) {
        if (n.readAt == null) {
          return n.copyWith(
            readAt: now,
            status: NotificationStatus.read,
            analytics: n.analytics.copyWith(opened: true),
          );
        }
        return n;
      }).toList();
      
      _unreadCount = 0;
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to mark all as read: $e');
    } finally {
      _setLoading(false);
    }
  }
}
```

## FCM Service Implementation

### Firebase Cloud Messaging Integration
```dart
class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  // Initialize FCM
  static Future<void> initialize() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      throw Exception('Notification permission denied');
    }
    
    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // Configure message handlers
    _configureMessageHandlers();
    
    // Get and store FCM token
    await _updateFCMToken();
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);
  }
  
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
    
    // Create notification channels for Android
    await _createNotificationChannels();
  }
  
  static void _configureMessageHandlers() {
    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Background message handler (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    // App opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // App opened from terminated state
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageOpenedApp(message);
      }
    });
  }
  
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Show local notification when app is in foreground
    await _showLocalNotification(message);
    
    // Update in-app notification state
    final notificationProvider = GetIt.instance<NotificationProvider>();
    await notificationProvider.handleForegroundNotification(message);
  }
  
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    
    final androidDetails = AndroidNotificationDetails(
      _getChannelId(message.data['category'] ?? 'general'),
      _getChannelName(message.data['category'] ?? 'general'),
      channelDescription: 'Fermi app notifications',
      importance: _getImportance(message.data['priority'] ?? 'medium'),
      priority: _getPriority(message.data['priority'] ?? 'medium'),
      icon: '@mipmap/ic_launcher',
      largeIcon: notification.android?.imageUrl != null
          ? DrawableResourceAndroidBitmap('@mipmap/ic_launcher')
          : null,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }
  
  static Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin == null) return;
    
    // Academic notifications
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'academic',
        'Academic',
        description: 'Notifications about assignments, grades, and classes',
        importance: Importance.high,
      ),
    );
    
    // Social notifications
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'social',
        'Social',
        description: 'Messages and social interactions',
        importance: Importance.high,
      ),
    );
    
    // Administrative notifications
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'administrative',
        'Administrative',
        description: 'Administrative announcements and updates',
        importance: Importance.defaultImportance,
      ),
    );
    
    // Critical alerts
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'alert',
        'Alerts',
        description: 'Critical alerts and emergency notifications',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      ),
    );
  }
  
  static Future<String?> getFCMToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }
  
  static Future<void> _updateFCMToken() async {
    try {
      final token = await getFCMToken();
      if (token != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await _storeTokenInFirestore(token, currentUser.uid);
        }
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }
  
  static Future<void> _storeTokenInFirestore(String token, String userId) async {
    final deviceInfo = await _getDeviceInfo();
    
    await FirebaseFirestore.instance
        .collection('notification_preferences')
        .doc(userId)
        .set({
      'deviceTokens': FieldValue.arrayUnion([
        {
          'token': token,
          'platform': deviceInfo.platform,
          'deviceId': deviceInfo.deviceId,
          'lastUsed': FieldValue.serverTimestamp(),
          'active': true,
        }
      ])
    }, SetOptions(merge: true));
  }
  
  static Future<DeviceInfo> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final info = await deviceInfoPlugin.androidInfo;
      return DeviceInfo(
        platform: 'android',
        deviceId: info.id,
      );
    } else if (Platform.isIOS) {
      final info = await deviceInfoPlugin.iosInfo;
      return DeviceInfo(
        platform: 'ios',
        deviceId: info.identifierForVendor ?? 'unknown',
      );
    } else {
      return DeviceInfo(
        platform: 'web',
        deviceId: 'web-${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Handle background notification
  // This is typically for analytics tracking or data processing
  print('Background message: ${message.messageId}');
}
```

## Testing Implementation

### Unit Testing
```dart
group('Notification System Tests', () {
  late NotificationProvider notificationProvider;
  late MockFirestore mockFirestore;
  late MockFCMService mockFCMService;
  
  setUp(() {
    mockFirestore = MockFirestore();
    mockFCMService = MockFCMService();
    notificationProvider = NotificationProvider(
      firestore: mockFirestore,
      fcmService: mockFCMService,
    );
  });
  
  test('should send notification successfully', () async {
    when(mockFirestore.collection('notifications'))
        .thenReturn(mockCollectionReference);
    when(mockCollectionReference.doc())
        .thenReturn(mockDocumentReference);
    when(mockDocumentReference.set(any))
        .thenAnswer((_) async => {});
    
    await notificationProvider.sendNotification(
      recipientId: 'user123',
      title: 'Test Notification',
      body: 'This is a test notification',
      type: NotificationType.assignment,
    );
    
    verify(mockDocumentReference.set(any)).called(1);
  });
  
  test('should respect user notification preferences', () async {
    final preferences = NotificationPreference(
      userId: 'user123',
      channelPreferences: ChannelPreferences(
        push: ChannelPreference(enabled: false),
        inApp: ChannelPreference(enabled: true),
      ),
    );
    
    when(mockFirestore.collection('notification_preferences'))
        .thenReturn(mockCollectionReference);
    when(mockCollectionReference.doc('user123'))
        .thenReturn(mockDocumentReference);
    when(mockDocumentReference.get())
        .thenAnswer((_) async => mockDocumentSnapshot);
    when(mockDocumentSnapshot.data())
        .thenReturn(preferences.toMap());
    
    final filteredChannels = await notificationProvider
        .filterChannelsByPreferences(
      [NotificationChannel.push, NotificationChannel.inApp],
      preferences,
      NotificationType.assignment,
      NotificationCategory.academic,
      NotificationPriority.medium,
    );
    
    expect(filteredChannels, equals([NotificationChannel.inApp]));
  });
});
```

This comprehensive notification system provides robust multi-channel delivery, user preference management, and detailed analytics for educational platform engagement tracking.