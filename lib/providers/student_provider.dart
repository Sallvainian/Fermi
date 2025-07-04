import 'dart:async';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/grade.dart';
import '../models/class_model.dart';
import '../repositories/student_repository.dart';
import '../repositories/class_repository.dart';
import '../core/service_locator.dart';

class StudentProvider with ChangeNotifier {
  late final StudentRepository _studentRepository;
  late final ClassRepository _classRepository;
  
  // State variables
  List<Student> _students = [];
  Student? _currentStudent;
  List<ClassModel> _studentClasses = [];
  Map<String, GradeStatistics> _studentStatisticsByClass = {};
  GradeStatistics? _overallStatistics;
  bool _isLoading = false;
  String? _error;
  
  // Selected student for detail view
  Student? _selectedStudent;
  
  // Stream subscriptions
  StreamSubscription<List<Student>>? _studentsSubscription;
  StreamSubscription<List<ClassModel>>? _classesSubscription;
  
  // Constructor
  StudentProvider() {
    _studentRepository = getIt<StudentRepository>();
    _classRepository = getIt<ClassRepository>();
  }
  
  // Getters
  List<Student> get students => _students;
  Student? get currentStudent => _currentStudent;
  List<ClassModel> get studentClasses => _studentClasses;
  Map<String, GradeStatistics> get studentStatisticsByClass => _studentStatisticsByClass;
  GradeStatistics? get overallStatistics => _overallStatistics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Student? get selectedStudent => _selectedStudent;
  
  // Get active students
  List<Student> get activeStudents {
    return _students.where((s) => s.isActive).toList();
  }
  
  // Get students by grade level
  List<Student> getStudentsByGradeLevel(int gradeLevel) {
    return _students.where((s) => s.gradeLevel == gradeLevel).toList();
  }
  
  // Load all active students
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
  
  // Load students by grade level
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
  
  // Load students by parent email
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
  
  // Load current student by user ID
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
  
  // Load classes for a student
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
  
  // Load student statistics
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
  
  // Create a new student
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
  
  // Update a student
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
  
  // Delete a student
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
  
  // Batch create students
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
  
  // Search students
  Future<List<Student>> searchStudents(String query) async {
    try {
      return await _studentRepository.searchStudents(query);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }
  
  // Check email availability
  Future<bool> isEmailAvailable(String email) async {
    try {
      return await _studentRepository.isEmailAvailable(email);
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  // Set selected student
  void setSelectedStudent(Student? student) {
    _selectedStudent = student;
    notifyListeners();
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