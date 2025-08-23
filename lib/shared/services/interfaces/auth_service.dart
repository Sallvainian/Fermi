import 'dart:async';

/// Abstract authentication service interface
/// Implementations can use Firebase Auth, firebase_dart, or other auth providers
abstract class AuthService {
  /// Get the current user
  AuthUser? get currentUser;

  /// Stream of authentication state changes
  Stream<AuthUser?> get authStateChanges;

  /// Sign in with email and password
  Future<AuthUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Create user with email and password
  Future<AuthUser?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Sign in with Google
  Future<AuthUser?> signInWithGoogle();

  /// Sign in anonymously
  Future<AuthUser?> signInAnonymously();

  /// Sign out
  Future<void> signOut();

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email});

  /// Send email verification
  Future<void> sendEmailVerification();

  /// Reload user data
  Future<void> reloadUser();

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  });

  /// Update user email
  Future<void> updateEmail({required String newEmail});

  /// Update user password
  Future<void> updatePassword({required String newPassword});

  /// Delete user account
  Future<void> deleteAccount();

  /// Get ID token
  Future<String?> getIdToken({bool forceRefresh = false});

  /// Set custom user claims (admin only)
  Future<void> setCustomClaims({
    required String uid,
    required Map<String, dynamic> claims,
  });

  /// Get custom user claims
  Future<Map<String, dynamic>?> getCustomClaims();
}

/// Platform-agnostic user model
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool emailVerified;
  final bool isAnonymous;
  final DateTime? creationTime;
  final DateTime? lastSignInTime;
  final String? phoneNumber;
  final Map<String, dynamic>? customClaims;

  AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.emailVerified = false,
    this.isAnonymous = false,
    this.creationTime,
    this.lastSignInTime,
    this.phoneNumber,
    this.customClaims,
  });

  /// Create from a map (for serialization)
  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      uid: map['uid'] as String,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      photoURL: map['photoURL'] as String?,
      emailVerified: map['emailVerified'] as bool? ?? false,
      isAnonymous: map['isAnonymous'] as bool? ?? false,
      creationTime: map['creationTime'] != null
          ? DateTime.parse(map['creationTime'] as String)
          : null,
      lastSignInTime: map['lastSignInTime'] != null
          ? DateTime.parse(map['lastSignInTime'] as String)
          : null,
      phoneNumber: map['phoneNumber'] as String?,
      customClaims: map['customClaims'] as Map<String, dynamic>?,
    );
  }

  /// Convert to a map (for serialization)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'emailVerified': emailVerified,
      'isAnonymous': isAnonymous,
      'creationTime': creationTime?.toIso8601String(),
      'lastSignInTime': lastSignInTime?.toIso8601String(),
      'phoneNumber': phoneNumber,
      'customClaims': customClaims,
    };
  }

  /// Copy with updated fields
  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    bool? emailVerified,
    bool? isAnonymous,
    DateTime? creationTime,
    DateTime? lastSignInTime,
    String? phoneNumber,
    Map<String, dynamic>? customClaims,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      emailVerified: emailVerified ?? this.emailVerified,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      creationTime: creationTime ?? this.creationTime,
      lastSignInTime: lastSignInTime ?? this.lastSignInTime,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      customClaims: customClaims ?? this.customClaims,
    );
  }
}