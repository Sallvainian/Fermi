import 'dart:async';
import 'package:firebase_dart/firebase_dart.dart';
import '../interfaces/auth_service.dart';
import '../logger_service.dart';

/// Windows implementation of AuthService using firebase_dart
/// Provides full Firebase functionality on Windows desktop
class WindowsAuthService implements AuthService {
  late FirebaseAuth _firebaseAuth;
  StreamController<AuthUser?>? _authStateController;
  AuthUser? _currentUser;
  
  static const String _logTag = 'WindowsAuthService';

  WindowsAuthService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _firebaseAuth = FirebaseAuth.instance;
      _authStateController = StreamController<AuthUser?>.broadcast();
      
      // Listen to Firebase auth state changes
      _firebaseAuth.authStateChanges().listen((User? firebaseUser) {
        _currentUser = firebaseUser != null ? _mapFirebaseUser(firebaseUser) : null;
        _authStateController?.add(_currentUser);
      });
      
      LoggerService.info('Windows Firebase Auth initialized', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to initialize Windows Firebase Auth', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges {
    return _authStateController?.stream ?? const Stream.empty();
  }

  @override
  Future<AuthUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      LoggerService.info('Attempting email/password sign-in', tag: _logTag);
      
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      if (user != null) {
        _currentUser = _mapFirebaseUser(user);
        LoggerService.info('Email/password sign-in successful', tag: _logTag);
        return _currentUser;
      }
      
      return null;
    } catch (e) {
      LoggerService.error('Email/password sign-in failed', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<AuthUser?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      LoggerService.info('Attempting to create user with email/password', tag: _logTag);
      
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      if (user != null) {
        _currentUser = _mapFirebaseUser(user);
        LoggerService.info('User creation successful', tag: _logTag);
        return _currentUser;
      }
      
      return null;
    } catch (e) {
      LoggerService.error('User creation failed', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      LoggerService.info('Attempting Google Sign-In via desktop webview', tag: _logTag);
      
      // For now, use simplified OAuth with firebase_dart's built-in Google provider
      // This will open a browser window for authentication
      final googleProvider = GoogleAuthProvider();
      
      // Add OAuth scopes
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      
      final userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
      final user = userCredential.user;
      
      if (user != null) {
        _currentUser = _mapFirebaseUser(user);
        LoggerService.info('Google Sign-In successful via popup', tag: _logTag);
        return _currentUser;
      }
      
      return null;
    } catch (e) {
      LoggerService.warning('Google Sign-In popup failed, trying redirect method', tag: _logTag);
      
      try {
        // Fallback to redirect method
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        await _firebaseAuth.signInWithRedirect(googleProvider);
        
        // Note: The result will be handled by the auth state listener
        LoggerService.info('Google Sign-In redirect initiated', tag: _logTag);
        return null; // Result will come through auth state changes
      } catch (redirectError) {
        LoggerService.error('Google Sign-In completely failed', tag: _logTag, error: redirectError);
        throw Exception(
          'Google Sign-In is not available on this Windows system. '
          'Please use email/password authentication instead. '
          'Error: ${redirectError.toString()}',
        );
      }
    }
  }

  @override
  Future<AuthUser?> signInAnonymously() async {
    try {
      LoggerService.info('Attempting anonymous sign-in', tag: _logTag);
      
      final userCredential = await _firebaseAuth.signInAnonymously();
      final user = userCredential.user;
      
      if (user != null) {
        _currentUser = _mapFirebaseUser(user);
        LoggerService.info('Anonymous sign-in successful', tag: _logTag);
        return _currentUser;
      }
      
      return null;
    } catch (e) {
      LoggerService.error('Anonymous sign-in failed', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      LoggerService.info('Signing out', tag: _logTag);
      await _firebaseAuth.signOut();
      _currentUser = null;
      LoggerService.info('Sign out successful', tag: _logTag);
    } catch (e) {
      LoggerService.error('Sign out failed', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      LoggerService.info('Sending password reset email', tag: _logTag);
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      LoggerService.info('Password reset email sent successfully', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to send password reset email', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
      LoggerService.info('Sending email verification', tag: _logTag);
      await user.sendEmailVerification();
      LoggerService.info('Email verification sent successfully', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to send email verification', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> reloadUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
      LoggerService.info('Reloading user data', tag: _logTag);
      await user.reload();
      _currentUser = _mapFirebaseUser(_firebaseAuth.currentUser!);
      _authStateController?.add(_currentUser);
      LoggerService.info('User data reloaded successfully', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to reload user data', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
      LoggerService.info('Updating user profile', tag: _logTag);
      // firebase_dart uses updateProfile instead of separate methods
      await user.updateProfile(displayName: displayName, photoURL: photoURL);
      await user.reload();
      
      _currentUser = _mapFirebaseUser(_firebaseAuth.currentUser!);
      _authStateController?.add(_currentUser);
      LoggerService.info('Profile updated successfully', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to update profile', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> updateEmail({required String newEmail}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
      LoggerService.info('Updating user email', tag: _logTag);
      await user.updateEmail(newEmail);
      await user.reload();
      
      _currentUser = _mapFirebaseUser(_firebaseAuth.currentUser!);
      _authStateController?.add(_currentUser);
      LoggerService.info('Email updated successfully', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to update email', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
      LoggerService.info('Updating user password', tag: _logTag);
      await user.updatePassword(newPassword);
      LoggerService.info('Password updated successfully', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to update password', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      
      LoggerService.info('Deleting user account', tag: _logTag);
      await user.delete();
      _currentUser = null;
      LoggerService.info('Account deleted successfully', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to delete account', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return null;
      }
      
      LoggerService.debug('Getting ID token', tag: _logTag);
      final token = await user.getIdToken(forceRefresh);
      return token;
    } catch (e) {
      LoggerService.error('Failed to get ID token', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> setCustomClaims({
    required String uid,
    required Map<String, dynamic> claims,
  }) async {
    // Custom claims require Admin SDK on the server side
    // This is not available in client-side implementations
    throw UnimplementedError(
      'Custom claims must be set server-side using Firebase Admin SDK. '
      'This feature is not available in client applications.',
    );
  }

  @override
  Future<Map<String, dynamic>?> getCustomClaims() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return null;
      }
      
      LoggerService.debug('Getting custom claims', tag: _logTag);
      final idTokenResult = await user.getIdTokenResult(false);
      return idTokenResult.claims;
    } catch (e) {
      LoggerService.error('Failed to get custom claims', tag: _logTag, error: e);
      return null;
    }
  }

  /// Map Firebase User to our AuthUser model
  AuthUser _mapFirebaseUser(User firebaseUser) {
    return AuthUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      photoURL: firebaseUser.photoURL,
      emailVerified: firebaseUser.emailVerified,
      isAnonymous: firebaseUser.isAnonymous,
      creationTime: firebaseUser.metadata.creationTime,
      lastSignInTime: firebaseUser.metadata.lastSignInTime,
      phoneNumber: firebaseUser.phoneNumber,
    );
  }

  /// Dispose resources
  void dispose() {
    _authStateController?.close();
  }
}