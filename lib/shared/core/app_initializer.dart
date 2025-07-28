import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import '../../config/firebase_options_env.dart';
import '../services/logger_service.dart';
import '../../features/notifications/data/services/notification_service.dart';
import '../../features/notifications/data/services/firebase_messaging_service.dart';
import '../../features/notifications/data/services/voip_token_service.dart';
import '../services/performance_service.dart';
import '../../features/auth/data/services/google_sign_in_service.dart';
import '../../features/auth/data/services/web_auth_helper_interface.dart';
import 'service_locator.dart';

/// Handles all app initialization tasks
class AppInitializer {
  static bool _firebaseInitialized = false;
  
  static bool get isFirebaseInitialized => _firebaseInitialized;
  
  /// Initialize all app dependencies
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Load environment variables
    await _loadEnvironment();
    
    // Initialize Firebase
    await _initializeFirebase();
    
    // Initialize Google Sign In (early in the startup)
    await _initializeGoogleSignIn();
    
    // Initialize web auth helper for COOP warning fix
    if (kIsWeb) {
      _initializeWebAuthHelper();
    }
    
    // Initialize performance monitoring (after Firebase)
    if (_firebaseInitialized) {
      await _initializePerformanceMonitoring();
    }
    
    // Setup service locator
    await _setupServiceLocator();
    
    // Initialize notification service
    if (_firebaseInitialized) {
      await _initializeNotifications();
    }
    
    // Initialize Firebase Messaging for VoIP
    if (_firebaseInitialized) {
      await _initializeFirebaseMessaging();
    }
    
    // Initialize VoIP token service for iOS
    if (_firebaseInitialized && !kIsWeb && Platform.isIOS) {
      await _initializeVoIPTokenService();
    }
    
    // Setup crash reporting
    if (_firebaseInitialized && !kIsWeb) {
      _setupCrashlytics();
    }
  }
  
  /// Load environment variables
  static Future<void> _loadEnvironment() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      LoggerService.info('Failed to load .env file', tag: 'AppInitializer');
    }
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
          tag: 'AppInitializer'
        );
        _firebaseInitialized = false;
        return;
      }
      
      await Firebase.initializeApp(
        options: EnvironmentFirebaseOptions.currentPlatform,
      );
      _firebaseInitialized = true;
      
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
        LoggerService.info('Firebase Realtime Database initialized', tag: 'AppInitializer');
      } catch (e) {
        LoggerService.warning('Firebase Realtime Database initialization error: $e', tag: 'AppInitializer');
      }
    } catch (e) {
      _firebaseInitialized = false;
      LoggerService.error('Firebase initialization error', tag: 'AppInitializer', error: e);
    }
  }
  
  /// Setup dependency injection
  static Future<void> _setupServiceLocator() async {
    try {
      await setupServiceLocator();
    } catch (e) {
      LoggerService.error('Service locator setup error', tag: 'AppInitializer', error: e);
    }
  }
  
  /// Initialize performance monitoring
  static Future<void> _initializePerformanceMonitoring() async {
    try {
      // Initialize performance monitoring asynchronously to avoid blocking main thread
      unawaited(PerformanceService().initialize());
      LoggerService.debug('Performance monitoring initialized (async)', tag: 'AppInitializer');
    } catch (e) {
      LoggerService.error('Performance monitoring initialization error', tag: 'AppInitializer', error: e);
    }
  }
  
  /// Initialize notification service
  static Future<void> _initializeNotifications() async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.requestPermissions();
      LoggerService.info('Notification service initialized', tag: 'AppInitializer');
    } catch (e) {
      LoggerService.error('Notification initialization error', tag: 'AppInitializer', error: e);
    }
  }
  
  /// Initialize Firebase Messaging for VoIP support
  static Future<void> _initializeFirebaseMessaging() async {
    try {
      final messagingService = FirebaseMessagingService();
      await messagingService.initialize();
      LoggerService.info('Firebase Messaging initialized for VoIP', tag: 'AppInitializer');
    } catch (e) {
      LoggerService.error('Firebase Messaging initialization error', tag: 'AppInitializer', error: e);
    }
  }
  
  /// Initialize VoIP token service for iOS
  static Future<void> _initializeVoIPTokenService() async {
    try {
      final voipTokenService = VoIPTokenService();
      await voipTokenService.initialize();
      LoggerService.info('VoIP token service initialized', tag: 'AppInitializer');
    } catch (e) {
      LoggerService.error('VoIP token service initialization error', tag: 'AppInitializer', error: e);
    }
  }
  
  /// Configure Crashlytics error reporting
  static void _setupCrashlytics() {
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    
    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  
  /// Initialize Google Sign In service
  static Future<void> _initializeGoogleSignIn() async {
    try {
      // Initialize with required scopes
      // In google_sign_in 6.x, this is synchronous  
      GoogleSignInService().initialize();
      LoggerService.info('Google Sign In initialized', tag: 'AppInitializer');
    } catch (e) {
      LoggerService.error('Google Sign In initialization error', tag: 'AppInitializer', error: e);
    }
  }
  
  /// Initialize web auth helper for COOP warning prevention
  static void _initializeWebAuthHelper() {
    try {
      WebAuthHelper().initialize();
      LoggerService.info('Web Auth Helper initialized', tag: 'AppInitializer');
    } catch (e) {
      LoggerService.error('Web Auth Helper initialization error', tag: 'AppInitializer', error: e);
    }
  }
  
  
  /// Handle uncaught errors in the app
  static void handleError(Object error, StackTrace stack) {
    LoggerService.error('Uncaught error in app', tag: 'AppInitializer', error: error);
    if (!kIsWeb && _firebaseInitialized) {
      FirebaseCrashlytics.instance.recordError(error, stack);
    }
  }
}