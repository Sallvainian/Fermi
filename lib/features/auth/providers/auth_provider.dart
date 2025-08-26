import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/user_model.dart';
import '../data/services/auth_service.dart';
import '../../notifications/data/services/web_in_app_notification_service.dart';
import '../../student/data/services/presence_service.dart';

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
        debugPrint('User reload failed: $e');
        await _handleInvalidUser('User account is no longer valid');
        return;
      }
      
      // Check if user still exists after reload
      final currentUser = _firebaseAuth.currentUser;
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
        _updatePresenceOnline();
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
      _updatePresenceOnline();
      _updatePresenceOnline();
      
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
        _updatePresenceOnline();
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
        _updatePresenceOnline();
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
  
  /// Complete OAuth sign-in flow after role selection.
  /// 
  /// Called after a new OAuth user selects their role.
  /// This method:
  /// 1. Creates/updates the user document in Firestore with role
  /// 2. Waits for eventual consistency
  /// 3. Loads the complete user model
  /// 4. Transitions to authenticated state
  Future<void> completeOAuthSignIn(String role) async {
    if (_authOperationInProgress) {
      debugPrint('Auth operation already in progress');
      return;
    }
    
    _authOperationInProgress = true;
    _startLoading();
    
    try {
      final user = _firebaseAuth.currentUser;
      
      if (user == null) {
        throw Exception('No authenticated user');
      }
      
      // Save user role and data
      await _authService.saveUserRole(
        uid: user.uid,
        role: role,
        email: user.email ?? '',
        displayName: user.displayName,
        photoURL: user.photoURL,
      );
      
      // Wait for Firestore eventual consistency
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Retry loading user model to handle eventual consistency
      UserModel? loadedUserModel;
      for (int attempt = 0; attempt < 3; attempt++) {
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
      _updatePresenceOnline();
      
      // Extra delay to ensure state propagates to UI
      await Future.delayed(const Duration(milliseconds: 100));
      
    } catch (e) {
      debugPrint('OAuth completion error: $e');
      _handleAuthError(e.toString());
      await signOut();
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }
  
  /// Create new account with email and password
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String role,
    String? displayName,
  }) async {
    if (_authOperationInProgress) {
      debugPrint('Auth operation already in progress');
      return;
    }
    
    _authOperationInProgress = true;
    _startLoading();
    
    try {
      // Validate input - role can be empty for initial signup
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }
      
      // Create user account
      final user = await _authService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      
      if (user == null) {
        throw Exception('Account creation failed');
      }
      
      // If role is provided, save it immediately (legacy flow)
      // Otherwise, defer role selection (new flow for email/password signup)
      if (role.isNotEmpty) {
        // Save user role immediately
        await _authService.saveUserRole(
          uid: user.uid,
          role: role,
          email: email,
          displayName: displayName,
        );
        
        // Wait for Firestore consistency
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Load complete user model
        final loadedUserModel = await _loadUserModelWithRetry(user.uid);
        
        if (loadedUserModel == null || loadedUserModel.role == null) {
          // Critical: Account created but profile save failed
          await _authService.signOut();
          throw Exception('Failed to create user profile. Please try signing in.');
        }
        
        // SUCCESS: Update state atomically
        _userModel = loadedUserModel;
        _setAuthState(AuthStatus.authenticated);
        _startNotificationsIfNeeded();
        _updatePresenceOnline();
      } else {
        // New user needs role selection - save basic info first
        // NOTE: The 'pending_users' collection has security rules restricting access
        // to document owners only (see firestore.rules line 49-50)
        await _firestore.collection('pending_users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'displayName': displayName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Keep status as authenticating to trigger role selection flow
        _setAuthState(AuthStatus.authenticating);
      }
      
    } catch (e) {
      debugPrint('Sign-up error: $e');
      _handleSignUpError(e);
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
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          data['uid'] = uid; // Ensure UID is included
          return data;
        }
      }
      return null;
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
  
  /// Handle invalid/expired user
  Future<void> _handleInvalidUser(String message) async {
    debugPrint('Invalid user: $message');
    _userModel = null;
    _errorMessage = message;
    _setAuthState(AuthStatus.unauthenticated);
    await _authService.signOut();
  }
  
  /// Handle authentication errors
  void _handleAuthError(String error) {
    _userModel = null;
    _errorMessage = error;
    _setAuthState(AuthStatus.error);
  }
  
  /// Handle sign-in specific errors
  void _handleSignInError(dynamic error) {
    String message = 'Sign in failed';
    
    if (error is firebase_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          message = 'No account found with this email';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password';
          break;
        default:
          message = error.message ?? 'Authentication failed';
      }
    } else {
      message = error.toString();
    }
    
    _handleAuthError(message);
  }
  
  /// Handle OAuth specific errors
  void _handleOAuthError(dynamic error, String provider) {
    String message = '$provider sign-in failed';
    
    // Add detailed logging for Windows debugging
    debugPrint('=== OAuth Error Details ===');
    debugPrint('Provider: $provider');
    debugPrint('Error Type: ${error.runtimeType}');
    debugPrint('Error: $error');
    
    if (error is firebase_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
          message = 'An account already exists with the same email address';
          break;
        case 'invalid-credential':
          message = 'Invalid $provider credentials';
          break;
        case 'operation-not-allowed':
          message = '$provider sign-in is not enabled';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        default:
          message = error.message ?? '$provider authentication failed';
      }
    } else if (error.toString().contains('OAuth') || error.toString().contains('authentication server')) {
      message = 'OAuth configuration error. Please ensure Firebase Functions are deployed and configured correctly';
    } else {
      message = error.toString();
    }
    
    _handleAuthError(message);
  }
  
  /// Handle sign-up specific errors  
  void _handleSignUpError(dynamic error) {
    String message = 'Sign up failed';
    
    if (error is firebase_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'weak-password':
          message = 'Password is too weak';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled';
          break;
        default:
          message = error.message ?? 'Account creation failed';
      }
    } else {
      message = error.toString();
    }
    
    _handleAuthError(message);
  }
  
  // ============= Notification Management =============
  
  void _startNotificationsIfNeeded() {
    if (kIsWeb && _userModel != null) {
      WebInAppNotificationService.instance.initialize();
    }
  }
  
  // ============= Presence Management =============
  
  void _updatePresenceOnline() {
    if (_userModel != null) {
      // Extract just the role name without the enum prefix
      final roleString = _userModel!.role.toString().split('.').last;
      _presenceService.updateUserPresence(true, userRole: roleString);
    }
  }
  
  void _updatePresenceOffline() {
    _presenceService.updateUserPresence(false);
  }
  
  void _stopNotificationsIfNeeded() {
    if (kIsWeb) {
      WebInAppNotificationService.instance.dispose();
    }
  }
  
  // ============= UI State Management =============
  
  void _startLoading() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }
  
  void _stopLoading() {
    _isLoading = false;
    notifyListeners();
  }
  
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _setAuthState(AuthStatus.unauthenticated);
    }
    notifyListeners();
  }
  
  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }
  
  // ============= User Profile Management =============
  
  /// Update user display name
  Future<void> updateDisplayName(String displayName) async {
    if (_userModel == null) return;
    
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        _userModel = _userModel!.copyWith(displayName: displayName);
        
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'displayName': displayName});
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to update display name: $e');
      rethrow;
    }
  }
  
  /// Update user photo URL
  Future<void> updatePhotoURL(String photoURL) async {
    if (_userModel == null) return;
    
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updatePhotoURL(photoURL);
        _userModel = _userModel!.copyWith(photoURL: photoURL);
        
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'photoURL': photoURL});
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to update photo URL: $e');
      rethrow;
    }
  }
  
  /// Reload user data from Firebase
  Future<void> reloadUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.reload();
        
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
      _userModel = null;
      _setAuthState(AuthStatus.unauthenticated);
    } catch (e) {
      debugPrint('Failed to delete account: $e');
      _handleAuthError(e.toString());
    } finally {
      _stopLoading();
    }
  }
  
  /// Sign out the current user
  Future<void> signOut() async {
    try {
      _stopNotificationsIfNeeded();
      _updatePresenceOffline();  // Update presence before signing out
      await _authService.signOut();
      _userModel = null;
      _errorMessage = null;
      _setAuthState(AuthStatus.unauthenticated);
    } catch (e) {
      debugPrint('Sign-out error: $e');
      // Force unauthenticated state even on error
      _userModel = null;
      _setAuthState(AuthStatus.unauthenticated);
    }
  }
  
  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    _startLoading();
    
    try {
      await _authService.sendPasswordResetEmail(email);
      // Success - no state change needed
    } catch (e) {
      debugPrint('Password reset error: $e');
      _handleAuthError(e.toString());
    } finally {
      _stopLoading();
    }
  }
  
  // ============= Additional Methods (Stubs for compatibility) =============
  
  /// Send email verification
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
  
  /// Re-authenticate with Apple
  Future<void> reauthenticateWithApple() async {
    // TODO: Implement Apple re-authentication
    throw UnimplementedError('Apple re-authentication not implemented');
  }
  
  /// Re-authenticate with Google
  Future<void> reauthenticateWithGoogle() async {
    // TODO: Implement Google re-authentication
    throw UnimplementedError('Google re-authentication not implemented');
  }
  
  /// Re-authenticate with email and password
  Future<void> reauthenticateWithEmail(String email, String password) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }
  
  /// Update profile picture
  Future<void> updateProfilePicture(String photoURL) async {
    await updatePhotoURL(photoURL);
  }
  
  /// Update profile (compatibility method)
  Future<void> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
  }) async {
    if (_userModel == null) return;
    
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return;
      
      // Update Firebase Auth displayName if provided
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      
      // Prepare Firestore update
      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (firstName != null) updates['firstName'] = firstName;
      if (lastName != null) updates['lastName'] = lastName;
      
      // Update Firestore if there are changes
      if (updates.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update(updates);
        
        // Update local model
        _userModel = _userModel!.copyWith(
          displayName: displayName ?? _userModel!.displayName,
          firstName: firstName ?? _userModel!.firstName,
          lastName: lastName ?? _userModel!.lastName,
        );
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to update profile: $e');
      rethrow;
    }
  }
  
  @override
  void dispose() {
    _stopNotificationsIfNeeded();
    super.dispose();
  }
}