import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/services/logger_service.dart';
import '../utils/auth_error_mapper.dart';

import '../../../shared/models/user_model.dart';
import '../data/services/auth_service.dart';
import '../data/services/username_auth_service.dart';
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
  final UsernameAuthService _usernameAuthService = UsernameAuthService();
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PresenceService _presenceService = PresenceService();

  // State management
  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _userModel;
  String? _errorMessage;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _selectedRole; // Track selected role before login

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
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _userModel != null;
  bool get rememberMe => _rememberMe;
  String? get selectedRole => _selectedRole;

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
            await _processOAuthUser(redirectResult.user!);
            return;
          }
        } catch (e) {
          LoggerService.warning('No redirect result or error checking', tag: 'AuthProvider');
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
        LoggerService.warning('Incomplete user profile for uid: ${user.uid}', tag: 'AuthProvider');
        _setAuthState(AuthStatus.authenticating);
      }
    } catch (e) {
      LoggerService.error('Auth initialization error', tag: 'AuthProvider', error: e);
      _handleAuthError(e.toString());
    }
  }

  // ============= OAuth Helper Methods =============

  /// Process OAuth user after successful authentication
  Future<void> _processOAuthUser(firebase_auth.User user) async {
    try {
      LoggerService.info('Processing OAuth user: ${user.email}', tag: 'AuthProvider');

      // Check if user has complete profile
      final userData = await _getUserDataWithRetry(user.uid);

      if (userData != null && userData['role'] != null) {
        // Existing user with role - complete sign in
        LoggerService.info('OAuth: Existing user with role, completing sign-in', tag: 'AuthProvider');
        final loadedUserModel = UserModel.fromFirestore(userData);
        _userModel = loadedUserModel;
        _setAuthState(AuthStatus.authenticated);
        _startNotificationsIfNeeded();
        _updatePresenceOnline();
      } else {
        // New user - needs role selection
        LoggerService.info('OAuth: New user, needs role selection', tag: 'AuthProvider');
        _setAuthState(AuthStatus.authenticating);
      }
    } catch (e) {
      LoggerService.error('Error processing OAuth user', tag: 'AuthProvider', error: e);
      _handleAuthError('Failed to complete sign-in. Please try again.');
    }
  }

  // ============= Core Authentication Methods =============

  /// Sign in with username and password
  Future<void> signInWithUsername(String username, String password) async {
    if (_authOperationInProgress) {
      LoggerService.warning('Auth operation already in progress', tag: 'AuthProvider');
      return;
    }

    _authOperationInProgress = true;
    _startLoading();

    try {
      // Validate input
      if (username.isEmpty || password.isEmpty) {
        throw Exception('Username and password are required');
      }

      // Authenticate with Firebase using username
      final user = await _usernameAuthService.signInWithUsername(
        username: username,
        password: password,
      );

      if (user == null) {
        throw Exception('Authentication failed');
      }

      // Load user model from Firestore
      final loadedUserModel = await _loadUserModelWithRetry(user.uid);

      if (loadedUserModel == null || loadedUserModel.role == null) {
        // User exists in Auth but not in Firestore - this shouldn't happen
        LoggerService.warning('User profile not found or incomplete', tag: 'AuthProvider');
        await _authService.signOut();
        throw Exception('User profile not found. Please contact support.');
      }

      // SUCCESS: Update state atomically
      _userModel = loadedUserModel;
      _setAuthState(AuthStatus.authenticated);
      _startNotificationsIfNeeded();
      _updatePresenceOnline();
    } catch (e) {
      LoggerService.error('Username sign-in error', tag: 'AuthProvider', error: e);
      _handleSignInError(e);
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }

  /// Sign up with username and password for teachers
  Future<void> signUpWithUsername({
    required String username,
    required String password,
    required String role,
  }) async {
    if (_authOperationInProgress) {
      LoggerService.warning('Auth operation already in progress', tag: 'AuthProvider');
      return;
    }

    _authOperationInProgress = true;
    _startLoading();

    try {
      // Validate input
      if (username.isEmpty || password.isEmpty) {
        throw Exception('Username and password are required');
      }

      // For teachers, create with temporary first/last names
      // They will complete their profile after initial auth
      final user = await _usernameAuthService.createTeacherAccount(
        username: username,
        password: password,
        firstName: '', // Will be updated in profile completion
        lastName: '', // Will be updated in profile completion
      );

      if (user == null) {
        throw Exception('Account creation failed');
      }

      // Load user model from Firestore
      final loadedUserModel = await _loadUserModelWithRetry(user.uid);

      if (loadedUserModel == null || loadedUserModel.role == null) {
        LoggerService.error('Failed to load user model after signup', tag: 'AuthProvider');
        await _authService.signOut();
        throw Exception('Failed to create user profile. Please try again.');
      }

      // SUCCESS: Update state - teacher needs to complete profile
      _userModel = loadedUserModel;
      _setAuthState(AuthStatus.authenticated);
      _startNotificationsIfNeeded();
      _updatePresenceOnline();
    } catch (e) {
      LoggerService.error('Username sign-up error', tag: 'AuthProvider', error: e);
      _handleSignUpError(e);
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }

  /// Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
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

      // Load user model from Firestore
      final loadedUserModel = await _loadUserModelWithRetry(user.uid);

      if (loadedUserModel == null || loadedUserModel.role == null) {
        // User exists in Auth but not in Firestore - this shouldn't happen
        LoggerService.warning('User profile not found or incomplete', tag: 'AuthProvider');
        await _authService.signOut();
        throw Exception(
          'User profile not found. Please contact support if you just signed up.',
        );
      }

      // SUCCESS: Update state atomically
      _userModel = loadedUserModel;
      _setAuthState(AuthStatus.authenticated);
      _startNotificationsIfNeeded();
      _updatePresenceOnline();
    } catch (e) {
      LoggerService.error('Email sign-in error', tag: 'AuthProvider', error: e);
      _handleSignInError(e);
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }

  /// Sign in with Google OAuth
  Future<void> signInWithGoogle() async {
    if (_authOperationInProgress) {
      LoggerService.warning('Auth operation already in progress', tag: 'AuthProvider');
      return;
    }

    _authOperationInProgress = true;
    _startLoading();
    clearError(); // Clear any previous errors

    try {
      LoggerService.info('Starting Google Sign-In process...', tag: 'AuthProvider');
      final user = await _authService.signInWithGoogle();

      if (user == null) {
        // User cancelled sign-in
        LoggerService.info('Google Sign-In: User cancelled', tag: 'AuthProvider');
        _setAuthState(AuthStatus.unauthenticated);
        clearError(); // Clear error state if user cancelled
        return;
      }

      LoggerService.debug('Google Sign-In: Auth success, checking profile...', tag: 'AuthProvider');

      // Check if user has complete profile
      final userData = await _getUserDataWithRetry(user.uid);

      if (userData != null && userData['role'] != null) {
        // Existing user with role - complete sign in
        LoggerService.info('Google Sign-In: Existing user with role', tag: 'AuthProvider');
        final loadedUserModel = UserModel.fromFirestore(userData);
        _userModel = loadedUserModel;
        _setAuthState(AuthStatus.authenticated);
        _startNotificationsIfNeeded();
        _updatePresenceOnline();
      } else {
        // New user - needs role selection
        // Keep status as authenticating to trigger role selection flow
        LoggerService.info('Google Sign-In: New user, needs role selection', tag: 'AuthProvider');
        _setAuthState(AuthStatus.authenticating);
      }
    } catch (e) {
      LoggerService.error('Google sign-in error', tag: 'AuthProvider', error: e);
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
      LoggerService.error('Apple sign-in error', tag: 'AuthProvider', error: e);
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
      LoggerService.warning('Auth operation already in progress', tag: 'AuthProvider');
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
          LoggerService.info('OAuth completion successful on attempt ${attempt + 1}', tag: 'AuthProvider');
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
      LoggerService.error('OAuth completion error', tag: 'AuthProvider', error: e);
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

      // Create user account
      final user = await _authService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (user == null) {
        throw Exception('Account creation failed');
      }

      // Validate that role is provided
      if (role.isEmpty) {
        await _authService.signOut();
        throw Exception('User role is required');
      }

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
        throw Exception(
          'Failed to create user profile. Please try signing in.',
        );
      }

      // SUCCESS: Update state atomically
      _userModel = loadedUserModel;
      _setAuthState(AuthStatus.authenticated);
      _startNotificationsIfNeeded();
      _updatePresenceOnline();
    } catch (e) {
      LoggerService.error('Sign-up error', tag: 'AuthProvider', error: e);
      _handleSignUpError(e);
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }

  /// Reload user model from Firestore
  Future<void> reloadUserModel() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    try {
      final loadedUserModel = await _loadUserModelWithRetry(user.uid);
      if (loadedUserModel != null) {
        _userModel = loadedUserModel;
        notifyListeners();
      }
    } catch (e) {
      LoggerService.error('Failed to reload user model', tag: 'AuthProvider', error: e);
    }
  }

  // ============= Helper Methods =============

  /// Load user model from Firestore with retry logic
  Future<UserModel?> _loadUserModelWithRetry(String uid) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay = _calculateRetryDelay(attempt);
          LoggerService.debug('Retry $attempt: wait ${delay.inMilliseconds}ms', tag: 'AuthProvider');
          await Future.delayed(delay);
        }

        final userData = await _getUserDataWithTimeout(uid);
        if (userData != null) {
          try {
            final userModel = UserModel.fromFirestore(userData);
            if (userModel.uid.isNotEmpty) {
              LoggerService.debug('Loaded user model on attempt ${attempt + 1}', tag: 'AuthProvider');
              return userModel;
            }
          } catch (e) {
            LoggerService.warning('Error parsing user model', tag: 'AuthProvider');
          }
        }
      } catch (e) {
        LoggerService.warning('Attempt ${attempt + 1} failed', tag: 'AuthProvider');
      }
    }
    LoggerService.warning('Failed to load user model after $_maxRetries attempts', tag: 'AuthProvider');
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
      LoggerService.warning('Timeout getting user data', tag: 'AuthProvider');
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
    LoggerService.warning('Invalid user: $message', tag: 'AuthProvider');
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
    final message = AuthErrorMapper.signInMessage(error);
    _handleAuthError(message);
  }

  /// Handle OAuth specific errors
  void _handleOAuthError(dynamic error, String provider) {
    AuthErrorMapper.logOAuthError(error, provider);
    final message = AuthErrorMapper.oAuthMessage(error, provider);
    _handleAuthError(message);
  }

  /// Handle sign-up specific errors
  void _handleSignUpError(dynamic error) {
    final message = AuthErrorMapper.signUpMessage(error);
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

  /// Set the selected role before login
  void setSelectedRole(String role) {
    _selectedRole = role;
    notifyListeners();
  }

  /// Clear the selected role
  void clearSelectedRole() {
    _selectedRole = null;
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

        await _firestore.collection('users').doc(user.uid).update({
          'displayName': displayName,
        });

        notifyListeners();
      }
    } catch (e) {
      LoggerService.error('Failed to update display name', tag: 'AuthProvider', error: e);
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

        await _firestore.collection('users').doc(user.uid).update({
          'photoURL': photoURL,
        });

        notifyListeners();
      }
    } catch (e) {
      LoggerService.error('Failed to update photo URL', tag: 'AuthProvider', error: e);
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
      LoggerService.error('Failed to reload user', tag: 'AuthProvider', error: e);
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
      LoggerService.warning('Failed to refresh custom claims', tag: 'AuthProvider');
    }
  }

  /// Verify teacher with special password and create/update account
  /// Used when a user enters the teacher verification password
  Future<bool> verifyTeacherAndSignIn(
    String username,
    String verificationPassword,
  ) async {
    if (_authOperationInProgress) {
      LoggerService.warning('Auth operation already in progress', tag: 'AuthProvider');
      return false;
    }

    _authOperationInProgress = true;
    _startLoading();

    try {
      // Verify the teacher password
      if (verificationPassword != 'educator2024') {
        throw Exception('Invalid teacher verification code');
      }

      // Check if user already exists
      final existingUid = await _usernameAuthService.getUidByUsername(username);

      User? user;

      if (existingUid != null) {
        // User exists - try to sign in with the verification password first
        // If that fails, it means they have their own password already
        try {
          user = await _usernameAuthService.signInWithUsername(
            username: username,
            password: verificationPassword,
          );
        } catch (e) {
          // User has a different password - update their role in Firestore
          // but tell them to use their existing password
          await _firestore.collection('users').doc(existingUid).update({
            'role': 'teacher',
            'verifiedAsTeacher': true,
            'teacherVerifiedAt': FieldValue.serverTimestamp(),
          });

          throw Exception(
            'Teacher role granted! Please sign in with your existing password.',
          );
        }

        if (user != null) {
          // Successfully signed in with verification password
          // Update their role to teacher
          await _firestore.collection('users').doc(user.uid).update({
            'role': 'teacher',
            'verifiedAsTeacher': true,
            'teacherVerifiedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // User doesn't exist - create new teacher account with the verification password
        final email = _usernameAuthService.generateSyntheticEmail(username);

        // Create Firebase Auth account with the verification password
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password:
              verificationPassword, // Use the verification password as initial password
        );

        user = credential.user;

        if (user == null) {
          throw Exception('Failed to create user account');
        }

        // Create user document in Firestore with teacher role
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'username': username.toLowerCase(),
          'email': email,
          'displayName': username,
          'role': 'teacher',
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'verifiedAsTeacher': true,
          'teacherVerifiedAt': FieldValue.serverTimestamp(),
          'needsPasswordReset':
              true, // Teacher should change from default password
        });
      }

      // If we have a user at this point, complete the sign-in
      if (user != null) {
        // Load user model
        final loadedUserModel = await _loadUserModelWithRetry(user.uid);

        if (loadedUserModel == null) {
          await _firebaseAuth.signOut();
          throw Exception('Failed to load teacher profile');
        }

        // Update state
        _userModel = loadedUserModel;
        _setAuthState(AuthStatus.authenticated);
        _startNotificationsIfNeeded();
        _updatePresenceOnline();

        return true;
      }

      return false;
    } catch (e) {
      LoggerService.error('Teacher verification error', tag: 'AuthProvider', error: e);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _authOperationInProgress = false;
      _stopLoading();
    }
  }

  // ============= Student Account Management (Teacher Only) =============

  /// Create a student account (teacher only)
  Future<void> createStudentAccount({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    // Verify current user is a teacher
    if (_userModel == null || !_userModel!.isTeacher) {
      throw Exception('Only teachers can create student accounts');
    }

    _startLoading();

    try {
      final user = await _usernameAuthService.createStudentAccount(
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        teacherId: _userModel!.uid,
      );

      if (user == null) {
        throw Exception('Failed to create student account');
      }

      // Don't change the current auth state - teacher remains logged in
      // Just show success
      LoggerService.info('Successfully created student account: $username', tag: 'AuthProvider');
    } catch (e) {
      LoggerService.error('Create student account error', tag: 'AuthProvider', error: e);
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _stopLoading();
    }
  }

  /// Batch create multiple student accounts (teacher only)
  Future<List<Map<String, String>>> batchCreateStudentAccounts({
    required List<Map<String, String>> students,
  }) async {
    // Verify current user is a teacher
    if (_userModel == null || !_userModel!.isTeacher) {
      throw Exception('Only teachers can create student accounts');
    }

    final results = <Map<String, String>>[];
    final errors = <String>[];

    for (final student in students) {
      try {
        final username = student['username'] ?? '';
        final password = student['password'] ?? '';
        final firstName = student['firstName'] ?? '';
        final lastName = student['lastName'] ?? '';

        if (username.isEmpty || password.isEmpty) {
          errors.add('Invalid data for student: $firstName $lastName');
          continue;
        }

        await createStudentAccount(
          username: username,
          password: password,
          firstName: firstName,
          lastName: lastName,
        );

        results.add({
          'username': username,
          'firstName': firstName,
          'lastName': lastName,
          'status': 'success',
        });
      } catch (e) {
        results.add({
          'username': student['username'] ?? '',
          'firstName': student['firstName'] ?? '',
          'lastName': student['lastName'] ?? '',
          'status': 'error',
          'error': e.toString(),
        });
      }
    }

    return results;
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
      LoggerService.error('Failed to delete account', tag: 'AuthProvider', error: e);
      _handleAuthError(e.toString());
    } finally {
      _stopLoading();
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      _stopNotificationsIfNeeded();
      _updatePresenceOffline(); // Update presence before signing out
      await _authService.signOut();

      // Clear app password unlock status to force re-authentication
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_unlocked', false);
      await prefs.remove('background_time');
      LoggerService.info('Sign-out: Cleared app password unlock status', tag: 'AuthProvider');

      _userModel = null;
      _errorMessage = null;
      _setAuthState(AuthStatus.unauthenticated);
    } catch (e) {
      LoggerService.error('Sign-out error', tag: 'AuthProvider', error: e);
      // Force unauthenticated state even on error
      _userModel = null;
      _setAuthState(AuthStatus.unauthenticated);

      // Still try to clear app password even on error
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_unlocked', false);
        await prefs.remove('background_time');
      } catch (_) {}
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    _startLoading();

    try {
      await _authService.sendPasswordResetEmail(email);
      // Success - no state change needed
    } catch (e) {
      LoggerService.error('Password reset error', tag: 'AuthProvider', error: e);
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
        await _firestore.collection('users').doc(user.uid).update(updates);

        // Update local model
        _userModel = _userModel!.copyWith(
          displayName: displayName ?? _userModel!.displayName,
          firstName: firstName ?? _userModel!.firstName,
          lastName: lastName ?? _userModel!.lastName,
        );

        notifyListeners();
      }
    } catch (e) {
      LoggerService.error('Failed to update profile', tag: 'AuthProvider', error: e);
      rethrow;
    }
  }

  @override
  void dispose() {
    _stopNotificationsIfNeeded();
    super.dispose();
  }
}
