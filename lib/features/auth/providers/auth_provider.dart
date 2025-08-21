import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

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

  AuthProvider(
      {AuthService? authService,
      AuthStatus initialStatus = AuthStatus.uninitialized,
      UserModel? userModel})
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

        try {
          // First, verify the user still exists in Firebase Auth
          // This will throw if the user account has been deleted
          await user.reload();
          
          // Check if user was deleted (currentUser becomes null after reload)
          final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
          if (currentUser == null) {
            // User no longer exists in Firebase Auth
            debugPrint('User account no longer exists in Firebase Auth');
            await _handleDeletedAccount();
            return;
          }

          // Get user model from Firestore
          final uid = user.uid;
          final userData = await _authService.getUserData(uid);
          final currentUserModel =
              userData != null ? UserModel.fromFirestore(userData) : null;

          if (currentUserModel != null) {
            _userModel = currentUserModel;
            _status = AuthStatus.authenticated;

            // Start web in-app notifications if on web
            if (kIsWeb) {
              WebInAppNotificationService().startWebInAppNotifications();
            }
          } else {
            // User exists in Auth but not in Firestore
            // This could mean:
            // 1. User data was deleted from Firestore
            // 2. User is mid-registration
            // 3. Database connection issue
            
            debugPrint('User exists in Auth but not in Firestore');
            
            // Try to determine if this is a connection issue
            try {
              // Test Firestore connectivity with a simple read
              await _firestore.collection('_health').doc('check').get()
                  .timeout(const Duration(seconds: 5));
              
              // If we get here, Firestore is working but user data is missing
              // This likely means the user was deleted from Firestore
              await _handleMissingUserData(user);
            } catch (e) {
              // Network/connection issue - show appropriate error
              _errorMessage = 'Unable to connect to server. Please check your internet connection.';
              _status = AuthStatus.error;
            }
          }
        } catch (e) {
          if (e.toString().contains('user-not-found') || 
              e.toString().contains('user-token-expired') ||
              e.toString().contains('invalid-user-token')) {
            // User token is invalid or user was deleted
            await _handleDeletedAccount();
          } else if (e.toString().contains('network-request-failed')) {
            // Network error
            _errorMessage = 'Network error. Please check your internet connection and try again.';
            _status = AuthStatus.error;
          } else {
            // Other auth errors
            debugPrint('Auth verification failed: $e');
            await _handleAuthError(e.toString());
          }
        }
      } else {
        // No user logged in
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      debugPrint('Failed to restore auth state: $e');
      await _handleAuthError(e.toString());
    } finally {
      notifyListeners();
    }
  }

  /// Handles the case when a user account has been deleted
  Future<void> _handleDeletedAccount() async {
    debugPrint('Handling deleted account - clearing cached credentials');
    
    // Clear any cached authentication
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Error signing out deleted user: $e');
    }
    
    // Reset state
    _status = AuthStatus.error;
    _userModel = null;
    _errorMessage = 'Your account no longer exists. Please create a new account or contact support.';
    _isLoading = false;
    
    notifyListeners();
  }

  /// Handles the case when user exists in Auth but not in Firestore
  Future<void> _handleMissingUserData(firebase_auth.User user) async {
    debugPrint('Handling missing user data for uid: ${user.uid}');
    
    // Sign out the user since their data is incomplete
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Error signing out user with missing data: $e');
    }
    
    // Reset state
    _status = AuthStatus.error;
    _userModel = null;
    _errorMessage = 'Your account data could not be found. Please sign in again or contact support.';
    _isLoading = false;
    
    notifyListeners();
  }

  /// Handles general authentication errors
  Future<void> _handleAuthError(String error) async {
    debugPrint('Handling auth error: $error');
    
    // Try to sign out to clear any invalid cached credentials
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Error signing out during error handling: $e');
    }
    
    // Set appropriate error message based on error type
    if (error.contains('network')) {
      _errorMessage = 'Network error. Please check your internet connection.';
    } else if (error.contains('permission-denied')) {
      _errorMessage = 'Access denied. Please try signing in again.';
    } else if (error.contains('too-many-requests')) {
      _errorMessage = 'Too many failed attempts. Please try again later.';
    } else {
      _errorMessage = 'Authentication failed. Please sign in again.';
    }
    
    _status = AuthStatus.error;
    _userModel = null;
    _isLoading = false;
    
    notifyListeners();
  }

  final _firestore = FirebaseFirestore.instance;

  /// The current authentication status.
  AuthStatus get status => _status;

  /// The currently signed in user model, or null if unauthenticated.
  UserModel? get userModel => _userModel;

  /// The Firebase Auth user, or null if not signed in.
  firebase_auth.User? get firebaseUser =>
      firebase_auth.FirebaseAuth.instance.currentUser;

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
      
      if (user != null) {
        // Verify the user account is still valid
        try {
          await user.reload();
          final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
          if (currentUser == null) {
            throw Exception('User account no longer exists');
          }
        } catch (e) {
          debugPrint('User verification failed during sign-in: $e');
          if (e.toString().contains('user-not-found') || 
              e.toString().contains('user-disabled')) {
            _errorMessage = 'This account no longer exists or has been disabled.';
          } else {
            _errorMessage = 'Authentication failed. Please try again.';
          }
          _status = AuthStatus.error;
          return;
        }
        
        final userData = await _authService.getUserData(user.uid);
        final userModel = userData != null ? UserModel.fromFirestore(userData) : null;
        
        if (userModel != null) {
          _userModel = userModel;
          _status = AuthStatus.authenticated;
          // Start web in-app notifications if on web
          if (kIsWeb) {
            WebInAppNotificationService().startWebInAppNotifications();
          }
        } else {
          // User exists in Auth but not in Firestore
          _errorMessage = 'Account data not found. Please contact support.';
          _status = AuthStatus.error;
          // Sign out to clear invalid state
          await firebase_auth.FirebaseAuth.instance.signOut();
        }
      } else {
        throw Exception('Sign in failed');
      }
    } catch (e) {
      debugPrint('Sign-in error: $e');
      // Parse Firebase Auth errors to user-friendly messages
      if (e.toString().contains('user-not-found')) {
        _errorMessage = 'No account found with this email address.';
      } else if (e.toString().contains('wrong-password')) {
        _errorMessage = 'Incorrect password. Please try again.';
      } else if (e.toString().contains('invalid-email')) {
        _errorMessage = 'Invalid email address format.';
      } else if (e.toString().contains('user-disabled')) {
        _errorMessage = 'This account has been disabled. Please contact support.';
      } else if (e.toString().contains('too-many-requests')) {
        _errorMessage = 'Too many failed attempts. Please try again later.';
      } else if (e.toString().contains('network-request-failed')) {
        _errorMessage = 'Network error. Please check your internet connection.';
      } else {
        _errorMessage = 'Sign in failed. Please try again.';
      }
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
      
      if (user != null) {
        // Verify the user account is valid
        try {
          await user.reload();
          final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
          if (currentUser == null) {
            throw Exception('User account no longer exists');
          }
        } catch (e) {
          debugPrint('User verification failed during Google sign-in: $e');
          _errorMessage = 'Authentication failed. Please try again.';
          _status = AuthStatus.error;
          return;
        }
        
        final userData = await _authService.getUserData(user.uid);
        final userModel = userData != null ? UserModel.fromFirestore(userData) : null;
        
        if (userModel != null) {
          // Existing user - sign them in directly
          _userModel = userModel;
          _status = AuthStatus.authenticated;
        } else {
          // New user - need role selection
          _status = AuthStatus.authenticating;
        }
      } else {
        // Sign-in was cancelled
        _errorMessage = 'Google sign-in was cancelled';
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      if (e.toString().contains('cancelled')) {
        _errorMessage = 'Sign in was cancelled';
      } else if (e.toString().contains('network')) {
        _errorMessage = 'Network error. Please check your internet connection.';
      } else {
        _errorMessage = 'Google sign-in failed. Please try again.';
      }
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signs in the user with Apple.
  ///
  /// Required for App Store compliance (Guideline 4.8) when other social
  /// sign-in methods are offered. For new users, returns null and sets status
  /// to authenticating to trigger role selection. For existing users, signs
  /// them in directly with their stored profile.
  Future<void> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Call the real Apple Sign-In
      final user = await _authService.signInWithApple();
      UserModel? userModel;
      if (user != null) {
        final userData = await _authService.getUserData(user.uid);
        userModel = userData != null ? UserModel.fromFirestore(userData) : null;
      }

      if (userModel != null) {
        // Existing user - sign them in directly
        _userModel = userModel;
        _status = AuthStatus.authenticated;
        // Start web in-app notifications if on web
        if (kIsWeb) {
          WebInAppNotificationService().startWebInAppNotifications();
        }
      } else if (user != null) {
        // New user - need role selection
        _status = AuthStatus.authenticating;
      } else {
        // Sign-in was cancelled or failed
        _errorMessage = 'Sign in with Apple was cancelled';
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      debugPrint('Apple sign-in error: $e');
      if (e.toString().contains('not available')) {
        _errorMessage = 'Sign in with Apple is not available on this device';
      } else if (e.toString().contains('cancelled')) {
        _errorMessage = 'Sign in was cancelled';
      } else {
        _errorMessage = 'Sign in with Apple failed. Please try again.';
      }
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Completes the Google sign‑in by assigning a role and finishing
  /// profile setup.
  Future<void> completeGoogleSignUp(
      {required UserRole role, String? parentEmail, String? gradeLevel}) async {
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

  /// Completes OAuth sign-up (Google, Apple, etc.) by assigning a role and finishing
  /// profile setup. This is a generic method that works for all OAuth providers.
  Future<void> completeOAuthSignUp(
      {required UserRole role, String? parentEmail, String? gradeLevel}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Update the user's role regardless of OAuth provider
      final user = _authService.currentUser;
      UserModel? userModel;
      if (user != null) {
        // First update the role in Firestore
        await _authService.updateUserRole(user.uid, role.toString());
        
        // Small delay to ensure Firestore write completes
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Then fetch the updated user data
        final userData = await _authService.getUserData(user.uid);
        userModel = userData != null ? UserModel.fromFirestore(userData) : null;
        
        // Debug logging
        debugPrint('OAuth sign-up completion - User role: ${userModel?.role}, Status will be: authenticated');
      }

      if (userModel != null) {
        _userModel = userModel;
        _status = AuthStatus.authenticated;
        debugPrint('OAuth sign-up successful - Status set to: $_status');
        
        // Start web in-app notifications if on web
        if (kIsWeb) {
          WebInAppNotificationService().startWebInAppNotifications();
        }
      } else {
        throw Exception('Failed to complete OAuth sign-up - user data not found');
      }
    } catch (e) {
      debugPrint('OAuth sign-up error: $e');
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      // CRITICAL: Sign out the Firebase user to prevent infinite loop
      // If role assignment fails, we must clear the auth state completely
      await firebase_auth.FirebaseAuth.instance.signOut();
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
  Future<void> updateProfile(
      {String? displayName, String? firstName, String? lastName}) async {
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
      final currentUser =
          userData != null ? UserModel.fromFirestore(userData) : null;
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
        currentUser =
            userData != null ? UserModel.fromFirestore(userData) : null;
      }
      if (currentUser != null) {
        _userModel = currentUser;
        notifyListeners();
      }
    } catch (e) {
      // Silently fail - custom claims refresh is not critical
    }
  }

  /// Deletes the user account and all associated data.
  ///
  /// Required for privacy compliance (GDPR, App Store guidelines).
  /// For security, may require recent authentication.
  Future<void> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Stop web notifications if on web
      if (kIsWeb) {
        WebInAppNotificationService().stopWebInAppNotifications();
      }

      // Delete account via AuthService
      await _authService.deleteAccount();

      // Reset state after successful deletion
      _resetState();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Re-authenticates user with email and password.
  ///
  /// Required before sensitive operations like account deletion.
  Future<void> reauthenticateWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      _isLoading = false;
      setError('Email and password are required for re-authentication.');
      return;
    }

    try {
      await _authService.reauthenticateWithEmail(email, password);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Re-authenticates user with Google Sign In.
  ///
  /// Required before sensitive operations like account deletion for Google users.
  Future<void> reauthenticateWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.reauthenticateWithGoogle();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Re-authenticates user with Apple Sign In.
  ///
  /// Required before sensitive operations like account deletion for Apple users.
  Future<void> reauthenticateWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.reauthenticateWithApple();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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
