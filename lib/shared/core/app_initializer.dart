import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../../config/firebase_options.dart';
import '../services/logger_service.dart';
import '../../features/notifications/data/services/notification_service.dart';
import '../../features/notifications/data/services/firebase_messaging_service.dart';
import '../../features/notifications/data/services/voip_token_service.dart';
import '../services/performance_service.dart';
import 'service_locator.dart';

/// Handles all app initialization tasks
class AppInitializer {
  static bool _firebaseInitialized = false;

  static bool get isFirebaseInitialized => _firebaseInitialized;

  /// Initialize all app dependencies
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // CRITICAL: Initialize Firebase first (required for everything)
    await _initializeFirebase();

    // CRITICAL: Setup service locator (required for dependency injection)
    await _setupServiceLocator();

    // DEFER: Everything else happens after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeferredServices();
    });
  }

  /// Initialize non-critical services after first frame render
  static Future<void> _initializeDeferredServices() async {
    if (!_firebaseInitialized) return;

    // Initialize in parallel for faster startup
    await Future.wait([
      // Performance monitoring is not critical
      _initializePerformanceMonitoring(),

      // Notifications can be initialized later
      _initializeNotifications(),

      // Messaging services for VoIP
      if (!kIsWeb) _initializeFirebaseMessaging(),

      // iOS-specific VoIP
      if (!kIsWeb && Platform.isIOS) _initializeVoIPTokenService(),
    ]);

    LoggerService.info('Deferred services initialized', tag: 'AppInitializer');
  }

  /// Initialize Firebase services
  static Future<void> _initializeFirebase() async {
    try {
      // On Linux desktop, Firebase is not supported natively
      // For development, we can either:
      // 1. Use Firebase emulators
      // 2. Run as a web app
      // 3. Skip Firebase for local testing
      if (defaultTargetPlatform == TargetPlatform.linux && !kIsWeb) {
        LoggerService.warning(
            'Firebase is not supported on Linux desktop. '
            'Consider running with: flutter run -d web-server',
            tag: 'AppInitializer');
        _firebaseInitialized = false;
        return;
      }

      LoggerService.info('Starting Firebase initialization...',
          tag: 'AppInitializer');

      // Check if Firebase is already initialized to avoid duplicate app error
      try {
        if (Firebase.apps.isEmpty) {
          // Use simple Firebase initialization with DefaultFirebaseOptions
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          LoggerService.info('Firebase initialized successfully',
              tag: 'AppInitializer');
        } else {
          LoggerService.info('Firebase already initialized, reusing existing instance',
              tag: 'AppInitializer');
        }
        _firebaseInitialized = true;
      } catch (e) {
        // If it's a duplicate app error, we can still proceed
        if (e.toString().contains('duplicate-app')) {
          LoggerService.warning('Firebase duplicate app error ignored',
              tag: 'AppInitializer');
          _firebaseInitialized = true;
        } else {
          // For other errors, rethrow
          rethrow;
        }
      }

      LoggerService.info('Firebase core initialized successfully',
          tag: 'AppInitializer');

      // Auth persistence is now handled in AuthService constructor

      // Skip emulator configuration for now
      // The Android emulator has issues with Google Play Services

      // Enable Firestore offline persistence
      if (!kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }

      // Initialize Firebase Realtime Database
      try {
        final database = FirebaseDatabase.instance;
        if (!kIsWeb) {
          // Enable offline persistence for Realtime Database
          database.setPersistenceEnabled(true);
        }
        LoggerService.info('Firebase Realtime Database initialized',
            tag: 'AppInitializer');
      } catch (e) {
        LoggerService.warning(
            'Firebase Realtime Database initialization error: $e',
            tag: 'AppInitializer');
      }
    } catch (e) {
      // Only set to false if we didn't handle the error above
      if (!_firebaseInitialized) {
        _firebaseInitialized = false;
        LoggerService.error('Firebase initialization error',
            tag: 'AppInitializer', error: e);
        // Don't rethrow - we've handled duplicate app errors above
      }
    }
  }

  /// Setup dependency injection
  static Future<void> _setupServiceLocator() async {
    try {
      await setupServiceLocator();
    } catch (e) {
      LoggerService.error('Service locator setup error',
          tag: 'AppInitializer', error: e);
    }
  }

  /// Initialize performance monitoring
  static Future<void> _initializePerformanceMonitoring() async {
    try {
      // Initialize performance monitoring asynchronously to avoid blocking main thread
      unawaited(PerformanceService().initialize());
      LoggerService.debug('Performance monitoring initialized (async)',
          tag: 'AppInitializer');
    } catch (e) {
      LoggerService.error('Performance monitoring initialization error',
          tag: 'AppInitializer', error: e);
    }
  }

  /// Initialize notification service
  static Future<void> _initializeNotifications() async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      // Only request permissions on mobile platforms, not web
      if (!kIsWeb) {
        await notificationService.requestPermissions();
      }
      LoggerService.info('Notification service initialized',
          tag: 'AppInitializer');
    } catch (e) {
      LoggerService.error('Notification initialization error',
          tag: 'AppInitializer', error: e);
    }
  }

  /// Initialize Firebase Messaging for VoIP support
  static Future<void> _initializeFirebaseMessaging() async {
    if (kIsWeb) {
      // Foreground-only on web → do not initialize FCM at all
      return;
    }
    try {
      final messagingService = FirebaseMessagingService();
      await messagingService.initialize();
      LoggerService.info('Firebase Messaging initialized for VoIP',
          tag: 'AppInitializer');
    } catch (e) {
      LoggerService.error('Firebase Messaging initialization error',
          tag: 'AppInitializer', error: e);
    }
  }

  /// Initialize VoIP token service for iOS
  static Future<void> _initializeVoIPTokenService() async {
    try {
      final voipTokenService = VoIPTokenService();
      await voipTokenService.initialize();
      LoggerService.info('VoIP token service initialized',
          tag: 'AppInitializer');
    } catch (e) {
      LoggerService.error('VoIP token service initialization error',
          tag: 'AppInitializer', error: e);
    }
  }

  /// Handle uncaught errors in the app
  static void handleError(Object error, StackTrace stack) {
    LoggerService.error('Uncaught error in app',
        tag: 'AppInitializer', error: error);
  }
}
