/// Class management state provider.
/// 
/// This module manages class (course) state for the education platform,
/// handling teacher and student class listings, enrollment operations,
/// and real-time updates through stream subscriptions.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/student.dart';
import '../repositories/class_repository.dart';
import '../repositories/student_repository.dart';
import '../core/service_locator.dart';

/// Provider managing class state and enrollment operations.
/// 
/// This provider serves as the central state manager for classes,
/// coordinating between class and student repositories. Key features:
/// - Real-time class list updates for teachers and students
/// - Student enrollment and unenrollment management
/// - Class archiving and restoration
/// - Academic year filtering
/// - Student search for enrollment
/// - Bulk enrollment operations
/// 
/// Maintains separate lists for teacher-owned and student-enrolled
/// classes with automatic stream management.
class ClassProvider with ChangeNotifier {
  /// Repository for class data operations.
  late final ClassRepository _classRepository;
  
  /// Repository for student data operations.
  late final StudentRepository _studentRepository;
  
  // State variables
  
  /// Classes taught by the current teacher.
  List<ClassModel> _teacherClasses = [];
  
  /// Classes enrolled by the current student.
  List<ClassModel> _studentClasses = [];
  
  /// Students enrolled in the selected class.
  List<Student> _classStudents = [];
  
  /// Loading state for async operations.
  bool _isLoading = false;
  
  /// Latest error message for UI display.
  String? _error;
  
  /// Currently selected class for detail views.
  ClassModel? _selectedClass;
  
  // Stream subscriptions
  
  /// Subscription for teacher's class list updates.
  StreamSubscription<List<ClassModel>>? _teacherClassesSubscription;
  
  /// Subscription for student's class list updates.
  StreamSubscription<List<ClassModel>>? _studentClassesSubscription;
  
  /// Subscription for class student list updates.
  StreamSubscription<List<Student>>? _classStudentsSubscription;
  
  /// Creates class provider with repository dependencies.
  /// 
  /// Retrieves repositories from dependency injection container.
  ClassProvider() {
    _classRepository = getIt<ClassRepository>();
    _studentRepository = getIt<StudentRepository>();
  }
  
  // Getters
  
  /// List of classes taught by current teacher.
  List<ClassModel> get teacherClasses => _teacherClasses;
  
  /// List of classes enrolled by current student.
  List<ClassModel> get studentClasses => _studentClasses;
  
  /// Students enrolled in selected class.
  List<Student> get classStudents => _classStudents;
  
  /// Whether an operation is in progress.
  bool get isLoading => _isLoading;
  
  /// Latest error message or null.
  String? get error => _error;
  
  /// Currently selected class or null.
  ClassModel? get selectedClass => _selectedClass;
  
  /// Filters teacher's classes to show only active ones.
  /// 
  /// Active classes accept new enrollments and assignments.
  List<ClassModel> get activeClasses {
    return _teacherClasses.where((c) => c.isActive).toList();
  }
  
  /// Filters teacher's classes to show only archived ones.
  /// 
  /// Archived classes are read-only historical records.
  List<ClassModel> get archivedClasses {
    return _teacherClasses.where((c) => !c.isActive).toList();
  }
  
  /// Filters classes by academic year.
  /// 
  /// Useful for year-specific views and reports.
  /// 
  /// @param academicYear Year to filter by (e.g., "2023-2024")
  /// @return List of classes from specified year
  List<ClassModel> getClassesByAcademicYear(String academicYear) {
    return _teacherClasses.where((c) => c.academicYear == academicYear).toList();
  }
  
  /// Loads and subscribes to teacher's class list.
  /// 
  /// Sets up real-time stream for class updates.
  /// Cancels any existing subscription before creating new one.
  /// 
  /// @param teacherId Teacher's unique identifier
  /// @throws Exception if loading fails
  Future<void> loadTeacherClasses(String teacherId) async {
    _setLoading(true);
    notifyListeners();  // Safe here, as it's before async
    
    try {
      _teacherClassesSubscription?.cancel();
      
      _teacherClassesSubscription = _classRepository.getTeacherClasses(teacherId).listen(
        (classList) {
          _teacherClasses = classList;
          _setLoading(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
        },
        onError: (error) {
          _setError(error.toString());
          _setLoading(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();  // Safe here
    }
  }
  
  /// Loads and subscribes to student's enrolled classes.
  /// 
  /// Sets up real-time stream for enrollment updates.
  /// Cancels any existing subscription before creating new one.
  /// 
  /// @param studentId Student's unique identifier
  /// @throws Exception if loading fails
  Future<void> loadStudentClasses(String studentId) async {
    _setLoading(true);
    notifyListeners();
    
    try {
      _studentClassesSubscription?.cancel();
      
      _studentClassesSubscription = _classRepository.getStudentClasses(studentId).listen(
        (classList) {
          _studentClasses = classList;
          _setLoading(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
        },
        onError: (error) {
          _setError(error.toString());
          _setLoading(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
    }
  }
  
  /// Loads and subscribes to class student roster.
  /// 
  /// Sets up real-time stream for enrollment changes.
  /// Students are ordered alphabetically by name.
  /// 
  /// @param classId Class identifier
  /// @throws Exception if loading fails
  Future<void> loadClassStudents(String classId) async {
    _setLoading(true);
    notifyListeners();
    
    try {
      _classStudentsSubscription?.cancel();
      
      _classStudentsSubscription = _studentRepository.getClassStudents(classId).listen(
        (studentList) {
          _classStudents = studentList;
          _setLoading(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
        },
        onError: (error) {
          _setError(error.toString());
          _setLoading(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
    }
  }
  
  /// Creates a new class in the system.
  /// 
  /// Adds class to Firestore and updates local state
  /// through stream subscription.
  /// 
  /// @param classModel Class data to create
  /// @return true if creation successful
  Future<bool> createClass(ClassModel classModel) async {
    _setLoading(true);
    notifyListeners();
    try {
      await _classRepository.createClass(classModel);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }
  
  /// Creates a new class with individual parameters.
  /// 
  /// Convenience method that builds a ClassModel from parameters.
  /// 
  /// @return true if creation successful
  Future<bool> createClassFromParams({
    required String name,
    required String subject,
    required String gradeLevel,
    String? description,
    String? room,
    String? schedule,
    required String academicYear,
    required String semester,
    int? maxStudents,
    required String teacherId,
  }) async {
    if (teacherId.isEmpty) {
      _setError('No teacher ID found');
      return false;
    }
    
    final classModel = ClassModel(
      id: '', // Will be generated by Firestore
      name: name,
      subject: subject,
      gradeLevel: gradeLevel,
      teacherId: teacherId,
      studentIds: [],
      description: description,
      room: room,
      schedule: schedule,
      academicYear: academicYear,
      semester: semester,
      maxStudents: maxStudents,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    return createClass(classModel);
  }
  
  /// Updates existing class information.
  /// 
  /// Modifies class in Firestore and updates local cache
  /// for immediate UI response.
  /// 
  /// @param classId Class to update
  /// @param classModel Updated class data
  /// @return true if update successful
  Future<bool> updateClass(String classId, ClassModel classModel) async {
    _setLoading(true);
    try {
      await _classRepository.updateClass(classId, classModel);
      
      // Update local list
      final index = _teacherClasses.indexWhere((c) => c.id == classId);
      if (index != -1) {
        _teacherClasses[index] = classModel;
        notifyListeners();
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }
  
  /// Permanently deletes a class.
  /// 
  /// Removes class from Firestore and local cache.
  /// This operation cannot be undone.
  /// 
  /// @param classId Class to delete
  /// @return true if deletion successful
  Future<bool> deleteClass(String classId) async {
    _setLoading(true);
    try {
      await _classRepository.deleteClass(classId);
      
      // Remove from local list
      _teacherClasses.removeWhere((c) => c.id == classId);
      notifyListeners();
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Archives an active class.
  /// 
  /// Archived classes become read-only and don't accept
  /// new enrollments or assignments. Updates local cache
  /// for immediate UI response.
  /// 
  /// @param classId Class to archive
  /// @return true if archiving successful
  Future<bool> archiveClass(String classId) async {
    _setLoading(true);
    try {
      await _classRepository.archiveClass(classId);
      
      // Update local list
      final index = _teacherClasses.indexWhere((c) => c.id == classId);
      if (index != -1) {
        _teacherClasses[index] = _teacherClasses[index].copyWith(
          isActive: false,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Restores an archived class to active status.
  /// 
  /// Reactivates class for new enrollments and assignments.
  /// Updates local cache for immediate UI response.
  /// 
  /// @param classId Class to restore
  /// @return true if restoration successful
  Future<bool> restoreClass(String classId) async {
    _setLoading(true);
    try {
      await _classRepository.restoreClass(classId);
      
      // Update local list
      final index = _teacherClasses.indexWhere((c) => c.id == classId);
      if (index != -1) {
        _teacherClasses[index] = _teacherClasses[index].copyWith(
          isActive: true,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Enrolls a student in a class.
  /// 
  /// Updates both class roster and student's enrollment list.
  /// Maintains bidirectional relationship in Firestore.
  /// Updates local state if class is currently selected.
  /// 
  /// @param classId Target class
  /// @param studentId Student to enroll
  /// @return true if enrollment successful
  Future<bool> enrollStudent(String classId, String studentId) async {
    _setLoading(true);
    try {
      await _classRepository.enrollStudent(classId, studentId);
      await _studentRepository.enrollInClass(studentId, classId);
      
      // Update local class if selected
      if (_selectedClass?.id == classId) {
        final updatedStudentIds = List<String>.from(_selectedClass!.studentIds)..add(studentId);
        _selectedClass = _selectedClass!.copyWith(
          studentIds: updatedStudentIds,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Removes a student from class enrollment.
  /// 
  /// Updates both class roster and student's enrollment list.
  /// Removes from local cache for immediate UI update.
  /// 
  /// @param classId Class to unenroll from
  /// @param studentId Student to remove
  /// @return true if unenrollment successful
  Future<bool> unenrollStudent(String classId, String studentId) async {
    _setLoading(true);
    try {
      await _classRepository.unenrollStudent(classId, studentId);
      await _studentRepository.unenrollFromClass(studentId, classId);
      
      // Update local class if selected
      if (_selectedClass?.id == classId) {
        final updatedStudentIds = List<String>.from(_selectedClass!.studentIds)..remove(studentId);
        _selectedClass = _selectedClass!.copyWith(
          studentIds: updatedStudentIds,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      
      // Remove from local student list
      _classStudents.removeWhere((s) => s.id == studentId);
      notifyListeners();
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Enrolls multiple students in a class at once.
  /// 
  /// Efficient bulk enrollment for class setup.
  /// Updates both class and student records.
  /// Removes duplicates automatically.
  /// 
  /// @param classId Target class
  /// @param studentIds List of students to enroll
  /// @return true if bulk enrollment successful
  Future<bool> enrollMultipleStudents(String classId, List<String> studentIds) async {
    _setLoading(true);
    try {
      await _classRepository.enrollMultipleStudents(classId, studentIds);
      
      // Enroll each student in their student record
      for (final studentId in studentIds) {
        await _studentRepository.enrollInClass(studentId, classId);
      }
      
      // Update local class if selected
      if (_selectedClass?.id == classId) {
        final updatedStudentIds = List<String>.from(_selectedClass!.studentIds)..addAll(studentIds);
        _selectedClass = _selectedClass!.copyWith(
          studentIds: updatedStudentIds.toSet().toList(), // Remove duplicates
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Checks if a student is enrolled in a class.
  /// 
  /// Queries current enrollment status from repository.
  /// 
  /// @param classId Class to check
  /// @param studentId Student to verify
  /// @return true if student is enrolled
  Future<bool> isStudentEnrolled(String classId, String studentId) async {
    try {
      return await _classRepository.isStudentEnrolled(classId, studentId);
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  /// Sets the currently selected class.
  /// 
  /// Used for detail views and context-aware operations.
  /// 
  /// @param classModel Class to select or null to clear
  void setSelectedClass(ClassModel? classModel) {
    _selectedClass = classModel;
    notifyListeners();  // This is safe - called from user interaction
  }
  
  /// Searches for students not enrolled in selected class.
  /// 
  /// Filters search results to show only students available
  /// for enrollment. Useful for enrollment UI.
  /// 
  /// @param query Search terms (name or email)
  /// @return List of available students
  Future<List<Student>> searchAvailableStudents(String query) async {
    try {
      final allStudents = await _studentRepository.searchStudents(query);
      
      // Filter out students already enrolled in the selected class
      if (_selectedClass != null) {
        return allStudents.where((student) => 
          !_selectedClass!.studentIds.contains(student.id)
        ).toList();
      }
      
      return allStudents;
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }
  
  /// Enrolls a student using an enrollment code.
  /// 
  /// Students can use this to join classes by entering
  /// the class enrollment code.
  /// 
  /// @param studentId Student to enroll
  /// @param enrollmentCode Class enrollment code
  /// @return true if enrollment successful
  Future<bool> enrollWithCode(String studentId, String enrollmentCode) async {
    _setLoading(true);
    try {
      await _classRepository.enrollWithCode(
        studentId, 
        enrollmentCode.toUpperCase(),
      );
      
      // The class list will be automatically updated via the stream subscription
      // No need to manually add it here as that would cause duplicates
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Generates a new enrollment code for a class.
  /// 
  /// Teachers can use this to create new codes when needed,
  /// such as for security or at the start of a new term.
  /// 
  /// @param classId Class to generate code for
  /// @return The new enrollment code or null on failure
  Future<String?> regenerateEnrollmentCode(String classId) async {
    _setLoading(true);
    try {
      final newCode = await _classRepository.regenerateEnrollmentCode(classId);
      
      // Update local class if it's in our list
      final index = _teacherClasses.indexWhere((c) => c.id == classId);
      if (index != -1) {
        _teacherClasses[index] = _teacherClasses[index].copyWith(
          enrollmentCode: newCode,
          updatedAt: DateTime.now(),
        );
        
        if (_selectedClass?.id == classId) {
          _selectedClass = _selectedClass!.copyWith(
            enrollmentCode: newCode,
            updatedAt: DateTime.now(),
          );
        }
        
        notifyListeners();
      }
      
      _setLoading(false);
      return newCode;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }
  
  // Helper methods
  
  /// Sets loading state and notifies listeners.
  /// 
  /// @param loading New loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    // Removed notifyListeners() here - will handle manually in sensitive areas
  }
  
  /// Sets error message and notifies listeners.
  /// 
  /// @param error Error description or null
  void _setError(String? error) {
    _error = error;
    // Removed notifyListeners() here - will handle manually in sensitive areas
  }
  
  /// Clears error message and notifies UI.
  /// 
  /// Called after user acknowledges error.
  void clearError() {
    _error = null;
    notifyListeners();  // This is safe - called by user interaction
  }
  
  /// Clears all cached data.
  /// 
  /// Resets provider to initial state.
  /// Useful for user logout or role switch.
  void clearData() {
    _teacherClasses = [];
    _studentClasses = [];
    _classStudents = [];
    _selectedClass = null;
    _isLoading = false;
    _error = null;
    notifyListeners();  // This is safe - called on logout
  }
  
  /// Cleans up resources when provider is disposed.
  /// 
  /// Cancels all stream subscriptions and disposes
  /// repositories to prevent memory leaks.
  @override
  void dispose() {
    // Cancel subscriptions
    _teacherClassesSubscription?.cancel();
    _studentClassesSubscription?.cancel();
    _classStudentsSubscription?.cancel();
    
    // Dispose repositories
    _classRepository.dispose();
    _studentRepository.dispose();
    
    super.dispose();
  }
}