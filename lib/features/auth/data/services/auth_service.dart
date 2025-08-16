import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// Temporarily disabled due to iOS dependency conflicts
// import 'package:google_sign_in/google_sign_in.dart';

/// Simple authentication service - does one thing well
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      
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
      // Mobile: Google Sign-In temporarily disabled due to iOS dependency conflicts
      throw UnimplementedError('Google Sign-In is temporarily unavailable on mobile');
      // final googleSignIn = GoogleSignIn.instance;
      // await googleSignIn.initialize();
      // final account = await googleSignIn.authenticate();
      // 
      // final auth = account.authentication;
      // final credential = GoogleAuthProvider.credential(
      //   idToken: auth.idToken,
      // );
      // 
      // final cred = await _auth.signInWithCredential(credential);
      // user = cred.user;
    }
    
    // Check if user document exists, create if not (for new Google users)
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // Parse name from Google account
        final nameParts = (user.displayName ?? '').split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        
        // Create user document
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? user.email?.split('@').first ?? 'User',
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

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    
    // Also sign out of Google on mobile
    // Temporarily disabled due to iOS dependency conflicts
    // if (!kIsWeb) {
    //   try {
    //     await GoogleSignIn.instance.signOut();
    //   } catch (_) {}
    // }
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
}