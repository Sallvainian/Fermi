/// Authentication repository interface for user management.
/// 
/// This module defines the contract for authentication operations
/// in the education platform, supporting multiple authentication
/// methods and user role management.
library;

import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/repositories/base_repository.dart';

/// Abstract repository defining authentication operations.
/// 
/// This interface provides a contract for authentication implementations,
/// supporting:
/// - Email/password authentication
/// - Google OAuth authentication
/// - User profile management
/// - Role-based user creation
/// - Password reset functionality
/// - Real-time auth state monitoring
/// 
/// Concrete implementations handle the actual authentication
/// logic with specific providers (e.g., Firebase Auth).
abstract class AuthRepository extends BaseRepository {
  /// Stream of authentication state changes.
  /// 
  /// Emits the current user when auth state changes (sign in/out).
  /// Emits null when no user is authenticated.
  Stream<User?> get authStateChanges;
  
  /// Gets the currently authenticated Firebase user.
  /// 
  /// Returns null if no user is signed in.
  User? get currentUser;
  
  /// Retrieves the current user's complete profile model.
  /// 
  /// Fetches the UserModel from the database for the currently
  /// authenticated user. Returns null if not authenticated or
  /// if the user profile doesn't exist.
  /// 
  /// @return Current user's profile or null
  /// @throws Exception if profile retrieval fails
  Future<UserModel?> getCurrentUserModel();
  
  /// Creates a new user account with email (Firebase Auth only).
  /// 
  /// This method only creates the Firebase Auth account without
  /// creating a user profile in Firestore. Used for initial
  /// account creation before role selection.
  /// 
  /// @param email User's email address
  /// @param password Account password
  /// @param displayName Full display name
  /// @param firstName User's first name
  /// @param lastName User's last name
  /// @return Created Firebase user or null on failure
  /// @throws Exception if account creation fails
  Future<User?> signUpWithEmailOnly({
    required String email,
    required String password,
    required String displayName,
    required String firstName,
    required String lastName,
  });
  
  /// Creates a complete user account with email and profile.
  /// 
  /// Creates both Firebase Auth account and Firestore user profile
  /// with role-specific information. Handles the complete signup
  /// flow including role assignment.
  /// 
  /// @param email User's email address
  /// @param password Account password
  /// @param displayName Full display name
  /// @param role User role (teacher/student/parent/admin)
  /// @param parentEmail Parent's email (for student accounts)
  /// @param gradeLevel Student's grade level (1-12)
  /// @return Created user profile or null on failure
  /// @throws Exception if signup fails
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    UserRole? role,
    String? parentEmail,
    int? gradeLevel,
  });
  
  /// Signs in an existing user with email and password.
  /// 
  /// Authenticates the user and retrieves their profile from
  /// Firestore. Returns the complete user profile on success.
  /// 
  /// @param email User's email address
  /// @param password Account password
  /// @return User profile or null if authentication fails
  /// @throws Exception if sign-in fails
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  });
  
  /// Signs in using Google OAuth authentication.
  /// 
  /// Handles the Google sign-in flow. For new users, returns
  /// null to trigger role selection. For existing users,
  /// returns their complete profile.
  /// 
  /// @return User profile for existing users, null for new
  /// @throws Exception if Google sign-in fails
  Future<UserModel?> signInWithGoogle();
  
  /// Completes Google sign-up by creating user profile.
  /// 
  /// Called after successful Google authentication to create
  /// the Firestore user profile with role information. Used
  /// when a new Google user needs to select their role.
  /// 
  /// @param role Selected user role
  /// @param parentEmail Parent's email (for students)
  /// @param gradeLevel Student's grade (for students)
  /// @return Created user profile
  /// @throws Exception if profile creation fails
  Future<UserModel?> completeGoogleSignUp({
    required UserRole role,
    String? parentEmail,
    int? gradeLevel,
  });
  
  /// Signs out the current user.
  /// 
  /// Clears authentication state and local session data.
  /// The authStateChanges stream will emit null after signout.
  /// 
  /// @throws Exception if sign-out fails
  Future<void> signOut();
  
  /// Sends a password reset email to the specified address.
  /// 
  /// Initiates the password reset flow by sending an email
  /// with reset instructions. The user must have an account
  /// with the provided email address.
  /// 
  /// @param email Email address to send reset link
  /// @throws Exception if email sending fails
  Future<void> resetPassword(String email);
  
  /// Updates the current user's profile information.
  /// 
  /// Updates both Firebase Auth profile and Firestore user
  /// document. Only provided fields are updated; null values
  /// are ignored.
  /// 
  /// @param displayName New display name
  /// @param firstName New first name
  /// @param lastName New last name
  /// @param photoURL New profile photo URL
  /// @param updatePhoto Whether to update the photo
  /// @throws Exception if profile update fails
  Future<void> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? photoURL,
    bool updatePhoto = false,
  });
}