import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/services/logger_service.dart';
import '../models/student_points_aggregate.dart';
import '../models/behavior_history_entry.dart';
import '../../domain/models/behavior.dart';

/// Repository for behavior points operations
///
/// Handles all Firestore interactions for the behavior points system.
/// Uses the aggregate pattern for efficient reads and atomic operations
/// for consistency.
class BehaviorPointsRepository {
  static const String _tag = 'BehaviorPointsRepository';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  BehaviorPointsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ============= Aggregate Operations =============

  /// Awards points to a student with idempotency check
  Future<bool> awardPoints({
    required String classId,
    required String studentId,
    required String studentName,
    required String behaviorId,
    required String behaviorName,
    required String behaviorType,
    required int points,
    String? note,
    String? operationId,
  }) async {
    try {
      // Generate operation ID for idempotency
      final opId = operationId ??
          '${DateTime.now().millisecondsSinceEpoch}_${studentId}_$behaviorId';

      LoggerService.info('Awarding points with operation ID: $opId', tag: _tag);

      // Get current user info
      final user = _auth.currentUser;
      if (user == null) {
        LoggerService.error('No authenticated user', tag: _tag);
        return false;
      }

      final teacherId = user.uid;
      final teacherName = user.displayName ?? user.email ?? 'Unknown Teacher';

      // References
      final classRef = _firestore.collection('classes').doc(classId);
      final aggregateRef = classRef.collection('studentPoints').doc(studentId);
      final historyRef = aggregateRef.collection('history').doc(opId);

      // Check for duplicate operation (idempotency)
      final historyDoc = await historyRef.get();
      if (historyDoc.exists) {
        LoggerService.warning(
          'Skipping duplicate operation: $opId',
          tag: _tag,
        );
        return false; // Already processed
      }

      // Create batch for atomic operation
      final batch = _firestore.batch();

      // Update aggregate with atomic increments
      final aggregateUpdate = StudentPointsAggregate.createIncrementUpdate(
        studentId: studentId,
        studentName: studentName,
        classId: classId,
        behaviorId: behaviorId,
        behaviorName: behaviorName,
        points: points,
      );

      batch.set(aggregateRef, aggregateUpdate, SetOptions(merge: true));

      // Add history entry
      final historyEntry = BehaviorHistoryEntry(
        operationId: opId,
        studentId: studentId,
        studentName: studentName,
        behaviorId: behaviorId,
        behaviorName: behaviorName,
        type: behaviorType,
        points: points,
        teacherId: teacherId,
        teacherName: teacherName,
        timestamp: DateTime.now(),
        note: note,
      );

      batch.set(historyRef, historyEntry.toFirestore());

      // Commit atomically
      await batch.commit();

      LoggerService.info(
        'Successfully awarded $points points to $studentName',
        tag: _tag,
      );
      return true;

    } catch (e) {
      LoggerService.error('Failed to award points', tag: _tag, error: e);
      return false;
    }
  }

  /// Streams all student aggregates for a class
  Stream<List<StudentPointsAggregate>> streamClassAggregates(String classId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('studentPoints')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => StudentPointsAggregate.fromFirestore(doc))
              .toList();
        });
  }

  /// Gets a single student's aggregate
  Future<StudentPointsAggregate?> getStudentAggregate(
    String classId,
    String studentId,
  ) async {
    try {
      final doc = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('studentPoints')
          .doc(studentId)
          .get();

      if (!doc.exists) return null;
      return StudentPointsAggregate.fromFirestore(doc);
    } catch (e) {
      LoggerService.error('Failed to get student aggregate', tag: _tag, error: e);
      return null;
    }
  }

  // ============= History Operations =============

  /// Streams behavior history for a class
  Stream<List<BehaviorHistoryEntry>> streamClassHistory(
    String classId, {
    int limit = 100,
  }) {
    return _firestore
        .collectionGroup('history')
        .where('studentId', isNotEqualTo: null)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          // Filter for this class's history
          final classHistory = snapshot.docs
              .where((doc) => doc.reference.path.contains('/classes/$classId/'))
              .map((doc) => BehaviorHistoryEntry.fromFirestore(doc))
              .toList();
          return classHistory;
        });
  }

  /// Streams behavior history for a specific student
  Stream<List<BehaviorHistoryEntry>> streamStudentHistory(
    String classId,
    String studentId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('studentPoints')
        .doc(studentId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BehaviorHistoryEntry.fromFirestore(doc))
              .toList();
        });
  }

  /// Undo last behavior point operation
  Future<bool> undoLastOperation(
    String classId,
    String studentId,
  ) async {
    try {
      // Get the last non-undone history entry
      final historySnapshot = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('studentPoints')
          .doc(studentId)
          .collection('history')
          .where('isUndone', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (historySnapshot.docs.isEmpty) {
        LoggerService.warning('No operation to undo', tag: _tag);
        return false;
      }

      final historyDoc = historySnapshot.docs.first;
      final history = BehaviorHistoryEntry.fromFirestore(historyDoc);

      // Create batch for atomic undo
      final batch = _firestore.batch();

      // Reverse the aggregate update
      final aggregateRef = _firestore
          .collection('classes')
          .doc(classId)
          .collection('studentPoints')
          .doc(studentId);

      final undoUpdate = StudentPointsAggregate.createUndoUpdate(
        behaviorId: history.behaviorId,
        points: history.points,
      );

      batch.update(aggregateRef, undoUpdate);

      // Mark history entry as undone
      batch.update(historyDoc.reference, {'isUndone': true});

      // Commit atomically
      await batch.commit();

      LoggerService.info(
        'Successfully undid operation ${history.operationId}',
        tag: _tag,
      );
      return true;

    } catch (e) {
      LoggerService.error('Failed to undo operation', tag: _tag, error: e);
      return false;
    }
  }

  // ============= Behavior Management =============

  /// Streams all behaviors for a class
  Stream<List<Behavior>> streamBehaviors(String classId) {
    // Get both default and custom behaviors
    return _firestore
        .collection('behaviors')
        .where('classId', whereIn: [null, classId])
        .snapshots()
        .map((snapshot) {
          final behaviors = snapshot.docs.map((doc) {
            final data = doc.data();
            return Behavior(
              id: doc.id,
              name: data['name'] ?? '',
              description: data['description'] ?? '',
              points: data['points'] ?? 0,
              type: data['type'] == 'negative'
                  ? BehaviorType.negative
                  : BehaviorType.positive,
              iconName: data['iconName'],
              isCustom: data['isCustom'] ?? false,
              teacherId: data['teacherId'],
              classId: data['classId'],
            );
          }).toList();

          // Sort: positive first, then by name
          behaviors.sort((a, b) {
            if (a.type != b.type) {
              return a.type == BehaviorType.positive ? -1 : 1;
            }
            return a.name.compareTo(b.name);
          });

          return behaviors;
        });
  }

  /// Creates a custom behavior
  Future<String?> createCustomBehavior(Behavior behavior) async {
    try {
      final docRef = await _firestore
          .collection('behaviors')
          .add(behavior.toFirestore());

      LoggerService.info('Created custom behavior: ${behavior.name}', tag: _tag);
      return docRef.id;
    } catch (e) {
      LoggerService.error('Failed to create behavior', tag: _tag, error: e);
      return null;
    }
  }

  /// Deletes a custom behavior
  Future<bool> deleteBehavior(String behaviorId) async {
    try {
      await _firestore
          .collection('behaviors')
          .doc(behaviorId)
          .delete();

      LoggerService.info('Deleted behavior: $behaviorId', tag: _tag);
      return true;
    } catch (e) {
      LoggerService.error('Failed to delete behavior', tag: _tag, error: e);
      return false;
    }
  }
}