import 'dart:async';
import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/student.dart';
import '../repositories/class_repository.dart';
import '../repositories/student_repository.dart';
import '../core/service_locator.dart';

class ClassProvider with ChangeNotifier {
  late final ClassRepository _classRepository;
  late final StudentRepository _studentRepository;
  
  // State variables
  List<ClassModel> _teacherClasses = [];
  List<ClassModel> _studentClasses = [];
  List<Student> _classStudents = [];
  bool _isLoading = false;
  String? _error;
  
  // Selected class for detail view
  ClassModel? _selectedClass;
  
  // Stream subscriptions
  StreamSubscription<List<ClassModel>>? _teacherClassesSubscription;
  StreamSubscription<List<ClassModel>>? _studentClassesSubscription;
  StreamSubscription<List<Student>>? _classStudentsSubscription;
  
  // Constructor
  ClassProvider() {
    _classRepository = getIt<ClassRepository>();
    _studentRepository = getIt<StudentRepository>();
  }
  
  // Getters
  List<ClassModel> get teacherClasses => _teacherClasses;
  List<ClassModel> get studentClasses => _studentClasses;
  List<Student> get classStudents => _classStudents;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ClassModel? get selectedClass => _selectedClass;
  
  // Get active classes
  List<ClassModel> get activeClasses {
    return _teacherClasses.where((c) => c.isActive).toList();
  }
  
  // Get archived classes
  List<ClassModel> get archivedClasses {
    return _teacherClasses.where((c) => !c.isActive).toList();
  }
  
  // Get classes by academic year
  List<ClassModel> getClassesByAcademicYear(String academicYear) {
    return _teacherClasses.where((c) => c.academicYear == academicYear).toList();
  }
  
  // Load classes for a teacher
  Future<void> loadTeacherClasses(String teacherId) async {
    _setLoading(true);
    try {
      _teacherClassesSubscription?.cancel();
      
      _teacherClassesSubscription = _classRepository.getTeacherClasses(teacherId).listen(
        (classList) {
          _teacherClasses = classList;
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
  
  // Load classes for a student
  Future<void> loadStudentClasses(String studentId) async {
    _setLoading(true);
    try {
      _studentClassesSubscription?.cancel();
      
      _studentClassesSubscription = _classRepository.getStudentClasses(studentId).listen(
        (classList) {
          _studentClasses = classList;
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
  
  // Load students for a class
  Future<void> loadClassStudents(String classId) async {
    _setLoading(true);
    try {
      _classStudentsSubscription?.cancel();
      
      _classStudentsSubscription = _studentRepository.getClassStudents(classId).listen(
        (studentList) {
          _classStudents = studentList;
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
  
  // Create a new class
  Future<bool> createClass(ClassModel classModel) async {
    _setLoading(true);
    try {
      await _classRepository.createClass(classModel);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Update a class
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
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Delete a class
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
  
  // Archive/Restore class
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
  
  // Student enrollment
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
  
  // Check enrollment
  Future<bool> isStudentEnrolled(String classId, String studentId) async {
    try {
      return await _classRepository.isStudentEnrolled(classId, studentId);
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  // Set selected class
  void setSelectedClass(ClassModel? classModel) {
    _selectedClass = classModel;
    notifyListeners();
  }
  
  // Search students
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
  
  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Clear all data
  void clearData() {
    _teacherClasses = [];
    _studentClasses = [];
    _classStudents = [];
    _selectedClass = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
  
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