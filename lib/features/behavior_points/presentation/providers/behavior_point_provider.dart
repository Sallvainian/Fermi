import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../shared/services/logger_service.dart';
import '../../domain/services/behavior_points_service.dart';
import '../../data/repositories/behavior_points_repository.dart';
import '../../data/models/student_points_aggregate.dart';
import '../../data/models/behavior_history_entry.dart';
import '../../domain/models/behavior.dart';

/// Student point summary for UI compatibility
class StudentPointSummary {
  final String studentId;
  final String studentName;
  final int totalPoints;
  final int positivePoints;
  final int negativePoints;
  final int recordCount;
  final DateTime? lastActivity;

  StudentPointSummary({
    required this.studentId,
    required this.studentName,
    required this.totalPoints,
    required this.positivePoints,
    required this.negativePoints,
    required this.recordCount,
    this.lastActivity,
  });

  factory StudentPointSummary.fromAggregate(StudentPointsAggregate aggregate) {
    return StudentPointSummary(
      studentId: aggregate.studentId,
      studentName: aggregate.studentName,
      totalPoints: aggregate.totalPoints,
      positivePoints: aggregate.positivePoints,
      negativePoints: aggregate.negativePoints,
      recordCount: aggregate.behaviorCounts.values.fold(0, (a, b) => a + b),
      lastActivity: aggregate.lastUpdated,
    );
  }
}

/// Behavior point record for UI compatibility
class BehaviorPoint {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final String behaviorId;
  final String behaviorName;
  final int points;
  final String reason;
  final String awardedBy;
  final String awardedByName;
  final DateTime awardedAt;

  BehaviorPoint({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.behaviorId,
    required this.behaviorName,
    required this.points,
    required this.reason,
    required this.awardedBy,
    required this.awardedByName,
    required this.awardedAt,
  });

  factory BehaviorPoint.fromHistoryEntry(BehaviorHistoryEntry entry, String classId) {
    return BehaviorPoint(
      id: entry.operationId,
      studentId: entry.studentId,
      studentName: entry.studentName,
      classId: classId,
      behaviorId: entry.behaviorId,
      behaviorName: entry.behaviorName,
      points: entry.points,
      reason: entry.note ?? '',
      awardedBy: entry.teacherId,
      awardedByName: entry.teacherName,
      awardedAt: entry.timestamp,
    );
  }

  factory BehaviorPoint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BehaviorPoint(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? 'Unknown Student',
      classId: data['classId'] ?? '',
      behaviorId: data['behaviorId'] ?? '',
      behaviorName: data['behaviorName'] ?? '',
      points: data['points'] ?? 0,
      reason: data['reason'] ?? data['note'] ?? '',
      awardedBy: data['awardedBy'] ?? data['teacherId'] ?? '',
      awardedByName: data['awardedByName'] ?? data['teacherName'] ?? 'Unknown',
      awardedAt: (data['awardedAt'] ?? data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Clean behavior point provider using the new backend architecture
class BehaviorPointProvider with ChangeNotifier {
  static const String _tag = 'BehaviorPointProvider';

  final BehaviorPointsService _service;
  final FirebaseAuth _auth;

  // Current state
  String? _currentClassId;
  bool _isLoading = false;
  String? _error;

  // Data streams and caches
  final Map<String, StudentPointsAggregate> _studentAggregates = {};
  final Map<String, StudentPointSummary> _studentSummaries = {};
  List<Behavior> _behaviors = [];
  List<BehaviorHistoryEntry> _historyEntries = [];
  List<BehaviorPoint> _behaviorPoints = [];

  // Stream subscriptions
  StreamSubscription<Map<String, StudentPointsAggregate>>? _aggregatesSubscription;
  StreamSubscription<List<Behavior>>? _behaviorsSubscription;
  StreamSubscription<List<BehaviorHistoryEntry>>? _historySubscription;

  // Factory constructor for dependency injection
  factory BehaviorPointProvider({
    BehaviorPointsService? service,
    FirebaseAuth? auth,
  }) {
    return BehaviorPointProvider._(
      service: service ?? BehaviorPointsService(),
      auth: auth ?? FirebaseAuth.instance,
    );
  }

  // Private constructor
  BehaviorPointProvider._({
    required BehaviorPointsService service,
    required FirebaseAuth auth,
  })  : _service = service,
        _auth = auth;

  // ============= Getters =============

  List<Behavior> get behaviors => _behaviors;
  List<Behavior> get positiveBehaviors =>
      _behaviors.where((b) => b.type == BehaviorType.positive).toList();
  List<Behavior> get negativeBehaviors =>
      _behaviors.where((b) => b.type == BehaviorType.negative).toList();

  Map<String, StudentPointSummary> get studentSummaries =>
      Map.unmodifiable(_studentSummaries);

  List<BehaviorPoint> get behaviorPoints => _behaviorPoints;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentClassId => _currentClassId;

  // ============= Public Methods =============

  /// Loads all data for a class
  Future<void> loadBehaviorPointsForClass(String classId) async {
    if (classId.isEmpty) {
      LoggerService.error('Cannot load behavior points: classId is empty', tag: _tag);
      return;
    }

    _currentClassId = classId;
    _setLoading(true);
    _error = null;

    try {
      // Cancel existing subscriptions
      await _cancelSubscriptions();

      // Subscribe to behaviors
      _behaviorsSubscription = _service.streamBehaviors(classId).listen(
        (behaviors) {
          _behaviors = behaviors;
          notifyListeners();
        },
        onError: (error) {
          LoggerService.error('Failed to load behaviors', tag: _tag, error: error);
          _error = 'Failed to load behaviors';
          notifyListeners();
        },
      );

      // Subscribe to student aggregates
      _aggregatesSubscription = _service.streamClassAggregates(classId).listen(
        (aggregates) {
          _studentAggregates.clear();
          _studentSummaries.clear();

          for (final entry in aggregates.entries) {
            final aggregate = entry.value;

            // Skip invalid entries
            if (aggregate.studentId.isEmpty ||
                aggregate.studentName == 'Loading...' ||
                aggregate.studentName == 'Unknown Student') {
              continue;
            }

            _studentAggregates[entry.key] = aggregate;
            _studentSummaries[entry.key] = StudentPointSummary.fromAggregate(aggregate);
          }

          notifyListeners();
        },
        onError: (error) {
          LoggerService.error('Failed to load student aggregates', tag: _tag, error: error);
          _error = 'Failed to load student points';
          notifyListeners();
        },
      );

      // Subscribe to history for activity feed
      _historySubscription = _service.streamClassHistory(classId).listen(
        (entries) {
          _historyEntries = entries;
          _behaviorPoints = entries
              .where((e) => !e.isUndone)
              .map((e) => BehaviorPoint.fromHistoryEntry(e, classId))
              .toList();
          notifyListeners();
        },
        onError: (error) {
          LoggerService.error('Failed to load history', tag: _tag, error: error);
        },
      );

    } finally {
      _setLoading(false);
    }
  }

  /// Awards points to a student
  Future<void> awardPoints({
    required String studentId,
    required String studentName,
    required String behaviorId,
    required int points,
    String? reason,
    String? operationId,
  }) async {
    if (_currentClassId == null) {
      LoggerService.error('No class selected', tag: _tag);
      _error = 'No class selected';
      notifyListeners();
      return;
    }

    // Validate student ID
    if (studentId.isEmpty) {
      LoggerService.error('Empty studentId provided - cannot award points', tag: _tag);
      _error = 'Invalid student ID';
      notifyListeners();
      return;
    }

    // Find the behavior
    final behavior = _behaviors.firstWhere(
      (b) => b.id == behaviorId,
      orElse: () => throw StateError('Behavior not found: $behaviorId'),
    );

    LoggerService.info('>>> AWARDING POINTS <<<', tag: _tag);
    LoggerService.info('Student: $studentId ($studentName)', tag: _tag);
    LoggerService.info('Behavior: ${behavior.name} (${behavior.points} points)', tag: _tag);

    final success = await _service.awardPoints(
      classId: _currentClassId!,
      studentId: studentId,
      studentName: studentName,
      behavior: behavior,
      note: reason,
      operationId: operationId,
    );

    if (!success) {
      _error = 'Failed to award points';
      notifyListeners();
    } else {
      LoggerService.info('Points awarded successfully', tag: _tag);
    }
  }

  /// Removes the last behavior point (undo operation)
  Future<void> removePoints({
    required String studentId,
  }) async {
    if (_currentClassId == null) {
      LoggerService.error('No class selected', tag: _tag);
      return;
    }

    final success = await _service.undoLastOperation(
      classId: _currentClassId!,
      studentId: studentId,
    );

    if (!success) {
      _error = 'Failed to undo operation';
      notifyListeners();
    }
  }

  /// Creates a custom behavior
  Future<void> createCustomBehavior({
    required String name,
    required String description,
    required int points,
    required String type,
    IconData? icon,
  }) async {
    if (_currentClassId == null) {
      LoggerService.error('No class selected', tag: _tag);
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      LoggerService.error('No authenticated user', tag: _tag);
      return;
    }

    final behaviorType = type.toLowerCase() == 'negative'
        ? BehaviorType.negative
        : BehaviorType.positive;

    final behaviorId = await _service.createCustomBehavior(
      name: name,
      description: description,
      points: points,
      type: behaviorType,
      teacherId: user.uid,
      classId: _currentClassId!,
      iconName: icon?.codePoint.toString(),
    );

    if (behaviorId == null) {
      _error = 'Failed to create custom behavior';
      notifyListeners();
    }
  }

  /// Deletes a custom behavior
  Future<void> deleteBehavior(String behaviorId) async {
    final success = await _service.deleteBehavior(behaviorId);
    if (!success) {
      _error = 'Failed to delete behavior';
      notifyListeners();
    }
  }

  /// Loads behaviors for a class (for backward compatibility)
  Future<void> loadBehaviorsForClass(String classId) async {
    // This is handled by loadBehaviorPointsForClass now
    await loadBehaviorPointsForClass(classId);
  }

  /// Calculates total points for the class
  int calculateClassTotalPoints() {
    return _studentAggregates.values.fold(
      0,
      (sum, aggregate) => sum + aggregate.totalPoints,
    );
  }

  /// Gets behavior points for a specific student
  List<BehaviorPoint> getBehaviorPointsForStudent(String studentId) {
    return _behaviorPoints
        .where((point) => point.studentId == studentId)
        .toList();
  }

  // ============= Private Methods =============

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> _cancelSubscriptions() async {
    await _aggregatesSubscription?.cancel();
    await _behaviorsSubscription?.cancel();
    await _historySubscription?.cancel();
  }

  // ============= Lifecycle =============

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}