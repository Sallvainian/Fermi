/// Student management state provider.
/// 
/// This module manages student data and operations for the education platform,
/// handling student listings, profile management, grade tracking, and
/// class enrollment status through real-time Firebase streams.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/student.dart';
import '../../../grades/domain/models/grade.dart';
import '../../../classes/domain/models/class_model.dart';
import '../../domain/repositories/student_repository.dart';
import '../../../classes/domain/repositories/class_repository.dart';
import '../../../../shared/core/service_locator.dart';

/// Provider managing student state and operations.
/// 
/// This provider serves as the central state manager for students,
/// coordinating between student and class repositories. Key features:
/// - Real-time student list updates with filtering capabilities
/// - Individual student profile management and statistics
/// - Class enrollment tracking for students
/// - Grade statistics aggregation (overall and per-class)
/// - Batch operations for efficient data management
/// - Parent-student relationship queries
/// - Email availability checking for registration
/// 
/// Maintains separate contexts for different student views:
/// all students, current student, and selected student for detail views.
class StudentProvider with ChangeNotifier {
  /// Repository for student data operations.
  late final StudentRepository _studentRepository;
  
  /// Repository for class data operations.
  late final ClassRepository _classRepository;
  
  // State variables
  
  /// List of students based on current filter/context.
  List<Student> _students = [];
  
  /// Currently authenticated student profile.
  Student? _currentStudent;
  
  /// Classes enrolled by the current student.
  List<ClassModel> _studentClasses = [];
  
  /// Grade statistics grouped by class ID.
  Map<String, GradeStatistics> _studentStatisticsByClass = {};
  
  /// Overall performance statistics across all classes.
  GradeStatistics? _overallStatistics;
  
  /// Loading state for async operations.
  bool _isLoading = false;
  
  /// Latest error message for UI display.
  String? _error;
  
  /// Selected student for detail views.
  Student? _selectedStudent;
  
  // Stream subscriptions
  
  /// Subscription for student list updates.
  StreamSubscription<List<Student>>? _studentsSubscription;
  
  /// Subscription for student's class enrollment updates.
  StreamSubscription<List<ClassModel>>? _classesSubscription;
  
  /// Creates student provider with repository dependencies.
  /// 
  /// Retrieves repositories from dependency injection container.
  StudentProvider() {
    _studentRepository = getIt<StudentRepository>();
    _classRepository = getIt<ClassRepository>();
  }
  
  // Getters
  
  /// List of students based on current filter.
  List<Student> get students => _students;
  
  /// Currently authenticated student profile or null.
  Student? get currentStudent => _currentStudent;
  
  /// Classes the current student is enrolled in.
  List<ClassModel> get studentClasses => _studentClasses;
  
  /// Grade statistics grouped by class ID.
  Map<String, GradeStatistics> get studentStatisticsByClass => _studentStatisticsByClass;
  
  /// Overall performance statistics or null.
  GradeStatistics? get overallStatistics => _overallStatistics;
  
  /// Whether an operation is in progress.
  bool get isLoading => _isLoading;
  
  /// Latest error message or null.
  String? get error => _error;
  
  /// Currently selected student for detail view or null.
  Student? get selectedStudent => _selectedStudent;
  
  /// Filters current student list to show only active students.
  /// 
  /// Active students are those not archived or disabled.
  /// Used for enrollment and class management views.
  List<Student> get activeStudents {
    return _students.where((s) => s.isActive).toList();
  }
  
  /// Filters current student list by grade level.
  /// 
  /// Useful for grade-specific views and assignments.
  /// 
  /// @param gradeLevel Grade level to filter by (e.g., 9, 10, 11, 12)
  /// @return List of students in the specified grade
  List<Student> getStudentsByGradeLevel(int gradeLevel) {
    return _students.where((s) => s.gradeLevel == gradeLevel).toList();
  }
  
  /// Loads and subscribes to all active students.
  /// 
  /// Sets up real-time stream for active student updates.
  /// Cancels any existing subscription before creating new one.
  /// Used in teacher views for student management.
  /// 
  /// @throws Exception if loading fails
  Future<void> loadActiveStudents() async {
    _setLoading(true);
    try {
      _studentsSubscription?.cancel();
      
      _studentsSubscription = _studentRepository.getActiveStudents().listen(
        (studentList) {
          _students = studentList;
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError(error.toString());
          _setLoading(false);
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  /// Loads and subscribes to students by grade level.
  /// 
  /// Sets up real-time stream for grade-specific student updates.
  /// Filters students to show only those in the specified grade.
  /// Cancels any existing subscription before creating new one.
  /// 
  /// @param gradeLevel Grade level to filter by
  /// @throws Exception if loading fails
  Future<void> loadStudentsByGradeLevel(int gradeLevel) async {
    _setLoading(true);
    try {
      _studentsSubscription?.cancel();
      
      _studentsSubscription = _studentRepository.getStudentsByGradeLevel(gradeLevel).listen(
        (studentList) {
          _students = studentList;
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError(error.toString());
          _setLoading(false);
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  /// Loads and subscribes to students by parent email.
  /// 
  /// Sets up real-time stream for parent-specific student updates.
  /// Used in parent portal views to show only their children.
  /// Cancels any existing subscription before creating new one.
  /// 
  /// @param parentEmail Parent's email address
  /// @throws Exception if loading fails
  Future<void> loadStudentsByParentEmail(String parentEmail) async {
    _setLoading(true);
    try {
      _studentsSubscription?.cancel();
      
      _studentsSubscription = _studentRepository.getStudentsByParentEmail(parentEmail).listen(
        (studentList) {
          _students = studentList;
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError(error.toString());
          _setLoading(false);
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  /// Loads current student profile and associated data.
  /// 
  /// Fetches student record by Firebase user ID and loads:
  /// - Student's enrolled classes
  /// - Grade statistics (overall and per-class)
  /// 
  /// Used during authentication to establish student context.
  /// 
  /// @param userId Firebase Auth user identifier
  /// @throws Exception if loading fails
  Future<void> loadCurrentStudent(String userId) async {
    _setLoading(true);
    try {
      _currentStudent = await _studentRepository.getStudentByUserId(userId);
      
      if (_currentStudent != null) {
        // Load student's classes
        await loadStudentClasses(_currentStudent!.id);
        
        // Load statistics
        await loadStudentStatistics(_currentStudent!.id);
      }
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  /// Loads and subscribes to student's enrolled classes.
  /// 
  /// Sets up real-time stream for class enrollment updates.
  /// Updates when student enrolls/unenrolls from classes.
  /// 
  /// @param studentId Student identifier
  /// @throws Exception if loading fails
  Future<void> loadStudentClasses(String studentId) async {
    try {
      _classesSubscription?.cancel();
      
      _classesSubscription = _classRepository.getStudentClasses(studentId).listen(
        (classList) {
          _studentClasses = classList;
          notifyListeners();
        },
        onError: (error) {
          _setError(error.toString());
        },
      );
    } catch (e) {
      _setError(e.toString());
    }
  }
  
  /// Loads comprehensive grade statistics for student.
  /// 
  /// Fetches both overall performance metrics and
  /// class-specific statistics for detailed analysis.
  /// Fails silently to avoid disrupting UI flow.
  /// 
  /// @param studentId Student identifier
  Future<void> loadStudentStatistics(String studentId) async {
    try {
      // Load overall statistics
      _overallStatistics = await _studentRepository.getStudentOverallStatistics(studentId);
      
      // Load statistics by class
      _studentStatisticsByClass = await _studentRepository.getStudentStatisticsByClass(studentId);
      
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }
  
  /// Creates a new student record.
  /// 
  /// Adds student to Firestore and updates local state
  /// through stream subscription if currently loading students.
  /// 
  /// @param student Student data to create
  /// @return true if creation successful
  Future<bool> createStudent(Student student) async {
    _setLoading(true);
    try {
      await _studentRepository.createStudent(student);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Updates existing student information.
  /// 
  /// Modifies student in Firestore and updates all local caches
  /// for immediate UI response. Updates current, selected, and
  /// list student references if they match.
  /// 
  /// @param studentId Student identifier
  /// @param student Updated student data
  /// @return true if update successful
  Future<bool> updateStudent(String studentId, Student student) async {
    _setLoading(true);
    try {
      await _studentRepository.updateStudent(studentId, student);
      
      // Update local lists
      final index = _students.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        _students[index] = student;
      }
      
      if (_currentStudent?.id == studentId) {
        _currentStudent = student;
      }
      
      if (_selectedStudent?.id == studentId) {
        _selectedStudent = student;
      }
      
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Permanently deletes a student record.
  /// 
  /// Removes student from Firestore and all local caches.
  /// This operation cannot be undone. Consider deactivation instead.
  /// Clears current and selected student if they match.
  /// 
  /// @param studentId Student to delete
  /// @return true if deletion successful
  Future<bool> deleteStudent(String studentId) async {
    _setLoading(true);
    try {
      await _studentRepository.deleteStudent(studentId);
      
      // Remove from local list
      _students.removeWhere((s) => s.id == studentId);
      
      if (_currentStudent?.id == studentId) {
        _currentStudent = null;
      }
      
      if (_selectedStudent?.id == studentId) {
        _selectedStudent = null;
      }
      
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Creates multiple student records in one operation.
  /// 
  /// Efficient batch creation for school setup or imports.
  /// All students are created or none are created (atomic operation).
  /// Updates local state through stream subscription.
  /// 
  /// @param students List of student data to create
  /// @return true if batch creation successful
  Future<bool> batchCreateStudents(List<Student> students) async {
    _setLoading(true);
    try {
      await _studentRepository.batchCreateStudents(students);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Searches students by name, email, or student ID.
  /// 
  /// Performs text search across student fields.
  /// Does not affect current student list state.
  /// 
  /// @param query Search terms
  /// @return List of matching students or empty list if error
  Future<List<Student>> searchStudents(String query) async {
    try {
      return await _studentRepository.searchStudents(query);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }
  
  /// Checks if email address is available for registration.
  /// 
  /// Validates that email is not already used by another student.
  /// Used during registration and profile update flows.
  /// 
  /// @param email Email address to check
  /// @return true if email is available, false if taken or error
  Future<bool> isEmailAvailable(String email) async {
    try {
      return await _studentRepository.isEmailAvailable(email);
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  /// Loads multiple students by their IDs.
  /// 
  /// Fetches student records for a list of student IDs.
  /// Used for displaying students in a class roster.
  /// Returns list of found students, skipping any not found.
  /// 
  /// @param studentIds List of student identifiers
  /// @return List of Student objects for found IDs
  Future<List<Student>> loadStudentsByIds(List<String> studentIds) async {
    if (studentIds.isEmpty) return [];
    
    _setLoading(true);
    try {
      final students = <Student>[];
      
      // Load students in parallel for efficiency
      final futures = studentIds.map((id) => _studentRepository.getStudent(id));
      final results = await Future.wait(futures);
      
      // Add non-null students to the list
      for (final student in results) {
        if (student != null) {
          students.add(student);
        }
      }
      
      _setLoading(false);
      return students;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return [];
    }
  }
  
  /// Sets the currently selected student.
  /// 
  /// Used for detail views and context-aware operations.
  /// 
  /// @param student Student to select or null to clear
  void setSelectedStudent(Student? student) {
    _selectedStudent = student;
    notifyListeners();
  }
  
  // Helper methods
  
  /// Sets loading state and notifies listeners.
  /// 
  /// @param loading New loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Sets error message and notifies listeners.
  /// 
  /// @param error Error description or null to clear
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  /// Clears error message and notifies UI.
  /// 
  /// Called after user acknowledges error.
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Clears all cached student data.
  /// 
  /// Resets provider to initial state.
  /// Useful for user logout or role switch.
  void clearData() {
    _students = [];
    _currentStudent = null;
    _studentClasses = [];
    _studentStatisticsByClass = {};
    _overallStatistics = null;
    _selectedStudent = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
  
  /// Cleans up resources when provider is disposed.
  /// 
  /// Cancels all stream subscriptions and disposes
  /// repositories to prevent memory leaks.
  @override
  void dispose() {
    // Cancel subscriptions
    _studentsSubscription?.cancel();
    _classesSubscription?.cancel();
    
    // Dispose repositories
    _studentRepository.dispose();
    _classRepository.dispose();
    
    super.dispose();
  }
}