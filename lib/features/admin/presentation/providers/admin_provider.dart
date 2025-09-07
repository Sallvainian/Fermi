import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../shared/services/logger_service.dart';
import '../../domain/models/system_stats.dart';
import '../../domain/models/admin_user.dart';

class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // State
  SystemStats? _systemStats;
  List<AdminUser> _recentUsers = [];
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  SystemStats? get systemStats => _systemStats;
  List<AdminUser> get recentUsers => _recentUsers;
  List<Map<String, dynamic>> get recentActivities => _recentActivities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load admin dashboard data
  Future<void> loadAdminDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load all data in parallel
      await Future.wait([
        _loadSystemStats(),
        _loadRecentUsers(),
        _loadRecentActivities(),
      ]);
    } catch (e) {
      LoggerService.error('Error loading admin dashboard: $e', tag: 'AdminProvider');
      _error = 'Failed to load dashboard data';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load system statistics
  Future<void> _loadSystemStats() async {
    try {
      // Get user counts
      final userCountsSnapshot = await _firestore.collection('users').get();
      final users = userCountsSnapshot.docs;

      int studentCount = 0;
      int teacherCount = 0;
      int adminCount = 0;

      for (var doc in users) {
        final role = doc.data()['role'] as String?;
        switch (role) {
          case 'student':
            studentCount++;
            break;
          case 'teacher':
            teacherCount++;
            break;
          case 'admin':
            adminCount++;
            break;
        }
      }

      // Get active sessions from presence collection
      final presenceSnapshot = await _firestore
          .collection('presence')
          .where('isOnline', isEqualTo: true)
          .get();
      final activeSessions = presenceSnapshot.docs.length;

      // Get recent activity count
      final now = DateTime.now();
      final oneDayAgo = now.subtract(const Duration(days: 1));
      final activitiesSnapshot = await _firestore
          .collection('activities')
          .where('timestamp', isGreaterThan: oneDayAgo)
          .limit(100)
          .get();
      final recentActivityCount = activitiesSnapshot.docs.length;

      _systemStats = SystemStats(
        totalUsers: users.length,
        studentCount: studentCount,
        teacherCount: teacherCount,
        adminCount: adminCount,
        activeSessions: activeSessions,
        recentActivityCount: recentActivityCount,
      );
    } catch (e) {
      LoggerService.error('Error loading system stats: $e', tag: 'AdminProvider');
    }
  }

  // Load recent users
  Future<void> _loadRecentUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      _recentUsers = snapshot.docs.map((doc) {
        final data = doc.data();
        return AdminUser(
          id: doc.id,
          email: data['email'] ?? '',
          displayName: data['displayName'] ?? '',
          role: data['role'] ?? 'student',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
          isOnline: data['isOnline'] ?? false,
        );
      }).toList();
    } catch (e) {
      LoggerService.error('Error loading recent users: $e', tag: 'AdminProvider');
    }
  }

  // Load recent activities
  Future<void> _loadRecentActivities() async {
    try {
      final snapshot = await _firestore
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      _recentActivities = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      LoggerService.error('Error loading recent activities: $e', tag: 'AdminProvider');
    }
  }

  // Create new student account
  Future<Map<String, String>?> createStudentAccount({
    required String username,
    required String password,
    String? displayName,
    String? grade,
  }) async {
    try {
      final callable = _functions.httpsCallable('createStudentAccount');
      final result = await callable.call({
        'username': username,
        'password': password,
        'displayName': displayName ?? username,
        'grade': grade,
      });

      final data = result.data as Map<String, dynamic>;
      
      // Refresh recent users
      await _loadRecentUsers();
      notifyListeners();

      return {
        'userId': data['userId'],
        'email': data['email'],
        'password': password,
      };
    } catch (e) {
      LoggerService.error('Error creating student account: $e', tag: 'AdminProvider');
      _error = 'Failed to create student account';
      notifyListeners();
      return null;
    }
  }

  // Create new teacher account
  Future<Map<String, String>?> createTeacherAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final callable = _functions.httpsCallable('createTeacherAccount');
      final result = await callable.call({
        'email': email,
        'password': password,
        'displayName': displayName,
      });

      final data = result.data as Map<String, dynamic>;
      
      // Refresh recent users
      await _loadRecentUsers();
      notifyListeners();

      return {
        'userId': data['userId'],
        'email': email,
        'password': password,
      };
    } catch (e) {
      LoggerService.error('Error creating teacher account: $e', tag: 'AdminProvider');
      _error = 'Failed to create teacher account';
      notifyListeners();
      return null;
    }
  }

  // Delete user account
  Future<bool> deleteUser(String userId) async {
    try {
      final callable = _functions.httpsCallable('deleteUserAccount');
      await callable.call({'userId': userId});
      
      // Refresh recent users
      await _loadRecentUsers();
      notifyListeners();
      
      return true;
    } catch (e) {
      LoggerService.error('Error deleting user: $e', tag: 'AdminProvider');
      _error = 'Failed to delete user';
      notifyListeners();
      return false;
    }
  }

  // Reset user password
  Future<String?> resetUserPassword(String userId) async {
    try {
      final callable = _functions.httpsCallable('resetUserPassword');
      final result = await callable.call({'userId': userId});
      
      final data = result.data as Map<String, dynamic>;
      return data['newPassword'] as String;
    } catch (e) {
      LoggerService.error('Error resetting password: $e', tag: 'AdminProvider');
      _error = 'Failed to reset password';
      notifyListeners();
      return null;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}