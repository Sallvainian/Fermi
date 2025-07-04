import '../models/student.dart';
import '../models/grade.dart';
import 'base_repository.dart';

abstract class StudentRepository extends BaseRepository {
  // CRUD operations
  Future<String> createStudent(Student student);
  Future<Student?> getStudent(String id);
  Future<Student?> getStudentByUserId(String userId);
  Future<void> updateStudent(String id, Student student);
  Future<void> deleteStudent(String id);
  
  // Class enrollment
  Future<void> enrollInClass(String studentId, String classId);
  Future<void> unenrollFromClass(String studentId, String classId);
  Future<void> enrollInMultipleClasses(String studentId, List<String> classIds);
  
  // Queries
  Stream<List<Student>> getClassStudents(String classId);
  Stream<List<Student>> getActiveStudents();
  Stream<List<Student>> getStudentsByGradeLevel(int gradeLevel);
  Future<List<Student>> searchStudents(String query);
  
  // Grade related
  Future<GradeStatistics?> getStudentOverallStatistics(String studentId);
  Future<Map<String, GradeStatistics>> getStudentStatisticsByClass(String studentId);
  
  // Parent related
  Stream<List<Student>> getStudentsByParentEmail(String parentEmail);
  
  // Batch operations
  Future<void> batchCreateStudents(List<Student> students);
  Future<void> batchUpdateStudents(Map<String, Student> students);
  
  // Validation
  Future<bool> isEmailAvailable(String email);
  Future<bool> isStudentEnrolledInClass(String studentId, String classId);
}