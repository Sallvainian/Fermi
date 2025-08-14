/// Simplified class management state provider.
/// 
/// This module manages class (course) state for the education platform,
/// using direct Firestore integration without complex repository patterns.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  /// Returns a stream of teacher's classes from Firestore.
  Stream<List<ClassModel>> loadTeacherClasses(String teacherId) {
    print('Loading classes for teacher: $teacherId');
    return _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      print('Got ${snapshot.docs.length} classes for teacher $teacherId');
      
      final List<ClassModel> classes = [];
      for (var doc in snapshot.docs) {
        try {
          print('Processing document: ${doc.id}');
          final classModel = ClassModel.fromFirestore(doc);
          classes.add(classModel);
          print('Successfully parsed class: ${classModel.name}');
        } catch (e, stack) {
          print('ERROR: Failed to parse class document ${doc.id}');
          print('Error: $e');
          print('Stack trace: $stack');
          // Continue processing other documents
        }
      }
      
      _teacherClasses = classes;
      notifyListeners();
      return classes;
    }).handleError((error, stackTrace) {
      print('STREAM ERROR: Failed to load teacher classes');
      print('Error: $error');
      print('Stack: $stackTrace');
      _teacherClasses = [];
      _setError('Failed to load classes: $error');
      notifyListeners();
      return <ClassModel>[];
    });
  }
  
  /// Loads student's enrolled classes from Firestore.
  Future<void> loadStudentClasses(String studentId) async {
    _setLoading(true);
    notifyListeners();
    
    try {
      _studentClassesSubscription?.cancel();
      
      // Direct Firestore query for student's enrolled classes
      _studentClassesSubscription = _firestore
          .collection('classes')
          .where('studentIds', arrayContains: studentId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen(
        (snapshot) {
          _studentClasses = snapshot.docs
              .map((doc) => ClassModel.fromFirestore(doc))
              .toList();
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          print('Error loading student classes: $error');
          _setError(error.toString());
          _setLoading(false);
          notifyListeners();
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
    }
  }
  
  /// Creates a new class.
  Future<void> createClass(ClassModel classModel) async {
    _setLoading(true);
    notifyListeners();
    
    try {
      await _firestore.collection('classes').add(classModel.toFirestore());
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
    }
  }
  
  /// Updates an existing class.
  Future<void> updateClass(String classId, ClassModel classModel) async {
    _setLoading(true);
    notifyListeners();
    
    try {
      await _firestore.collection('classes').doc(classId).update(classModel.toFirestore());
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
    }
  }
  
  /// Deletes a class.
  Future<void> deleteClass(String classId) async {
    _setLoading(true);
    notifyListeners();
    
    try {
      await _firestore.collection('classes').doc(classId).delete();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
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
    notifyListeners();
    
    try {
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (classDoc.exists) {
        final studentIds = List<String>.from(classDoc.data()?['studentIds'] ?? []);
        if (studentIds.isNotEmpty) {
          final studentsSnapshot = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: studentIds)
              .get();
          
          _classStudents = studentsSnapshot.docs
              .map((doc) => Student.fromFirestore(doc))
              .toList();
        } else {
          _classStudents = [];
        }
      }
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      print('Error loading class students: $e');
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
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
  
  /// Enrolls with an enrollment code.
  Future<bool> enrollWithCode(String studentId, String enrollmentCode) async {
    try {
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
      await classDoc.reference.update({
        'studentIds': FieldValue.arrayUnion([studentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
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
          .where((student) =>
              student.displayName.toLowerCase().contains(queryLower) ||
              (student.email?.toLowerCase().contains(queryLower) ?? false))
          .toList();
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }
  
  /// Enrolls multiple students in a class.
  Future<bool> enrollMultipleStudents(String classId, List<String> studentIds) async {
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
  }
  
  void _setError(String? value) {
    _error = value;
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  String _generateEnrollmentCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }
  
  @override
  void dispose() {
    _teacherClassesSubscription?.cancel();
    _studentClassesSubscription?.cancel();
    super.dispose();
  }
}