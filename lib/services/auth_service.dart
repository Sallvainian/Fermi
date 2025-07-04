import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';

class AuthService {
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: dotenv.env['GOOGLE_OAUTH_CLIENT_ID'],
  );

  AuthService() {
    try {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
    } catch (e) {
      if (kDebugMode) print('Firebase not available: $e');
    }
  }

  // Stream of auth state changes
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

  // Get current user
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

  // Get current user model
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

  // Sign up with email and password only (without creating Firestore document)
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

  // Sign up with email and password (creates both Auth and Firestore user)
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

  // Sign in with email and password
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

  // Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    if (_auth == null || _firestore == null) {
      throw Exception('Firebase not available - cannot sign in with Google');
    }
    
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
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

  // Complete Google sign up with role
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

  // Sign out
  Future<void> signOut() async {
    final futures = <Future>[];
    if (_auth != null) futures.add(_auth!.signOut());
    futures.add(_googleSignIn.signOut());
    await Future.wait(futures);
  }

  // Reset password
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

  // Update user profile
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

  // Update last active timestamp
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

  // Handle Firebase Auth exceptions
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