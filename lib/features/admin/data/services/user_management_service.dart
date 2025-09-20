import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/models/user_model.dart';

class UserManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const int _pageSize = 25;

  Stream<QuerySnapshot> getUsersStream({
    String? roleFilter,
    String? searchQuery,
    int limit = _pageSize,
    DocumentSnapshot? startAfter,
  }) {
    Query query = _firestore.collection('users');
    
    if (roleFilter != null && roleFilter != 'all') {
      query = query.where('role', isEqualTo: roleFilter);
    }
    
    query = query.orderBy('createdAt', descending: true);
    
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    query = query.limit(limit);
    
    return query.snapshots();
  }

  Future<List<UserModel>> getUsers({
    String? roleFilter,
    String? searchQuery,
    int limit = _pageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore.collection('users');
      
      if (roleFilter != null && roleFilter != 'all') {
        query = query.where('role', isEqualTo: roleFilter);
      }
      
      query = query.orderBy('createdAt', descending: true);
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      query = query.limit(limit);
      
      final snapshot = await query.get();
      
      List<UserModel> users = snapshot.docs.map((doc) {
        return UserModel.fromFirestore(doc);
      }).toList();
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        users = users.where((user) {
          final displayName = user.displayName?.toLowerCase() ?? '';
          final email = user.email?.toLowerCase() ?? '';
          final username = user.username?.toLowerCase() ?? '';
          return displayName.contains(searchLower) ||
                 email.contains(searchLower) ||
                 username.contains(searchLower);
        }).toList();
      }
      
      return users;
    } catch (e) {
      LoggerService.error('Error fetching users: $e', tag: 'UserManagementService');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final users = usersSnapshot.docs;
      
      int studentCount = 0;
      int teacherCount = 0;
      int adminCount = 0;
      int onlineCount = 0;
      
      for (var doc in users) {
        final data = doc.data();
        final role = data['role'] as String?;
        final isOnline = data['isOnline'] as bool? ?? false;
        
        if (isOnline) onlineCount++;
        
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
      
      return {
        'total': users.length,
        'students': studentCount,
        'teachers': teacherCount,
        'admins': adminCount,
        'online': onlineCount,
      };
    } catch (e) {
      LoggerService.error('Error fetching user stats: $e', tag: 'UserManagementService');
      return {
        'total': 0,
        'students': 0,
        'teachers': 0,
        'admins': 0,
        'online': 0,
      };
    }
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await _logActivity('user_updated', {
        'targetUserId': userId,
        'updates': updates.keys.toList(),
      });
      
      return true;
    } catch (e) {
      LoggerService.error('Error updating user $userId: $e', tag: 'UserManagementService');
      return false;
    }
  }

  Future<bool> updateUserRole(String userId, String newRole) async {
    try {
      final callable = _functions.httpsCallable('updateUserRole');
      await callable.call({
        'userId': userId,
        'newRole': newRole,
      });
      
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await _logActivity('role_changed', {
        'targetUserId': userId,
        'newRole': newRole,
      });
      
      return true;
    } catch (e) {
      LoggerService.error('Error updating user role: $e', tag: 'UserManagementService');
      return false;
    }
  }

  Future<String?> resetUserPassword(String userId) async {
    try {
      final callable = _functions.httpsCallable('resetUserPassword');
      final result = await callable.call({'userId': userId});
      
      final data = result.data as Map<String, dynamic>;
      final newPassword = data['newPassword'] as String?;
      
      await _logActivity('password_reset', {
        'targetUserId': userId,
      });
      
      return newPassword;
    } catch (e) {
      LoggerService.error('Error resetting password: $e', tag: 'UserManagementService');
      return null;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser?.uid == userId) {
        throw Exception('Cannot delete your own account');
      }
      
      final callable = _functions.httpsCallable('deleteUserAccount');
      await callable.call({'userId': userId});
      
      await _logActivity('user_deleted', {
        'targetUserId': userId,
      });
      
      return true;
    } catch (e) {
      LoggerService.error('Error deleting user: $e', tag: 'UserManagementService');
      return false;
    }
  }

  Future<bool> bulkAssignToClasses(List<String> userIds, List<String> classIds) async {
    try {
      final batch = _firestore.batch();
      
      for (final userId in userIds) {
        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {
          'enrolledClassIds': FieldValue.arrayUnion(classIds),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      for (final classId in classIds) {
        final classRef = _firestore.collection('classes').doc(classId);
        batch.update(classRef, {
          'studentIds': FieldValue.arrayUnion(userIds),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      await _logActivity('bulk_class_assignment', {
        'userCount': userIds.length,
        'classCount': classIds.length,
      });
      
      return true;
    } catch (e) {
      LoggerService.error('Error bulk assigning to classes: $e', tag: 'UserManagementService');
      return false;
    }
  }

  Future<bool> bulkUpdateUsers(List<String> userIds, Map<String, dynamic> updates) async {
    try {
      final batch = _firestore.batch();
      
      for (final userId in userIds) {
        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {
          ...updates,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      await _logActivity('bulk_user_update', {
        'userCount': userIds.length,
        'updates': updates.keys.toList(),
      });
      
      return true;
    } catch (e) {
      LoggerService.error('Error bulk updating users: $e', tag: 'UserManagementService');
      return false;
    }
  }

  Future<bool> bulkDeleteUsers(List<String> userIds) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null && userIds.contains(currentUser.uid)) {
        throw Exception('Cannot delete your own account');
      }
      
      for (final userId in userIds) {
        final callable = _functions.httpsCallable('deleteUserAccount');
        await callable.call({'userId': userId});
      }
      
      await _logActivity('bulk_user_delete', {
        'userCount': userIds.length,
      });
      
      return true;
    } catch (e) {
      LoggerService.error('Error bulk deleting users: $e', tag: 'UserManagementService');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableClasses() async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['name'] ?? '',
        'description': doc.data()['description'] ?? '',
        'teacherId': doc.data()['teacherId'] ?? '',
        'studentCount': (doc.data()['studentIds'] as List?)?.length ?? 0,
      }).toList();
    } catch (e) {
      LoggerService.error('Error fetching classes: $e', tag: 'UserManagementService');
      return [];
    }
  }

  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return {};
      
      final userData = userDoc.data()!;
      userData['uid'] = userDoc.id;
      
      final classesSnapshot = await _firestore
          .collection('classes')
          .where('studentIds', arrayContains: userId)
          .get();
      
      final classes = classesSnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['name'] ?? '',
      }).toList();
      
      final activitiesSnapshot = await _firestore
          .collection('activities')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      
      final activities = activitiesSnapshot.docs.map((doc) => doc.data()).toList();
      
      return {
        'user': userData,
        'classes': classes,
        'activities': activities,
      };
    } catch (e) {
      LoggerService.error('Error fetching user details: $e', tag: 'UserManagementService');
      return {};
    }
  }

  Future<void> _logActivity(String type, Map<String, dynamic> details) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _firestore.collection('activities').add({
        'type': type,
        'performedBy': user.uid,
        'performedByEmail': user.email,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      });
    } catch (e) {
      LoggerService.error('Error logging activity: $e', tag: 'UserManagementService');
    }
  }

  Future<String> exportUsersToCSV(List<UserModel> users) async {
    try {
      final headers = [
        'UID',
        'Display Name',
        'Email',
        'Username',
        'Role',
        'Grade Level',
        'Parent Email',
        'Created At',
        'Last Active',
      ];
      
      final rows = users.map((user) => [
        user.uid,
        user.displayName ?? '',
        user.email ?? '',
        user.username ?? '',
        user.role?.name ?? '',
        user.gradeLevel ?? '',
        user.parentEmail ?? '',
        user.createdAt?.toIso8601String() ?? '',
        user.lastActive?.toIso8601String() ?? '',
      ]).toList();
      
      final csvContent = [
        headers.join(','),
        ...rows.map((row) => row.map((cell) => '"${cell.toString().replaceAll('"', '""')}"').join(',')),
      ].join('\n');
      
      return csvContent;
    } catch (e) {
      LoggerService.error('Error exporting users to CSV: $e', tag: 'UserManagementService');
      return '';
    }
  }
}