/// Abstract repository interface for user operations.
/// 
/// This module defines the contract for user data operations,
/// providing methods for managing user profiles and related
/// data in the educational platform.
library;

import '../../../../shared/models/user_model.dart';

/// Repository interface for user operations.
/// 
/// Provides abstract methods for user management including
/// profile retrieval, updates, and role-based queries.
abstract class UserRepository {
  /// Gets a user by their ID.
  Future<UserModel?> getUserById(String userId);
  
  /// Gets a user by their email.
  Future<UserModel?> getUserByEmail(String email);
  
  /// Creates a new user profile.
  Future<void> createUser(UserModel user);
  
  /// Updates an existing user profile.
  Future<void> updateUser(UserModel user);
  
  /// Gets all users with a specific role.
  Stream<List<UserModel>> getUsersByRole(String role);
  
  /// Gets all teachers.
  Stream<List<UserModel>> getTeachers();
  
  /// Gets all students.
  Stream<List<UserModel>> getStudents();
  
  /// Updates the last active timestamp for a user.
  Future<void> updateLastActive(String userId);
  
  /// Checks if a user exists.
  Future<bool> userExists(String userId);
  
  /// Deletes a user profile.
  Future<void> deleteUser(String userId);
  
  /// Searches users by name or email.
  Future<List<UserModel>> searchUsers(String query);
  
  /// Gets multiple users by their IDs.
  Future<List<UserModel>> getUsersByIds(List<String> userIds);
}