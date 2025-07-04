import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../core/service_locator.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  authenticating,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  late final AuthRepository _authRepository;
  
  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _userModel;
  String? _errorMessage;
  bool _isLoading = false;

  // Getters
  AuthStatus get status => _status;
  UserModel? get userModel => _userModel;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  User? get firebaseUser => _authRepository.currentUser;

  // Constructor
  AuthProvider() {
    _authRepository = getIt<AuthRepository>();
    _initializeAuth();
  }

  // Initialize auth state listener
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

  // Sign up with email only (creates Auth user, redirects to role selection)
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

  // Sign up with email (creates complete user profile)
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

  // Sign in with email
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

  // Sign in with Google
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

  // Complete Google sign up with role
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

  // Sign out
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

  // Reset password
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

  // Update profile
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

  // Update user role (for role selection after Google sign-in)
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

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Public method to clear error (useful for UI)
  void clearError() {
    _clearError();
    notifyListeners();
  }
}