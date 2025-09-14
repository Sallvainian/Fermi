import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/services/logger_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'desktop_oauth_handler_direct.dart';

/// Simple authentication service - does one thing well
class AuthService {
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  // Use GoogleSignIn.instance singleton for mobile (v7+)
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;
  // Desktop OAuth handler for Windows/Mac/Linux
  // Direct OAuth handler that works without Firebase Functions
  final DirectDesktopOAuthHandler _directOAuthHandler =
      DirectDesktopOAuthHandler();

  AuthService() {
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;

    // Initialize Google Sign-In based on platform
    _initializeGoogleSignIn();

    // Web persistence
    if (kIsWeb) {
      _auth!.setPersistence(Persistence.LOCAL);
    }
  }

  // Helper method to validate school email domains
  bool _isValidSchoolEmail(String email) {
    final emailLower = email.toLowerCase();
    
    // No hardcoded admin emails - use domain validation instead
    // Admins must use @fermi-plus.com domain
    
    // School domain validation
    const validDomains = [
      '@roselleschools.org',  // Teachers
      '@rosellestudent.org',  // Students
      '@fermi-plus.com',      // Admins
    ];
    
    for (final domain in validDomains) {
      if (emailLower.endsWith(domain)) {
        return true;
      }
    }
    
    return false;
  }

  void _initializeGoogleSignIn() async {
    String clientId = '';
    String clientSecret = '';

    // Safely try to access dotenv - it might not be initialized yet
    try {
      // Try both naming conventions for backwards compatibility
      clientId =
          dotenv.env['GOOGLE_OAUTH_CLIENT_ID'] ??
          dotenv.env['GOOGLE_CLIENT_ID'] ??
          '';
      clientSecret =
          dotenv.env['GOOGLE_OAUTH_CLIENT_SECRET'] ??
          dotenv.env['GOOGLE_CLIENT_SECRET'] ??
          '';
    } catch (e) {
      // dotenv not initialized yet - this is fine, we'll use empty strings
      LoggerService.info(
        '.env not loaded yet, OAuth will use defaults',
        tag: 'AuthService',
      );
    }

    // Debug output to verify .env is loading
    LoggerService.debug(
      '=== OAuth Credentials Debug ===',
      tag: 'AuthService',
    );
    LoggerService.debug(
      'Platform: ${kIsWeb ? "Web" : Platform.operatingSystem}',
      tag: 'AuthService',
    );
    LoggerService.debug(
      'Client ID loaded: ${clientId.isNotEmpty ? "Yes (${clientId.substring(0, 10)}...)" : "No"}',
      tag: 'AuthService',
    );
    LoggerService.debug(
      'Client Secret loaded: ${clientSecret.isNotEmpty ? "Yes" : "No"}',
      tag: 'AuthService',
    );

    // Don't initialize all_platforms for desktop - we'll use DesktopOAuthHandler
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      LoggerService.info('Using DesktopOAuthHandler for desktop platform', tag: 'AuthService');
      if (clientId.isEmpty || clientSecret.isEmpty) {
        LoggerService.error('Google OAuth credentials not found in .env file', tag: 'AuthService');
        LoggerService.warning('Windows Google Sign-In will not work without credentials', tag: 'AuthService');
      }
      // Desktop platforms don't use GoogleSignIn.instance
      LoggerService.info('Desktop uses secure OAuth handler - GoogleSignIn.instance not configured', tag: 'AuthService');
    } else if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      // Mobile platforms: Configure GoogleSignIn.instance
      LoggerService.info('Configuring GoogleSignIn.instance for mobile', tag: 'AuthService');
      await _configureGoogleSignInForMobile();
    } else if (kIsWeb) {
      // Web doesn't need GoogleSignIn.instance configuration (uses Firebase Auth popup)
      LoggerService.info('Web uses Firebase Auth popup; GoogleSignIn.instance not used', tag: 'AuthService');
    }
  }

  /// Configure GoogleSignIn.instance for mobile platforms (v7+)
  Future<void> _configureGoogleSignInForMobile() async {
    try {
      // In v7+, GoogleSignIn.instance must be initialized before use
      await _googleSignIn.initialize();
      LoggerService.info('GoogleSignIn.instance initialized for mobile', tag: 'AuthService');
    } catch (e) {
      LoggerService.error('Failed to initialize GoogleSignIn.instance', tag: 'AuthService', error: e);
    }
  }

  // Current user
  User? get currentUser => _auth?.currentUser;
  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? Stream.value(null);

  // Sign up with username support
  Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
    String? username,
  }) async {
    // Validate email domain before attempting sign up
    if (!_isValidSchoolEmail(email)) {
      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Registration is restricted to authorized email addresses (@roselleschools.org for teachers, @rosellestudent.org for students, @fermi-plus.com for admins)',
      );
    }
    
    final cred = await _auth!.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (cred.user != null) {
      await cred.user!.updateDisplayName(displayName);

      // Parse name parts
      final nameParts = displayName?.split(' ') ?? [];
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      // Extract username from synthetic email if not provided
      String? finalUsername = username;
      if (finalUsername == null && email.endsWith('@fermi.local')) {
        finalUsername = email.substring(0, email.indexOf('@'));
      }

      // Update user document created by blocking function
      // Only add/update client-side fields without overwriting backend fields
      await _firestore!.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'firstName': firstName,
        'lastName': lastName,
        'username': finalUsername,
        'lastActive': FieldValue.serverTimestamp(),
        // Don't update: email, displayName, role, createdAt, emailVerified, isEmailUser, profileComplete
        // These are already set by the blocking function
      }, SetOptions(merge: true));
    }

    return cred.user;
  }

  // Sign in with email
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    if (_auth == null || _firestore == null) {
      throw UnsupportedError(
        'Firebase not available on Windows. Use mock authentication.',
      );
    }

    // Validate email domain before sign in
    if (!_isValidSchoolEmail(email)) {
      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Sign in is restricted to authorized email addresses (@roselleschools.org for teachers, @rosellestudent.org for students, @fermi-plus.com for admins)',
      );
    }

    final cred = await _auth!.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update last active
    if (cred.user != null) {
      await _firestore!
          .collection('users')
          .doc(cred.user!.uid)
          .set({'lastActive': FieldValue.serverTimestamp()}, SetOptions(merge: true))
          .catchError((_) {});
    }

    return cred.user;
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    if (_auth == null || _firestore == null) {
      throw UnsupportedError(
        'Firebase not available. Check Firebase initialization.',
      );
    }

    User? user;

    if (kIsWeb) {
      // Web: Use Firebase Auth popup
      LoggerService.info('Google Sign-In: Using Firebase popup (web)', tag: 'AuthService');
      try {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');

        // Force account selection to prevent auto-login with wrong account
        provider.setCustomParameters({
          'prompt': 'select_account', // Forces the account picker even if user is already signed in
        });

        LoggerService.debug('Attempting signInWithPopup...', tag: 'AuthService');

        try {
          // Try popup first
          final cred = await _auth!.signInWithPopup(provider);
          user = cred.user;
          LoggerService.info('Google Sign-In: Successful for ${user?.email}', tag: 'AuthService');
        } catch (popupError) {
          LoggerService.warning('Popup failed', tag: 'AuthService');

          // If popup fails, try redirect method
          if (popupError.toString().contains('popup-blocked') ||
              popupError.toString().contains('popup-closed-by-user')) {
            LoggerService.warning('Popup blocked/closed, trying redirect...', tag: 'AuthService');

            // Use redirect method as fallback
            await _auth!.signInWithRedirect(provider);

            // After redirect, this will be handled by getRedirectResult
            final result = await _auth!.getRedirectResult();
            if (result.user != null) {
              user = result.user;
              LoggerService.info('Redirect Sign-In: success for ${user?.email}', tag: 'AuthService');
            } else {
              LoggerService.warning('Redirect sign-in completed but no user returned', tag: 'AuthService');
              return null;
            }
          } else {
            // Re-throw if it's not a popup issue
            rethrow;
          }
        }
      } catch (e) {
        LoggerService.error('Google Sign-In Web Error', tag: 'AuthService', error: e);

        final errorString = e.toString();
        if (errorString.contains('popup-closed-by-user')) {
          LoggerService.info('User closed the popup window', tag: 'AuthService');
          return null;
        } else if (errorString.contains('unauthorized-domain')) {
          LoggerService.error('Unauthorized domain - check Firebase OAuth redirect URIs', tag: 'AuthService');
          LoggerService.error('Current domain: ${Uri.base.host}', tag: 'AuthService');
          throw Exception(
            'This domain is not authorized for Google Sign-In. Please contact support.',
          );
        } else if (errorString.contains('invalid-credential')) {
          LoggerService.error('Invalid OAuth credentials - check Firebase config', tag: 'AuthService');
          throw Exception(
            'Authentication configuration error. Please contact support.',
          );
        } else if (errorString.contains('auth/popup-blocked')) {
          LoggerService.warning('Popup was blocked by browser', tag: 'AuthService');
          throw Exception(
            'Sign-in popup was blocked. Please allow popups for this site and try again.',
          );
        }
        rethrow;
      }
    } else if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      // Desktop platforms: Use secure OAuth flow via Firebase Functions
      LoggerService.info('Google Sign-In: secure OAuth flow (desktop)', tag: 'AuthService');

      try {
        // Perform secure OAuth flow - no secrets exposed in client
        final credential = await _directOAuthHandler.performDirectOAuthFlow();

        if (credential == null) {
          LoggerService.info('Google Sign-In: User cancelled or flow failed', tag: 'AuthService');
          return null;
        }

        user = credential.user;
        LoggerService.info('Google Sign-In: success for ${user?.email}', tag: 'AuthService');
      } catch (e) {
        LoggerService.error('Google Sign-In error', tag: 'AuthService', error: e);
        rethrow;
      }
    } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Mobile: Use Firebase Auth with Google provider directly
      LoggerService.info('Google Sign-In: using Firebase Google provider (mobile)', tag: 'AuthService');

      try {
        // For v7+ compatibility, use Firebase Auth directly with Google provider
        // This avoids the complex google_sign_in package API changes
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');

        // Use signInWithProvider for mobile platforms (requires proper setup)
        final cred = await _auth!.signInWithProvider(provider);
        user = cred.user;

        LoggerService.info('Google Sign-In: authenticated via Firebase provider', tag: 'AuthService');
      } catch (e) {
        LoggerService.error('Google Sign-In mobile authentication failed', tag: 'AuthService', error: e);
        LoggerService.warning('No provider fallback available in v7+ environment', tag: 'AuthService');

        // If all methods fail, throw the original error
        rethrow;
      }
    } else {
      throw UnsupportedError('Google Sign-In not supported on this platform');
    }

    // Check if user document exists, create if not (for new Google users)
    if (user != null) {
      final doc = await _firestore!.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // Parse name from Google account
        final nameParts = (user.displayName ?? '').split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName = nameParts.length > 1
            ? nameParts.sublist(1).join(' ')
            : '';

        // Create user document with merge to preserve backend-assigned role
        await _firestore!.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName':
              user.displayName ?? user.email?.split('@').first ?? 'User',
          'firstName': firstName,
          'lastName': lastName,
          'photoURL': user.photoURL,
          // Don't set role - backend blocking function assigns based on email domain
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Update last active
        await _firestore!.collection('users').doc(user.uid).set({
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    return user;
  }

  // Sign in with Apple (required for App Store compliance - Guideline 4.8)
  Future<User?> signInWithApple() async {
    try {
      // Check if Apple Sign In is available
      if (!await SignInWithApple.isAvailable()) {
        throw Exception('Sign in with Apple is not available on this device');
      }

      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: kIsWeb
            ? WebAuthenticationOptions(
                clientId: 'com.academic-tools.fermi.services',
                redirectUri: Uri.parse(
                  'https://teacher-dashboard-flutterfire.firebaseapp.com/__/auth/handler',
                ),
              )
            : null,
      );

      // Create Firebase credential from Apple credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with Apple credential
      final userCredential = await _auth!.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      // Handle user data (similar to Google Sign-In)
      if (user != null) {
        final doc = await _firestore!.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          // Create user document for new Apple users
          String firstName = '';
          String lastName = '';
          String displayName = user.displayName ?? 'User';

          // Apple provides name data during first sign-in only
          if (appleCredential.givenName != null ||
              appleCredential.familyName != null) {
            firstName = appleCredential.givenName ?? '';
            lastName = appleCredential.familyName ?? '';
            displayName = '$firstName $lastName'.trim();
            if (displayName.isEmpty) {
              displayName = user.email?.split('@').first ?? 'User';
            }
          } else {
            // Fallback to email prefix if no name provided
            displayName = user.email?.split('@').first ?? 'User';
          }

          await _firestore!.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'displayName': displayName,
            'firstName': firstName,
            'lastName': lastName,
            'photoURL': user.photoURL,
            'role': null, // Will be set during role selection
            'createdAt': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
            'authProvider': 'apple', // Track auth method for privacy compliance
          });
        } else {
          // Update last active for existing users
          await _firestore!.collection('users').doc(user.uid).update({
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
      }

      return user;
    } catch (e) {
      LoggerService.error('Apple Sign-In error', tag: 'AuthService', error: e);
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth!.signOut();

    // Platform-specific sign out
    if (!kIsWeb) {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop: Using secure OAuth - Firebase handles token revocation
        LoggerService.info('Sign Out: Desktop OAuth tokens handled by Firebase', tag: 'AuthService');
      } else if (Platform.isIOS || Platform.isAndroid) {
        // Mobile: Sign out from GoogleSignIn.instance
        try {
          await _googleSignIn.signOut();
          LoggerService.info('Sign Out: Signed out from GoogleSignIn.instance', tag: 'AuthService');
        } catch (e) {
          LoggerService.warning('Sign Out: Failed to sign out from GoogleSignIn.instance', tag: 'AuthService');
        }
      }
    }
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    await _auth!.sendPasswordResetEmail(email: email);
  }

  // Update user role (for role selection after Google sign-in)
  Future<void> updateUserRole(String uid, String role) async {
    // Parse role properly
    String roleStr = role;
    if (role.contains('.')) {
      roleStr = role.split('.').last;
    }

    // Use set with merge to handle both existing and new documents
    // This ensures it works even if the document doesn't exist yet
    await _firestore!.collection('users').doc(uid).set({
      'role': roleStr,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // If student, also create student document
    if (roleStr == 'student') {
      final userDoc = await _firestore!.collection('users').doc(uid).get();
      final userData = userDoc.data();
      if (userData != null) {
        await _firestore!.collection('students').doc(uid).set({
          'id': uid, // Document ID
          'userId': uid, // This is what getStudentByUserId looks for
          'email': userData['email'] ?? '',
          'displayName': userData['displayName'] ?? 'Student',
          'firstName': userData['firstName'] ?? '',
          'lastName': userData['lastName'] ?? '',
          'isActive': true,
          'classIds': [],
          'gradeLevel': 9, // Default grade level, can be updated later
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  // Save user role with username support
  Future<void> saveUserRole({
    required String uid,
    required String role,
    required String email,
    String? displayName,
    String? photoURL,
    String? username,
  }) async {
    // Extract username from synthetic email if not provided
    String? finalUsername = username;
    if (finalUsername == null && email.endsWith('@fermi.local')) {
      finalUsername = email.substring(0, email.indexOf('@'));
    }

    await _firestore!.collection('users').doc(uid).set({
      'uid': uid,
      'role': role,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'username': finalUsername,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth!.sendPasswordResetEmail(email: email);
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore!.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      // Ensure uid field exists
      data['uid'] = uid;
    }
    return data;
  }

  // Delete user account and all associated data
  // Required for privacy compliance (GDPR, App Store guidelines)
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      final uid = user.uid;

      // Get user data to check role for additional cleanup
      final userData = await getUserData(uid);
      final userRole = userData?['role'] as String?;

      // Delete user document from Firestore
      await _firestore!.collection('users').doc(uid).delete().catchError((_) {
        // Continue even if user document doesn't exist
      });

      // If user is a student, also delete from students collection
      if (userRole == 'student') {
        await _firestore!.collection('students').doc(uid).delete().catchError((
          _,
        ) {
          // Continue even if student document doesn't exist
        });
      }

      // Delete from any other collections that might contain user data
      // Note: In a production app, you'd want to implement a more comprehensive
      // cleanup that removes user data from all relevant collections

      // Delete Firebase Auth account (this must be done last)
      await user.delete();

      LoggerService.info('User account deleted successfully', tag: 'AuthService');
    } catch (e) {
      LoggerService.error('Error deleting account', tag: 'AuthService', error: e);

      // Handle common deletion errors
      if (e.toString().contains('requires-recent-login')) {
        throw Exception(
          'For security reasons, please sign in again before deleting your account.',
        );
      } else if (e.toString().contains('network-request-failed')) {
        throw Exception(
          'Network error. Please check your connection and try again.',
        );
      } else {
        throw Exception('Failed to delete account. Please try again.');
      }
    }
  }

  // Re-authenticate user for sensitive operations like account deletion
  Future<void> reauthenticateWithEmail(String email, String password) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      LoggerService.error('Re-authentication failed', tag: 'AuthService', error: e);
      if (e.toString().contains('wrong-password')) {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.toString().contains('user-mismatch')) {
        throw Exception('Email does not match current user.');
      } else {
        throw Exception('Authentication failed. Please try again.');
      }
    }
  }

  // Re-authenticate with Google for account deletion
  Future<void> reauthenticateWithGoogle() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      if (kIsWeb) {
        // Web: Use popup re-authentication
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        await user.reauthenticateWithPopup(provider);
      } else if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        // Desktop: Use secure OAuth flow for re-authentication
        LoggerService.info('Re-authentication: secure OAuth flow (desktop)', tag: 'AuthService');

        final credential = await _directOAuthHandler.performDirectOAuthFlow();

        if (credential == null) {
          throw Exception('Google re-authentication was cancelled');
        }

        // User is already re-authenticated through the secure flow
        LoggerService.info('Re-authentication: success', tag: 'AuthService');
      } else if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        // Mobile: Use Firebase Auth Google provider for re-authentication
        try {
          final provider = GoogleAuthProvider();
          provider.addScope('email');
          provider.addScope('profile');

          // Use reauthenticateWithProvider for mobile platforms
          await user.reauthenticateWithProvider(provider);

          LoggerService.info('Google re-authentication: success via Firebase provider', tag: 'AuthService');
        } catch (providerError) {
          LoggerService.error('Firebase provider re-authentication failed', tag: 'AuthService', error: providerError);
          LoggerService.warning('No fallback re-auth available in v7+ env', tag: 'AuthService');
          throw Exception(
            'Google re-authentication failed via Firebase provider',
          );
        }
      } else {
        throw Exception(
          'Google re-authentication not available on this platform',
        );
      }
    } catch (e) {
      LoggerService.error('Google re-authentication failed', tag: 'AuthService', error: e);
      throw Exception('Google authentication failed. Please try again.');
    }
  }

  // Re-authenticate with Apple for account deletion
  Future<void> reauthenticateWithApple() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      // Request Apple ID credential for re-authentication
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [],
        webAuthenticationOptions: kIsWeb
            ? WebAuthenticationOptions(
                clientId: 'com.academic-tools.fermi.firebase',
                redirectUri: Uri.parse(
                  'https://teacher-dashboard-flutterfire.firebaseapp.com/__/auth/handler',
                ),
              )
            : null,
      );

      // Create Firebase credential from Apple credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Re-authenticate with Firebase
      await user.reauthenticateWithCredential(oauthCredential);
    } catch (e) {
      LoggerService.error('Apple re-authentication failed', tag: 'AuthService', error: e);
      throw Exception('Apple authentication failed. Please try again.');
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    final user = _auth?.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
}
