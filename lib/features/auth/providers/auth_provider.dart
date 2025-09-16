import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/services/logger_service.dart';

import '../../../shared/models/user_model.dart';
import '../data/services/auth_service.dart';
import '../../notifications/data/services/web_in_app_notification_service.dart';
import '../../student/data/services/presence_service.dart';

/// Simplified authentication states for the application.
enum AuthStatus {
  /// Initial state - checking authentication status
  uninitialized,

  /// User is authenticated with complete profile
  authenticated,

  /// Authentication in progress
  authenticating,

  /// User is not authenticated
  unauthenticated,

  /// Authentication error occurred
  error,
}

// Type alias for Firebase Auth User
typedef User = firebase_auth.User;

/// Simplified authentication provider with domain-based role assignment.
///
/// Key simplifications:
/// 1. No role selection - roles are assigned automatically based on email domain
/// 2. No separate role verification - handled by cloud functions
/// 3. Streamlined sign-in flow
class AuthProvider extends ChangeNotifier {
  // Dependencies
  final AuthService _authService;
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PresenceService _presenceService = PresenceService();

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
    // Initialize auth state
    _initializeAuthState();
  }

  // ============= Getters =============

  AuthStatus get status => _status;
  UserModel? get userModel => _userModel;
  firebase_auth.User? get firebaseUser => _firebaseAuth.currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _userModel != null;
  bool get rememberMe => _rememberMe;

  // ============= Initialization =============

  /// Initialize authentication state on app startup
  Future<void> _initializeAuthState() async {
    try {
      // Check for redirect result first (for web OAuth redirects)
      if (kIsWeb) {
        try {
          LoggerService.info('Checking for OAuth redirect result...', tag: 'AuthProvider');
          final redirectResult = await _firebaseAuth.getRedirectResult();
          if (redirectResult.user != null) {
            LoggerService.info('Found redirect result for ${redirectResult.user!.email}', tag: 'AuthProvider');
            // Process the redirect sign-in
            await _processUser(redirectResult.user!);
            return;
          }
        } catch (e) {
          // This is normal if there's no redirect result
          LoggerService.debug('No redirect result available: $e', tag: 'AuthProvider');
        }
      }

      final user = _firebaseAuth.currentUser;

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
        LoggerService.warning('User reload failed', tag: 'AuthProvider');
        await _handleInvalidUser('User account is no longer valid');
        return;
      }

      // Check if user still exists after reload
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        await _handleInvalidUser('User session expired');
        return;
      }

      // Load user model from Firestore
      await _processUser(currentUser);
    } catch (e) {
      LoggerService.error('Auth initialization error', tag: 'AuthProvider', error: e);
      _handleAuthError(e.toString());
    }
  }

  /// Process user after authentication
  Future<void> _processUser(firebase_auth.User user) async {
    try {
      // Load user model from Firestore with retry logic
      var loadedUserModel = await _loadUserModelWithRetry(user.uid);

      // If user document doesn't exist and it's an admin account, create it
      // This handles manually created admin accounts in Firebase Auth
      if (loadedUserModel == null && user.email != null) {
        final email = user.email!.toLowerCase();
        
        // ONLY auto-create for @fermi-plus.com admin accounts
        if (email.endsWith('@fermi-plus.com')) {
          LoggerService.info('Creating Firestore document for manually created admin: ${user.email}', tag: 'AuthProvider');
          
          // Create the admin user document
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? user.email?.split('@').first ?? 'Admin',
            'role': 'admin',
            'createdAt': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
            'isEmailUser': true,
            'profileComplete': false,
          });
          
          // Try loading again
          loadedUserModel = await _loadUserModelWithRetry(user.uid);
        }
      }

      if (loadedUserModel != null && loadedUserModel.role != null) {
        // SUCCESS: We have both Firebase Auth user AND complete user model
        _userModel = loadedUserModel;
        _setAuthState(AuthStatus.authenticated);
        _startNotificationsIfNeeded();
        _updatePresenceOnline();
      } else {
        // User profile not found or incomplete
        LoggerService.error('User profile not found for uid: ${user.uid}', tag: 'AuthProvider');
        await _authService.signOut();
        _handleAuthError('User profile not found. Please contact support.');
      }
    } catch (e) {
      LoggerService.error('Error processing user', tag: 'AuthProvider', error: e);
      _handleAuthError('Failed to load user profile. Please try again.');
    }
  }

  // ============= Core Authentication Methods =============

  /// Universal sign in with email and password
  /// No role checking needed - role is determined by email domain
  Future<void> signIn(String email, String password) async {
    if (_authOperationInProgress) {
      LoggerService.warning('Auth operation already in progress', tag: 'AuthProvider');
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
      final user = await _authService.signIn(email: email, password: password);

      if (user == null) {
        throw Exception('Authentication failed');
      }

      // Process the authenticated user
      await _processUser(user);
    } catch (e) {
      LoggerService.error('Sign-in error', tag: 'AuthProvider', error: e);
      _handleSignInError(e);
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }

  /// Universal sign up with email and password
  /// Role is automatically assigned based on email domain
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (_authOperationInProgress) {
      LoggerService.warning('Auth operation already in progress', tag: 'AuthProvider');
      return;
    }

    _authOperationInProgress = true;
    _startLoading();

    try {
      // Validate input
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }

      // Create user with Firebase Auth
      // The blocking function will automatically assign role based on email domain
      final user = await _authService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (user == null) {
        throw Exception('Account creation failed');
      }

      // Process the newly created user
      await _processUser(user);
    } catch (e) {
      LoggerService.error('Sign-up error', tag: 'AuthProvider', error: e);
      _handleSignUpError(e);
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }

  /// Sign in with Google OAuth
  /// Role is automatically assigned based on email domain
  Future<void> signInWithGoogle() async {
    if (_authOperationInProgress) {
      LoggerService.warning('Auth operation already in progress', tag: 'AuthProvider');
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

      // Process the authenticated user
      await _processUser(user);
    } catch (e) {
      LoggerService.error('Google sign-in error', tag: 'AuthProvider', error: e);
      _handleOAuthError(e, 'Google');
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }

  /// Sign in with Apple OAuth
  /// Role is automatically assigned based on email domain
  Future<void> signInWithApple() async {
    if (_authOperationInProgress) {
      LoggerService.warning('Auth operation already in progress', tag: 'AuthProvider');
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

      // Process the authenticated user
      await _processUser(user);
    } catch (e) {
      LoggerService.error('Apple sign-in error', tag: 'AuthProvider', error: e);
      _handleOAuthError(e, 'Apple');
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    _startLoading();
    try {
      await _authService.sendPasswordResetEmail(email);
      _errorMessage = null;
    } catch (e) {
      LoggerService.error('Password reset error', tag: 'AuthProvider', error: e);
      _handleAuthError(e.toString());
    } finally {
      _stopLoading();
    }
  }

  /// Resend email verification
  Future<void> resendEmailVerification() async {
    _startLoading();
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        _errorMessage = null;
      } else {
        throw Exception('No user signed in');
      }
    } catch (e) {
      LoggerService.error('Email verification error', tag: 'AuthProvider', error: e);
      _handleAuthError(e.toString());
    } finally {
      _stopLoading();
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      LoggerService.info('Signing out user', tag: 'AuthProvider');

      // Update presence to offline
      _updatePresenceOffline();

      // Clear user model first
      _userModel = null;

      // Sign out from Firebase
      await _authService.signOut();

      // Clear any stored preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selectedRole');

      // Set state to unauthenticated
      _setAuthState(AuthStatus.unauthenticated);
      _errorMessage = null;
    } catch (e) {
      LoggerService.error('Sign-out error', tag: 'AuthProvider', error: e);
      // Even if sign-out fails, clear local state
      _userModel = null;
      _setAuthState(AuthStatus.unauthenticated);
    }
  }

  // ============= Helper Methods =============

  /// Load user model with retry logic for Firestore eventual consistency
  Future<UserModel?> _loadUserModelWithRetry(String uid) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      if (attempt > 0) {
        final delay = _calculateRetryDelay(attempt);
        LoggerService.info('Retry attempt $attempt after ${delay.inMilliseconds}ms', tag: 'AuthProvider');
        await Future.delayed(delay);
      }

      try {
        final userData = await _getUserDataWithRetry(uid);
        if (userData != null) {
          final userModel = UserModel.fromFirestore(userData);
          if (userModel.role != null) {
            LoggerService.info('Successfully loaded user model on attempt ${attempt + 1}', tag: 'AuthProvider');
            return userModel;
          }
        }
      } catch (e) {
        LoggerService.warning('Attempt ${attempt + 1} failed: $e', tag: 'AuthProvider');
        if (attempt == _maxRetries - 1) rethrow;
      }
    }
    return null;
  }

  /// Get user data from Firestore with single retry
  Future<Map<String, dynamic>?> _getUserDataWithRetry(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return {'uid': doc.id, ...doc.data()!};
      }
    } catch (e) {
      LoggerService.warning('First attempt to get user data failed, retrying...', tag: 'AuthProvider');
      await Future.delayed(const Duration(milliseconds: 500));
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return {'uid': doc.id, ...doc.data()!};
      }
    }
    return null;
  }

  /// Calculate exponential backoff delay for retries
  Duration _calculateRetryDelay(int attempt) {
    final exponentialDelay = _baseRetryDelay * (1 << attempt);
    return exponentialDelay > _maxRetryDelay ? _maxRetryDelay : exponentialDelay;
  }

  /// Handle invalid user scenario
  Future<void> _handleInvalidUser(String message) async {
    await _authService.signOut();
    _userModel = null;
    _setAuthState(AuthStatus.unauthenticated);
    _errorMessage = message;
    notifyListeners();
  }

  /// Update authentication state
  void _setAuthState(AuthStatus newStatus) {
    if (_status != newStatus) {
      LoggerService.info('Auth state change: $_status -> $newStatus', tag: 'AuthProvider');
      _status = newStatus;
      notifyListeners();
    }
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

  /// Handle authentication errors
  void _handleAuthError(String error) {
    _errorMessage = error;
    _setAuthState(AuthStatus.error);
    notifyListeners();
  }

  /// Handle sign-in specific errors
  void _handleSignInError(dynamic error) {
    String errorMessage;
    final errorString = error.toString();
    
    if (errorString.contains('user-not-found')) {
      errorMessage = 'No user found with this email';
    } else if (errorString.contains('wrong-password')) {
      errorMessage = 'Incorrect password';
    } else if (errorString.contains('invalid-credential')) {
      errorMessage = 'Invalid email or password. Please check your credentials and try again';
    } else if (errorString.contains('invalid-email')) {
      errorMessage = 'Invalid email address';
    } else if (errorString.contains('user-disabled')) {
      errorMessage = 'This account has been disabled';
    } else if (errorString.contains('too-many-requests')) {
      errorMessage = 'Too many failed attempts. Please try again later';
    } else if (errorString.contains('permission-denied')) {
      errorMessage = errorString.replaceAll('Exception: ', '');
    } else {
      errorMessage = 'Sign in failed. Please try again';
    }
    
    _handleAuthError(errorMessage);
  }

  /// Handle sign-up specific errors
  void _handleSignUpError(dynamic error) {
    String errorMessage;
    final errorString = error.toString();
    
    if (errorString.contains('email-already-in-use')) {
      errorMessage = 'An account already exists with this email';
    } else if (errorString.contains('weak-password')) {
      errorMessage = 'Password is too weak';
    } else if (errorString.contains('invalid-email')) {
      errorMessage = 'Invalid email address';
    } else if (errorString.contains('permission-denied')) {
      errorMessage = errorString.replaceAll('Exception: ', '');
    } else {
      errorMessage = 'Sign up failed. Please try again';
    }
    
    _handleAuthError(errorMessage);
  }

  /// Handle OAuth specific errors
  void _handleOAuthError(dynamic error, String provider) {
    // Log the full error for debugging
    LoggerService.error('OAuth Error Details', tag: 'AuthProvider', error: error);
    LoggerService.debug('Error type: ${error.runtimeType}', tag: 'AuthProvider');
    LoggerService.debug('Error string: ${error.toString()}', tag: 'AuthProvider');
    
    String baseMessage;
    final errorString = error.toString().toLowerCase();
    
    // Check for various permission-denied formats
    if (errorString.contains('permission-denied') || 
        errorString.contains('permission_denied') ||
        errorString.contains('authorized school') ||
        errorString.contains('@roselleschools.org') ||
        errorString.contains('@rosellestudent.org') ||
        errorString.contains('@fermi-plus.com')) {
      baseMessage = 'Error: You must use a valid @roselleschools.org email address';
    } else if (errorString.contains('account-exists-with-different-credential')) {
      baseMessage = 'An account already exists with this email using a different sign-in method';
    } else if (errorString.contains('popup-closed-by-user') || errorString.contains('cancelled')) {
      baseMessage = 'Sign-in cancelled';
    } else {
      // Log unknown error format for debugging
      LoggerService.warning('Unknown OAuth error format: $errorString', tag: 'AuthProvider');
      baseMessage = 'Authentication failed';
    }
    
    // For error messages starting with "Error:", use as-is
    final errorMessage = baseMessage.startsWith('Error:') 
        ? baseMessage 
        : '$provider sign-in failed: $baseMessage';
    _handleAuthError(errorMessage);
  }

  /// Start notifications if needed (web only)
  void _startNotificationsIfNeeded() {
    if (kIsWeb && _userModel != null) {
      WebInAppNotificationService.instance.startListening(_userModel!.id);
    }
  }

  /// Update user presence to online
  void _updatePresenceOnline() {
    if (_userModel != null) {
      _presenceService.updatePresence(_userModel!.id, true);
    }
  }

  /// Update user presence to offline
  void _updatePresenceOffline() {
    if (_userModel != null) {
      _presenceService.updatePresence(_userModel!.id, false);
    }
  }

  /// Update remember me preference
  Future<void> setRememberMe(bool value) async {
    _rememberMe = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', value);
    notifyListeners();
  }

  // ============= Additional Methods for Compatibility =============
  
  /// Clear current error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Reload user model from Firestore
  Future<void> reloadUserModel() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      final loadedUserModel = await _loadUserModelWithRetry(user.uid);
      if (loadedUserModel != null) {
        _userModel = loadedUserModel;
        notifyListeners();
      }
    }
  }
  
  /// Reload current user
  Future<void> reloadUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.reload();
      await reloadUserModel();
    }
  }
  
  /// Set selected role (no longer needed but kept for compatibility)
  void setSelectedRole(String role) {
    // No-op - roles are now determined by email domain
    LoggerService.info('setSelectedRole called but ignored - roles are domain-based', tag: 'AuthProvider');
  }
  
  /// Create student account (admin only)
  Future<void> createStudentAccount({
    required String username,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    throw Exception('Student account creation should be done through admin functions');
  }
  
  /// Reauthenticate with Apple
  Future<void> reauthenticateWithApple() async {
    await signInWithApple();
  }
  
  /// Reauthenticate with Google
  Future<void> reauthenticateWithGoogle() async {
    await signInWithGoogle();
  }
  
  /// Reauthenticate with email and password
  Future<void> reauthenticateWithEmail(String email, String password) async {
    final user = _firebaseAuth.currentUser;
    if (user != null && user.email != null) {
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }
  
  /// Delete user account
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.delete();
      await signOut();
    }
  }
  
  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      
      // Update Firestore document
      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (firstName != null) updates['firstName'] = firstName;
      if (lastName != null) updates['lastName'] = lastName;
      
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);
        await reloadUserModel();
      }
    }
  }
  
  /// Update profile picture
  Future<void> updateProfilePicture(String photoUrl) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.updatePhotoURL(photoUrl);
      await _firestore.collection('users').doc(user.uid).update({
        'photoURL': photoUrl,
      });
      await reloadUserModel();
    }
  }

  @override
  void dispose() {
    // Clean up presence when provider is disposed
    _updatePresenceOffline();
    super.dispose();
  }
}