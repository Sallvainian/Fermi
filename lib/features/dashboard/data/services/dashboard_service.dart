import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/services/logger_service.dart';
import '../../domain/models/activity_model.dart';
import '../../../assignments/domain/models/assignment.dart';
import '../../../grades/domain/models/grade.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get recent activities for a teacher
  Future<List<ActivityModel>> getTeacherActivities(
    String teacherId, {
    int limit = 10,
  }) async {
    try {
      // First check if the collection exists
      final querySnapshot = await _firestore
          .collection('activities')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => ActivityModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Log the full error which includes index creation link in development
      LoggerService.error(
        'Error fetching teacher activities - if index is missing, check console for creation link',
        error: e,
      );
      // Return empty list to prevent app crash
      return [];
    }
  }

  // Get recent activities for a student
  Future<List<ActivityModel>> getStudentActivities(
    String studentId,
    List<String> classIds, {
    int limit = 10,
  }) async {
    try {
      if (classIds.isEmpty) return [];

      final querySnapshot = await _firestore
          .collection('activities')
          .where('classId', whereIn: classIds)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => ActivityModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      LoggerService.error('Error fetching student activities', error: e);
      return [];
    }
  }

  // Get assignment statistics for teacher dashboard
  Future<Map<String, int>> getTeacherAssignmentStats(String teacherId) async {
    try {
      // Get total assignments
      final assignmentsQuery = await _firestore
          .collection('assignments')
          .where('teacherId', isEqualTo: teacherId)
          .where('status', isEqualTo: 'active')
          .get();

      // Get assignments needing grading
      final gradingQuery = await _firestore
          .collection('assignments')
          .where('teacherId', isEqualTo: teacherId)
          .where('needsGrading', isEqualTo: true)
          .get()
          .catchError((e) {
            LoggerService.warning('Assignment grading query failed: $e');
            return _firestore.collection('assignments').limit(0).get();
          });

      return {
        'totalAssignments': assignmentsQuery.size,
        'toGrade': gradingQuery.size,
      };
    } catch (e) {
      LoggerService.error('Error fetching assignment stats', error: e);
      return {'totalAssignments': 0, 'toGrade': 0};
    }
  }

  // Get assignment statistics for student dashboard
  Future<Map<String, int>> getStudentAssignmentStats(
    String studentId,
    List<String> classIds,
  ) async {
    try {
      if (classIds.isEmpty) {
        return {'totalAssignments': 0, 'dueSoon': 0};
      }

      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3));

      // Get total active assignments
      final totalQuery = await _firestore
          .collection('assignments')
          .where('classId', whereIn: classIds)
          .where('status', isEqualTo: 'active')
          .get();

      // Get assignments due soon (within 3 days)
      final dueSoonQuery = await _firestore
          .collection('assignments')
          .where('classId', whereIn: classIds)
          .where('dueDate', isGreaterThanOrEqualTo: now)
          .where('dueDate', isLessThanOrEqualTo: threeDaysFromNow)
          .get();

      return {
        'totalAssignments': totalQuery.size,
        'dueSoon': dueSoonQuery.size,
      };
    } catch (e) {
      LoggerService.error('Error fetching student assignment stats', error: e);
      return {'totalAssignments': 0, 'dueSoon': 0};
    }
  }

  // Create an activity log entry
  Future<void> logActivity(ActivityModel activity) async {
    try {
      await _firestore.collection('activities').add(activity.toMap());
    } catch (e) {
      LoggerService.error('Error logging activity', error: e);
    }
  }

  // Get upcoming assignments for a student
  Future<List<Assignment>> getUpcomingAssignments(
    String studentId,
    List<String> classIds, {
    int limit = 5,
  }) async {
    try {
      if (classIds.isEmpty) return [];

      final now = DateTime.now();

      final querySnapshot = await _firestore
          .collection('assignments')
          .where('classId', whereIn: classIds)
          .where('status', isEqualTo: 'active')
          .where('dueDate', isGreaterThan: now)
          .orderBy('dueDate')
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Assignment.fromFirestore(doc))
          .toList();
    } catch (e) {
      LoggerService.error('Error fetching upcoming assignments', error: e);
      return [];
    }
  }

  // Get recent grades for a student
  Future<List<Grade>> getRecentGrades(String studentId, {int limit = 5}) async {
    try {
      final querySnapshot = await _firestore
          .collection('grades')
          .where('studentId', isEqualTo: studentId)
          .where('isGraded', isEqualTo: true)
          .orderBy('gradedAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => Grade.fromFirestore(doc)).toList();
    } catch (e) {
      LoggerService.error('Error fetching recent grades', error: e);
      return [];
    }
  }

  // Calculate GPA for a student
  Future<double> calculateGPA(String studentId) async {
    try {
      final gradesQuery = await _firestore
          .collection('grades')
          .where('studentId', isEqualTo: studentId)
          .where('isGraded', isEqualTo: true)
          .get();

      if (gradesQuery.docs.isEmpty) return 0.0;

      double totalPoints = 0;
      double totalPossible = 0;

      for (var doc in gradesQuery.docs) {
        final grade = Grade.fromFirestore(doc);
        totalPoints += grade.pointsEarned;
        totalPossible += grade.pointsPossible;
      }

      if (totalPossible == 0) return 0.0;

      // Convert percentage to 4.0 scale GPA
      final percentage = (totalPoints / totalPossible) * 100;
      if (percentage >= 93) return 4.0;
      if (percentage >= 90) return 3.7;
      if (percentage >= 87) return 3.3;
      if (percentage >= 83) return 3.0;
      if (percentage >= 80) return 2.7;
      if (percentage >= 77) return 2.3;
      if (percentage >= 73) return 2.0;
      if (percentage >= 70) return 1.7;
      if (percentage >= 67) return 1.3;
      if (percentage >= 65) return 1.0;
      return 0.0;
    } catch (e) {
      LoggerService.error('Error calculating GPA', error: e);
      return 0.0;
    }
  }
}
