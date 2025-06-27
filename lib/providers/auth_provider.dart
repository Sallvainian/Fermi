import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  authenticating,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
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
  User? get firebaseUser => _authService.currentUser;

  // Constructor
  AuthProvider() {
    _initializeAuth();
  }

  // Initialize auth state listener
  void _initializeAuth() {
    _authService.authStateChanges.listen((User? user) async {
      if (user == null) {
        _status = AuthStatus.unauthenticated;
        _userModel = null;
      } else {
        // Try to get user model from Firestore
        final userModel = await _authService.getCurrentUserModel();
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
  }

  // Sign up with email
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

      final userModel = await _authService.signUpWithEmail(
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

      final userModel = await _authService.signInWithEmail(
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

      final userModel = await _authService.signInWithGoogle();

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

      final userModel = await _authService.completeGoogleSignUp(
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
      await _authService.signOut();
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
      await _authService.resetPassword(email);
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
    String? photoURL,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      // Refresh user model
      _userModel = await _authService.getCurrentUserModel();
      notifyListeners();
      return true;
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
}