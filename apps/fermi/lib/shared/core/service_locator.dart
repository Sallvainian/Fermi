/// Service locator configuration for dependency injection.
///
/// This module sets up the application's dependency injection container
/// using the GetIt package. It provides a centralized location for
/// registering and resolving dependencies throughout the application.
///
/// The service locator pattern helps:
/// - Decouple classes from their dependencies
/// - Enable easy testing with mock implementations
/// - Provide a single source of truth for object creation
/// - Manage object lifecycles (singleton vs factory)
library;

import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/assignments/data/services/assignment_service.dart';
import '../../features/chat/data/services/chat_service.dart';
import '../../features/assignments/data/services/submission_service.dart';
import '../services/logger_service.dart';
import 'app_initializer.dart';
// All repository imports removed - using direct Firestore access
// Repository pattern removed in favor of simpler direct Firebase SDK usage

/// Global instance of the GetIt service locator.
/// This provides access to registered dependencies throughout the app.
final GetIt getIt = GetIt.instance;

/// Initializes and registers all application dependencies.
///
/// This function must be called during app initialization (in main.dart)
/// after Firebase has been initialized. It sets up:
///
/// 1. **Firebase Services** (as singletons):
///    - FirebaseAuth for authentication
///    - FirebaseFirestore for database operations
///    - FirebaseStorage for file storage
///
/// 2. **Core Services** (as singletons):
///    - AuthService for authentication logic
///    - LoggerService for centralized logging
///
/// 3. **Repository Layer** (as singletons):
///    - All repository implementations that abstract data access
///
/// 4. **Business Logic Services** (as factories):
///    - Services that contain business logic and use repositories
///
/// Registration types:
/// - `registerLazySingleton`: Creates instance only when first requested, then reuses
/// - `registerFactory`: Creates new instance each time it's requested
///
/// @throws Exception if Firebase is not initialized before calling this
Future<void> setupServiceLocator() async {
  // Setting up service locator...
  
  // Prevent double registration
  if (getIt.isRegistered<FirebaseAuth>()) {
    LoggerService.info('Service locator already initialized - skipping', tag: 'ServiceLocator');
    return;
  }

  // Check Firebase initialization status
  if (!AppInitializer.isFirebaseInitialized) {
    LoggerService.warning(
      'Firebase not initialized - skipping Firebase service registration',
      tag: 'ServiceLocator'
    );
    return;
  }
  
  // Firebase is initialized (either regular Firebase or firebase_dart)
  LoggerService.info(
    'Firebase is initialized - registering all services',
    tag: 'ServiceLocator'
  );

  // Register Firebase instances
  try {
    getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
    getIt.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
    getIt.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
    LoggerService.info('Registered Firebase instances', tag: 'ServiceLocator');
  } catch (e) {
    LoggerService.error('Failed to register Firebase instances', tag: 'ServiceLocator', error: e);
  }

  // Register services
  getIt.registerLazySingleton<AuthService>(() => AuthService());
  // LoggerService is a singleton that doesn't need GetIt

  // Repositories removed - using direct Firestore access in providers
  // This reduces code complexity by ~7,000 lines

  // Register services with dependencies
  getIt.registerFactory<AssignmentService>(
    () => AssignmentService(firestore: getIt<FirebaseFirestore>()),
  );

  getIt.registerFactory<ChatService>(() => ChatService());
  getIt.registerFactory<SubmissionService>(
    () => SubmissionService(firestore: getIt<FirebaseFirestore>()),
  );

  // Calendar service removed - using direct Firestore access

  LoggerService.info('Service locator setup complete', tag: 'ServiceLocator');
}

/// Convenience extension for accessing registered services.
///
/// This extension provides type-safe getters for all registered services,
/// making it easier to retrieve dependencies without having to specify
/// the type parameter each time.
///
/// Usage example:
/// ```dart
/// final auth = getIt.auth; // Instead of getIt.get<FirebaseAuth>()
/// final userRepo = getIt.authRepository; // Instead of getIt.get<AuthRepository>()
/// ```
///
/// Benefits:
/// - Cleaner, more readable code
/// - Compile-time type safety
/// - IntelliSense support for available services
/// - Single point of maintenance for service names
extension ServiceLocatorExtension on GetIt {
  FirebaseAuth get auth => get<FirebaseAuth>();
  FirebaseFirestore get firestore => get<FirebaseFirestore>();
  FirebaseStorage get storage => get<FirebaseStorage>();

  AuthService get authService => get<AuthService>();
  AssignmentService get assignmentService => get<AssignmentService>();
  ChatService get chatService => get<ChatService>();
  SubmissionService get submissionService => get<SubmissionService>();
  // LoggerService is a singleton - use LoggerService.method() directly
  // Repository getters removed - using direct Firestore access
}
