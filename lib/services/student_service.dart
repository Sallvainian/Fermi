/// Student management service for the education platform.
/// 
/// This service provides comprehensive functionality for managing
/// student profiles, enrollments, and related data operations.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';

/// Core service for managing students in Firestore.
/// 
/// This service handles:
/// - Student lifecycle management (create, read, update, delete)
/// - Class enrollment management
/// - Student queries and filtering
/// - Batch operations for efficient bulk processing
/// - Real-time student data streams
/// 
/// The service uses dependency injection for Firestore instance,
/// supporting both production and testing environments.
class StudentService {
  /// Firestore database instance for batch operations.
  final FirebaseFirestore _firestore;
  
  /// Reference to the students collection in Firestore.
  final CollectionReference _studentsCollection;

  /// Creates a StudentService instance.
  /// 
  /// Accepts optional [firestore] parameter for dependency injection,
  /// defaulting to the singleton instance if not provided.
  /// This pattern supports both production use and unit testing.
  StudentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _studentsCollection = (firestore ?? FirebaseFirestore.instance).collection('students');

  // --- Student CRUD Operations ---

  /// Creates a new student in Firestore.
  /// 
  /// Adds the student to the database and returns it with
  /// the generated document ID. The student's metadata and
  /// enrollment data should be set before calling this method.
  /// 
  /// @param student Student model to create
  /// @return Created student with generated ID
  /// @throws Exception if creation fails
  Future<Student> createStudent(Student student) async {
    try {
      final docRef = await _studentsCollection.add(student.toFirestore());
      return student.copyWith(id: docRef.id);
    } catch (e) {
      // Error creating student: $e
      rethrow;
    }
  }

  /// Retrieves a single student by ID.
  /// 
  /// Fetches the student document from Firestore and converts
  /// it to a Student model. Returns null if the student
  /// doesn't exist.
  /// 
  /// @param studentId Unique identifier of the student
  /// @return Student instance or null if not found
  /// @throws Exception if retrieval fails
  Future<Student?> getStudent(String studentId) async {
    try {
      final doc = await _studentsCollection.doc(studentId).get();
      if (!doc.exists) return null;
      return Student.fromFirestore(doc);
    } catch (e) {
      // Error getting student: $e
      rethrow;
    }
  }

  /// Retrieves a student by their user ID.
  /// 
  /// Queries for the student record associated with a specific
  /// user authentication ID. Returns null if no student is found.
  /// 
  /// @param userId User authentication ID
  /// @return Student instance or null if not found
  /// @throws Exception if query fails
  Future<Student?> getStudentByUserId(String userId) async {
    try {
      final query = await _studentsCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (query.docs.isEmpty) return null;
      return Student.fromFirestore(query.docs.first);
    } catch (e) {
      // Error getting student by userId: $e
      rethrow;
    }
  }

  /// Streams all students in the system.
  /// 
  /// Returns a real-time stream of all students:
  /// - Ordered by display name (alphabetical)
  /// - Including both active and inactive students
  /// - Updated in real-time as data changes
  /// 
  /// @return Stream of student lists
  Stream<List<Student>> getAllStudents() {
    return _studentsCollection
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Student.fromFirestore(doc))
            .toList());
  }

  /// Streams active students only.
  /// 
  /// Returns a real-time stream of students where:
  /// - isActive field is true
  /// - Ordered by display name (alphabetical)
  /// - Updated in real-time as data changes
  /// 
  /// @return Stream of active student lists
  Stream<List<Student>> getActiveStudents() {
    return _studentsCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final students = snapshot.docs
              .map((doc) => Student.fromFirestore(doc))
              .toList();
          // Sort in memory temporarily until index is created
          students.sort((a, b) => a.displayName.compareTo(b.displayName));
          return students;
        });
  }

  /// Streams students enrolled in a specific class.
  /// 
  /// Returns a real-time stream of students:
  /// - Enrolled in the given class ID
  /// - Ordered by display name (alphabetical)
  /// - Updated in real-time as enrollments change
  /// 
  /// @param classId Class identifier to filter students
  /// @return Stream of student lists for the class
  Stream<List<Student>> getStudentsForClass(String classId) {
    return _studentsCollection
        .where('classIds', arrayContains: classId)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Student.fromFirestore(doc))
            .toList());
  }

  /// Streams students filtered by grade level.
  /// 
  /// Returns a real-time stream of students:
  /// - At the specified grade level
  /// - Ordered by display name (alphabetical)
  /// - Updated in real-time as data changes
  /// 
  /// @param gradeLevel Grade level to filter by
  /// @return Stream of student lists for the grade
  Stream<List<Student>> getStudentsByGrade(int gradeLevel) {
    return _studentsCollection
        .where('gradeLevel', isEqualTo: gradeLevel)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Student.fromFirestore(doc))
            .toList());
  }

  /// Searches students by name or email.
  /// 
  /// Performs a case-insensitive search across student names and emails.
  /// Note: This is a simple implementation that may need optimization
  /// for large datasets. Consider implementing server-side search
  /// or using a search service for better performance.
  /// 
  /// @param query Search query string
  /// @return List of matching students
  /// @throws Exception if search fails
  Future<List<Student>> searchStudents(String query) async {
    try {
      final queryLower = query.toLowerCase();
      
      // Get all students and filter on client side
      // TODO: Implement server-side search for better performance
      final snapshot = await _studentsCollection.get();
      final allStudents = snapshot.docs
          .map((doc) => Student.fromFirestore(doc))
          .toList();
      
      return allStudents.where((student) {
        return student.displayName.toLowerCase().contains(queryLower) ||
               student.email.toLowerCase().contains(queryLower) ||
               student.firstName.toLowerCase().contains(queryLower) ||
               student.lastName.toLowerCase().contains(queryLower);
      }).toList();
    } catch (e) {
      // Error searching students: $e
      rethrow;
    }
  }

  /// Updates an existing student in Firestore.
  /// 
  /// Overwrites the entire student document with the provided
  /// data. Automatically updates the updatedAt timestamp.
  /// Ensure all required fields are present in the student model.
  /// 
  /// @param student Student model with updated data
  /// @throws Exception if update fails or student doesn't exist
  Future<void> updateStudent(Student student) async {
    try {
      final updatedStudent = student.copyWith(updatedAt: DateTime.now());
      await _studentsCollection
          .doc(student.id)
          .update(updatedStudent.toFirestore());
    } catch (e) {
      // Error updating student: $e
      rethrow;
    }
  }

  /// Deletes a student from Firestore.
  /// 
  /// Permanently removes the student document from the database.
  /// This operation cannot be undone. Consider using soft delete
  /// (setting isActive to false) instead for data retention.
  /// 
  /// @param studentId ID of the student to delete
  /// @throws Exception if deletion fails
  Future<void> deleteStudent(String studentId) async {
    try {
      await _studentsCollection.doc(studentId).delete();
    } catch (e) {
      // Error deleting student: $e
      rethrow;
    }
  }

  /// Soft deletes a student by setting isActive to false.
  /// 
  /// Marks the student as inactive without removing the record.
  /// This preserves historical data while removing the student
  /// from active queries and operations.
  /// 
  /// @param studentId ID of the student to deactivate
  /// @throws Exception if update fails
  Future<void> deactivateStudent(String studentId) async {
    try {
      await _studentsCollection.doc(studentId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error deactivating student: $e
      rethrow;
    }
  }

  /// Reactivates a previously deactivated student.
  /// 
  /// Sets the student's isActive field back to true,
  /// making them visible in active student queries.
  /// 
  /// @param studentId ID of the student to reactivate
  /// @throws Exception if update fails
  Future<void> reactivateStudent(String studentId) async {
    try {
      await _studentsCollection.doc(studentId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error reactivating student: $e
      rethrow;
    }
  }

  // --- Class Enrollment Management ---

  /// Enrolls a student in a class.
  /// 
  /// Adds the class ID to the student's classIds array if not
  /// already present. Updates the student's modification timestamp.
  /// 
  /// @param studentId ID of the student to enroll
  /// @param classId ID of the class to enroll in
  /// @throws Exception if enrollment fails
  Future<void> enrollInClass(String studentId, String classId) async {
    try {
      await _studentsCollection.doc(studentId).update({
        'classIds': FieldValue.arrayUnion([classId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error enrolling student in class: $e
      rethrow;
    }
  }

  /// Unenrolls a student from a class.
  /// 
  /// Removes the class ID from the student's classIds array.
  /// Updates the student's modification timestamp.
  /// 
  /// @param studentId ID of the student to unenroll
  /// @param classId ID of the class to unenroll from
  /// @throws Exception if unenrollment fails
  Future<void> unenrollFromClass(String studentId, String classId) async {
    try {
      await _studentsCollection.doc(studentId).update({
        'classIds': FieldValue.arrayRemove([classId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error unenrolling student from class: $e
      rethrow;
    }
  }

  /// Bulk enrolls multiple students in a class.
  /// 
  /// Efficiently enrolls multiple students using batch operations.
  /// All enrollments succeed or fail together (atomic operation).
  /// 
  /// @param studentIds List of student IDs to enroll
  /// @param classId ID of the class to enroll in
  /// @throws Exception if batch enrollment fails
  Future<void> bulkEnrollInClass(List<String> studentIds, String classId) async {
    try {
      final batch = _firestore.batch();
      
      for (final studentId in studentIds) {
        batch.update(_studentsCollection.doc(studentId), {
          'classIds': FieldValue.arrayUnion([classId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      // Error bulk enrolling students: $e
      rethrow;
    }
  }

  /// Bulk unenrolls multiple students from a class.
  /// 
  /// Efficiently unenrolls multiple students using batch operations.
  /// All unenrollments succeed or fail together (atomic operation).
  /// 
  /// @param studentIds List of student IDs to unenroll
  /// @param classId ID of the class to unenroll from
  /// @throws Exception if batch unenrollment fails
  Future<void> bulkUnenrollFromClass(List<String> studentIds, String classId) async {
    try {
      final batch = _firestore.batch();
      
      for (final studentId in studentIds) {
        batch.update(_studentsCollection.doc(studentId), {
          'classIds': FieldValue.arrayRemove([classId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      // Error bulk unenrolling students: $e
      rethrow;
    }
  }

  // --- Batch Operations ---

  /// Creates multiple students in a single batch operation.
  /// 
  /// Efficiently creates multiple student records using Firestore
  /// batch writes. Each student gets a generated document ID.
  /// All writes succeed or fail together (atomic operation).
  /// 
  /// @param students List of Student models to create
  /// @throws Exception if batch creation fails
  Future<void> bulkCreateStudents(List<Student> students) async {
    try {
      final batch = _firestore.batch();
      
      for (final student in students) {
        final docRef = _studentsCollection.doc();
        batch.set(docRef, student.copyWith(id: docRef.id).toFirestore());
      }
      
      await batch.commit();
    } catch (e) {
      // Error bulk creating students: $e
      rethrow;
    }
  }

  /// Updates multiple students in a single batch operation.
  /// 
  /// Efficiently updates multiple student records using Firestore
  /// batch writes. All students get updated timestamps.
  /// All updates succeed or fail together (atomic operation).
  /// 
  /// @param students List of Student models with updated data
  /// @throws Exception if batch update fails
  Future<void> bulkUpdateStudents(List<Student> students) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (final student in students) {
        final updatedStudent = student.copyWith(updatedAt: now);
        batch.update(
          _studentsCollection.doc(student.id),
          updatedStudent.toFirestore(),
        );
      }
      
      await batch.commit();
    } catch (e) {
      // Error bulk updating students: $e
      rethrow;
    }
  }

  // --- Statistics and Analytics ---

  /// Gets the total count of students in the system.
  /// 
  /// Returns the number of student records, including both
  /// active and inactive students.
  /// 
  /// @return Total student count
  /// @throws Exception if count retrieval fails
  Future<int> getTotalStudentCount() async {
    try {
      final snapshot = await _studentsCollection.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      // Error getting student count: $e
      rethrow;
    }
  }

  /// Gets the count of active students only.
  /// 
  /// Returns the number of students where isActive is true.
  /// 
  /// @return Active student count
  /// @throws Exception if count retrieval fails
  Future<int> getActiveStudentCount() async {
    try {
      final snapshot = await _studentsCollection
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      // Error getting active student count: $e
      rethrow;
    }
  }

  /// Gets the count of students in a specific class.
  /// 
  /// Returns the number of students enrolled in the given class.
  /// 
  /// @param classId Class identifier
  /// @return Student count for the class
  /// @throws Exception if count retrieval fails
  Future<int> getClassStudentCount(String classId) async {
    try {
      final snapshot = await _studentsCollection
          .where('classIds', arrayContains: classId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      // Error getting class student count: $e
      rethrow;
    }
  }

  /// Gets enrollment statistics by grade level.
  /// 
  /// Returns a map of grade level to student count for
  /// visualization and reporting purposes.
  /// 
  /// @return Map of grade level to student count
  /// @throws Exception if statistics retrieval fails
  Future<Map<int, int>> getGradeLevelStatistics() async {
    try {
      final snapshot = await _studentsCollection
          .where('isActive', isEqualTo: true)
          .get();
      
      final stats = <int, int>{};
      for (final doc in snapshot.docs) {
        final student = Student.fromFirestore(doc);
        stats[student.gradeLevel] = (stats[student.gradeLevel] ?? 0) + 1;
      }
      
      return stats;
    } catch (e) {
      // Error getting grade level statistics: $e
      rethrow;
    }
  }
}