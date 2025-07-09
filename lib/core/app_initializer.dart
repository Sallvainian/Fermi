import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../firebase_options.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
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
    
    // Setup service locator
    await _setupServiceLocator();
    
    // Initialize notification service
    if (_firebaseInitialized && !kIsWeb) {
      await _initializeNotifications();
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
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseInitialized = true;
      
      // Enable Firestore offline persistence
      if (!kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
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
  
  /// Handle uncaught errors in the app
  static void handleError(Object error, StackTrace stack) {
    LoggerService.error('Uncaught error in app', tag: 'AppInitializer', error: error);
    if (!kIsWeb && _firebaseInitialized) {
      FirebaseCrashlytics.instance.recordError(error, stack);
    }
  }
}