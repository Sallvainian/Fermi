import 'package:flutter/foundation.dart';

/// Minimal stand‑in for the authentication status enumeration.
///
/// This enum mirrors the original project's `AuthStatus` values. It is
/// deliberately simplistic to avoid pulling in the entire Firebase
/// dependency tree for unit tests and example usage.
enum AuthStatus {
  uninitialized,
  authenticated,
  authenticating,
  unauthenticated,
  error,
}

/// Minimal stand‑in for user roles.
///
/// In the real application, user roles are more complex and likely come
/// from Firestore. Here we provide a simple representation suitable for
/// dependency isolation and testing. A new role can be added by
/// instantiating another `UserRole` constant.
class UserRole {
  final String name;
  const UserRole._(this.name);

  static const teacher = UserRole._('teacher');
  static const student = UserRole._('student');
}

/// Minimal stand‑in for the user model.
///
/// This model holds the authenticated user's role. In the real
/// implementation it would contain additional profile fields.
class UserModel {
  final UserRole? role;
  const UserModel({this.role});
}

/// Minimal stand‑in for a Firebase Auth user.
///
/// Only the properties and methods used by this codebase are defined here.
class User {
  bool emailVerified;
  final String? email;
  User({required this.emailVerified, this.email});

  Future<void> sendEmailVerification() async {
    // In tests this can be overridden or stubbed.
  }

  Future<void> reload() async {
    // In tests this can be overridden or stubbed.
  }
}

/// Minimal stand‑in for an authentication repository.
///
/// The real repository would wrap FirebaseAuth and Firestore operations.
class AuthRepository {
  User? currentUser;
  // Additional members omitted.
}

/// Simplified authentication provider used for routing and tests.
///
/// This class exposes only the subset of functionality required by the
/// routing logic and verify‑email screen. It is intentionally lightweight
/// to enable unit testing without Firebase dependencies.
class AuthProvider extends ChangeNotifier {
  AuthRepository? _authRepository;
  AuthStatus _status;
  UserModel? _userModel;

  AuthProvider({AuthRepository? repository, AuthStatus initialStatus = AuthStatus.uninitialized, UserModel? userModel})
      : _authRepository = repository,
        _status = initialStatus,
        _userModel = userModel;

  /// Current authentication status.
  AuthStatus get status => _status;

  /// Complete user profile or null if not authenticated.
  UserModel? get userModel => _userModel;

  /// Whether user is fully authenticated with role.
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Firebase Auth user instance (stubbed).
  User? get firebaseUser => _authRepository?.currentUser;

  /// Sends a verification email to the currently signed‑in user.
  ///
  /// If the user is logged in and their email has not been verified, this
  /// method triggers sending a verification email. In this stub
  /// implementation the call is asynchronous but does not perform any
  /// network operations.
  Future<void> sendEmailVerification() async {
    final user = _authRepository?.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Reloads the current user to refresh authentication data.
  ///
  /// This is necessary to update properties such as [User.emailVerified]
  /// after the user completes email verification. In this stub it simply
  /// calls `reload()` on the [User] instance and notifies listeners.
  Future<void> reloadUser() async {
    final user = _authRepository?.currentUser;
    if (user != null) {
      await user.reload();
      // In a real implementation the repository would refresh its local
      // reference to the user here.
      notifyListeners();
    }
  }
}