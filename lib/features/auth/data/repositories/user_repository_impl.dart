/// Concrete implementation of the user repository.
/// 
/// This module implements the UserRepository interface using
/// Firebase Firestore for data persistence, providing user
/// management functionality for the educational platform.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/user_model.dart';
import '../../domain/repositories/user_repository.dart';

/// Firebase implementation of UserRepository.
/// 
/// Manages user profiles in Firestore with support for:
/// - User creation and updates
/// - Role-based queries
/// - Search functionality
/// - Batch operations
class UserRepositoryImpl implements UserRepository {
  final FirebaseFirestore _firestore;
  static const String _collection = 'users';
  
  /// Creates repository with Firestore instance.
  UserRepositoryImpl(this._firestore);
  
  @override
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      
      if (!doc.exists) return null;
      
      return UserModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }
  
  @override
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (query.docs.isEmpty) return null;
      
      return UserModel.fromFirestore(query.docs.first);
    } catch (e) {
      throw Exception('Failed to get user by email: $e');
    }
  }
  
  @override
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(user.uid).set(
        user.toFirestore(),
      );
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }
  
  @override
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(user.uid).update(
        user.toFirestore(),
      );
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }
  
  @override
  Stream<List<UserModel>> getUsersByRole(String role) {
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }
  
  @override
  Stream<List<UserModel>> getTeachers() {
    return getUsersByRole('teacher');
  }
  
  @override
  Stream<List<UserModel>> getStudents() {
    return getUsersByRole('student');
  }
  
  @override
  Future<void> updateLastActive(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update last active: $e');
    }
  }
  
  @override
  Future<bool> userExists(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Failed to check user existence: $e');
    }
  }
  
  @override
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
  
  @override
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final lowercaseQuery = query.toLowerCase();
      
      // Search by display name
      final nameQuery = await _firestore
          .collection(_collection)
          .where('displayNameLowercase', isGreaterThanOrEqualTo: lowercaseQuery)
          .where('displayNameLowercase', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
          .limit(20)
          .get();
      
      // Search by email
      final emailQuery = await _firestore
          .collection(_collection)
          .where('email', isGreaterThanOrEqualTo: lowercaseQuery)
          .where('email', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
          .limit(20)
          .get();
      
      // Combine and deduplicate results
      final userMap = <String, UserModel>{};
      
      for (final doc in nameQuery.docs) {
        final user = UserModel.fromFirestore(doc);
        userMap[user.uid] = user;
      }
      
      for (final doc in emailQuery.docs) {
        final user = UserModel.fromFirestore(doc);
        userMap[user.uid] = user;
      }
      
      return userMap.values.toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }
  
  @override
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return [];
      
      // Firestore has a limit of 10 for 'whereIn' queries
      final chunks = <List<String>>[];
      for (var i = 0; i < userIds.length; i += 10) {
        chunks.add(
          userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10),
        );
      }
      
      final users = <UserModel>[];
      
      for (final chunk in chunks) {
        final query = await _firestore
            .collection(_collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        
        users.addAll(
          query.docs.map((doc) => UserModel.fromFirestore(doc)),
        );
      }
      
      return users;
    } catch (e) {
      throw Exception('Failed to get users by IDs: $e');
    }
  }
}