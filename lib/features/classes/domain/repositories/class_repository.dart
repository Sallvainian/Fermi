/// Class repository interface for academic class management.
///
/// This module defines the contract for class operations in the
/// education platform, supporting creation, enrollment, and
/// management of academic classes.
library;

import '../models/class_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/repositories/base_repository.dart';

/// Abstract repository defining class management operations.
///
/// This interface provides a comprehensive contract for class
/// implementations, supporting:
/// - CRUD operations for academic classes
/// - Student enrollment and management
/// - Teacher-class associations
/// - Class archiving and restoration
/// - Statistical analysis
/// - Academic year filtering
/// - Batch enrollment operations
///
/// Concrete implementations handle the actual data persistence
/// and business logic for class management.
abstract class ClassRepository extends BaseRepository {
  /// Creates a new academic class.
  ///
  /// Initializes a class with subject, schedule, and teacher
  /// information. Returns the generated class ID.
  ///
  /// @param classModel Class details to create
  /// @return Generated class ID
  /// @throws Exception if creation fails
  Future<String> createClass(ClassModel classModel);

  /// Retrieves a class by ID.
  ///
  /// Fetches complete class details including metadata,
  /// schedule, and teacher information.
  ///
  /// @param classId Unique class identifier
  /// @return Class instance or null if not found
  /// @throws Exception if retrieval fails
  Future<ClassModel?> getClass(String classId);

  /// Updates class information.
  ///
  /// Modifies class details such as name, schedule,
  /// or description. Cannot change the teacher after
  /// creation without special permissions.
  ///
  /// @param classId ID of class to update
  /// @param classModel Updated class information
  /// @throws Exception if update fails
  Future<void> updateClass(String classId, ClassModel classModel);

  /// Permanently deletes a class.
  ///
  /// Removes the class and all associated data.
  /// This operation cannot be undone. Consider
  /// archiving instead for recoverable deletion.
  ///
  /// @param classId ID of class to delete
  /// @throws Exception if deletion fails
  Future<void> deleteClass(String classId);

  /// Streams all classes taught by a teacher.
  ///
  /// Returns real-time updates of classes where the
  /// specified teacher is the instructor. Includes
  /// both active and archived classes.
  ///
  /// @param teacherId Teacher's user ID
  /// @return Stream of teacher's class lists
  Stream<List<ClassModel>> getTeacherClasses(String teacherId);

  /// Streams all classes a student is enrolled in.
  ///
  /// Returns real-time updates of classes where the
  /// student is enrolled. Updates when enrollment changes.
  ///
  /// @param studentId Student's user ID
  /// @return Stream of student's class lists
  Stream<List<ClassModel>> getStudentClasses(String studentId);

  /// Adds a student to a class.
  ///
  /// Enrolls a student in the specified class.
  /// Updates enrollment count and student list.
  ///
  /// @param classId Target class ID
  /// @param studentId Student to enroll
  /// @throws Exception if enrollment fails
  Future<void> addStudent(String classId, String studentId);

  /// Removes a student from a class.
  ///
  /// Unenrolls a student from the specified class.
  /// Updates enrollment count accordingly.
  ///
  /// @param classId Target class ID
  /// @param studentId Student to remove
  /// @throws Exception if removal fails
  Future<void> removeStudent(String classId, String studentId);

  /// Retrieves all students enrolled in a class.
  ///
  /// Fetches complete list of students with their
  /// profile information for roster display.
  ///
  /// @param classId Class to get students for
  /// @return List of enrolled student profiles
  /// @throws Exception if retrieval fails
  Future<List<UserModel>> getClassStudents(String classId);

  /// Checks if a student is enrolled in a class.
  ///
  /// Quick verification without loading full student list.
  /// Useful for access control and validation.
  ///
  /// @param classId Class to check
  /// @param studentId Student to verify
  /// @return true if enrolled, false otherwise
  /// @throws Exception if check fails
  Future<bool> isStudentEnrolled(String classId, String studentId);

  /// Calculates statistics for a class.
  ///
  /// Generates aggregate data including:
  /// - Total enrollment count
  /// - Assignment completion rates
  /// - Average grades
  /// - Attendance statistics
  /// - Activity metrics
  ///
  /// @param classId Class to analyze
  /// @return Map of statistical data
  /// @throws Exception if calculation fails
  Future<Map<String, dynamic>> getClassStats(String classId);

  /// Archives a class at end of term.
  ///
  /// Moves the class to archived state, hiding it
  /// from active lists while preserving all data.
  /// Can be restored if needed.
  ///
  /// @param classId ID of class to archive
  /// @throws Exception if archiving fails
  Future<void> archiveClass(String classId);

  /// Restores an archived class.
  ///
  /// Returns the class to active state, making it
  /// visible in current class lists again.
  ///
  /// @param classId ID of class to restore
  /// @throws Exception if restoration fails
  Future<void> restoreClass(String classId);

  /// Enrolls a single student in a class.
  ///
  /// Alternative method for student enrollment with
  /// additional validation and notifications.
  ///
  /// @param classId Target class ID
  /// @param studentId Student to enroll
  /// @throws Exception if enrollment fails
  Future<void> enrollStudent(String classId, String studentId);

  /// Unenrolls a single student from a class.
  ///
  /// Alternative method for student removal with
  /// proper cleanup and notifications.
  ///
  /// @param classId Target class ID
  /// @param studentId Student to unenroll
  /// @throws Exception if unenrollment fails
  Future<void> unenrollStudent(String classId, String studentId);

  /// Enrolls multiple students in batch.
  ///
  /// Efficiently adds multiple students to a class
  /// using batch operations. All enrollments succeed
  /// or fail together.
  ///
  /// @param classId Target class ID
  /// @param studentIds List of students to enroll
  /// @throws Exception if batch enrollment fails
  Future<void> enrollMultipleStudents(String classId, List<String> studentIds);

  /// Retrieves active classes for an academic year.
  ///
  /// Fetches non-archived classes for a specific teacher
  /// and academic year. Useful for term-based filtering.
  ///
  /// @param teacherId Teacher's user ID
  /// @param academicYear Academic year (e.g., "2023-2024")
  /// @return List of active classes
  /// @throws Exception if retrieval fails
  Future<List<ClassModel>> getActiveClasses(
      String teacherId, String academicYear);

  /// Finds a class by its enrollment code.
  ///
  /// Used for student enrollment via code entry.
  /// Only returns active classes with valid codes.
  ///
  /// @param enrollmentCode The enrollment code to search for
  /// @return Class instance or null if not found
  /// @throws Exception if search fails
  Future<ClassModel?> getClassByEnrollmentCode(String enrollmentCode);

  /// Enrolls a student using an enrollment code.
  ///
  /// Validates the enrollment code and adds the student
  /// to the class if capacity allows.
  ///
  /// @param studentId Student to enroll
  /// @param enrollmentCode Class enrollment code
  /// @return The enrolled class model
  /// @throws Exception if enrollment fails
  Future<ClassModel> enrollWithCode(String studentId, String enrollmentCode);

  /// Generates a new enrollment code for a class.
  ///
  /// Creates a unique 6-character alphanumeric code
  /// and updates the class record.
  ///
  /// @param classId Class to generate code for
  /// @return The new enrollment code
  /// @throws Exception if generation fails
  Future<String> regenerateEnrollmentCode(String classId);
}
