import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../shared/models/user_model.dart';
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
  final AuthService _authService;
  AuthStatus _status;
  UserModel? _userModel;
  String? _errorMessage;
  bool _isLoading;

  /// Whether the user has chosen to persist their authentication session.
  bool _rememberMe = false;

  AuthProvider({AuthService? authService, AuthStatus initialStatus = AuthStatus.uninitialized, UserModel? userModel})
      : _authService = authService ?? AuthService(),
        _status = initialStatus,
        _userModel = userModel,
        _isLoading = false {
    // Initialize auth state on creation
    _initializeAuthState();
  }

  /// Initializes auth state by checking for existing Firebase user.
  /// This restores the user session on app restart/refresh.
  Future<void> _initializeAuthState() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        // User is logged in, fetch their profile
        _status = AuthStatus.authenticating;
        notifyListeners();
        
        // Get user model from Firestore
        final uid = user.uid;
        final userData = await _authService.getUserData(uid);
        final currentUserModel = userData != null ? UserModel.fromFirestore(userData) : null;
        
        if (currentUserModel != null) {
          _userModel = currentUserModel;
          _status = AuthStatus.authenticated;
          
          // Start web in-app notifications if on web
          if (kIsWeb) {
            WebInAppNotificationService().startWebInAppNotifications();
          }
        } else {
          // User exists in Auth but not in Firestore - might be mid-registration
          _status = AuthStatus.authenticating;
        }
      } else {
        // No user logged in
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      debugPrint('Failed to restore auth state: $e');
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

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
      final user = await _authService.signIn(
        email: email,
        password: password,
      );
      UserModel? userModel;
      if (user != null) {
        final userData = await _authService.getUserData(user.uid);
        userModel = userData != null ? UserModel.fromFirestore(userData) : null;
      }
      
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
      final user = await _authService.signInWithGoogle();
      UserModel? userModel;
      if (user != null) {
        final userData = await _authService.getUserData(user.uid);
        userModel = userData != null ? UserModel.fromFirestore(userData) : null;
      }
      
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
      // After Google sign-in, update the user's role
      final user = _authService.currentUser;
      UserModel? userModel;
      if (user != null) {
        await _authService.updateUserRole(user.uid, role.toString());
        final userData = await _authService.getUserData(user.uid);
        userModel = userData != null ? UserModel.fromFirestore(userData) : null;
      }
      
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
      // Call the real Firebase sign-up (Auth account only)
      final user = await _authService.signUp(
        email: email,
        password: password,
        displayName: email.split('@')[0], // Use email prefix as display name
      );
      
      if (user != null) {
        // Don't assign role or set authenticated - let router handle role selection
        _status = AuthStatus.authenticating;
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
      // Update display name in Firebase Auth
      final user = _authService.currentUser;
      if (user != null && displayName != null) {
        await user.updateDisplayName(displayName);
      }
      
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

  /// Updates the user's profile picture URL.
  Future<void> updateProfilePicture(String photoURL) async {
    if (_userModel == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Update Firebase Auth profile
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePhotoURL(photoURL);
      }
      
      // Update local model
      _userModel = _userModel!.copyWith(photoURL: photoURL);
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
      await _authService.signOut();
      _resetState();
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
      final userData = await _authService.getUserData(user.uid);
      final currentUser = userData != null ? UserModel.fromFirestore(userData) : null;
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
      final user = _authService.currentUser;
      UserModel? currentUser;
      if (user != null) {
        final userData = await _authService.getUserData(user.uid);
        currentUser = userData != null ? UserModel.fromFirestore(userData) : null;
      }
      if (currentUser != null) {
        _userModel = currentUser;
        notifyListeners();
      }
    } catch (e) {
      // Silently fail - custom claims refresh is not critical
    }
  }

  /// Cleans up resources when provider is disposed.
  /// Ensures proper cleanup to prevent memory leaks.
  @override
  void dispose() {
    // Clean up any pending operations
    _isLoading = false;
    _errorMessage = null;
    _userModel = null;
    _status = AuthStatus.uninitialized;
    
    // Stop web notifications if on web
    if (kIsWeb) {
      WebInAppNotificationService().stopWebInAppNotifications();
    }
    
    super.dispose();
  }

  /// Resets provider state on logout.
  /// Called internally during sign out to ensure clean state.
  void _resetState() {
    _status = AuthStatus.unauthenticated;
    _userModel = null;
    _rememberMe = false;
    _errorMessage = null;
    _isLoading = false;
  }
}