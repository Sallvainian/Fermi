import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/assignment.dart';
import '../../../../shared/services/firestore_repository.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/services/retry_service.dart';
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
    return await RetryService.withRetry(
      () async {
        final id = await _repository.create(assignment.toFirestore());
        final createdAssignment = assignment.copyWith(id: id);
        
        // Schedule notification reminder for due date if service is available
        if (_notificationService != null) {
          await _notificationService.scheduleAssignmentReminder(createdAssignment);
        }
        
        LoggerService.info(
            'Created assignment: ${createdAssignment.title} for class ${createdAssignment.classId}');
        return createdAssignment;
      },
      config: RetryConfigs.standard,
      onRetry: (attempt, delay, error) {
        LoggerService.warning(
            'Retrying assignment creation (attempt $attempt): ${error.toString()}');
      },
    );
  }

  /// Retrieves a single assignment by ID
  Future<Assignment?> getAssignment(String assignmentId) async {
    return await _repository.get(assignmentId);
  }

  /// Updates an existing assignment
  Future<void> updateAssignment(Assignment assignment) async {
    await RetryService.withRetry(
      () async {
        await _repository.update(assignment.id, assignment.toFirestore());
        LoggerService.info('Updated assignment: ${assignment.title}');
      },
      config: RetryConfigs.standard,
    );
  }

  /// Deletes an assignment and cascades to related grades with transaction safety
  Future<void> deleteAssignment(String assignmentId) async {
    await _repository.runTransaction<void>((transaction, collection) async {
      // First, verify the assignment exists
      final assignmentDoc = await transaction.get(
        collection.doc(assignmentId),
      );
      
      if (!assignmentDoc.exists) {
        throw Exception('Assignment not found: $assignmentId');
      }
      
      // Fetch all grades for this assignment
      final gradesQuery = await _repository.getCollectionReference('grades')
          .where('assignmentId', isEqualTo: assignmentId)
          .get();
      
      // Delete all related grades within the transaction
      for (final gradeDoc in gradesQuery.docs) {
        transaction.delete(gradeDoc.reference);
      }
      
      // Finally, delete the assignment itself
      transaction.delete(assignmentDoc.reference);
      
      LoggerService.info(
          'Deleted assignment $assignmentId and ${gradesQuery.docs.length} related grades');
    });
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
      'status': AssignmentStatus.active.name,
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
    await RetryService.withRetry(
      () async {
        final now = DateTime.now();
        
        final assignments = await _repository.getList((col) => col
            .where('isPublished', isEqualTo: false)
            .where('publishAt', isLessThanOrEqualTo: Timestamp.fromDate(now)));
        
        if (assignments.isEmpty) return;
        
        final updates = <String, Map<String, dynamic>>{};
        for (final assignment in assignments) {
          updates[assignment.id] = {
            'isPublished': true,
            'status': AssignmentStatus.active.name,
            'updatedAt': FieldValue.serverTimestamp(),
          };
        }
        
        await _repository.batchUpdate(updates);
        LoggerService.info('Published ${assignments.length} scheduled assignments');
      },
      config: RetryConfigs.aggressive,  // More retries for scheduled jobs
      onRetry: (attempt, delay, error) {
        LoggerService.warning(
            'Retrying scheduled assignment publishing (attempt $attempt): ${error.toString()}');
      },
    );
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
        .where('status', isEqualTo: AssignmentStatus.active.name)
        .orderBy('dueDate', descending: true));
  }

  /// Archives completed assignments older than specified days
  Future<void> archiveOldAssignments({int daysOld = 30}) async {
    await RetryService.withRetry(
      () async {
        final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
        
        final assignments = await _repository.getList((col) => col
            .where('status', isEqualTo: AssignmentStatus.completed.name)
            .where('dueDate', isLessThan: Timestamp.fromDate(cutoffDate)));
        
        if (assignments.isEmpty) return;
        
        final updates = <String, Map<String, dynamic>>{};
        for (final assignment in assignments) {
          updates[assignment.id] = {
            'status': AssignmentStatus.archived.name,
            'updatedAt': FieldValue.serverTimestamp(),
          };
        }
        
        await _repository.batchUpdate(updates);
        LoggerService.info('Archived ${assignments.length} old assignments');
      },
      config: RetryConfigs.standard,
    );
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