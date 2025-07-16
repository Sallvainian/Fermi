/// Authentication service for managing user authentication and profiles.
/// 
/// This service provides comprehensive authentication functionality including:
/// - Email/password authentication
/// - Google OAuth authentication
/// - User profile management
/// - Role-based user creation
/// - Password reset functionality
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'google_sign_in_service.dart';

/// Core authentication service handling all auth-related operations.
/// 
/// This service manages the complete authentication lifecycle:
/// - User registration with role selection
/// - Multiple authentication methods (email, Google)
/// - Profile creation and updates
/// - Session management
/// - Error handling with user-friendly messages
/// 
/// The service gracefully handles Firebase initialization failures
/// for development environments without Firebase configuration.
class AuthService {
  /// Firebase Authentication instance for auth operations.
  /// Nullable to handle cases where Firebase is not initialized.
  FirebaseAuth? _auth;
  
  /// Firestore instance for user profile management.
  /// Nullable to handle cases where Firebase is not initialized.
  FirebaseFirestore? _firestore;
  
  /// Google Sign-In service instance.
  final GoogleSignInService _googleSignInService = GoogleSignInService();

  /// Initializes the authentication service.
  /// 
  /// Attempts to get Firebase instances with graceful fallback
  /// for development environments without Firebase configuration.
  /// Errors are caught and logged in debug mode without throwing.
  AuthService() {
    try {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
    } catch (e) {
      if (kDebugMode) print('Firebase not available: $e');
    }
  }
  

  /// Stream that emits auth state changes.
  /// 
  /// Provides real-time updates when:
  /// - User signs in
  /// - User signs out
  /// - User's auth token refreshes
  /// 
  /// Returns empty stream if Firebase Auth is not available.
  /// Catches and logs errors in debug mode for resilience.
  /// 
  /// @return Stream emitting current User or null
  Stream<User?> get authStateChanges {
    if (_auth == null) {
      if (kDebugMode) print('Firebase Auth not available');
      return Stream.value(null);
    }
    try {
      return _auth!.authStateChanges();
    } catch (e) {
      if (kDebugMode) print('Firebase Auth error: $e');
      return Stream.value(null);
    }
  }

  /// Gets the currently authenticated Firebase user.
  /// 
  /// Returns null in the following cases:
  /// - No user is signed in
  /// - Firebase Auth is not available
  /// - An error occurs accessing the current user
  /// 
  /// Errors are caught and logged in debug mode.
  /// 
  /// @return Current Firebase User or null
  User? get currentUser {
    if (_auth == null) {
      if (kDebugMode) print('Firebase Auth not available');
      return null;
    }
    try {
      return _auth!.currentUser;
    } catch (e) {
      if (kDebugMode) print('Firebase Auth error: $e');
      return null;
    }
  }

  /// Retrieves the complete UserModel for the current user.
  /// 
  /// Fetches the user's profile data from Firestore based on
  /// the current authentication state. This includes:
  /// - User role (teacher/student/admin)
  /// - Profile information
  /// - Settings and preferences
  /// 
  /// Returns null if:
  /// - No user is authenticated
  /// - Firestore is not available
  /// - User document doesn't exist
  /// - An error occurs during fetch
  /// 
  /// @return UserModel instance or null
  Future<UserModel?> getCurrentUserModel() async {
    if (_firestore == null) {
      if (kDebugMode) print('Firestore not available');
      return null;
    }
    
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore!.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error getting user model: $e');
      return null;
    }
  }

  /// Creates an authentication account without completing profile setup.
  /// 
  /// This method is used for the two-step registration process:
  /// 1. Create Firebase Auth account (this method)
  /// 2. Select role and complete profile (separate step)
  /// 
  /// Stores temporary user data in 'pending_users' collection
  /// for later profile completion. This allows role selection
  /// after initial account creation.
  /// 
  /// @param email User's email address
  /// @param password User's chosen password
  /// @param displayName Full display name
  /// @param firstName User's first name
  /// @param lastName User's last name
  /// @return Firebase User if successful, null otherwise
  /// @throws Exception if Firebase is not available
  /// @throws String error message for auth failures
  Future<User?> signUpWithEmailOnly({
    required String email,
    required String password,
    required String displayName,
    required String firstName,
    required String lastName,
  }) async {
    if (_auth == null) {
      throw Exception('Firebase not available - cannot sign up');
    }
    
    try {
      // Create auth user
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return null;

      // Update display name
      await credential.user!.updateDisplayName(displayName);
      
      // Store temporary user data in Firestore for role selection
      await _firestore!.collection('pending_users').doc(credential.user!.uid).set({
        'email': email,
        'displayName': displayName,
        'firstName': firstName,
        'lastName': lastName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Creates a complete user account with authentication and profile.
  /// 
  /// This method performs full user registration:
  /// 1. Creates Firebase Auth account
  /// 2. Creates user profile in Firestore
  /// 3. Sets up role-specific fields
  /// 
  /// Automatically parses display name into first/last names
  /// and configures role-specific fields like teacherId/studentId.
  /// 
  /// @param email User's email address
  /// @param password User's chosen password
  /// @param displayName Full display name
  /// @param role User's role (teacher/student/admin)
  /// @param parentEmail Parent's email (students only)
  /// @param gradeLevel Student's grade level (students only)
  /// @return Complete UserModel if successful, null otherwise
  /// @throws Exception if Firebase is not available
  /// @throws String error message for auth failures
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    UserRole? role,
    String? parentEmail,
    int? gradeLevel,
  }) async {
    if (_auth == null || _firestore == null) {
      throw Exception('Firebase not available - cannot sign up');
    }
    
    try {
      // Create auth user
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return null;

      // Update display name
      await credential.user!.updateDisplayName(displayName);

      // Parse first and last names from displayName
      final nameParts = displayName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      
      // Create user document in Firestore
      final userModel = UserModel(
        uid: credential.user!.uid,
        email: email,
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        role: role,
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        parentEmail: role == UserRole.student ? parentEmail : null,
        gradeLevel: role == UserRole.student ? gradeLevel : null,
        teacherId: role == UserRole.teacher ? credential.user!.uid : null,
        studentId: role == UserRole.student ? credential.user!.uid : null,
      );

      await _firestore!
          .collection('users')
          .doc(credential.user!.uid)
          .set(userModel.toFirestore());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Authenticates a user with email and password.
  /// 
  /// Performs sign-in and automatically:
  /// - Updates the user's last active timestamp
  /// - Retrieves complete user profile from Firestore
  /// - Returns full UserModel with role information
  /// 
  /// @param email User's email address
  /// @param password User's password
  /// @return UserModel if successful, null if user not found
  /// @throws Exception if Firebase is not available
  /// @throws String error message for auth failures
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_auth == null || _firestore == null) {
      throw Exception('Firebase not available - cannot sign in');
    }
    
    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return null;

      // Update last active
      await _updateLastActive(credential.user!.uid);

      return await getCurrentUserModel();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Authenticates a user using Google OAuth.
  /// 
  /// Implements Google Sign-In flow:
  /// 1. Triggers Google authentication popup
  /// 2. Obtains OAuth credentials
  /// 3. Signs in to Firebase with Google credential
  /// 4. Checks if user profile exists
  /// 
  /// For new Google users, returns null to trigger
  /// role selection flow. Existing users get their
  /// complete profile returned.
  /// 
  /// @return UserModel for existing users, null for new users
  /// @throws Exception if Firebase is not available or sign-in fails
  Future<UserModel?> signInWithGoogle() async {
    if (_auth == null || _firestore == null) {
      throw Exception('Firebase not available - cannot sign in with Google');
    }
    
    try {
      // For web platform, use Firebase Auth's OAuth flow
      if (kIsWeb) {
        // Use Firebase Auth's built-in Google provider for web
        final googleProvider = GoogleAuthProvider();
        final userCredential = await _auth!.signInWithPopup(googleProvider);
        
        if (userCredential.user == null) {
          throw Exception('Failed to sign in with Google');
        }

        // Check if user exists in Firestore
        final userDoc = await _firestore!
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          // New user - need to set role
          return null; // Will handle role selection in UI
        }

        // Update last active
        await _updateLastActive(userCredential.user!.uid);

        return UserModel.fromFirestore(userDoc);
      }
      
      // For desktop platforms (Windows/Linux), google_sign_in is not supported
      // We'll need to implement a different approach for desktop
      if (!_googleSignInService.isPlatformSupported) {
        throw Exception('Google Sign-In is not supported on this platform. Please use email/password authentication or run as a web app.');
      }
      
      // For mobile platforms (Android/iOS/macOS), use the GoogleSignInService
      final GoogleSignInAccount? googleUser = await _googleSignInService.signIn();
      
      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Get authentication details from the account
      // In google_sign_in 7.x, authentication property is synchronous
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      // Create a new credential using idToken
      // Note: In 7.x, access tokens are obtained separately via authorization
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        // accessToken is no longer available here - use authorization if needed
      );

      // Sign in to Firebase
      final userCredential = await _auth!.signInWithCredential(credential);
      if (userCredential.user == null) {
        throw Exception('Failed to sign in with Google credential');
      }

      // Check if user exists in Firestore
      final userDoc = await _firestore!
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        // New user - need to set role
        return null; // Will handle role selection in UI
      }

      // Update last active
      await _updateLastActive(userCredential.user!.uid);

      return UserModel.fromFirestore(userDoc);
    } catch (e) {
      if (kDebugMode) print('Google sign in error: $e');
      rethrow;
    }
  }

  /// Completes profile setup for Google-authenticated users.
  /// 
  /// Called after initial Google sign-in to:
  /// - Set user role (teacher/student)
  /// - Create complete user profile in Firestore
  /// - Migrate any pending user data
  /// - Configure role-specific fields
  /// 
  /// Handles both email signup users completing via Google
  /// and pure Google sign-in users setting up profiles.
  /// 
  /// @param role Selected user role
  /// @param parentEmail Parent's email (students only)
  /// @param gradeLevel Student's grade level (students only)
  /// @return Complete UserModel after profile creation
  /// @throws Exception if profile creation fails
  Future<UserModel?> completeGoogleSignUp({
    required UserRole role,
    String? parentEmail,
    int? gradeLevel,
  }) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      // Check if we have pending user data (from email signup)
      String firstName = '';
      String lastName = '';
      String displayName = user.displayName ?? user.email!.split('@')[0];
      
      final pendingUserDoc = await _firestore!.collection('pending_users').doc(user.uid).get();
      if (pendingUserDoc.exists) {
        final pendingData = pendingUserDoc.data() as Map<String, dynamic>;
        firstName = pendingData['firstName'] ?? '';
        lastName = pendingData['lastName'] ?? '';
        displayName = pendingData['displayName'] ?? displayName;
        
        // Delete the pending user data
        await _firestore!.collection('pending_users').doc(user.uid).delete();
      } else {
        // For Google sign-in, try to split the display name
        if (user.displayName != null) {
          final nameParts = user.displayName!.split(' ');
          firstName = nameParts.isNotEmpty ? nameParts.first : '';
          lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        }
      }
      
      final userModel = UserModel(
        uid: user.uid,
        email: user.email!,
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        role: role,
        photoURL: user.photoURL,
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        parentEmail: role == UserRole.student ? parentEmail : null,
        gradeLevel: role == UserRole.student ? gradeLevel : null,
        teacherId: role == UserRole.teacher ? user.uid : null,
        studentId: role == UserRole.student ? user.uid : null,
      );

      await _firestore!
          .collection('users')
          .doc(user.uid)
          .set(userModel.toFirestore());

      return userModel;
    } catch (e) {
      if (kDebugMode) print('Error completing Google sign up: $e');
      rethrow;
    }
  }

  /// Signs out the current user from all auth providers.
  /// 
  /// Performs complete sign-out:
  /// - Signs out from Firebase Auth
  /// - Signs out from Google (if applicable)
  /// - Clears all authentication state
  /// 
  /// Handles partial failures gracefully using Future.wait
  /// to ensure all providers attempt sign-out.
  Future<void> signOut() async {
    final futures = <Future>[];
    if (_auth != null) futures.add(_auth!.signOut());
    
    // Sign out from Google using disconnect (clears cached auth)
    // Only attempt this on platforms that support google_sign_in
    if (_googleSignInService.isPlatformSupported) {
      try {
        // In 7.x, disconnect returns Future<void>
        futures.add(_googleSignInService.disconnect());
      } catch (e) {
        // Handle case where GoogleSignIn is not initialized
        if (kDebugMode) print('Google sign out error: $e');
      }
    }
    
    await Future.wait(futures);
  }

  /// Sends a password reset email to the specified address.
  /// 
  /// Initiates Firebase's password reset flow:
  /// - Validates email exists in system
  /// - Sends reset link to email
  /// - User clicks link to set new password
  /// 
  /// @param email Email address to send reset link to
  /// @throws Exception if Firebase is not available
  /// @throws String error message for invalid email or other failures
  Future<void> resetPassword(String email) async {
    if (_auth == null) {
      throw Exception('Firebase not available - cannot reset password');
    }
    
    try {
      await _auth!.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Updates the current user's profile information.
  /// 
  /// Synchronizes changes across:
  /// - Firebase Auth profile (display name, photo)
  /// - Firestore user document
  /// 
  /// All parameters are optional - only provided fields
  /// are updated. Automatically updates last active timestamp.
  /// 
  /// @param displayName New display name
  /// @param firstName New first name
  /// @param lastName New last name
  /// @param photoURL New photo URL
  /// @param updatePhoto Whether to update the photo URL
  /// @throws Exception if update fails
  Future<void> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? photoURL,
    bool updatePhoto = false,
  }) async {
    final user = currentUser;
    if (user == null) return;

    try {
      // Update Firebase Auth profile
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (updatePhoto) {
        await user.updatePhotoURL(photoURL);
      }

      // Update Firestore document
      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (firstName != null) updates['firstName'] = firstName;
      if (lastName != null) updates['lastName'] = lastName;
      if (updatePhoto) updates['photoURL'] = photoURL;
      updates['lastActive'] = FieldValue.serverTimestamp();

      await _firestore!.collection('users').doc(user.uid).update(updates);
    } catch (e) {
      if (kDebugMode) print('Error updating profile: $e');
      rethrow;
    }
  }

  /// Updates the user's last active timestamp in Firestore.
  /// 
  /// Private helper method called during sign-in to track
  /// user activity. Uses server timestamp for consistency
  /// across different client time zones.
  /// 
  /// Fails silently with debug logging if update fails
  /// to avoid interrupting the sign-in flow.
  /// 
  /// @param uid User ID to update
  Future<void> _updateLastActive(String uid) async {
    if (_firestore == null) return;
    
    try {
      await _firestore!.collection('users').doc(uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('Error updating last active: $e');
    }
  }

  /// Converts Firebase Auth exceptions to user-friendly error messages.
  /// 
  /// Maps Firebase error codes to human-readable messages that
  /// can be displayed in the UI. Covers all common auth errors:
  /// - Registration errors (weak password, email in use)
  /// - Sign-in errors (invalid credentials, disabled account)
  /// - Network and operational errors
  /// - Verification and OAuth errors
  /// 
  /// Falls back to generic message for unknown error codes.
  /// 
  /// @param e FirebaseAuthException to handle
  /// @return User-friendly error message string
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak. Please use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Please sign in instead.';
      case 'invalid-email':
        return 'The email address is invalid. Please check and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Username or password invalid. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      case 'invalid-verification-code':
        return 'The verification code is invalid. Please try again.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid. Please try again.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different account.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different credentials.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}