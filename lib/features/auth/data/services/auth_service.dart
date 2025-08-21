import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Simple authentication service - does one thing well
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthService() {
    // Web persistence
    if (kIsWeb) {
      _auth.setPersistence(Persistence.LOCAL);
    }
  }

  // Current user
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (cred.user != null) {
      await cred.user!.updateDisplayName(displayName);

      // Parse name parts
      final nameParts = displayName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // Create user document with proper structure
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': email,
        'displayName': displayName,
        'firstName': firstName,
        'lastName': lastName,
        'photoURL': null,
        'role': null, // Will be set during role selection
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
    }

    return cred.user;
  }

  // Sign in with email
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update last active
    if (cred.user != null) {
      await _firestore.collection('users').doc(cred.user!.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }

    return cred.user;
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    User? user;

    if (kIsWeb) {
      // Web: Use popup
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      user = cred.user;
    } else {
      // Mobile: Use Google Sign-In SDK
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      user = cred.user;
    }

    // Check if user document exists, create if not (for new Google users)
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // Parse name from Google account
        final nameParts = (user.displayName ?? '').split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        // Create user document
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName':
              user.displayName ?? user.email?.split('@').first ?? 'User',
          'firstName': firstName,
          'lastName': lastName,
          'photoURL': user.photoURL,
          'role': null, // Will be set during role selection
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });
      } else {
        // Update last active
        await _firestore.collection('users').doc(user.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
    }

    return user;
  }

  // Sign in with Apple (required for App Store compliance - Guideline 4.8)
  Future<User?> signInWithApple() async {
    try {
      // Check if Apple Sign In is available
      if (!await SignInWithApple.isAvailable()) {
        throw Exception('Sign in with Apple is not available on this device');
      }

      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: kIsWeb
            ? WebAuthenticationOptions(
                clientId: 'com.academic-tools.fermi.firebase',
                redirectUri: Uri.parse(
                  'https://teacher-dashboard-flutterfire.firebaseapp.com/__/auth/handler',
                ),
              )
            : null,
      );

      // Create Firebase credential from Apple credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with Apple credential
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      // Handle user data (similar to Google Sign-In)
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          // Create user document for new Apple users
          String firstName = '';
          String lastName = '';
          String displayName = user.displayName ?? 'User';

          // Apple provides name data during first sign-in only
          if (appleCredential.givenName != null || appleCredential.familyName != null) {
            firstName = appleCredential.givenName ?? '';
            lastName = appleCredential.familyName ?? '';
            displayName = '$firstName $lastName'.trim();
            if (displayName.isEmpty) {
              displayName = user.email?.split('@').first ?? 'User';
            }
          } else {
            // Fallback to email prefix if no name provided
            displayName = user.email?.split('@').first ?? 'User';
          }

          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'displayName': displayName,
            'firstName': firstName,
            'lastName': lastName,
            'photoURL': user.photoURL,
            'role': null, // Will be set during role selection
            'createdAt': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
            'authProvider': 'apple', // Track auth method for privacy compliance
          });
        } else {
          // Update last active for existing users
          await _firestore.collection('users').doc(user.uid).update({
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
      }

      return user;
    } catch (e) {
      debugPrint('Apple Sign-In error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();

    // Also sign out of Google on mobile
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Email verification
  Future<void> sendEmailVerification() async {
    await currentUser?.sendEmailVerification();
  }

  // Update user role (for role selection after Google sign-in)
  Future<void> updateUserRole(String uid, String role) async {
    // Parse role properly
    String roleStr = role;
    if (role.contains('.')) {
      roleStr = role.split('.').last;
    }

    await _firestore.collection('users').doc(uid).update({
      'role': roleStr,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // If student, also create student document
    if (roleStr == 'student') {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      if (userData != null) {
        await _firestore.collection('students').doc(uid).set({
          'uid': uid,
          'email': userData['email'],
          'displayName': userData['displayName'],
          'firstName': userData['firstName'] ?? '',
          'lastName': userData['lastName'] ?? '',
          'isActive': true,
          'classIds': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      // Ensure uid field exists
      data['uid'] = uid;
    }
    return data;
  }

  // Delete user account and all associated data
  // Required for privacy compliance (GDPR, App Store guidelines)
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      final uid = user.uid;
      
      // Get user data to check role for additional cleanup
      final userData = await getUserData(uid);
      final userRole = userData?['role'] as String?;

      // Delete user document from Firestore
      await _firestore.collection('users').doc(uid).delete().catchError((_) {
        // Continue even if user document doesn't exist
      });

      // If user is a student, also delete from students collection
      if (userRole == 'student') {
        await _firestore.collection('students').doc(uid).delete().catchError((_) {
          // Continue even if student document doesn't exist
        });
      }

      // Delete from any other collections that might contain user data
      // Note: In a production app, you'd want to implement a more comprehensive
      // cleanup that removes user data from all relevant collections
      
      // Delete Firebase Auth account (this must be done last)
      await user.delete();
      
      debugPrint('User account deleted successfully');
    } catch (e) {
      debugPrint('Error deleting account: $e');
      
      // Handle common deletion errors
      if (e.toString().contains('requires-recent-login')) {
        throw Exception(
          'For security reasons, please sign in again before deleting your account.'
        );
      } else if (e.toString().contains('network-request-failed')) {
        throw Exception(
          'Network error. Please check your connection and try again.'
        );
      } else {
        throw Exception('Failed to delete account. Please try again.');
      }
    }
  }

  // Re-authenticate user for sensitive operations like account deletion
  Future<void> reauthenticateWithEmail(String email, String password) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      debugPrint('Re-authentication failed: $e');
      if (e.toString().contains('wrong-password')) {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.toString().contains('user-mismatch')) {
        throw Exception('Email does not match current user.');
      } else {
        throw Exception('Authentication failed. Please try again.');
      }
    }
  }

  // Re-authenticate with Google for account deletion
  Future<void> reauthenticateWithGoogle() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      if (kIsWeb) {
        // Web: Use popup re-authentication
        final provider = GoogleAuthProvider();
        await user.reauthenticateWithPopup(provider);
      } else {
        // Mobile: Use Google Sign-In SDK
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google sign-in was cancelled');
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await user.reauthenticateWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Google re-authentication failed: $e');
      throw Exception('Google authentication failed. Please try again.');
    }
  }

  // Re-authenticate with Apple for account deletion
  Future<void> reauthenticateWithApple() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      // Request Apple ID credential for re-authentication
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [],
        webAuthenticationOptions: kIsWeb
            ? WebAuthenticationOptions(
                clientId: 'com.academic-tools.fermi.firebase',
                redirectUri: Uri.parse(
                  'https://teacher-dashboard-flutterfire.firebaseapp.com/__/auth/handler',
                ),
              )
            : null,
      );

      // Create Firebase credential from Apple credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Re-authenticate with Firebase
      await user.reauthenticateWithCredential(oauthCredential);
    } catch (e) {
      debugPrint('Apple re-authentication failed: $e');
      throw Exception('Apple authentication failed. Please try again.');
    }
  }
}
