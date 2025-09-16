import 'dart:async';
import '../../data/repositories/behavior_points_repository.dart';
import '../../data/models/student_points_aggregate.dart';
import '../../data/models/behavior_history_entry.dart';
import '../models/behavior.dart';
import '../../../../shared/services/logger_service.dart';

/// Service layer for behavior points business logic
///
/// Coordinates between the repository and provider layers,
/// handling validation and business rules.
class BehaviorPointsService {
  static const String _tag = 'BehaviorPointsService';

  final BehaviorPointsRepository _repository;

  BehaviorPointsService({
    BehaviorPointsRepository? repository,
  }) : _repository = repository ?? BehaviorPointsRepository();

  // ============= Point Operations =============

  /// Awards points to a student with validation
  Future<bool> awardPoints({
    required String classId,
    required String studentId,
    required String studentName,
    required Behavior behavior,
    String? note,
    String? operationId,
  }) async {
    // Validate inputs
    if (classId.isEmpty) {
      LoggerService.error('Class ID is required', tag: _tag);
      return false;
    }

    if (studentId.isEmpty) {
      LoggerService.error('Student ID is required', tag: _tag);
      return false;
    }

    if (studentName.trim().isEmpty ||
        studentName == 'Loading...' ||
        studentName == 'Unknown Student') {
      LoggerService.error('Valid student name is required', tag: _tag);
      return false;
    }

    // Award points through repository
    return await _repository.awardPoints(
      classId: classId,
      studentId: studentId,
      studentName: studentName,
      behaviorId: behavior.id,
      behaviorName: behavior.name,
      behaviorType: behavior.type.name,
      points: behavior.points,
      note: note ?? behavior.description,
      operationId: operationId,
    );
  }

  /// Undo the last operation for a student
  Future<bool> undoLastOperation({
    required String classId,
    required String studentId,
  }) async {
    if (classId.isEmpty || studentId.isEmpty) {
      LoggerService.error('Class ID and Student ID are required', tag: _tag);
      return false;
    }

    return await _repository.undoLastOperation(classId, studentId);
  }

  // ============= Data Streaming =============

  /// Streams aggregated points for all students in a class
  Stream<Map<String, StudentPointsAggregate>> streamClassAggregates(String classId) {
    if (classId.isEmpty) {
      return Stream.value({});
    }

    return _repository.streamClassAggregates(classId).map((aggregates) {
      // Convert list to map for easy lookup
      final map = <String, StudentPointsAggregate>{};
      for (final aggregate in aggregates) {
        // Skip invalid entries
        if (aggregate.studentId.isEmpty ||
            aggregate.studentName == 'Loading...' ||
            aggregate.studentName == 'Unknown Student') {
          continue;
        }
        map[aggregate.studentId] = aggregate;
      }
      return map;
    });
  }

  /// Streams behavior history for a class
  Stream<List<BehaviorHistoryEntry>> streamClassHistory(
    String classId, {
    int limit = 100,
  }) {
    if (classId.isEmpty) {
      return Stream.value([]);
    }

    return _repository.streamClassHistory(classId, limit: limit);
  }

  /// Streams behavior history for a specific student
  Stream<List<BehaviorHistoryEntry>> streamStudentHistory(
    String classId,
    String studentId, {
    int limit = 50,
  }) {
    if (classId.isEmpty || studentId.isEmpty) {
      return Stream.value([]);
    }

    return _repository.streamStudentHistory(classId, studentId, limit: limit);
  }

  /// Streams all behaviors available for a class
  Stream<List<Behavior>> streamBehaviors(String classId) {
    if (classId.isEmpty) {
      return Stream.value([]);
    }

    return _repository.streamBehaviors(classId);
  }

  // ============= Behavior Management =============

  /// Creates a custom behavior for a class
  Future<String?> createCustomBehavior({
    required String name,
    required String description,
    required int points,
    required BehaviorType type,
    required String teacherId,
    required String classId,
    String? iconName,
  }) async {
    // Validate inputs
    if (name.trim().isEmpty) {
      LoggerService.error('Behavior name is required', tag: _tag);
      return null;
    }

    if (points == 0) {
      LoggerService.error('Points cannot be zero', tag: _tag);
      return null;
    }

    // Ensure points match type
    final adjustedPoints = type == BehaviorType.positive
        ? points.abs()
        : -points.abs();

    final behavior = Behavior(
      id: '', // Will be set by Firestore
      name: name.trim(),
      description: description.trim(),
      points: adjustedPoints,
      type: type,
      iconName: iconName,
      isCustom: true,
      teacherId: teacherId,
      classId: classId,
    );

    return await _repository.createCustomBehavior(behavior);
  }

  /// Deletes a custom behavior
  Future<bool> deleteBehavior(String behaviorId) async {
    if (behaviorId.isEmpty) {
      LoggerService.error('Behavior ID is required', tag: _tag);
      return false;
    }

    return await _repository.deleteBehavior(behaviorId);
  }

  // ============= Analytics & Statistics =============

  /// Calculates class-wide statistics
  Map<String, dynamic> calculateClassStatistics(
    Map<String, StudentPointsAggregate> aggregates,
  ) {
    if (aggregates.isEmpty) {
      return {
        'totalStudents': 0,
        'averagePoints': 0.0,
        'totalPositivePoints': 0,
        'totalNegativePoints': 0,
        'topPerformers': [],
        'needsAttention': [],
      };
    }

    final students = aggregates.values.toList();
    final totalStudents = students.length;

    final totalPoints = students.fold<int>(
      0,
      (sum, student) => sum + student.totalPoints,
    );

    final totalPositive = students.fold<int>(
      0,
      (sum, student) => sum + student.positivePoints,
    );

    final totalNegative = students.fold<int>(
      0,
      (sum, student) => sum + student.negativePoints,
    );

    // Sort by total points
    students.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    // Get top 5 performers
    final topPerformers = students
        .where((s) => s.totalPoints > 0)
        .take(5)
        .toList();

    // Get students needing attention (negative points)
    final needsAttention = students
        .where((s) => s.totalPoints < 0)
        .toList();

    return {
      'totalStudents': totalStudents,
      'averagePoints': totalPoints / totalStudents,
      'totalPositivePoints': totalPositive,
      'totalNegativePoints': totalNegative,
      'topPerformers': topPerformers,
      'needsAttention': needsAttention,
    };
  }
}