/// Enhanced ClassService with performance monitoring integration.
/// 
/// This service extends the original ClassService with comprehensive
/// performance monitoring, caching, and error handling improvements.
library;

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/class_model.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/services/performance_service.dart';
import '../../../../shared/services/cache_service.dart';
import '../../../../shared/services/retry_service.dart';
import '../../../../shared/services/validation_service.dart';

/// Enhanced service class for managing educational classes with performance monitoring.
/// 
/// Provides all the functionality of the original ClassService with additional:
/// - Performance monitoring and metrics
/// - Intelligent caching for frequently accessed data
/// - Retry mechanisms for network operations
/// - Input validation and sanitization
/// - Comprehensive error handling
class ClassServiceEnhanced {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CacheService _cache = CacheService();
  final PerformanceService _performance = PerformanceService();
  
  /// Collection reference for classes in Firestore
  CollectionReference<Map<String, dynamic>> get _classesCollection => 
      _firestore.collection('classes');

  /// Creates a new class with performance monitoring and validation.
  /// 
  /// Includes automatic performance tracking, input validation,
  /// and caching of the created class.
  /// 
  /// @param classModel Class data to create
  /// @return Created class with assigned ID and enrollment code
  /// @throws Exception if validation fails or creation fails
  Future<ClassModel> createClass(ClassModel classModel) async {
    return await _performance.timeOperation(
      'create_class',
      () async {
        try {
          // Validate input data
          _validateClassModel(classModel);
          
          // Generate unique enrollment code with retry
          final enrollmentCode = await RetryService.withRetry(
            () => _generateUniqueEnrollmentCode(),
            config: RetryConfigs.standard,
          );
          
          // Create class with enrollment code
          final classWithCode = classModel.copyWith(
            enrollmentCode: enrollmentCode,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          // Add to Firestore with retry
          final docRef = await RetryService.withRetry(
            () => _classesCollection.add(classWithCode.toFirestore()),
            config: RetryConfigs.standard,
          );
          
          // Return class with generated ID
          final createdClass = classWithCode.copyWith(id: docRef.id);
          
          // Cache the created class
          await _cache.set(
            'class_${docRef.id}',
            createdClass.toFirestore(),
            ttl: const Duration(hours: 2),
          );
          
          // Cache enrollment code for quick lookup
          await _cache.set(
            'enrollment_code_$enrollmentCode',
            createdClass.toFirestore(),
            ttl: const Duration(hours: 24),
          );
          
          // Record custom metrics
          _performance.recordMetric('class_created', 1);
          _performance.recordMetric('enrollment_codes_generated', 1);
          
          LoggerService.info(
            'Created class: ${createdClass.name} with enrollment code: $enrollmentCode (ID: ${createdClass.id}, Teacher: ${createdClass.teacherId})',
          );
          
          return createdClass;
          
        } catch (e) {
          LoggerService.error(
            'Error creating class: ${classModel.name}',
            error: e,
          );
          rethrow;
        }
      },
      attributes: {
        'class_name': classModel.name,
        'teacher_id': classModel.teacherId,
        'operation': 'create',
      },
    );
  }

  /// Updates an existing class with performance monitoring.
  /// 
  /// Includes cache invalidation and performance tracking.
  /// 
  /// @param classModel Updated class data
  /// @return Updated class model
  Future<ClassModel> updateClass(ClassModel classModel) async {
    return await _performance.timeOperation(
      'update_class',
      () async {
        try {
          // Validate input data
          _validateClassModel(classModel);
          
          final updatedClass = classModel.copyWith(
            updatedAt: DateTime.now(),
          );
          
          // Update in Firestore with retry
          await RetryService.withRetry(
            () => _classesCollection
                .doc(classModel.id)
                .update(updatedClass.toFirestore()),
            config: RetryConfigs.standard,
          );
          
          // Update cache
          await _cache.set(
            'class_${classModel.id}',
            updatedClass.toFirestore(),
            ttl: const Duration(hours: 2),
          );
          
          // Invalidate related caches
          await _cache.clearPattern('teacher_classes_${classModel.teacherId}');
          await _cache.clearPattern('class_stats_${classModel.id}');
          
          // Record metrics
          _performance.recordMetric('class_updated', 1);
          
          LoggerService.info(
            'Updated class: ${classModel.name} (ID: ${classModel.id})',
          );
          
          return updatedClass;
          
        } catch (e) {
          LoggerService.error(
            'Error updating class (ID: ${classModel.id})',
            error: e,
          );
          rethrow;
        }
      },
      attributes: {
        'class_id': classModel.id,
        'class_name': classModel.name,
        'operation': 'update',
      },
    );
  }

  /// Retrieves a class by ID with caching and performance monitoring.
  /// 
  /// Checks cache first, then Firestore if not found.
  /// 
  /// @param classId ID of the class to retrieve
  /// @return Class model if found, null otherwise
  Future<ClassModel?> getClassById(String classId) async {
    return await _performance.timeOperation(
      'get_class_by_id',
      () async {
        try {
          // Check cache first
          final cachedClass = await _cache.get<Map<String, dynamic>>('class_$classId');
          if (cachedClass != null) {
            _performance.recordMetric('cache_hit_class_by_id', 1);
            // Create ClassModel directly from cached data
            return ClassModel(
              id: classId,
              teacherId: cachedClass['teacherId'] ?? '',
              name: cachedClass['name'] ?? '',
              subject: cachedClass['subject'] ?? '',
              description: cachedClass['description'],
              gradeLevel: cachedClass['gradeLevel'] ?? '',
              room: cachedClass['room'],
              schedule: cachedClass['schedule'],
              studentIds: List<String>.from(cachedClass['studentIds'] ?? []),
              maxStudents: cachedClass['maxStudents'],
              enrollmentCode: cachedClass['enrollmentCode'],
              isActive: cachedClass['isActive'] ?? true,
              academicYear: cachedClass['academicYear'] ?? '',
              semester: cachedClass['semester'] ?? '',
              createdAt: cachedClass['createdAt'] is String 
                ? DateTime.parse(cachedClass['createdAt'])
                : cachedClass['createdAt']?.toDate() ?? DateTime.now(),
              updatedAt: cachedClass['updatedAt'] is String 
                ? DateTime.parse(cachedClass['updatedAt'])
                : cachedClass['updatedAt']?.toDate(),
              settings: cachedClass['settings'] != null 
                ? Map<String, dynamic>.from(cachedClass['settings']) 
                : null,
            );
          }
          
          // Get from Firestore with retry
          final doc = await RetryService.withRetry(
            () => _classesCollection.doc(classId).get(),
            config: RetryConfigs.fast,
          );
          
          if (!doc.exists) {
            _performance.recordMetric('class_not_found', 1);
            return null;
          }
          
          final classModel = ClassModel.fromFirestore(doc);
          
          // Cache the result
          await _cache.set(
            'class_$classId',
            classModel.toFirestore(),
            ttl: const Duration(hours: 2),
          );
          
          _performance.recordMetric('class_retrieved', 1);
          return classModel;
          
        } catch (e) {
          LoggerService.error(
            'Error getting class by ID: $classId',
            error: e,
          );
          rethrow;
        }
      },
      attributes: {
        'class_id': classId,
        'operation': 'get_by_id',
      },
    );
  }

  /// Retrieves a class by enrollment code with caching.
  /// 
  /// Uses cached enrollment code lookups for performance.
  /// 
  /// @param enrollmentCode The enrollment code to search for
  /// @return Class model if found, null otherwise
  Future<ClassModel?> getClassByEnrollmentCode(String enrollmentCode) async {
    return await _performance.timeOperation(
      'get_class_by_enrollment_code',
      () async {
        try {
          // Validate enrollment code format
          final codeValidation = ValidationService.validateClassCode(enrollmentCode);
          if (codeValidation != null) {
            throw Exception('Invalid enrollment code format: $codeValidation');
          }
          
          // Check cache first
          final cachedClass = await _cache.get<Map<String, dynamic>>(
            'enrollment_code_$enrollmentCode',
          );
          if (cachedClass != null) {
            _performance.recordMetric('cache_hit_enrollment_code', 1);
            // Create ClassModel directly from cached data
            return ClassModel(
              id: cachedClass['id'] ?? 'cached_class',
              teacherId: cachedClass['teacherId'] ?? '',
              name: cachedClass['name'] ?? '',
              subject: cachedClass['subject'] ?? '',
              description: cachedClass['description'],
              gradeLevel: cachedClass['gradeLevel'] ?? '',
              room: cachedClass['room'],
              schedule: cachedClass['schedule'],
              studentIds: List<String>.from(cachedClass['studentIds'] ?? []),
              maxStudents: cachedClass['maxStudents'],
              enrollmentCode: cachedClass['enrollmentCode'],
              isActive: cachedClass['isActive'] ?? true,
              academicYear: cachedClass['academicYear'] ?? '',
              semester: cachedClass['semester'] ?? '',
              createdAt: cachedClass['createdAt'] is String 
                ? DateTime.parse(cachedClass['createdAt'])
                : cachedClass['createdAt']?.toDate() ?? DateTime.now(),
              updatedAt: cachedClass['updatedAt'] is String 
                ? DateTime.parse(cachedClass['updatedAt'])
                : cachedClass['updatedAt']?.toDate(),
              settings: cachedClass['settings'] != null 
                ? Map<String, dynamic>.from(cachedClass['settings']) 
                : null,
            );
          }
          
          // Query Firestore with retry
          final querySnapshot = await RetryService.withRetry(
            () => _classesCollection
                .where('enrollmentCode', isEqualTo: enrollmentCode)
                .where('isActive', isEqualTo: true)
                .limit(1)
                .get(),
            config: RetryConfigs.standard,
          );
          
          if (querySnapshot.docs.isEmpty) {
            _performance.recordMetric('enrollment_code_not_found', 1);
            return null;
          }
          
          final classModel = ClassModel.fromFirestore(querySnapshot.docs.first);
          
          // Cache the result
          await _cache.set(
            'enrollment_code_$enrollmentCode',
            classModel.toFirestore(),
            ttl: const Duration(hours: 24),
          );
          
          _performance.recordMetric('enrollment_code_found', 1);
          return classModel;
          
        } catch (e) {
          LoggerService.error(
            'Error getting class by enrollment code: $enrollmentCode',
            error: e,
          );
          rethrow;
        }
      },
      attributes: {
        'enrollment_code': enrollmentCode,
        'operation': 'get_by_enrollment_code',
      },
    );
  }

  /// Enrolls a student in a class with comprehensive validation and monitoring.
  /// 
  /// Includes capacity checking, duplicate enrollment prevention,
  /// and performance tracking.
  /// 
  /// @param studentId ID of the student to enroll
  /// @param enrollmentCode The enrollment code for the class
  /// @return The class the student was enrolled in
  /// @throws Exception if enrollment fails
  Future<ClassModel> enrollStudent(String studentId, String enrollmentCode) async {
    return await _performance.timeOperation(
      'enroll_student',
      () async {
        try {
          // Validate inputs
          final studentIdValidation = ValidationService.validateUsername(studentId);
          if (studentIdValidation != null) {
            throw Exception('Invalid student ID: $studentIdValidation');
          }
          
          // Find class by enrollment code
          final classModel = await getClassByEnrollmentCode(enrollmentCode);
          
          if (classModel == null) {
            _performance.recordMetric('enrollment_failed_invalid_code', 1);
            throw Exception('Invalid enrollment code');
          }
          
          // Check if student is already enrolled
          if (classModel.studentIds.contains(studentId)) {
            _performance.recordMetric('enrollment_failed_already_enrolled', 1);
            throw Exception('Student is already enrolled in this class');
          }
          
          // Check if class is full
          if (classModel.isFull) {
            _performance.recordMetric('enrollment_failed_class_full', 1);
            throw Exception('Class is at maximum capacity');
          }
          
          // Add student to class with retry
          final updatedStudentIds = [...classModel.studentIds, studentId];
          
          await RetryService.withRetry(
            () => _classesCollection.doc(classModel.id).update({
              'studentIds': updatedStudentIds,
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            }),
            config: RetryConfigs.standard,
          );
          
          final updatedClass = classModel.copyWith(
            studentIds: updatedStudentIds,
            updatedAt: DateTime.now(),
          );
          
          // Update caches
          await _cache.set(
            'class_${classModel.id}',
            updatedClass.toFirestore(),
            ttl: const Duration(hours: 2),
          );
          
          // Invalidate related caches
          await _cache.clearPattern('student_classes_$studentId');
          await _cache.clearPattern('class_stats_${classModel.id}');
          
          // Record metrics
          _performance.recordMetric('student_enrolled', 1);
          _performance.recordMetric('class_enrollment_count', updatedStudentIds.length.toDouble());
          
          LoggerService.info(
            'Enrolled student $studentId in class ${classModel.name} (ID: ${classModel.id}, Count: ${updatedStudentIds.length})',
          );
          
          return updatedClass;
          
        } catch (e) {
          LoggerService.error(
            'Error enrolling student $studentId with code $enrollmentCode',
            error: e,
          );
          rethrow;
        }
      },
      attributes: {
        'student_id': studentId,
        'enrollment_code': enrollmentCode,
        'operation': 'enroll_student',
      },
    );
  }

  /// Gets teacher class statistics with caching and performance monitoring.
  /// 
  /// Caches results for 30 minutes to improve performance.
  /// 
  /// @param teacherId ID of the teacher
  /// @return Map containing comprehensive class statistics
  Future<Map<String, dynamic>> getTeacherClassStats(String teacherId) async {
    return await _performance.timeOperation(
      'get_teacher_class_stats',
      () async {
        try {
          // Check cache first
          final cacheKey = 'teacher_stats_$teacherId';
          final cachedStats = await _cache.get<Map<String, dynamic>>(cacheKey);
          if (cachedStats != null) {
            _performance.recordMetric('cache_hit_teacher_stats', 1);
            return cachedStats;
          }
          
          // Query Firestore with retry
          final snapshot = await RetryService.withRetry(
            () => _classesCollection
                .where('teacherId', isEqualTo: teacherId)
                .where('isActive', isEqualTo: true)
                .get(),
            config: RetryConfigs.standard,
          );
          
          final classes = snapshot.docs
              .map((doc) => ClassModel.fromFirestore(doc))
              .toList();
          
          // Calculate comprehensive stats
          int totalStudents = 0;
          int totalCapacity = 0;
          double totalUtilization = 0;
          
          for (final classModel in classes) {
            totalStudents += classModel.studentCount;
            totalCapacity += classModel.maxStudents ?? 0;
            if (classModel.maxStudents != null && classModel.maxStudents! > 0) {
              totalUtilization += (classModel.studentCount / classModel.maxStudents!) * 100;
            }
          }
          
          final stats = {
            'totalClasses': classes.length,
            'totalStudents': totalStudents,
            'totalCapacity': totalCapacity,
            'averageClassSize': classes.isEmpty 
                ? 0 
                : (totalStudents / classes.length).round(),
            'averageUtilization': classes.isEmpty 
                ? 0 
                : (totalUtilization / classes.length).round(),
            'utilizationPercentage': totalCapacity > 0 
                ? ((totalStudents / totalCapacity) * 100).round() 
                : 0,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
          
          // Cache the results
          await _cache.set(
            cacheKey,
            stats,
            ttl: const Duration(minutes: 30),
          );
          
          // Record metrics
          _performance.recordMetric('teacher_stats_calculated', 1);
          _performance.recordMetric('teacher_total_classes', classes.length.toDouble());
          _performance.recordMetric('teacher_total_students', totalStudents.toDouble());
          
          return stats;
          
        } catch (e) {
          LoggerService.error(
            'Error getting teacher class stats for teacher: $teacherId',
            error: e,
          );
          rethrow;
        }
      },
      attributes: {
        'teacher_id': teacherId,
        'operation': 'get_teacher_stats',
      },
    );
  }

  /// Validates class model data.
  void _validateClassModel(ClassModel classModel) {
    if (classModel.name.isEmpty) {
      throw Exception('Class name cannot be empty');
    }
    
    if (classModel.teacherId.isEmpty) {
      throw Exception('Teacher ID cannot be empty');
    }
    
    if (classModel.maxStudents != null && classModel.maxStudents! < 1) {
      throw Exception('Maximum students must be at least 1');
    }
    
    // Validate using ValidationService
    final nameValidation = ValidationService.validateTextLength(
      classModel.name,
      fieldName: 'Class name',
      minLength: 1,
      maxLength: 100,
    );
    if (nameValidation != null) {
      throw Exception('Invalid class name: $nameValidation');
    }
  }

  /// Generates a unique enrollment code with performance monitoring.
  Future<String> _generateUniqueEnrollmentCode() async {
    return await _performance.timeOperation(
      'generate_enrollment_code',
      () async {
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        const codeLength = 6;
        const maxAttempts = 100;
        
        final random = Random();
        
        for (int attempt = 0; attempt < maxAttempts; attempt++) {
          // Generate random code
          final code = String.fromCharCodes(
            Iterable.generate(
              codeLength,
              (_) => chars.codeUnitAt(random.nextInt(chars.length)),
            ),
          );
          
          // Check if code already exists
          final existing = await getClassByEnrollmentCode(code);
          if (existing == null) {
            _performance.recordMetric('enrollment_code_generation_attempts', attempt + 1.0);
            return code;
          }
        }
        
        _performance.recordMetric('enrollment_code_generation_failed', 1);
        throw Exception('Unable to generate unique enrollment code');
      },
      attributes: {
        'operation': 'generate_code',
      },
    );
  }

  /// Clears all caches related to classes.
  /// 
  /// Useful for testing or when data consistency is critical.
  Future<void> clearAllCaches() async {
    await _cache.clearPattern('class_');
    await _cache.clearPattern('enrollment_code_');
    await _cache.clearPattern('teacher_stats_');
    await _cache.clearPattern('student_classes_');
    await _cache.clearPattern('class_stats_');
    
    LoggerService.info('All class-related caches cleared');
  }

  /// Gets performance metrics for the service.
  Map<String, dynamic> getPerformanceMetrics() {
    return _performance.getPerformanceStats();
  }

}