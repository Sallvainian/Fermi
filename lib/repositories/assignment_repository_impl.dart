import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assignment.dart';
import '../services/firestore_service.dart';
import '../services/logger_service.dart';
import 'assignment_repository.dart';
import 'firestore_repository.dart';

class AssignmentRepositoryImpl extends FirestoreRepository<Assignment> 
    implements AssignmentRepository {
  
  AssignmentRepositoryImpl(FirebaseFirestore firestore)
      : super(
          firestore: firestore,
          collectionPath: 'assignments',
          fromFirestore: (doc) => Assignment.fromFirestore(doc),
          toFirestore: (assignment) => assignment.toFirestore(),
          logTag: 'AssignmentRepository',
        );
  
  @override
  Future<String> createAssignment(Assignment assignment) async {
    try {
      final assignmentWithTimestamp = assignment.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return await create(assignmentWithTimestamp);
    } catch (e) {
      LoggerService.error('Failed to create assignment', tag: tag, error: e);
      rethrow;
    }
  }  
  @override
  Future<Assignment?> getAssignment(String assignmentId) => read(assignmentId);
  
  @override
  Future<void> updateAssignment(String assignmentId, Assignment assignment) async {
    try {
      final updatedAssignment = assignment.copyWith(
        id: assignmentId,
        updatedAt: DateTime.now(),
      );
      await update(assignmentId, updatedAssignment);
    } catch (e) {
      LoggerService.error('Failed to update assignment', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> deleteAssignment(String assignmentId) => delete(assignmentId);
  
  @override
  Stream<List<Assignment>> getClassAssignments(String classId) {
    return stream(
      conditions: [
        QueryCondition(field: 'classId', isEqualTo: classId),
      ],
      orderBy: [
        OrderBy(field: 'createdAt', descending: true),
      ],
    );
  }  
  @override
  Stream<List<Assignment>> getTeacherAssignments(String teacherId) {
    return stream(
      conditions: [
        QueryCondition(field: 'teacherId', isEqualTo: teacherId),
      ],
      orderBy: [
        OrderBy(field: 'createdAt', descending: true),
      ],
    );
  }
  
  @override
  Stream<List<Assignment>> getClassAssignmentsForMultipleClasses(List<String> classIds) {
    if (classIds.isEmpty) {
      return Stream.value([]);
    }
    
    return stream(
      conditions: [
        QueryCondition(field: 'classId', whereIn: classIds),
      ],
      orderBy: [
        OrderBy(field: 'dueDate', descending: false),
      ],
    );
  }
  
  @override
  Future<List<Assignment>> getUpcomingAssignments(String classId, {int limit = 5}) async {
    final now = DateTime.now();
    return await list(
      conditions: [
        QueryCondition(field: 'classId', isEqualTo: classId),
        QueryCondition(field: 'dueDate', isGreaterThan: Timestamp.fromDate(now)),
        QueryCondition(field: 'isPublished', isEqualTo: true),
        QueryCondition(field: 'status', isEqualTo: 'active'),
      ],
      orderBy: [
        OrderBy(field: 'dueDate', descending: false),
      ],
      limit: limit,
    );
  }  
  @override
  Future<List<Assignment>> getOverdueAssignments(String classId) async {
    final now = DateTime.now();
    return await list(
      conditions: [
        QueryCondition(field: 'classId', isEqualTo: classId),
        QueryCondition(field: 'dueDate', isLessThan: Timestamp.fromDate(now)),
        QueryCondition(field: 'isPublished', isEqualTo: true),
        QueryCondition(field: 'status', isEqualTo: 'active'),
      ],
      orderBy: [
        OrderBy(field: 'dueDate', descending: true),
      ],
    );
  }
  
  @override
  Future<void> publishAssignment(String assignmentId) async {
    try {
      final assignment = await getAssignment(assignmentId);
      if (assignment != null) {
        final published = assignment.copyWith(
          isPublished: true,
          status: AssignmentStatus.active,
          updatedAt: DateTime.now(),
        );
        await update(assignmentId, published);
      }
    } catch (e) {
      LoggerService.error('Failed to publish assignment', tag: tag, error: e);
      rethrow;
    }
  }  
  @override
  Future<void> archiveAssignment(String assignmentId) async {
    try {
      final assignment = await getAssignment(assignmentId);
      if (assignment != null) {
        final archived = assignment.copyWith(
          status: AssignmentStatus.archived,
          updatedAt: DateTime.now(),
        );
        await update(assignmentId, archived);
      }
    } catch (e) {
      LoggerService.error('Failed to archive assignment', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> unpublishAssignment(String assignmentId) async {
    try {
      final assignment = await getAssignment(assignmentId);
      if (assignment != null) {
        final unpublished = assignment.copyWith(
          isPublished: false,
          status: AssignmentStatus.draft,
          updatedAt: DateTime.now(),
        );
        await update(assignmentId, unpublished);
      }
    } catch (e) {
      LoggerService.error('Failed to unpublish assignment', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<void> restoreAssignment(String assignmentId) async {
    try {
      final assignment = await getAssignment(assignmentId);
      if (assignment != null) {
        final restored = assignment.copyWith(
          status: AssignmentStatus.draft,
          updatedAt: DateTime.now(),
        );
        await update(assignmentId, restored);
      }
    } catch (e) {
      LoggerService.error('Failed to restore assignment', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  Future<Map<String, dynamic>> getAssignmentStats(String classId) async {
    try {
      final assignments = await list(
        conditions: [
          QueryCondition(field: 'classId', isEqualTo: classId),
        ],
      );
      
      final now = DateTime.now();
      final total = assignments.length;
      final active = assignments.where((a) => a.status == AssignmentStatus.active).length;
      final overdue = assignments.where((a) => 
        a.status == AssignmentStatus.active && 
        a.dueDate.isBefore(now)
      ).length;
      final upcoming = assignments.where((a) => 
        a.status == AssignmentStatus.active && 
        a.dueDate.isAfter(now)
      ).length;
      
      return {
        'total': total,
        'active': active,
        'overdue': overdue,
        'upcoming': upcoming,
        'completed': assignments.where((a) => a.status == AssignmentStatus.completed).length,
        'archived': assignments.where((a) => a.status == AssignmentStatus.archived).length,
      };
    } catch (e) {
      LoggerService.error('Failed to get assignment stats', tag: tag, error: e);
      rethrow;
    }
  }
}