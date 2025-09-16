import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:fermi_plus/features/behavior_points/data/models/behavior_history_entry.dart';
import 'package:fermi_plus/features/behavior_points/data/models/student_points_aggregate.dart';
import 'package:fermi_plus/features/behavior_points/domain/models/behavior.dart';
import 'package:fermi_plus/shared/services/logger_service.dart';

/// Service for managing behavior points using Firebase Functions
/// All write operations go through server-side Functions for security
/// Read operations use Firestore streams for real-time updates
class BehaviorPointsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-east4',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Award behavior points to a student via Firebase Function
  Future<bool> awardBehaviorPoints({
    required String classId,
    required String studentId,
    required String studentName,
    required Behavior behavior,
  }) async {
    // Skip invalid entries
    if (studentId.isEmpty || studentName == 'Loading...') {
      LoggerService.warning(
        'Skipping invalid student entry: $studentName (ID: $studentId)',
      );
      return false;
    }

    try {
      final callable = _functions.httpsCallable('awardBehaviorPoints');
      final result = await callable.call({
        'classId': classId,
        'studentId': studentId,
        'studentName': studentName,
        'behaviorId': behavior.id,
        'behaviorName': behavior.name,
        'points': behavior.points,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        LoggerService.info(
          'Points awarded successfully: ${data['operationId']}',
        );
        return true;
      } else {
        LoggerService.warning('Points award failed: ${data['message']}');
        return false;
      }
    } on FirebaseFunctionsException catch (e) {
      LoggerService.error('Firebase Function error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      LoggerService.error('Failed to award points: $e');
      return false;
    }
  }

  /// Undo previously awarded behavior points via Firebase Function
  Future<bool> undoBehaviorPoints({
    required String classId,
    required String studentId,
    required String historyId,
  }) async {
    try {
      final callable = _functions.httpsCallable('undoBehaviorPoints');
      final result = await callable.call({
        'classId': classId,
        'studentId': studentId,
        'historyId': historyId,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        LoggerService.info('Points undone successfully');
        return true;
      } else {
        LoggerService.warning('Points undo failed: ${data['message']}');
        return false;
      }
    } on FirebaseFunctionsException catch (e) {
      LoggerService.error('Firebase Function error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      LoggerService.error('Failed to undo points: $e');
      return false;
    }
  }

  /// Get class points summary via Firebase Function (for initial load)
  Future<Map<String, StudentPointsAggregate>> getClassPointsSummary(
    String classId,
  ) async {
    try {
      final callable = _functions.httpsCallable('getClassPointsSummary');
      final result = await callable.call({'classId': classId});

      final data = result.data as Map<String, dynamic>;
      final summaries = <String, StudentPointsAggregate>{};

      if (data['success'] == true && data['summaries'] != null) {
        (data['summaries'] as Map<String, dynamic>).forEach((key, value) {
          summaries[key] = StudentPointsAggregate.fromMap(
            value as Map<String, dynamic>,
          );
        });
      }

      return summaries;
    } on FirebaseFunctionsException catch (e) {
      LoggerService.error('Firebase Function error: ${e.code} - ${e.message}');
      return {};
    } catch (e) {
      LoggerService.error('Failed to get points summary: $e');
      return {};
    }
  }

  /// Watch real-time updates to class points summary (read-only stream)
  Stream<Map<String, StudentPointsAggregate>> watchClassPointsSummary(
    String classId,
  ) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('studentPoints')
        .snapshots()
        .map((snapshot) {
          final summaries = <String, StudentPointsAggregate>{};

          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              // Filter out invalid entries
              if (data['studentId'] != null &&
                  data['studentId'].toString().isNotEmpty &&
                  data['studentName'] != 'Loading...') {
                summaries[doc.id] = StudentPointsAggregate.fromMap(data);
              }
            } catch (e) {
              LoggerService.error(
                'Error parsing student points aggregate: ${doc.id} - $e',
              );
            }
          }

          return summaries;
        });
  }

  /// Watch recent history entries for a class (read-only stream)
  Stream<List<BehaviorHistoryEntry>> watchRecentHistory(
    String classId, {
    int limit = 10,
  }) {
    return _firestore
        .collectionGroup('history')
        .where('classId', isEqualTo: classId)
        .where('isUndone', isEqualTo: false)
        .orderBy('awardedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return BehaviorHistoryEntry.fromMap(doc.data());
                } catch (e) {
                  LoggerService.error(
                    'Error parsing history entry: ${doc.id} - $e',
                  );
                  return null;
                }
              })
              .where((entry) => entry != null)
              .cast<BehaviorHistoryEntry>()
              .toList();
        });
  }

  /// Watch history entries for a specific student (read-only stream)
  Stream<List<BehaviorHistoryEntry>> watchStudentHistory(
    String classId,
    String studentId, {
    int limit = 20,
  }) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('studentPoints')
        .doc(studentId)
        .collection('history')
        .where('isUndone', isEqualTo: false)
        .orderBy('awardedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return BehaviorHistoryEntry.fromMap(doc.data());
                } catch (e) {
                  LoggerService.error(
                    'Error parsing student history entry: ${doc.id} - $e',
                  );
                  return null;
                }
              })
              .where((entry) => entry != null)
              .cast<BehaviorHistoryEntry>()
              .toList();
        });
  }

  /// Get a single student's points aggregate (read-only)
  Future<StudentPointsAggregate?> getStudentPoints(
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

      if (!doc.exists) {
        return null;
      }

      return StudentPointsAggregate.fromMap(doc.data()!);
    } catch (e) {
      LoggerService.error('Failed to get student points: $e');
      return null;
    }
  }

  /// Stream class behaviors for real-time updates.
  Stream<List<Behavior>> watchClassBehaviors(String classId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('behaviors')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return Behavior.fromFirestore(doc);
                } catch (error) {
                  LoggerService.error(
                    'Failed to parse behavior ${doc.id}: $error',
                  );
                  return null;
                }
              })
              .whereType<Behavior>()
              .toList();
        });
  }

  /// Create or update a behavior for the class.
  Future<bool> saveBehavior({
    required String classId,
    required String teacherId,
    String? behaviorId,
    required String name,
    required String description,
    required int points,
    required BehaviorType type,
    required IconData icon,
  }) async {
    try {
      final behaviorsRef = _firestore
          .collection('classes')
          .doc(classId)
          .collection('behaviors');

      final docRef = behaviorId != null && behaviorId.isNotEmpty
          ? behaviorsRef.doc(behaviorId)
          : behaviorsRef.doc();

      await docRef.set({
        'name': name,
        'description': description,
        'points': points,
        'type': type.name,
        'iconCodePoint': icon.codePoint,
        'isCustom': true,
        'teacherId': teacherId,
        'classId': classId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      LoggerService.error('Failed to save behavior: $e');
      return false;
    }
  }

  /// Delete a behavior document from the class.
  Future<bool> deleteBehavior({
    required String classId,
    required String behaviorId,
  }) async {
    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('behaviors')
          .doc(behaviorId)
          .delete();
      return true;
    } catch (e) {
      LoggerService.error('Failed to delete behavior: $e');
      return false;
    }
  }
}
