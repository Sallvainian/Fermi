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
import '../utils/platform_utils.dart';
import 'app_initializer.dart';
import '../../features/assignments/domain/repositories/assignment_repository.dart';
import '../../features/assignments/data/repositories/assignment_repository_impl.dart';
import '../../features/classes/domain/repositories/class_repository.dart';
import '../../features/classes/data/repositories/class_repository_impl.dart';
import '../../features/grades/domain/repositories/grade_repository.dart';
import '../../features/grades/data/repositories/grade_repository_impl.dart';
import '../../features/student/domain/repositories/student_repository.dart';
import '../../features/student/data/repositories/student_repository_impl.dart';
import '../../features/assignments/domain/repositories/submission_repository.dart';
import '../../features/assignments/data/repositories/submission_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
// Discussion repository removed - using direct Firestore in SimpleDiscussionProvider
// import '../../features/discussions/domain/repositories/discussion_repository.dart';
// import '../../features/discussions/data/repositories/discussion_repository_impl.dart';
import '../../features/calendar/domain/repositories/calendar_repository.dart';
import '../../features/calendar/data/repositories/calendar_repository_impl.dart';
import '../../features/calendar/data/services/calendar_service.dart';
import '../../features/games/domain/repositories/jeopardy_repository.dart';
import '../../features/games/data/repositories/firebase_jeopardy_repository.dart';

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

  // Check Firebase initialization status
  if (!AppInitializer.isFirebaseInitialized) {
    LoggerService.warning(
      'Firebase not initialized - skipping Firebase service registration',
      tag: 'ServiceLocator'
    );
    
    // Register only essential non-Firebase services
    getIt.registerLazySingleton<LoggerService>(() => LoggerService());
    return;
  }
  
  // Firebase is initialized (either regular Firebase or firebase_dart)
  LoggerService.info(
    'Firebase is initialized - registering all services',
    tag: 'ServiceLocator'
  );

  // Register Firebase instances (works with both firebase_core and firebase_dart)
  if (PlatformUtils.needsWindowsServices) {
    // For Windows, we use firebase_dart instances
    // These are accessed through our platform-specific services
    LoggerService.info('Registering firebase_dart instances for Windows', tag: 'ServiceLocator');
  } else {
    // For other platforms, use regular Firebase instances
    getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
    getIt.registerLazySingleton<FirebaseFirestore>(
        () => FirebaseFirestore.instance);
    getIt.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
    LoggerService.info('Registered standard Firebase instances', tag: 'ServiceLocator');
  }

  // Register services
  getIt.registerLazySingleton<AuthService>(() => AuthService());
  getIt.registerLazySingleton<LoggerService>(() => LoggerService());

  // Register repositories (these will use platform-specific services via ServiceFactory)
  if (!PlatformUtils.needsWindowsServices) {
    getIt.registerLazySingleton<AssignmentRepository>(
      () => AssignmentRepositoryImpl(getIt<FirebaseFirestore>()),
    );
  } else {
    // For Windows, repositories will use firebase_dart through ServiceFactory
    LoggerService.info('Windows repositories will use ServiceFactory pattern', tag: 'ServiceLocator');
  }

  if (!PlatformUtils.needsWindowsServices) {
    getIt.registerLazySingleton<ClassRepository>(
      () => ClassRepositoryImpl(getIt<FirebaseFirestore>()),
    );

    getIt.registerLazySingleton<GradeRepository>(
      () => GradeRepositoryImpl(getIt<FirebaseFirestore>()),
    );

    getIt.registerLazySingleton<StudentRepository>(
      () => StudentRepositoryImpl(getIt<FirebaseFirestore>()),
    );

    getIt.registerLazySingleton<SubmissionRepository>(
      () => SubmissionRepositoryImpl(getIt<FirebaseFirestore>()),
    );

    getIt.registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(getIt<FirebaseFirestore>(), getIt<FirebaseAuth>()),
    );
  }

  // Discussion repository removed - using direct Firestore in SimpleDiscussionProvider
  // getIt.registerLazySingleton<DiscussionRepository>(
  //   () => DiscussionRepositoryImpl(getIt<FirebaseFirestore>(), getIt<FirebaseAuth>()),
  // );

  if (!PlatformUtils.needsWindowsServices) {
    getIt.registerLazySingleton<CalendarRepository>(
      () => CalendarRepositoryImpl(getIt<FirebaseFirestore>()),
    );

    getIt.registerLazySingleton<JeopardyRepository>(
      () => FirebaseJeopardyRepository(firestore: getIt<FirebaseFirestore>()),
    );
  }

  // Register services with dependencies (if not Windows)
  if (!PlatformUtils.needsWindowsServices) {
    getIt.registerFactory<AssignmentService>(
      () => AssignmentService(firestore: getIt<FirebaseFirestore>()),
    );

    getIt.registerFactory<ChatService>(() => ChatService());
    getIt.registerFactory<SubmissionService>(
      () => SubmissionService(firestore: getIt<FirebaseFirestore>()),
    );

    getIt.registerFactory<CalendarService>(
      () => CalendarService(
        getIt<CalendarRepository>(),
        getIt<ClassRepository>(),
      ),
    );
  }

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
  AssignmentRepository get assignmentRepository => get<AssignmentRepository>();
  ClassRepository get classRepository => get<ClassRepository>();
  GradeRepository get gradeRepository => get<GradeRepository>();
  StudentRepository get studentRepository => get<StudentRepository>();
  SubmissionRepository get submissionRepository => get<SubmissionRepository>();
  ChatRepository get chatRepository => get<ChatRepository>();
  // DiscussionRepository get discussionRepository => get<DiscussionRepository>();
  CalendarRepository get calendarRepository => get<CalendarRepository>();
  AssignmentService get assignmentService => get<AssignmentService>();
  ChatService get chatService => get<ChatService>();
  SubmissionService get submissionService => get<SubmissionService>();
  CalendarService get calendarService => get<CalendarService>();
  LoggerService get loggerService => get<LoggerService>();
  JeopardyRepository get jeopardyRepository => get<JeopardyRepository>();
}
