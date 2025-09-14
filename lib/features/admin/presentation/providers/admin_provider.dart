import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../shared/services/logger_service.dart';
import '../../domain/models/system_stats.dart';
import '../../domain/models/admin_user.dart';
import '../../data/services/bulk_import_service.dart';
import '../../constants/bulk_import_constants.dart';

class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final BulkImportService _bulkImportService = BulkImportService();

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
      // Get user counts - fetch all users to count by role
      final userCountsSnapshot = await _firestore.collection('users').get();
      final users = userCountsSnapshot.docs;
      
      LoggerService.info('Querying users collection...', tag: 'AdminProvider');
      LoggerService.info('Found ${users.length} total users in Firestore', tag: 'AdminProvider');

      int studentCount = 0;
      int teacherCount = 0;
      int adminCount = 0;
      int unknownRoleCount = 0;

      for (var doc in users) {
        final data = doc.data();
        final role = data['role'] as String?;
        
        // Log each user for debugging
        LoggerService.debug('User ${doc.id}: role=$role, email=${data['email']}', tag: 'AdminProvider');
        
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
          default:
            unknownRoleCount++;
            if (role != null) {
              LoggerService.warning('Unknown role "$role" for user ${doc.id}', tag: 'AdminProvider');
            } else {
              LoggerService.warning('No role set for user ${doc.id}', tag: 'AdminProvider');
            }
        }
      }

      if (unknownRoleCount > 0) {
        LoggerService.warning('Found $unknownRoleCount users with unknown or missing roles', tag: 'AdminProvider');
      }

      // Get active sessions from presence collection
      int activeSessions = 0;
      try {
        final presenceSnapshot = await _firestore
            .collection('presence')
            .where('online', isEqualTo: true)  // Changed from 'isOnline' to 'online' to match what PresenceService sets
            .get();
        
        // Filter out stale sessions (older than 5 minutes)
        final now = DateTime.now();
        int actualActiveSessions = 0;
        
        for (var doc in presenceSnapshot.docs) {
          final data = doc.data();
          final lastSeen = data['lastSeen'];
          
          if (lastSeen != null && lastSeen is Timestamp) {
            final lastSeenTime = lastSeen.toDate();
            final minutesSinceLastSeen = now.difference(lastSeenTime).inMinutes;
            
            // Only count as active if seen within last 5 minutes
            if (minutesSinceLastSeen < 5) {
              actualActiveSessions++;
              LoggerService.debug('Active session: ${data['displayName'] ?? data['uid']} (seen ${minutesSinceLastSeen}m ago)', tag: 'AdminProvider');
            } else {
              LoggerService.debug('Stale session: ${data['displayName'] ?? data['uid']} (seen ${minutesSinceLastSeen}m ago)', tag: 'AdminProvider');
            }
          } else {
            // If no lastSeen timestamp, don't count as active
            LoggerService.warning('Session without lastSeen timestamp: ${doc.id}', tag: 'AdminProvider');
          }
        }
        
        activeSessions = actualActiveSessions;
        LoggerService.info('Found ${presenceSnapshot.docs.length} online records, but only $activeSessions are actually active (seen within 5 minutes)', tag: 'AdminProvider');
      } catch (e) {
        LoggerService.warning('Error loading presence data: $e', tag: 'AdminProvider');
        activeSessions = 0;
      }

      // Get recent activity count - use Timestamp for proper Firestore query
      int recentActivityCount = 0;
      try {
        final now = DateTime.now();
        final oneDayAgo = now.subtract(const Duration(days: 1));
        final oneDayAgoTimestamp = Timestamp.fromDate(oneDayAgo);
        
        final activitiesSnapshot = await _firestore
            .collection('activities')
            .where('timestamp', isGreaterThan: oneDayAgoTimestamp)
            .limit(100)
            .get();
        recentActivityCount = activitiesSnapshot.docs.length;
        LoggerService.info('Found $recentActivityCount recent activities', tag: 'AdminProvider');
      } catch (e) {
        LoggerService.warning('Error loading activities: $e', tag: 'AdminProvider');
        recentActivityCount = 0;
      }

      _systemStats = SystemStats(
        totalUsers: users.length,
        studentCount: studentCount,
        teacherCount: teacherCount,
        adminCount: adminCount,
        activeSessions: activeSessions,
        recentActivityCount: recentActivityCount,
      );
      
      LoggerService.info('System stats successfully loaded: Total=${users.length}, Students=$studentCount, Teachers=$teacherCount, Admins=$adminCount, Active=$activeSessions', tag: 'AdminProvider');
    } catch (e) {
      LoggerService.error('Critical error loading system stats: $e', tag: 'AdminProvider');
      
      // Set zero values instead of fake data when loading fails
      _systemStats = SystemStats(
        totalUsers: 0,
        studentCount: 0,
        teacherCount: 0,
        adminCount: 0,
        activeSessions: 0,
        recentActivityCount: 0,
      );
      
      // Rethrow to show error to user
      throw Exception('Failed to load dashboard statistics. Please check your permissions and try again.');
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

  // Bulk create student accounts
  Future<Map<String, dynamic>?> bulkCreateStudent({
    required String username,
    required String displayName,
    required int gradeLevel,
    String? parentEmail,
    List<String>? classIds,
    String? password,
  }) async {
    try {
      // Generate secure password if not provided
      final studentPassword = password ?? _generateSecurePassword();
      
      final callable = _functions.httpsCallable('createStudentAccount');
      final result = await callable.call({
        'username': username,
        'displayName': displayName,
        'gradeLevel': gradeLevel.toString(),
        'password': studentPassword,
        'parentEmail': parentEmail,
        'classIds': classIds ?? [],
      });

      // Include the generated password in the return data
      final responseData = result.data as Map<String, dynamic>;
      responseData['temporaryPassword'] = studentPassword;
      return responseData;
    } catch (e) {
      LoggerService.error('Error in bulk create student: $e', tag: 'AdminProvider');
      rethrow;
    }
  }

  // Bulk create teacher accounts
  Future<Map<String, dynamic>?> bulkCreateTeacher({
    required String email,
    required String password,
    required String displayName,
    List<String>? subjects,
  }) async {
    try {
      final callable = _functions.httpsCallable('createTeacherAccount');
      final result = await callable.call({
        'email': email,
        'password': password,
        'displayName': displayName,
        'subjects': subjects ?? [],
      });

      return result.data as Map<String, dynamic>;
    } catch (e) {
      LoggerService.error('Error in bulk create teacher: $e', tag: 'AdminProvider');
      rethrow;
    }
  }

  // Bulk import students from parsed data
  Future<BulkImportResult> bulkImportStudents(List<Map<String, dynamic>> students) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final result = await _bulkImportService.bulkImportStudents(students);
      
      // Refresh recent users after bulk import
      await _loadRecentUsers();
      
      return result;
    } catch (e) {
      LoggerService.error('Error bulk importing students: $e', tag: 'AdminProvider');
      _error = 'Failed to bulk import students';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Bulk import teachers from parsed data
  Future<BulkImportResult> bulkImportTeachers(List<Map<String, dynamic>> teachers) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final result = await _bulkImportService.bulkImportTeachers(teachers);
      
      // Refresh recent users after bulk import
      await _loadRecentUsers();
      
      return result;
    } catch (e) {
      LoggerService.error('Error bulk importing teachers: $e', tag: 'AdminProvider');
      _error = 'Failed to bulk import teachers';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Validate bulk import data
  Future<Map<String, dynamic>> validateBulkData(
    List<Map<String, dynamic>> data,
    String type,
  ) async {
    try {
      return await _bulkImportService.validateBulkData(data, type);
    } catch (e) {
      LoggerService.error('Error validating bulk data: $e', tag: 'AdminProvider');
      _error = 'Failed to validate data';
      rethrow;
    }
  }

  // Bulk assign students to classes
  Future<void> bulkAssignToClasses(List<String> studentIds, List<String> classIds) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _bulkImportService.bulkAssignToClasses(studentIds, classIds);
    } catch (e) {
      LoggerService.error('Error bulk assigning to classes: $e', tag: 'AdminProvider');
      _error = 'Failed to assign students to classes';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Generate secure password for students
  String _generateSecurePassword() {
    final random = Random.secure();
    const charset = BulkImportConstants.passwordCharset;
    const length = BulkImportConstants.passwordLength;
    
    // Generate password using cryptographically secure random selection from charset
    String password = List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
    
    // Ensure password has at least one of each required character type
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#\$%^&*]').hasMatch(password);
    
    if (!hasUpper || !hasLower || !hasNumber || !hasSpecial) {
      // Recursively generate a new password if requirements aren't met
      return _generateSecurePassword();
    }
    
    return password;
  }
}