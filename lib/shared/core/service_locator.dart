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
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/auth_service.dart';
import '../services/assignment_service.dart';
import '../services/chat_service.dart';
import '../services/submission_service.dart';
import '../services/logger_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/auth_repository_impl.dart';
import '../repositories/assignment_repository.dart';
import '../repositories/assignment_repository_impl.dart';
import '../../features/classes/domain/repositories/class_repository.dart';
import '../../features/classes/data/repositories/class_repository_impl.dart';
import '../repositories/grade_repository.dart';
import '../repositories/grade_repository_impl.dart';
import '../repositories/student_repository.dart';
import '../repositories/student_repository_impl.dart';
import '../repositories/submission_repository.dart';
import '../repositories/submission_repository_impl.dart';
import '../repositories/chat_repository.dart';
import '../repositories/chat_repository_impl.dart';
import '../../features/discussions/domain/repositories/discussion_repository.dart';
import '../../features/discussions/data/repositories/discussion_repository_impl.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/calendar_repository_impl.dart';
import '../repositories/user_repository.dart';
import '../repositories/user_repository_impl.dart';
import '../services/calendar_service.dart';

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
///    - FirebaseCrashlytics for error reporting
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
  
  // Register Firebase instances
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  getIt.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  getIt.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  getIt.registerLazySingleton<FirebaseCrashlytics>(() => FirebaseCrashlytics.instance);

  // Register services
  getIt.registerLazySingleton<AuthService>(() => AuthService());
  getIt.registerLazySingleton<LoggerService>(() => LoggerService());
  
  // Register repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<AuthService>()),
  );
  
  getIt.registerLazySingleton<AssignmentRepository>(
    () => AssignmentRepositoryImpl(getIt<FirebaseFirestore>()),
  );
  
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
  
  getIt.registerLazySingleton<DiscussionRepository>(
    () => DiscussionRepositoryImpl(getIt<FirebaseFirestore>(), getIt<FirebaseAuth>()),
  );
  
  getIt.registerLazySingleton<CalendarRepository>(
    () => CalendarRepositoryImpl(getIt<FirebaseFirestore>()),
  );
  
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(getIt<FirebaseFirestore>()),
  );
  
  // Register services with dependencies
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
      getIt<UserRepository>(),
      getIt<ClassRepository>(),
    ),
  );
  
  // CalendarService registered
  
  // Note: Providers will be refactored to use these services via dependency injection
  // rather than creating service instances directly
  // Service locator setup complete
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
  FirebaseCrashlytics get crashlytics => get<FirebaseCrashlytics>();
  
  AuthService get authService => get<AuthService>();
  AuthRepository get authRepository => get<AuthRepository>();
  AssignmentRepository get assignmentRepository => get<AssignmentRepository>();
  ClassRepository get classRepository => get<ClassRepository>();
  GradeRepository get gradeRepository => get<GradeRepository>();
  StudentRepository get studentRepository => get<StudentRepository>();
  SubmissionRepository get submissionRepository => get<SubmissionRepository>();
  ChatRepository get chatRepository => get<ChatRepository>();
  DiscussionRepository get discussionRepository => get<DiscussionRepository>();
  CalendarRepository get calendarRepository => get<CalendarRepository>();
  UserRepository get userRepository => get<UserRepository>();
  AssignmentService get assignmentService => get<AssignmentService>();
  ChatService get chatService => get<ChatService>();
  SubmissionService get submissionService => get<SubmissionService>();
  CalendarService get calendarService => get<CalendarService>();
  LoggerService get loggerService => get<LoggerService>();
}