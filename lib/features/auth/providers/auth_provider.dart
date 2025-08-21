import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../shared/models/user_model.dart';
import '../data/services/auth_service.dart';
import '../../notifications/data/services/web_in_app_notification_service.dart';

/// Authentication states for the application.
enum AuthStatus {
  /// Initial state - checking authentication status
  uninitialized,
  
  /// User is authenticated with complete profile
  authenticated,
  
  /// Authentication in progress (login, signup, role selection)
  authenticating,
  
  /// User is not authenticated
  unauthenticated,
  
  /// Authentication error occurred
  error,
}

// Type alias for Firebase Auth User
typedef User = firebase_auth.User;

/// Robust authentication provider with proper state management.
/// 
/// Key principles:
/// 1. NEVER set authenticated status without valid userModel
/// 2. Handle Firestore eventual consistency with retries
/// 3. Clear separation between Firebase Auth and app auth state
/// 4. Atomic state transitions with proper error handling
class AuthProvider extends ChangeNotifier {
  // Dependencies
  final AuthService _authService;
  
  // State management
  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _userModel;
  String? _errorMessage;
  bool _isLoading = false;
  bool _rememberMe = false;
  
  // Retry configuration for Firestore reads
  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(milliseconds: 500);
  static const Duration _maxRetryDelay = Duration(seconds: 3);
  
  // Prevent concurrent auth operations
  bool _authOperationInProgress = false;
  
  AuthProvider({
    AuthService? authService,
    AuthStatus? initialStatus,
    UserModel? initialUserModel,
  }) : _authService = authService ?? AuthService(),
        _status = initialStatus ?? AuthStatus.uninitialized,
        _userModel = initialUserModel {
    _initializeAuthState();
  }
  
  // ============= Getters =============
  
  AuthStatus get status => _status;
  UserModel? get userModel => _userModel;
  firebase_auth.User? get firebaseUser => firebase_auth.FirebaseAuth.instance.currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _userModel != null;
  bool get rememberMe => _rememberMe;
  
  // ============= Initialization =============
  
  /// Initialize authentication state on app startup
  Future<void> _initializeAuthState() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        _setAuthState(AuthStatus.unauthenticated);
        return;
      }
      
      // Set authenticating while we load user data
      _setAuthState(AuthStatus.authenticating);
      
      // Verify user is still valid
      try {
        await user.reload();
      } catch (e) {
        debugPrint('User reload failed: $e');
        await _handleInvalidUser('User account is no longer valid');
        return;
      }
      
      // Check if user still exists after reload
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        await _handleInvalidUser('User session expired');
        return;
      }
      
      // Load user model from Firestore with retry logic
      final loadedUserModel = await _loadUserModelWithRetry(user.uid);
      
      if (loadedUserModel != null && loadedUserModel.role != null) {
        // SUCCESS: We have both Firebase Auth user AND complete user model
        _userModel = loadedUserModel;
        _setAuthState(AuthStatus.authenticated);
        _startNotificationsIfNeeded();
      } else {
        // User exists in Auth but incomplete profile in Firestore
        // Could be mid-registration or data corruption
        debugPrint('Incomplete user profile for uid: ${user.uid}');
        _setAuthState(AuthStatus.authenticating);
      }
      
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      _handleAuthError(e.toString());
    }
  }
  
  // ============= Core Authentication Methods =============
  
  /// Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
    if (_authOperationInProgress) {
      debugPrint('Auth operation already in progress');
      return;
    }
    
    _authOperationInProgress = true;
    _startLoading();
    
    try {
      // Validate input
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }
      
      // Authenticate with Firebase
      final user = await _authService.signIn(
        email: email,
        password: password,
      );
      
      if (user == null) {
        throw Exception('Authentication failed');
      }
      
      // Load user model from Firestore
      final loadedUserModel = await _loadUserModelWithRetry(user.uid);
      
      if (loadedUserModel == null || loadedUserModel.role == null) {
        // Critical: User authenticated but no valid profile
        await _authService.signOut();
        throw Exception('User profile not found. Please contact support.');
      }
      
      // SUCCESS: Update state atomically
      _userModel = loadedUserModel;
      _setAuthState(AuthStatus.authenticated);
      _startNotificationsIfNeeded();
      
    } catch (e) {
      debugPrint('Email sign-in error: $e');
      _handleSignInError(e);
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }
  
  /// Sign in with Google OAuth
  Future<void> signInWithGoogle() async {
    if (_authOperationInProgress) {
      debugPrint('Auth operation already in progress');
      return;
    }
    
    _authOperationInProgress = true;
    _startLoading();
    
    try {
      final user = await _authService.signInWithGoogle();
      
      if (user == null) {
        // User cancelled sign-in
        _setAuthState(AuthStatus.unauthenticated);
        return;
      }
      
      // Check if user has complete profile
      final userData = await _getUserDataWithRetry(user.uid);
      
      if (userData != null && userData['role'] != null) {
        // Existing user with role - complete sign in
        final loadedUserModel = UserModel.fromFirestore(userData);
        _userModel = loadedUserModel;
        _setAuthState(AuthStatus.authenticated);
        _startNotificationsIfNeeded();
      } else {
        // New user - needs role selection
        // Keep status as authenticating to trigger role selection flow
        _setAuthState(AuthStatus.authenticating);
      }
      
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      _handleOAuthError(e, 'Google');
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }
  
  /// Signs in the user using Apple OAuth.
  ///
  /// **Flow for new vs existing users:**
  /// - If the user is signing in for the first time (i.e., no profile or role exists),
  ///   the authentication state is set to [AuthStatus.authenticating] to trigger the
  ///   role selection and profile completion flow.
  /// - If the user already exists and has a complete profile (including a role),
  ///   the user is signed in directly and the authentication state is set to [AuthStatus.authenticated].
  ///
  /// If the user cancels the sign-in process, the authentication state is set to [AuthStatus.unauthenticated].
  /// Any errors during the sign-in process are handled and the appropriate error state is set.
  Future<void> signInWithApple() async {
    if (_authOperationInProgress) {
      debugPrint('Auth operation already in progress');
      return;
    }
    
    _authOperationInProgress = true;
    _startLoading();
    
    try {
      final user = await _authService.signInWithApple();
      
      if (user == null) {
        // User cancelled sign-in
        _setAuthState(AuthStatus.unauthenticated);
        return;
      }
      
      // Check if user has complete profile
      final userData = await _getUserDataWithRetry(user.uid);
      
      if (userData != null && userData['role'] != null) {
        // Existing user with role - complete sign in
        final loadedUserModel = UserModel.fromFirestore(userData);
        _userModel = loadedUserModel;
        _setAuthState(AuthStatus.authenticated);
        _startNotificationsIfNeeded();
      } else {
        // New user - needs role selection
        _setAuthState(AuthStatus.authenticating);
      }
      
    } catch (e) {
      debugPrint('Apple sign-in error: $e');
      _handleOAuthError(e, 'Apple');
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }
  
  /// Complete OAuth sign-up by setting role
  Future<void> completeOAuthSignUp({
    required UserRole role,
    String? parentEmail,
    String? gradeLevel,
  }) async {
    if (_authOperationInProgress) {
      debugPrint('Auth operation already in progress');
      return;
    }
    
    _authOperationInProgress = true;
    _startLoading();
    
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }
      
      // Update role in Firestore
      await _authService.updateUserRole(user.uid, role.toString());
      
      // Wait for Firestore to propagate the change
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Load updated user model with aggressive retry
      UserModel? loadedUserModel;
      for (int attempt = 0; attempt < 10; attempt++) {
        if (attempt > 0) {
          await Future.delayed(_baseRetryDelay * attempt);
        }
        
        loadedUserModel = await _loadUserModelWithRetry(user.uid);
        if (loadedUserModel != null && loadedUserModel.role != null) {
          debugPrint('OAuth completion successful on attempt ${attempt + 1}');
          break;
        }
      }
      
      if (loadedUserModel == null || loadedUserModel.role == null) {
        // Critical failure - role not saved properly
        await _authService.signOut();
        throw Exception('Failed to save user role. Please try again.');
      }
      
      // SUCCESS: Update state atomically
      _userModel = loadedUserModel;
      _setAuthState(AuthStatus.authenticated);
      _startNotificationsIfNeeded();
      
      // Extra delay to ensure state propagates to UI
      await Future.delayed(const Duration(milliseconds: 100));
      
    } catch (e) {
      debugPrint('OAuth completion error: $e');
      // Sign out to prevent stuck state
      await _authService.signOut();
      _handleAuthError(e.toString());
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }
  
  /// Complete Google sign-up (backward compatibility)
  Future<void> completeGoogleSignUp({
    required UserRole role,
    String? parentEmail,
    String? gradeLevel,
  }) async {
    return completeOAuthSignUp(
      role: role,
      parentEmail: parentEmail,
      gradeLevel: gradeLevel,
    );
  }
  
  /// Sign up with email only (role selection happens after)
  Future<void> signUpWithEmailOnly(String email, String password) async {
    if (_authOperationInProgress) {
      debugPrint('Auth operation already in progress');
      return;
    }
    
    _authOperationInProgress = true;
    _startLoading();
    
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }
      
      final user = await _authService.signUp(
        email: email,
        password: password,
        displayName: email.split('@')[0],
      );
      
      if (user == null) {
        throw Exception('Sign up failed');
      }
      
      // Set authenticating status to trigger role selection
      _setAuthState(AuthStatus.authenticating);
      
    } catch (e) {
      debugPrint('Email sign-up error: $e');
      _handleSignUpError(e);
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }
  
  /// Sign out the current user
  Future<void> signOut() async {
    if (_authOperationInProgress) {
      debugPrint('Auth operation already in progress');
      return;
    }
    
    _authOperationInProgress = true;
    _startLoading();
    
    try {
      _stopNotificationsIfNeeded();
      await _authService.signOut();
      _resetState();
    } catch (e) {
      debugPrint('Sign out error: $e');
      _setError('Failed to sign out. Please try again.');
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }
  
  // ============= Helper Methods =============
  
  /// Load user model from Firestore with retry logic
  Future<UserModel?> _loadUserModelWithRetry(String uid) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay = _calculateRetryDelay(attempt);
          debugPrint('Retry $attempt: Waiting ${delay.inMilliseconds}ms');
          await Future.delayed(delay);
        }
        
        final userData = await _getUserDataWithTimeout(uid);
        if (userData != null) {
          try {
            final userModel = UserModel.fromFirestore(userData);
            if (userModel.uid.isNotEmpty) {
              debugPrint('Successfully loaded user model on attempt ${attempt + 1}');
              return userModel;
            }
          } catch (e) {
            debugPrint('Error parsing user model: $e');
          }
        }
      } catch (e) {
        debugPrint('Attempt ${attempt + 1} failed: $e');
      }
    }
    
    debugPrint('Failed to load user model after $_maxRetries attempts');
    return null;
  }
  
  /// Get user data from Firestore with timeout
  Future<Map<String, dynamic>?> _getUserDataWithTimeout(String uid) async {
    try {
      return await _authService.getUserData(uid)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Timeout getting user data: $e');
      return null;
    }
  }
  
  /// Get user data with retry (lower level than model loading)
  Future<Map<String, dynamic>?> _getUserDataWithRetry(String uid) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(_baseRetryDelay * attempt);
      }
      
      final data = await _getUserDataWithTimeout(uid);
      if (data != null) {
        return data;
      }
    }
    return null;
  }
  
  /// Calculate retry delay with exponential backoff
  Duration _calculateRetryDelay(int attempt) {
    final delay = _baseRetryDelay * (1 << attempt); // Exponential backoff
    return delay > _maxRetryDelay ? _maxRetryDelay : delay;
  }
  
  /// Update authentication state atomically
  void _setAuthState(AuthStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }
  
  /// Set error message
  void _setError(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }
  
  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Start loading state
  void _startLoading() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Stop loading state
  void _stopLoading() {
    _isLoading = false;
    notifyListeners();
  }
  
  /// Handle invalid user (deleted, expired, etc.)
  Future<void> _handleInvalidUser(String reason) async {
    debugPrint('Invalid user: $reason');
    try {
      await _authService.signOut();
    } catch (_) {}
    _resetState();
    _setError(reason);
  }
  
  /// Handle authentication errors
  void _handleAuthError(String error) {
    _status = AuthStatus.error;
    _userModel = null;
    
    if (error.contains('network')) {
      _errorMessage = 'Network error. Please check your connection.';
    } else if (error.contains('permission-denied')) {
      _errorMessage = 'Access denied. Please try again.';
    } else if (error.contains('too-many-requests')) {
      _errorMessage = 'Too many attempts. Please try again later.';
    } else {
      _errorMessage = 'Authentication failed. Please try again.';
    }
    
    notifyListeners();
  }
  
  /// Handle sign-in specific errors
  void _handleSignInError(dynamic error) {
    final errorStr = error.toString();
    
    if (errorStr.contains('user-not-found')) {
      _setError('No account found with this email.');
    } else if (errorStr.contains('wrong-password')) {
      _setError('Incorrect password.');
    } else if (errorStr.contains('invalid-email')) {
      _setError('Invalid email address.');
    } else if (errorStr.contains('user-disabled')) {
      _setError('This account has been disabled.');
    } else if (errorStr.contains('network')) {
      _setError('Network error. Please check your connection.');
    } else {
      _setError('Sign in failed. Please try again.');
    }
    
    _status = AuthStatus.unauthenticated;
  }
  
  /// Handle sign-up specific errors
  void _handleSignUpError(dynamic error) {
    final errorStr = error.toString();
    
    if (errorStr.contains('email-already-in-use')) {
      _setError('An account already exists with this email.');
    } else if (errorStr.contains('weak-password')) {
      _setError('Password is too weak.');
    } else if (errorStr.contains('invalid-email')) {
      _setError('Invalid email address.');
    } else {
      _setError('Sign up failed. Please try again.');
    }
    
    _status = AuthStatus.unauthenticated;
  }
  
  /// Handle OAuth specific errors
  void _handleOAuthError(dynamic error, String provider) {
    final errorStr = error.toString();
    
    if (errorStr.contains('cancelled')) {
      _setError('$provider sign-in was cancelled.');
    } else if (errorStr.contains('not available')) {
      _setError('$provider sign-in is not available on this device.');
    } else if (errorStr.contains('network')) {
      _setError('Network error. Please check your connection.');
    } else {
      _setError('$provider sign-in failed. Please try again.');
    }
    
    _status = AuthStatus.unauthenticated;
  }
  
  /// Reset all state
  void _resetState() {
    _status = AuthStatus.unauthenticated;
    _userModel = null;
    _errorMessage = null;
    _isLoading = false;
    _rememberMe = false;
    notifyListeners();
  }
  
  /// Start notifications if on web
  void _startNotificationsIfNeeded() {
    if (kIsWeb) {
      try {
        WebInAppNotificationService().startWebInAppNotifications();
      } catch (e) {
        debugPrint('Failed to start notifications: $e');
      }
    }
  }
  
  /// Stop notifications if on web
  void _stopNotificationsIfNeeded() {
    if (kIsWeb) {
      try {
        WebInAppNotificationService().stopWebInAppNotifications();
      } catch (e) {
        debugPrint('Failed to stop notifications: $e');
      }
    }
  }
  
  // ============= Profile Management =============
  
  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
  }) async {
    if (_userModel == null) return;
    
    _startLoading();
    
    try {
      final user = _authService.currentUser;
      if (user != null && displayName != null) {
        await user.updateDisplayName(displayName);
      }
      
      _userModel = _userModel!.copyWith(
        displayName: displayName ?? _userModel!.displayName,
        firstName: firstName ?? _userModel!.firstName,
        lastName: lastName ?? _userModel!.lastName,
      );
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to update profile');
    } finally {
      _stopLoading();
    }
  }
  
  /// Update profile picture
  Future<void> updateProfilePicture(String photoURL) async {
    if (_userModel == null) return;
    
    _startLoading();
    
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePhotoURL(photoURL);
      }
      
      _userModel = _userModel!.copyWith(photoURL: photoURL);
      notifyListeners();
    } catch (e) {
      _setError('Failed to update profile picture');
    } finally {
      _stopLoading();
    }
  }
  
  // ============= Email Verification =============
  
  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } catch (e) {
      _setError('Failed to send verification email');
    }
  }
  
  /// Reload user to check email verification
  Future<void> reloadUser() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        
        // Reload user model from Firestore
        final loadedUserModel = await _loadUserModelWithRetry(user.uid);
        if (loadedUserModel != null) {
          _userModel = loadedUserModel;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to reload user: $e');
    }
  }
  
  /// Refresh custom claims
  Future<void> refreshCustomClaims() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final loadedUserModel = await _loadUserModelWithRetry(user.uid);
        if (loadedUserModel != null) {
          _userModel = loadedUserModel;
          notifyListeners();
        }
      }
    } catch (e) {
      // Silently fail - not critical
      debugPrint('Failed to refresh custom claims: $e');
    }
  }
  
  // ============= Account Management =============
  
  /// Delete user account
  Future<void> deleteAccount() async {
    _startLoading();
    
    try {
      _stopNotificationsIfNeeded();
      await _authService.deleteAccount();
      _resetState();
    } catch (e) {
      _handleAuthError(e.toString());
    } finally {
      _stopLoading();
    }
  }
  
  /// Re-authenticate with email
  Future<void> reauthenticateWithEmail(String email, String password) async {
    _startLoading();
    
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }
      
      await _authService.reauthenticateWithEmail(email, password);
    } catch (e) {
      _setError('Re-authentication failed');
    } finally {
      _stopLoading();
    }
  }
  
  /// Re-authenticate with Google
  Future<void> reauthenticateWithGoogle() async {
    _startLoading();
    
    try {
      await _authService.reauthenticateWithGoogle();
    } catch (e) {
      _setError('Google re-authentication failed');
    } finally {
      _stopLoading();
    }
  }
  
  /// Re-authenticate with Apple
  Future<void> reauthenticateWithApple() async {
    _startLoading();
    
    try {
      await _authService.reauthenticateWithApple();
    } catch (e) {
      _setError('Apple re-authentication failed');
    } finally {
      _stopLoading();
    }
  }
  
  // ============= Utility Methods =============
  
  /// Set remember me preference
  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }
  
  /// Set error message (public for UI use)
  void setError(String message) {
    _setError(message);
  }
  
  @override
  void dispose() {
    _stopNotificationsIfNeeded();
    _authOperationInProgress = false;
    _resetState();
    super.dispose();
  }
}