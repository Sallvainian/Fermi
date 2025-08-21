/// Student repository interface for learner management.
///
/// This module defines the contract for student operations in the
/// education platform, supporting student profiles, enrollment,
/// academic performance tracking, and parent associations.
library;

import '../models/student.dart';
import '../../../grades/domain/models/grade.dart';
import '../../../../shared/repositories/base_repository.dart';

/// Abstract repository defining student management operations.
///
/// This interface provides a comprehensive contract for student
/// implementations, supporting:
/// - CRUD operations for student profiles
/// - Class enrollment and scheduling
/// - Academic performance tracking
/// - Parent-student relationships
/// - Grade level organization
/// - Batch operations for efficiency
/// - Search and filtering capabilities
///
/// Concrete implementations handle the actual student
/// data persistence and business logic.
abstract class StudentRepository extends BaseRepository {
  // CRUD operations

  /// Creates a new student profile in the system.
  ///
  /// Initializes a student record with personal information,
  /// grade level, and enrollment status. Returns the generated
  /// student ID for reference.
  ///
  /// @param student Student model with profile data
  /// @return Generated unique student ID
  /// @throws Exception if creation fails
  Future<String> createStudent(Student student);

  /// Retrieves a student by their unique identifier.
  ///
  /// Fetches complete student profile including personal
  /// information, enrollment status, and grade level.
  ///
  /// @param id Unique student identifier
  /// @return Student instance or null if not found
  /// @throws Exception if retrieval fails
  Future<Student?> getStudent(String id);

  /// Retrieves a student by their associated user ID.
  ///
  /// Maps from the authentication user ID to the student
  /// profile. Useful for user login flows.
  ///
  /// @param userId Authentication user identifier
  /// @return Student instance or null if not found
  /// @throws Exception if retrieval fails
  Future<Student?> getStudentByUserId(String userId);

  /// Updates an existing student profile.
  ///
  /// Modifies student information such as grade level,
  /// contact details, or enrollment status.
  ///
  /// @param id Student ID to update
  /// @param student Updated student information
  /// @throws Exception if update fails
  Future<void> updateStudent(String id, Student student);

  /// Permanently deletes a student profile.
  ///
  /// Removes the student record and associated data.
  /// This operation cannot be undone.
  ///
  /// @param id Student ID to delete
  /// @throws Exception if deletion fails
  Future<void> deleteStudent(String id);

  // Class enrollment

  /// Enrolls a student in a specific class.
  ///
  /// Adds the student to the class roster and updates
  /// the student's enrolled classes list.
  ///
  /// @param studentId Student to enroll
  /// @param classId Target class identifier
  /// @throws Exception if enrollment fails
  Future<void> enrollInClass(String studentId, String classId);

  /// Removes a student from a class enrollment.
  ///
  /// Updates both the class roster and student's
  /// enrolled classes list.
  ///
  /// @param studentId Student to unenroll
  /// @param classId Class to remove from
  /// @throws Exception if unenrollment fails
  Future<void> unenrollFromClass(String studentId, String classId);

  /// Enrolls a student in multiple classes at once.
  ///
  /// Batch operation for efficiency when adding a student
  /// to several classes, such as during term registration.
  ///
  /// @param studentId Student to enroll
  /// @param classIds List of class identifiers
  /// @throws Exception if batch enrollment fails
  Future<void> enrollInMultipleClasses(String studentId, List<String> classIds);

  // Queries

  /// Streams all students enrolled in a specific class.
  ///
  /// Returns real-time updates of the class roster,
  /// useful for attendance and grade management.
  ///
  /// @param classId Class to get students from
  /// @return Stream of enrolled student lists
  Stream<List<Student>> getClassStudents(String classId);

  /// Streams all active students in the system.
  ///
  /// Filters to only include students with active
  /// enrollment status, excluding graduated or inactive.
  ///
  /// @return Stream of active student lists
  Stream<List<Student>> getActiveStudents();

  /// Streams students by their grade level.
  ///
  /// Useful for grade-specific communications,
  /// curriculum planning, and cohort analysis.
  ///
  /// @param gradeLevel Grade level to filter by
  /// @return Stream of students in that grade
  Stream<List<Student>> getStudentsByGradeLevel(int gradeLevel);

  /// Searches for students by name or ID.
  ///
  /// Performs text search across student names and
  /// identifiers for quick lookup functionality.
  ///
  /// @param query Search terms
  /// @return List of matching students
  /// @throws Exception if search fails
  Future<List<Student>> searchStudents(String query);

  // Grade related

  /// Calculates overall academic statistics for a student.
  ///
  /// Aggregates performance data across all enrolled classes:
  /// - Overall GPA/average
  /// - Total assignments completed
  /// - Attendance rates
  /// - Performance trends
  ///
  /// @param studentId Student to analyze
  /// @return Overall grade statistics or null
  /// @throws Exception if calculation fails
  Future<GradeStatistics?> getStudentOverallStatistics(String studentId);

  /// Gets grade statistics broken down by class.
  ///
  /// Returns a map of class IDs to statistics, showing
  /// performance in each enrolled class separately.
  ///
  /// @param studentId Student to analyze
  /// @return Map of class ID to grade statistics
  /// @throws Exception if calculation fails
  Future<Map<String, GradeStatistics>> getStudentStatisticsByClass(
      String studentId);

  // Parent related

  /// Streams all students associated with a parent email.
  ///
  /// Returns real-time updates of children linked to a
  /// parent account, useful for parent portal access.
  ///
  /// @param parentEmail Parent's email address
  /// @return Stream of associated student lists
  Stream<List<Student>> getStudentsByParentEmail(String parentEmail);

  // Batch operations

  /// Creates multiple student profiles in one operation.
  ///
  /// Efficient bulk import for new student registration,
  /// such as at the beginning of an academic year.
  /// All creates succeed or fail together.
  ///
  /// @param students List of student profiles to create
  /// @throws Exception if batch creation fails
  Future<void> batchCreateStudents(List<Student> students);

  /// Updates multiple student profiles in one operation.
  ///
  /// Efficient bulk update for grade level promotion
  /// or mass profile updates. Atomically updates all
  /// provided students.
  ///
  /// @param students Map of student IDs to updated profiles
  /// @throws Exception if batch update fails
  Future<void> batchUpdateStudents(Map<String, Student> students);

  // Validation

  /// Checks if an email address is available for use.
  ///
  /// Verifies the email isn't already associated with
  /// an existing student account. Used during registration.
  ///
  /// @param email Email address to check
  /// @return true if available, false if taken
  /// @throws Exception if check fails
  Future<bool> isEmailAvailable(String email);

  /// Verifies if a student is enrolled in a specific class.
  ///
  /// Quick check for enrollment status without loading
  /// full student or class profiles.
  ///
  /// @param studentId Student to check
  /// @param classId Class to verify enrollment in
  /// @return true if enrolled, false otherwise
  /// @throws Exception if verification fails
  Future<bool> isStudentEnrolledInClass(String studentId, String classId);
}
