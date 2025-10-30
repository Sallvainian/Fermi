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

/// Defines the possible authentication states of the application.
enum AuthStatus {
  /// The initial state while the authentication status is being determined.
  uninitialized,

  /// The user is successfully authenticated and has a complete profile.
  authenticated,

  /// An authentication operation is currently in progress.
  authenticating,

  /// The user is not authenticated.
  unauthenticated,

  /// An error occurred during an authentication process.
  error,
}

// Type alias for Firebase Auth User
typedef User = firebase_auth.User;

/// A provider that manages user authentication and session state.
///
/// This class handles all authentication-related logic, including sign-in,
/// sign-up, sign-out, and state management. It uses a domain-based role
/// assignment system, where user roles are automatically determined by their
/// email domain.
///
/// It interacts with [AuthService] for the underlying authentication
/// mechanisms and provides a simplified [AuthStatus] to the rest of the app.
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

  /// Creates an [AuthProvider].
  ///
  /// Initializes the auth state and sets up dependencies.
  ///
  /// - [authService]: An optional [AuthService] instance for dependency injection.
  /// - [initialStatus]: The initial [AuthStatus] for testing purposes.
  /// - [initialUserModel]: The initial [UserModel] for testing purposes.
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

  /// The current authentication status.
  AuthStatus get status => _status;

  /// The currently authenticated user's data model.
  UserModel? get userModel => _userModel;

  /// The underlying Firebase user object.
  firebase_auth.User? get firebaseUser => _firebaseAuth.currentUser;

  /// The last error message, if any.
  String? get errorMessage => _errorMessage;

  /// Whether an authentication operation is in progress.
  bool get isLoading => _isLoading;

  /// Whether the user is fully authenticated.
  bool get isAuthenticated => _status == AuthStatus.authenticated && _userModel != null;

  /// Whether the user has selected "Remember Me".
  bool get rememberMe => _rememberMe;

  // ============= Initialization =============

  /// Initializes the authentication state when the provider is first created.
  ///
  /// This method checks for an existing Firebase user session, handles OAuth
  /// redirects on the web, and loads the user's profile data if they are
  /// already logged in.
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

  /// Processes a Firebase user to load their associated [UserModel].
  ///
  /// This method is called after a successful sign-in or during initialization.
  /// It loads the user's profile from Firestore, handles the creation of profiles
  /// for manually added admin accounts, and sets the final authenticated state.
  ///
  /// - [user]: The Firebase user to process.
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

  /// Signs in a user with their email and password.
  ///
  /// The user's role is automatically determined by their email domain upon
  /// successful authentication.
  ///
  /// - [email]: The user's email address.
  /// - [password]: The user's password.
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

  /// Creates a new user account with email and password.
  ///
  /// The user's role is automatically assigned based on their email domain
  /// by a cloud function upon account creation.
  ///
  /// - [email]: The user's email address.
  /// - [password]: The user's chosen password.
  /// - [displayName]: The user's display name.
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

  /// Initiates the Google Sign-In flow.
  ///
  /// The user's role is determined by their email domain upon successful
  /// authentication.
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

  /// Initiates the Apple Sign-In flow.
  ///
  /// The user's role is determined by their email domain upon successful
  /// authentication.
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

  /// Sends a password reset email to the specified email address.
  ///
  /// - [email]: The email address to send the reset link to.
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

  /// Resends the email verification link to the current user.
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

  /// Signs out the current user.
  ///
  /// This method clears the user's session, updates their presence to offline,
  /// and resets the authentication state.
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

  /// Loads a [UserModel] from Firestore with a retry mechanism.
  ///
  /// This method attempts to fetch the user's data multiple times to handle
  /// potential eventual consistency delays in Firestore.
  ///
  /// - [uid]: The user ID to load.
  ///
  /// Returns the loaded [UserModel] or `null` if not found after all retries.
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

  /// Fetches user data from Firestore with a single retry.
  ///
  /// - [uid]: The user ID to fetch.
  ///
  /// Returns a map of user data or `null`.
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

  /// Calculates the delay for exponential backoff retries.
  ///
  /// - [attempt]: The current retry attempt number.
  Duration _calculateRetryDelay(int attempt) {
    final exponentialDelay = _baseRetryDelay * (1 << attempt);
    return exponentialDelay > _maxRetryDelay ? _maxRetryDelay : exponentialDelay;
  }

  /// Handles cases where the user's session is no longer valid.
  ///
  /// This method signs the user out and sets an appropriate error message.
  ///
  /// - [message]: The error message to display.
  Future<void> _handleInvalidUser(String message) async {
    await _authService.signOut();
    _userModel = null;
    _setAuthState(AuthStatus.unauthenticated);
    _errorMessage = message;
    notifyListeners();
  }

  /// Updates the authentication state and notifies listeners.
  ///
  /// - [newStatus]: The new [AuthStatus] to set.
  void _setAuthState(AuthStatus newStatus) {
    if (_status != newStatus) {
      LoggerService.info('Auth state change: $_status -> $newStatus', tag: 'AuthProvider');
      _status = newStatus;
      notifyListeners();
    }
  }

  /// Sets the provider to a loading state.
  void _startLoading() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  /// Stops the loading state.
  void _stopLoading() {
    _isLoading = false;
    notifyListeners();
  }

  /// Handles a generic authentication error.
  ///
  /// - [error]: The error message.
  void _handleAuthError(String error) {
    _errorMessage = error;
    _setAuthState(AuthStatus.error);
    notifyListeners();
  }

  /// Handles errors specific to the sign-in process.
  ///
  /// - [error]: The error object from the sign-in attempt.
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

  /// Handles errors specific to the sign-up process.
  ///
  /// - [error]: The error object from the sign-up attempt.
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

  /// Handles errors specific to OAuth providers (Google, Apple).
  ///
  /// - [error]: The error object from the OAuth attempt.
  /// - [provider]: The name of the OAuth provider.
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

  /// Starts listening for in-app notifications if the user is on the web.
  void _startNotificationsIfNeeded() {
    if (kIsWeb && _userModel != null) {
      WebInAppNotificationService.instance.startListening(_userModel!.id);
    }
  }

  /// Updates the user's presence to 'online'.
  void _updatePresenceOnline() {
    if (_userModel != null) {
      _presenceService.updatePresence(
        _userModel!.id,
        true,
        userRole: _userModel!.role?.name,
      );
    }
  }

  /// Updates the user's presence to 'offline'.
  void _updatePresenceOffline() {
    if (_userModel != null) {
      _presenceService.updatePresence(
        _userModel!.id,
        false,
        userRole: _userModel!.role?.name,
      );
    }
  }

  /// Sets the "Remember Me" preference for the user.
  ///
  /// - [value]: `true` to remember the user, `false` otherwise.
  Future<void> setRememberMe(bool value) async {
    _rememberMe = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', value);
    notifyListeners();
  }

  // ============= Additional Methods for Compatibility =============
  
  /// Clears the current error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Reloads the user model from Firestore.
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
  
  /// Reloads the current Firebase user and their user model.
  Future<void> reloadUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.reload();
      await reloadUserModel();
    }
  }
  
  /// A no-op method for backward compatibility. Roles are now domain-based.
  void setSelectedRole(String role) {
    // No-op - roles are now determined by email domain
    LoggerService.info('setSelectedRole called but ignored - roles are domain-based', tag: 'AuthProvider');
  }
  
  /// Throws an exception, as student accounts should be created via admin functions.
  Future<void> createStudentAccount({
    required String username,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    throw Exception('Student account creation should be done through admin functions');
  }
  
  /// Reauthenticates the user with Apple Sign-In.
  Future<void> reauthenticateWithApple() async {
    await signInWithApple();
  }
  
  /// Reauthenticates the user with Google Sign-In.
  Future<void> reauthenticateWithGoogle() async {
    await signInWithGoogle();
  }
  
  /// Reauthenticates the user with their email and password.
  ///
  /// - [email]: The user's email.
  /// - [password]: The user's password.
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
  
  /// Deletes the current user's account.
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.delete();
      await signOut();
    }
  }
  
  /// Updates the user's profile information.
  ///
  /// - [displayName]: The new display name.
  /// - [firstName]: The new first name.
  /// - [lastName]: The new last name.
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
  
  /// Updates the user's profile picture URL.
  ///
  /// - [photoUrl]: The new URL of the profile picture.
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