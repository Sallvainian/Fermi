import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import '../interfaces/auth_service.dart';

/// Firebase implementation of AuthService
class FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  AuthUser? get currentUser {
    final fbUser = _auth.currentUser;
    return fbUser != null ? _convertUser(fbUser) : null;
  }

  @override
  Stream<AuthUser?> get authStateChanges {
    return _auth.authStateChanges().map((fbUser) {
      return fbUser != null ? _convertUser(fbUser) : null;
    });
  }

  @override
  Future<AuthUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user != null ? _convertUser(credential.user!) : null;
    } on fb.FirebaseAuthException {
      rethrow;
    }
  }

  @override
  Future<AuthUser?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user != null ? _convertUser(credential.user!) : null;
    } on fb.FirebaseAuthException {
      rethrow;
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Create a new credential
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user != null 
          ? _convertUser(userCredential.user!) 
          : null;
    } on fb.FirebaseAuthException {
      rethrow;
    }
  }

  @override
  Future<AuthUser?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user != null ? _convertUser(credential.user!) : null;
    } on fb.FirebaseAuthException {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  @override
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    await _auth.currentUser?.updateDisplayName(displayName);
    await _auth.currentUser?.updatePhotoURL(photoURL);
  }

  @override
  Future<void> updateEmail({required String newEmail}) async {
    await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  @override
  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await _auth.currentUser?.getIdToken(forceRefresh);
  }

  @override
  Future<void> setCustomClaims({
    required String uid,
    required Map<String, dynamic> claims,
  }) async {
    // This requires Firebase Admin SDK, not available in client SDK
    // Would need to call a Cloud Function to set custom claims
    throw UnimplementedError(
      'setCustomClaims requires Firebase Admin SDK. '
      'Use a Cloud Function to set custom claims.',
    );
  }

  @override
  Future<Map<String, dynamic>?> getCustomClaims() async {
    final idTokenResult = await _auth.currentUser?.getIdTokenResult();
    return idTokenResult?.claims;
  }

  /// Convert Firebase User to our AuthUser model
  AuthUser _convertUser(fb.User fbUser) {
    return AuthUser(
      uid: fbUser.uid,
      email: fbUser.email,
      displayName: fbUser.displayName,
      photoURL: fbUser.photoURL,
      emailVerified: fbUser.emailVerified,
      isAnonymous: fbUser.isAnonymous,
      creationTime: fbUser.metadata.creationTime,
      lastSignInTime: fbUser.metadata.lastSignInTime,
      phoneNumber: fbUser.phoneNumber,
    );
  }
}