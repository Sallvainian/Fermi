import '../models/class_model.dart';
import '../models/user_model.dart';
import 'base_repository.dart';

abstract class ClassRepository extends BaseRepository {
  /// Create a new class
  Future<String> createClass(ClassModel classModel);
  
  /// Get class by ID
  Future<ClassModel?> getClass(String classId);
  
  /// Update a class
  Future<void> updateClass(String classId, ClassModel classModel);
  
  /// Delete a class
  Future<void> deleteClass(String classId);
  
  /// Get classes for a teacher
  Stream<List<ClassModel>> getTeacherClasses(String teacherId);
  
  /// Get classes for a student
  Stream<List<ClassModel>> getStudentClasses(String studentId);
  
  /// Add student to class
  Future<void> addStudent(String classId, String studentId);
  
  /// Remove student from class
  Future<void> removeStudent(String classId, String studentId);
  
  /// Get students in a class
  Future<List<UserModel>> getClassStudents(String classId);
  
  /// Check if student is enrolled
  Future<bool> isStudentEnrolled(String classId, String studentId);
  
  /// Get class statistics
  Future<Map<String, dynamic>> getClassStats(String classId);
  
  /// Archive a class
  Future<void> archiveClass(String classId);
  
  /// Restore a class from archive
  Future<void> restoreClass(String classId);
  
  /// Enroll a single student
  Future<void> enrollStudent(String classId, String studentId);
  
  /// Unenroll a single student
  Future<void> unenrollStudent(String classId, String studentId);
  
  /// Enroll multiple students
  Future<void> enrollMultipleStudents(String classId, List<String> studentIds);
  
  /// Get active classes for current academic year
  Future<List<ClassModel>> getActiveClasses(String teacherId, String academicYear);
}