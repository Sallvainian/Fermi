import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/auth_service.dart';
import '../services/assignment_service.dart';
import '../services/chat_service.dart';
import '../services/submission_service.dart';
import '../services/test_service.dart';
import '../services/logger_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/auth_repository_impl.dart';
import '../repositories/assignment_repository.dart';
import '../repositories/assignment_repository_impl.dart';
import '../repositories/class_repository.dart';
import '../repositories/class_repository_impl.dart';
import '../repositories/grade_repository.dart';
import '../repositories/grade_repository_impl.dart';
import '../repositories/student_repository.dart';
import '../repositories/student_repository_impl.dart';
import '../repositories/submission_repository.dart';
import '../repositories/submission_repository_impl.dart';
import '../repositories/chat_repository.dart';
import '../repositories/chat_repository_impl.dart';

final GetIt getIt = GetIt.instance;

/// Initialize all services and dependencies
Future<void> setupServiceLocator() async {
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
  
  // Register services with dependencies
  getIt.registerFactory<AssignmentService>(
    () => AssignmentService(firestore: getIt<FirebaseFirestore>()),
  );
  
  getIt.registerFactory<ChatService>(() => ChatService());  
  getIt.registerFactory<SubmissionService>(
    () => SubmissionService(firestore: getIt<FirebaseFirestore>()),
  );
  
  getIt.registerFactory<TestService>(() => TestService());
  
  // Note: Providers will be refactored to use these services via dependency injection
  // rather than creating service instances directly
}

/// Helper extension for easy access to services
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
  AssignmentService get assignmentService => get<AssignmentService>();
  ChatService get chatService => get<ChatService>();
  SubmissionService get submissionService => get<SubmissionService>();
  TestService get testService => get<TestService>();
  LoggerService get loggerService => get<LoggerService>();
}