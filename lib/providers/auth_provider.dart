/// Authentication state management provider.
/// 
/// This module manages authentication state and user sessions for the
/// education platform. It provides a centralized authentication interface
/// that handles email/password and Google sign-in flows, role selection,
/// and profile management.
library;

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../core/service_locator.dart';

/// Enumeration of possible authentication states.
/// 
/// Tracks the current authentication status throughout
/// the application lifecycle:
/// - uninitialized: Initial state before auth check
/// - authenticated: User is fully authenticated with role
/// - authenticating: User authenticated but needs role selection
/// - unauthenticated: No authenticated user
/// - error: Authentication error occurred
enum AuthStatus {
  uninitialized,
  authenticated,
  authenticating,
  unauthenticated,
  error,
}

/// Provider managing authentication state and user operations.
/// 
/// This provider serves as the central authentication manager,
/// coordinating between Firebase Auth and Firestore user profiles.
/// Key features:
/// - Real-time auth state monitoring
/// - Email and Google authentication flows
/// - Two-step registration for role selection
/// - Profile management and updates
/// - Error handling and loading states
/// - Automatic session persistence
/// 
/// The provider distinguishes between Firebase Auth users and
/// complete user profiles with roles in Firestore.
class AuthProvider extends ChangeNotifier {
  /// Repository for authentication operations.
  late final AuthRepository _authRepository;
  
  /// Current authentication status.
  AuthStatus _status = AuthStatus.uninitialized;
  
  /// Complete user profile with role information.
  UserModel? _userModel;
  
  /// Latest error message for UI display.
  String? _errorMessage;
  
  /// Loading state for async operations.
  bool _isLoading = false;

  // Getters
  
  /// Current authentication status.
  AuthStatus get status => _status;
  
  /// Complete user profile or null if not authenticated.
  UserModel? get userModel => _userModel;
  
  /// Latest error message or null if no error.
  String? get errorMessage => _errorMessage;
  
  /// Whether an authentication operation is in progress.
  bool get isLoading => _isLoading;
  
  /// Whether user is fully authenticated with role.
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  
  /// Firebase Auth user instance.
  User? get firebaseUser => _authRepository.currentUser;

  /// Creates auth provider and initializes auth state monitoring.
  /// 
  /// Retrieves the auth repository from dependency injection
  /// and sets up real-time auth state listeners.
  AuthProvider() {
    _authRepository = getIt<AuthRepository>();
    _initializeAuth();
  }

  /// Sets up Firebase Auth state monitoring.
  /// 
  /// Listens to auth state changes and synchronizes with
  /// Firestore user profiles. Handles three scenarios:
  /// 1. No user - sets unauthenticated state
  /// 2. User with profile - sets authenticated state
  /// 3. User without profile - needs role selection
  /// 
  /// Falls back gracefully if Firebase is not initialized.
  void _initializeAuth() {
    try {
      _authRepository.authStateChanges.listen((User? user) async {
        if (user == null) {
          _status = AuthStatus.unauthenticated;
          _userModel = null;
        } else {
          // Try to get user model from Firestore
          final userModel = await _authRepository.getCurrentUserModel();
          if (userModel != null) {
            _userModel = userModel;
            _status = AuthStatus.authenticated;
          } else {
            // User exists in Auth but not in Firestore (Google sign-in needs role)
            _status = AuthStatus.authenticating;
          }
        }
        notifyListeners();
      });
    } catch (e) {
      // Firebase not initialized - set to unauthenticated for development
      if (kDebugMode) {
        print('Firebase Auth not available: $e');
      }
      _status = AuthStatus.unauthenticated;
      _userModel = null;
      notifyListeners();
    }
  }

  /// Creates Firebase Auth user without Firestore profile.
  /// 
  /// First step of two-step registration process. Creates
  /// authentication credentials but not the full user profile.
  /// User must select role after this step.
  /// 
  /// @param email User's email address
  /// @param password Secure password
  /// @param displayName Full display name
  /// @param firstName User's first name
  /// @param lastName User's last name
  /// @return true if auth user created successfully
  Future<bool> signUpWithEmailOnly({
    required String email,
    required String password,
    required String displayName,
    required String firstName,
    required String lastName,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = await _authRepository.signUpWithEmailOnly(
        email: email,
        password: password,
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
      );

      if (user != null) {
        // User needs to select role
        _status = AuthStatus.authenticating;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Creates complete user account with role.
  /// 
  /// Full registration process that creates both Firebase Auth
  /// user and Firestore profile with role information.
  /// 
  /// @param email User's email address
  /// @param password Secure password
  /// @param displayName Full display name
  /// @param role User role (teacher/student/parent/admin)
  /// @param parentEmail Parent's email (for student accounts)
  /// @param gradeLevel Student's grade level
  /// @return true if account created successfully
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? parentEmail,
    int? gradeLevel,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final userModel = await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        parentEmail: parentEmail,
        gradeLevel: gradeLevel,
      );

      if (userModel != null) {
        _userModel = userModel;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Authenticates user with email and password.
  /// 
  /// Verifies credentials and loads complete user profile
  /// from Firestore. Sets authenticated state on success.
  /// 
  /// @param email User's email address
  /// @param password Account password
  /// @return true if sign in successful
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final userModel = await _authRepository.signInWithEmail(
        email: email,
        password: password,
      );

      if (userModel != null) {
        _userModel = userModel;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Authenticates user with Google OAuth.
  /// 
  /// Handles two scenarios:
  /// 1. Existing user - loads profile and authenticates
  /// 2. New user - sets authenticating state for role selection
  /// 
  /// @return true if Google sign in successful
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _clearError();

      final userModel = await _authRepository.signInWithGoogle();

      if (userModel != null) {
        _userModel = userModel;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else if (firebaseUser != null) {
        // User needs to select role
        _status = AuthStatus.authenticating;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Completes Google sign-up by creating user profile.
  /// 
  /// Second step for new Google users. Creates Firestore
  /// profile with selected role and additional information.
  /// 
  /// @param role Selected user role
  /// @param parentEmail Parent's email (for students)
  /// @param gradeLevel Student's grade level
  /// @return true if profile created successfully
  Future<bool> completeGoogleSignUp({
    required UserRole role,
    String? parentEmail,
    int? gradeLevel,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final userModel = await _authRepository.completeGoogleSignUp(
        role: role,
        parentEmail: parentEmail,
        gradeLevel: gradeLevel,
      );

      if (userModel != null) {
        _userModel = userModel;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Signs out the current user.
  /// 
  /// Clears authentication state and user profile.
  /// Triggers navigation to login screen through
  /// state change notifications.
  /// 
  /// @throws Exception if sign out fails
  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _authRepository.signOut();
      _userModel = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Sends password reset email to user.
  /// 
  /// Initiates Firebase Auth password reset flow.
  /// User receives email with reset link.
  /// 
  /// @param email Account email address
  /// @return true if reset email sent successfully
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _clearError();
      await _authRepository.resetPassword(email);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Updates user profile information.
  /// 
  /// Modifies both Firebase Auth profile and Firestore
  /// user document. Refreshes cached user model after update.
  /// 
  /// @param displayName New display name
  /// @param firstName New first name
  /// @param lastName New last name
  /// @param photoURL New profile photo URL
  /// @param updatePhoto Whether to update photo
  /// @return true if profile updated successfully
  Future<bool> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? photoURL,
    bool updatePhoto = false,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await _authRepository.updateProfile(
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        photoURL: photoURL,
        updatePhoto: updatePhoto,
      );

      // Refresh user model
      _userModel = await _authRepository.getCurrentUserModel();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Updates user role after initial authentication.
  /// 
  /// Convenience method for role selection screen.
  /// Creates Firestore profile for authenticated users
  /// who don't have one yet (Google sign-in flow).
  /// 
  /// @param role Selected user role
  /// @return true if role updated successfully
  Future<bool> updateUserRole(UserRole role) async {
    try {
      _setLoading(true);
      _clearError();

      final userModel = await _authRepository.completeGoogleSignUp(
        role: role,
      );

      if (userModel != null) {
        _userModel = userModel;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sets loading state and notifies listeners.
  /// 
  /// @param value New loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Sets error state with message.
  /// 
  /// Updates status to error and stores message
  /// for UI display.
  /// 
  /// @param message Error description
  void _setError(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }

  /// Clears error message internally.
  /// 
  /// Does not notify listeners.
  void _clearError() {
    _errorMessage = null;
  }

  /// Clears error message and notifies UI.
  /// 
  /// Public method for UI to dismiss error messages
  /// after user acknowledgment.
  void clearError() {
    _clearError();
    notifyListeners();
  }
}