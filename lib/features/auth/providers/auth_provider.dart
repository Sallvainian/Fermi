import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../shared/models/user_model.dart';
import '../domain/repositories/auth_repository.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/services/auth_service.dart';
import '../../notifications/data/services/web_in_app_notification_service.dart';

/// Enumeration describing the current authentication state.
///
/// This mirrors the states used in the full application but is kept
/// intentionally lightweight. Only the values used in the routing logic
/// are included here. Additional states can be added as needed to match
/// the real implementation.
enum AuthStatus {
  /// The authentication status has not yet been determined.
  uninitialized,

  /// The user is fully authenticated and has completed any required
  /// onboarding steps (such as role selection and email verification).
  authenticated,

  /// The user is in the process of authenticating or onboarding. In the
  /// real application this includes flows such as Google sign‑in where
  /// the user must select a role before they are considered authenticated.
  authenticating,

  /// The user is not authenticated. This includes logged‑out users and
  /// error states.
  unauthenticated,

  /// An unrecoverable authentication error occurred.
  error,
}

// Using Firebase Auth User directly
typedef User = firebase_auth.User;

/// Simplified authentication provider for routing and verification.
///
/// This provider exposes a minimal API used throughout the application.
/// It intentionally omits complex logic so that unit tests can exercise
/// the routing without pulling in Firebase dependencies. All methods
/// operate synchronously or with minimal delay and simply update local
/// state.
class AuthProvider extends ChangeNotifier {
  final AuthRepository? _authRepository;
  AuthStatus _status;
  UserModel? _userModel;
  String? _errorMessage;
  bool _isLoading;

  /// Whether the user has chosen to persist their authentication session.
  bool _rememberMe = false;

  AuthProvider({AuthRepository? repository, AuthStatus initialStatus = AuthStatus.uninitialized, UserModel? userModel})
      : _authRepository = repository ?? AuthRepositoryImpl(AuthService()),
        _status = initialStatus,
        _userModel = userModel,
        _isLoading = false;

  /// The current authentication status.
  AuthStatus get status => _status;

  /// The currently signed in user model, or null if unauthenticated.
  UserModel? get userModel => _userModel;

  /// The Firebase Auth user, or null if not signed in.
  firebase_auth.User? get firebaseUser => firebase_auth.FirebaseAuth.instance.currentUser;

  /// A human‑readable error message, if an authentication error occurred.
  String? get errorMessage => _errorMessage;

  /// Whether an authentication operation is in progress.
  bool get isLoading => _isLoading;

  /// Sets a new error message and notifies listeners. Use this to
  /// surface authentication errors to the UI.
  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Whether the user is fully authenticated.
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Whether the current session should be persisted across app launches.
  bool get rememberMe => _rememberMe;

  /// Sets the persistence of the authentication session. When set to
  /// `true`, the provider will keep the current user in memory and
  /// indicate to any underlying repository that the session should be
  /// persisted. In this stub implementation it simply stores the flag
  /// locally.
  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  /// Clears any existing error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Signs in the user with an email and password.
  ///
  /// Calls Firebase Auth to authenticate the user and fetch their profile
  /// from Firestore.
  Future<void> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      _isLoading = false;
      setError('Email and password are required.');
      return;
    }
    
    try {
      // Call the real Firebase authentication
      final userModel = await _authRepository?.signInWithEmail(
        email: email,
        password: password,
      );
      
      if (userModel != null) {
        _userModel = userModel;
        _status = AuthStatus.authenticated;
        // Start web in-app notifications if on web
        if (kIsWeb) {
          WebInAppNotificationService().startWebInAppNotifications();
        }
      } else {
        throw Exception('Sign in failed');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signs in the user with Google.
  ///
  /// For new users, returns null and sets status to authenticating
  /// to trigger role selection. For existing users, signs them in
  /// directly with their stored profile.
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Call the real Google Sign-In
      final userModel = await _authRepository?.signInWithGoogle();
      
      if (userModel != null) {
        // Existing user - sign them in directly
        _userModel = userModel;
        _status = AuthStatus.authenticated;
      } else {
        // New user - need role selection
        _status = AuthStatus.authenticating;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Completes the Google sign‑in by assigning a role and finishing
  /// profile setup.
  Future<void> completeGoogleSignUp({required UserRole role, String? parentEmail, String? gradeLevel}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Call the real repository to complete Google sign-up
      final userModel = await _authRepository?.completeGoogleSignUp(
        role: role,
        parentEmail: parentEmail,
        gradeLevel: gradeLevel,
      );
      
      if (userModel != null) {
        _userModel = userModel;
        _status = AuthStatus.authenticated;
      } else {
        throw Exception('Failed to complete Google sign-up');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registers a new user with an email and password.
  ///
  /// Creates a new user account in Firebase Auth and writes their
  /// profile to Firestore.
  Future<void> signUpWithEmailOnly(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    if (email.isEmpty || password.isEmpty) {
      _isLoading = false;
      setError('Email and password are required.');
      return;
    }
    
    try {
      // Call the real Firebase sign-up
      final userModel = await _authRepository?.signUpWithEmail(
        email: email,
        password: password,
        displayName: email.split('@')[0], // Use email prefix as display name
        role: UserRole.student, // Default role for email-only signup
      );
      
      if (userModel != null) {
        _userModel = userModel;
        _status = AuthStatus.authenticated;
      } else {
        throw Exception('Sign up failed');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the user profile with new display name or names.
  Future<void> updateProfile({String? displayName, String? firstName, String? lastName}) async {
    if (_userModel == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Call the real Firebase update
      await _authRepository?.updateProfile(
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
      );
      
      // Update local model
      _userModel = _userModel!.copyWith(
        displayName: displayName ?? _userModel!.displayName,
        firstName: firstName ?? _userModel!.firstName,
        lastName: lastName ?? _userModel!.lastName,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signs the user out.
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Stop web in-app notifications if on web
      if (kIsWeb) {
        WebInAppNotificationService().stopWebInAppNotifications();
      }
      // Call the real Firebase sign-out
      await _authRepository?.signOut();
      _status = AuthStatus.unauthenticated;
      _userModel = null;
      _rememberMe = false;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a verification email to the currently signed in user.
  Future<void> sendEmailVerification() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Reloads the current user to refresh authentication data.
  Future<void> reloadUser() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      // Refresh user model from repository
      final currentUser = await _authRepository?.getCurrentUserModel();
      if (currentUser != null) {
        _userModel = currentUser;
      }
      notifyListeners();
    }
  }

  /// Refreshes custom claims and updates the local user model.
  ///
  /// Retrieves custom claims from Firebase Auth and updates the user's role.
  Future<void> refreshCustomClaims() async {
    try {
      // Get fresh user data from repository
      final currentUser = await _authRepository?.getCurrentUserModel();
      if (currentUser != null) {
        _userModel = currentUser;
        notifyListeners();
      }
    } catch (e) {
      // Silently fail - custom claims refresh is not critical
    }
  }
}