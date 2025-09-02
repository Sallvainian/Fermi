import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for handling username-based authentication.
/// 
/// This service converts usernames to synthetic emails for Firebase Auth
/// while maintaining a clean username-based interface for users.
class UsernameAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Domain suffix for synthetic emails
  static const String _emailDomain = '@fermi.local';
  
  /// Generate a synthetic email from a username
  String generateSyntheticEmail(String username) {
    return '${username.toLowerCase()}$_emailDomain';
  }
  
  /// Extract username from a synthetic email
  String? extractUsernameFromEmail(String email) {
    if (email.endsWith(_emailDomain)) {
      return email.substring(0, email.length - _emailDomain.length);
    }
    return null;
  }
  
  /// Check if a username is already taken
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return false;
    }
  }
  
  /// Get user UID by username
  Future<String?> getUidByUsername(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting UID by username: $e');
      return null;
    }
  }
  
  /// Sign in with username and password
  Future<User?> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      // Convert username to synthetic email
      final email = generateSyntheticEmail(username);
      
      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Update last active timestamp
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .update({
          'lastActive': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
      
      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Convert Firebase Auth errors to user-friendly messages
      switch (e.code) {
        case 'user-not-found':
          throw Exception('Username not found');
        case 'wrong-password':
          throw Exception('Incorrect password');
        case 'invalid-email':
          // This shouldn't happen with our synthetic emails
          throw Exception('Invalid username format');
        case 'user-disabled':
          throw Exception('This account has been disabled');
        case 'invalid-credential':
          throw Exception('Invalid username or password');
        default:
          throw Exception(e.message ?? 'Authentication failed');
      }
    } catch (e) {
      debugPrint('Username sign-in error: $e');
      rethrow;
    }
  }
  
  /// Create a new student account with username and password
  Future<User?> createStudentAccount({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    String? teacherId,
  }) async {
    try {
      // Validate username availability
      final isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username "$username" is already taken');
      }
      
      // Generate synthetic email
      final email = generateSyntheticEmail(username);
      final displayName = '$firstName $lastName';
      
      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(displayName);
        
        // Create user document in Firestore
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'username': username.toLowerCase(),
          'email': email,
          'displayName': displayName,
          'firstName': firstName,
          'lastName': lastName,
          'role': 'student',
          'teacherId': teacherId,
          'photoURL': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });
        
        return credential.user;
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('Username already exists');
        case 'weak-password':
          throw Exception('Password is too weak (minimum 6 characters)');
        case 'invalid-email':
          throw Exception('Invalid username format');
        default:
          throw Exception(e.message ?? 'Failed to create account');
      }
    } catch (e) {
      debugPrint('Create student account error: $e');
      rethrow;
    }
  }
  
  /// Create a teacher account with username and password
  Future<User?> createTeacherAccount({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      // Validate username availability
      final isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username "$username" is already taken');
      }
      
      // Generate synthetic email
      final email = generateSyntheticEmail(username);
      final displayName = '$firstName $lastName';
      
      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(displayName);
        
        // Create user document in Firestore
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'username': username.toLowerCase(),
          'email': email,
          'displayName': displayName,
          'firstName': firstName,
          'lastName': lastName,
          'role': 'teacher',
          'photoURL': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });
        
        return credential.user;
      }
      
      return null;
    } catch (e) {
      debugPrint('Create teacher account error: $e');
      rethrow;
    }
  }
  
  /// Update password for a user (teacher can reset student passwords)
  Future<void> updatePasswordForUser({
    required String username,
    required String newPassword,
  }) async {
    try {
      // This would require Firebase Admin SDK or Cloud Functions
      // For now, we'll throw an exception indicating this needs backend support
      throw UnimplementedError(
        'Password reset requires Firebase Admin SDK. '
        'Please implement a Cloud Function for this feature.'
      );
    } catch (e) {
      debugPrint('Update password error: $e');
      rethrow;
    }
  }
  
  /// Validate username format
  bool isValidUsername(String username) {
    // Username must be:
    // - 3-20 characters long
    // - Contain only letters, numbers, and underscores
    // - Start with a letter
    final regex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{2,19}$');
    return regex.hasMatch(username);
  }
  
  /// Generate a username suggestion based on name
  String generateUsername(String firstName, String lastName) {
    // Create username from first initial + last name + number
    final firstInitial = firstName.isNotEmpty ? firstName[0].toLowerCase() : '';
    final lastNameClean = lastName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    // Start with base username
    String baseUsername = '$firstInitial$lastNameClean';
    
    // Ensure minimum length
    if (baseUsername.length < 3) {
      baseUsername = '${firstName.toLowerCase()}${lastName.toLowerCase()}'.replaceAll(RegExp(r'[^a-z0-9]'), '');
    }
    
    // Truncate if too long
    if (baseUsername.length > 17) {
      baseUsername = baseUsername.substring(0, 17);
    }
    
    // Add number suffix (will be incremented if not unique)
    return '${baseUsername}01';
  }
  
  /// Get next available username with number suffix
  Future<String> getNextAvailableUsername(String baseUsername) async {
    // Remove any trailing numbers
    final cleanBase = baseUsername.replaceAll(RegExp(r'\d+$'), '');
    
    // Try up to 99 suffixes
    for (int i = 1; i < 100; i++) {
      final username = '$cleanBase${i.toString().padLeft(2, '0')}';
      if (await isUsernameAvailable(username)) {
        return username;
      }
    }
    
    // If all 99 are taken, throw error
    throw Exception('Could not generate unique username');
  }
}