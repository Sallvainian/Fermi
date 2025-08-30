import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/assignment.dart';
import '../../../../shared/services/firestore_repository.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../notifications/data/services/notification_service.dart';

/// Refactored service for managing educational assignments.
///
/// This implementation delegates all generic CRUD operations to the
/// reusable [FirestoreRepository], avoiding duplication of Firestore
/// interaction code. It exposes higher level domain operations such
/// as publishing and scheduling while remaining focused on assignment-
/// specific logic.
class AssignmentService {
  final FirestoreRepository<Assignment> _repository;
  final NotificationService? _notificationService;

  AssignmentService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _repository = FirestoreRepository<Assignment>(
          collectionPath: 'assignments',
          firestore: firestore,
          fromFirestore: (doc) => Assignment.fromFirestore(doc),
          toFirestore: (model) => model.toFirestore(),
        ),
        _notificationService = notificationService;

  /// Creates a new assignment with notification scheduling
  Future<Assignment> createAssignment(Assignment assignment) async {
    final id = await _repository.create(assignment.toFirestore());
    final createdAssignment = assignment.copyWith(id: id);
    
    // Schedule notification reminder for due date if service is available
    if (_notificationService != null) {
      await _notificationService.scheduleAssignmentReminder(createdAssignment);
    }
    
    LoggerService.info(
        'Created assignment: ${createdAssignment.title} for class ${createdAssignment.classId}');
    return createdAssignment;
  }

  /// Retrieves a single assignment by ID
  Future<Assignment?> getAssignment(String assignmentId) async {
    return await _repository.get(assignmentId);
  }

  /// Updates an existing assignment
  Future<void> updateAssignment(Assignment assignment) async {
    await _repository.update(assignment.id, assignment.toFirestore());
    LoggerService.info('Updated assignment: ${assignment.title}');
  }

  /// Deletes an assignment and cascades to related grades
  Future<void> deleteAssignment(String assignmentId) async {
    // Delete all grades for this assignment first
    final grades = await _repository.firestore
        .collection('grades')
        .where('assignmentId', isEqualTo: assignmentId)
        .get();
    
    final batch = _repository.firestore.batch();
    for (final doc in grades.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_repository.collection.doc(assignmentId));
    
    await batch.commit();
    LoggerService.info('Deleted assignment $assignmentId and ${grades.docs.length} related grades');
  }

  /// Streams published assignments for a specific class
  Stream<List<Assignment>> getAssignmentsForClass(String classId) {
    return _repository.streamList((col) => col
        .where('classId', isEqualTo: classId)
        .where('isPublished', isEqualTo: true)
        .orderBy('dueDate', descending: false));
  }

  /// Streams all assignments created by a specific teacher
  Stream<List<Assignment>> getAssignmentsForTeacher(String teacherId) {
    return _repository.streamList((col) => col
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true));
  }

  /// Gets assignments for a specific student based on their classes
  Future<List<Assignment>> getAssignmentsForStudent(
      String studentId, List<String> classIds) async {
    if (classIds.isEmpty) return [];
    
    return await _repository.getList((col) => col
        .where('classId', whereIn: classIds)
        .where('isPublished', isEqualTo: true)
        .orderBy('dueDate', descending: false));
  }

  /// Publishes a draft assignment
  Future<void> publishAssignment(String assignmentId) async {
    await _repository.collection.doc(assignmentId).update({
      'isPublished': true,
      'status': AssignmentStatus.active.toString().split('.').last,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    LoggerService.info('Published assignment: $assignmentId');
  }

  /// Unpublishes an assignment
  Future<void> unpublishAssignment(String assignmentId) async {
    await _repository.collection.doc(assignmentId).update({
      'isPublished': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    LoggerService.info('Unpublished assignment: $assignmentId');
  }

  /// Publishes assignments scheduled for automatic release
  Future<void> publishScheduledAssignments() async {
    final now = DateTime.now();
    
    final assignments = await _repository.getList((col) => col
        .where('isPublished', isEqualTo: false)
        .where('publishAt', isLessThanOrEqualTo: Timestamp.fromDate(now)));
    
    if (assignments.isEmpty) return;
    
    final batch = _repository.firestore.batch();
    
    for (final assignment in assignments) {
      batch.update(_repository.collection.doc(assignment.id), {
        'isPublished': true,
        'status': AssignmentStatus.active.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    LoggerService.info('Published ${assignments.length} scheduled assignments');
  }

  /// Gets upcoming assignments for a class
  Future<List<Assignment>> getUpcomingAssignments(String classId, {int days = 7}) async {
    final cutoffDate = DateTime.now().add(Duration(days: days));
    
    return await _repository.getList((col) => col
        .where('classId', isEqualTo: classId)
        .where('isPublished', isEqualTo: true)
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(cutoffDate))
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
        .orderBy('dueDate'));
  }

  /// Gets overdue assignments for a class
  Future<List<Assignment>> getOverdueAssignments(String classId) async {
    return await _repository.getList((col) => col
        .where('classId', isEqualTo: classId)
        .where('isPublished', isEqualTo: true)
        .where('dueDate', isLessThan: Timestamp.fromDate(DateTime.now()))
        .where('status', isEqualTo: AssignmentStatus.active.toString().split('.').last)
        .orderBy('dueDate', descending: true));
  }

  /// Archives completed assignments older than specified days
  Future<void> archiveOldAssignments({int daysOld = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    
    final assignments = await _repository.getList((col) => col
        .where('status', isEqualTo: AssignmentStatus.completed.toString().split('.').last)
        .where('dueDate', isLessThan: Timestamp.fromDate(cutoffDate)));
    
    if (assignments.isEmpty) return;
    
    final batch = _repository.firestore.batch();
    
    for (final assignment in assignments) {
      batch.update(_repository.collection.doc(assignment.id), {
        'status': AssignmentStatus.archived.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    LoggerService.info('Archived ${assignments.length} old assignments');
  }

  /// Gets assignment statistics for a teacher
  Future<Map<String, dynamic>> getTeacherAssignmentStats(String teacherId) async {
    final assignments = await _repository.getList((col) => col
        .where('teacherId', isEqualTo: teacherId));
    
    final now = DateTime.now();
    int activeCount = 0;
    int overdueCount = 0;
    int upcomingCount = 0;
    int draftCount = 0;
    
    for (final assignment in assignments) {
      if (assignment.status == AssignmentStatus.draft) {
        draftCount++;
      } else if (assignment.status == AssignmentStatus.active) {
        activeCount++;
        if (assignment.dueDate.isBefore(now)) {
          overdueCount++;
        } else if (assignment.dueDate.difference(now).inDays <= 7) {
          upcomingCount++;
        }
      }
    }
    
    return {
      'totalAssignments': assignments.length,
      'activeAssignments': activeCount,
      'draftAssignments': draftCount,
      'overdueAssignments': overdueCount,
      'upcomingAssignments': upcomingCount,
    };
  }
}