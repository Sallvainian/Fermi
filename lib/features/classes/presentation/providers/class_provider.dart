/// Simplified class management state provider.
///
/// This module manages class (course) state for the education platform,
/// using direct Firestore integration without complex repository patterns.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/services/logger_service.dart';
import '../../domain/models/class_model.dart';
import '../../../student/domain/models/student.dart';

/// Simplified provider managing class state.
///
/// Direct Firestore integration for essential class operations.
class ClassProvider with ChangeNotifier {
  /// Firestore instance for database operations
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables
  List<ClassModel> _teacherClasses = [];
  List<ClassModel> _studentClasses = [];
  List<Student> _classStudents = [];
  bool _isLoading = false;
  String? _error;
  ClassModel? _selectedClass;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _teacherClassesSubscription;
  StreamSubscription<QuerySnapshot>? _studentClassesSubscription;

  /// Creates class provider with direct Firestore access.
  ClassProvider() {
    // No dependency injection needed - using Firestore directly
  }

  // Getters
  List<ClassModel> get teacherClasses => _teacherClasses;
  List<ClassModel> get studentClasses => _studentClasses;
  List<Student> get classStudents => _classStudents;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ClassModel? get selectedClass => _selectedClass;

  List<ClassModel> get activeClasses {
    return _teacherClasses.where((c) => c.isActive).toList();
  }

  List<ClassModel> get archivedClasses {
    return _teacherClasses.where((c) => !c.isActive).toList();
  }

  List<ClassModel> _sortClasses(List<ClassModel> classes) {
    final sorted = List<ClassModel>.from(classes);
    sorted.sort((a, b) {
      final aPeriod = a.periodNumber;
      final bPeriod = b.periodNumber;

      if (aPeriod != null && bPeriod != null) {
        final comparison = aPeriod.compareTo(bPeriod);
        if (comparison != 0) return comparison;
      } else if (aPeriod != null) {
        // Prioritise classes with parsed periods over those without
        return -1;
      } else if (bPeriod != null) {
        return 1;
      }

      // Fallback to alphabetical order to provide deterministic results
      final nameComparison = a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      );
      if (nameComparison != 0) return nameComparison;

      // As a last resort, compare creation timestamps to keep ordering stable
      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }

  /// Returns a stream of teacher's classes from Firestore.
  Stream<List<ClassModel>> loadTeacherClasses(String teacherId) {
    // Cancel previous subscription if exists
    _teacherClassesSubscription?.cancel();

    // Set up new subscription
    _teacherClassesSubscription = _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .listen(
          (snapshot) {
            final List<ClassModel> classes = [];
            for (var doc in snapshot.docs) {
              try {
                final classModel = ClassModel.fromFirestore(doc);
                classes.add(classModel);
              } catch (e) {
                // ERROR: Failed to parse class document ${doc.id}: $e
                // Continue processing other documents
              }
            }

            _teacherClasses = _sortClasses(classes);
            _setLoading(false);
            // Defer notification to next frame to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              notifyListeners();
            });
          },
          onError: (error) {
            // ERROR: Failed to load teacher classes: $error
            _teacherClasses = [];
            _setError('Failed to load classes: $error');
            _setLoading(false);
            // Defer notification to next frame to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              notifyListeners();
            });
          },
        );

    // Return the stream for UI if needed
    return _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
          final classes = snapshot.docs
              .map((doc) => ClassModel.fromFirestore(doc))
              .toList();
          return _sortClasses(classes);
        });
  }

  /// Loads student's enrolled classes from Firestore.
  Future<void> loadStudentClasses(String studentId) async {
    _setLoading(true);

    // Cancel previous subscription if exists
    _studentClassesSubscription?.cancel();

    // Set up new subscription (same pattern as loadTeacherClasses)
    _studentClassesSubscription = _firestore
        .collection('classes')
        .where('studentIds', arrayContains: studentId)
        .snapshots()
        .listen(
          (snapshot) {
            final List<ClassModel> classes = [];
            for (var doc in snapshot.docs) {
              try {
                final classModel = ClassModel.fromFirestore(doc);
                classes.add(classModel);
              } catch (e) {
                // ERROR: Failed to parse class document ${doc.id}: $e
                // Continue processing other documents
              }
            }

            _studentClasses = classes;
            _setLoading(false);
            // Defer notification to next frame to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              notifyListeners();
            });
          },
          onError: (error) {
            // ERROR: Failed to load student classes: $error
            _studentClasses = [];
            _setError('Failed to load classes: $error');
            _setLoading(false);
            // Defer notification to next frame to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              notifyListeners();
            });
          },
        );
  }

  /// Creates a new class.
  Future<void> createClass(ClassModel classModel) async {
    _setLoading(true);

    try {
      await _firestore.collection('classes').add(classModel.toFirestore());
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// Updates an existing class.
  Future<void> updateClass(String classId, ClassModel classModel) async {
    _setLoading(true);

    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .update(classModel.toFirestore());
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// Deletes a class.
  Future<void> deleteClass(String classId) async {
    _setLoading(true);

    try {
      await _firestore.collection('classes').doc(classId).delete();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// Gets a specific class by ID.
  Future<ClassModel?> getClassById(String classId) async {
    try {
      final doc = await _firestore.collection('classes').doc(classId).get();
      if (doc.exists) {
        return ClassModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      LoggerService.error(
        'Error getting class by ID',
        tag: 'ClassProvider',
        error: e,
      );
      return null;
    }
  }

  /// Sets the selected class.
  void setSelectedClass(ClassModel? classModel) {
    _selectedClass = classModel;
    notifyListeners();
  }

  /// Loads students for a specific class.
  Future<void> loadClassStudents(String classId) async {
    _setLoading(true);

    try {
      final classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();
      if (classDoc.exists) {
        final studentIds = List<String>.from(
          classDoc.data()?['studentIds'] ?? [],
        );
        if (studentIds.isNotEmpty) {
          // Firestore 'whereIn' queries have a limit of 30 items
          // If we have more than 30 students, batch the queries
          _classStudents = [];

          // Process in batches of 30
          const batchSize = 30;
          for (int i = 0; i < studentIds.length; i += batchSize) {
            // Get the batch of IDs (max 30)
            final batchIds = studentIds.sublist(
              i,
              i + batchSize > studentIds.length ? studentIds.length : i + batchSize,
            );

            // Query users collection with the batch of UIDs
            final studentsSnapshot = await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: batchIds)
                .where('role', isEqualTo: 'student')
                .get();

            _classStudents.addAll(
              studentsSnapshot.docs.map((doc) => Student.fromFirestore(doc)),
            );
          }

          LoggerService.info(
            'Loaded ${_classStudents.length} students for class $classId from ${studentIds.length} IDs',
            tag: 'ClassProvider',
          );
        } else {
          _classStudents = [];
        }
      }
      _setLoading(false);
    } catch (e) {
      LoggerService.error(
        'Error loading class students',
        tag: 'ClassProvider',
        error: e,
      );
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// Regenerates enrollment code for a class.
  Future<String?> regenerateEnrollmentCode(String classId) async {
    try {
      final newCode = _generateEnrollmentCode();
      await _firestore.collection('classes').doc(classId).update({
        'enrollmentCode': newCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return newCode;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Unenrolls a student from a class.
  Future<bool> unenrollStudent(String classId, String studentId) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': FieldValue.arrayRemove([studentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Archives a class.
  Future<bool> archiveClass(String classId) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Restores an archived class.
  Future<bool> restoreClass(String classId) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Enrolls with an enrollment code with retry logic for blocked connections.
  Future<bool> enrollWithCode(String studentId, String enrollmentCode) async {
    // Add retry logic for ERR_BLOCKED_BY_CLIENT errors
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // Small delay to avoid hitting rate limits
        if (retryCount > 0) {
          await Future.delayed(Duration(seconds: retryCount * 2));
        }

        final classQuery = await _firestore
            .collection('classes')
            .where('enrollmentCode', isEqualTo: enrollmentCode.toUpperCase())
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (classQuery.docs.isEmpty) {
          _setError('Invalid enrollment code');
          return false;
        }

        final classDoc = classQuery.docs.first;

        // Check if student is already enrolled
        final classData = classDoc.data();
        final studentIds = List<String>.from(classData['studentIds'] ?? []);
        if (studentIds.contains(studentId)) {
          _setError('You are already enrolled in this class');
          return false;
        }

        await classDoc.reference.update({
          'studentIds': FieldValue.arrayUnion([studentId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      } catch (e) {
        retryCount++;
        LoggerService.warning('Enrollment attempt $retryCount failed: $e');

        if (retryCount >= maxRetries) {
          _setError('Unable to join class. Please try again in a moment.');
          return false;
        }
        // Continue to retry
      }
    }

    return false;
  }

  /// Creates a class from parameters.
  Future<bool> createClassFromParams({
    required String name,
    required String subject,
    required String gradeLevel,
    String? description,
    String? room,
    String? schedule,
    String? academicYear,
    required String teacherId,
  }) async {
    try {
      final classData = {
        'teacherId': teacherId,
        'name': name,
        'subject': subject,
        'gradeLevel': gradeLevel,
        'room': room ?? '',
        'schedule': schedule ?? '',
        'description': description ?? '',
        'academicYear': academicYear ?? '2024-2025',
        'isActive': true,
        'enrollmentCode': _generateEnrollmentCode(),
        'studentIds': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('classes').add(classData);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Searches for available students to enroll.
  Future<List<Student>> searchAvailableStudents(String query) async {
    try {
      final queryLower = query.toLowerCase();
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      return usersSnapshot.docs
          .map((doc) => Student.fromFirestore(doc))
          .where(
            (student) =>
                student.displayName.toLowerCase().contains(queryLower) ||
                (student.email?.toLowerCase().contains(queryLower) ?? false),
          )
          .toList();
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  /// Enrolls multiple students in a class.
  Future<bool> enrollMultipleStudents(
    String classId,
    List<String> studentIds,
  ) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': FieldValue.arrayUnion(studentIds),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _generateEnrollmentCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  @override
  void dispose() {
    _teacherClassesSubscription?.cancel();
    _studentClassesSubscription?.cancel();
    super.dispose();
  }
}
