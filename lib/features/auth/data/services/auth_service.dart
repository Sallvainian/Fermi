import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as all_platforms;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'desktop_oauth_handler.dart';

/// Simple authentication service - does one thing well
class AuthService {
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  // Use regular GoogleSignIn for mobile, all_platforms for desktop
  GoogleSignIn? _googleSignIn;
  all_platforms.GoogleSignIn? _googleSignInDesktop;
  // Desktop OAuth handler for Windows/Mac/Linux
  final DesktopOAuthHandler _desktopOAuthHandler = DesktopOAuthHandler();

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
  
  void _initializeGoogleSignIn() {
    final clientId = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'] ?? '';
    final clientSecret = dotenv.env['GOOGLE_OAUTH_CLIENT_SECRET'] ?? '';
    
    // Debug output to verify .env is loading
    debugPrint('=== OAuth Credentials Debug ===');
    debugPrint('Platform: ${kIsWeb ? "Web" : Platform.operatingSystem}');
    debugPrint('Client ID loaded: ${clientId.isNotEmpty ? "Yes (${clientId.substring(0, 10)}...)" : "No"}');
    debugPrint('Client Secret loaded: ${clientSecret.isNotEmpty ? "Yes" : "No"}');
    
    // Don't initialize all_platforms for desktop - we'll use DesktopOAuthHandler
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      debugPrint('Using DesktopOAuthHandler for desktop platform');
      if (clientId.isEmpty || clientSecret.isEmpty) {
        debugPrint('ERROR: Google OAuth credentials not found in .env file');
        debugPrint('Windows Google Sign-In will not work without credentials');
      } else {
        // Initialize all_platforms GoogleSignIn for desktop with OAuth credentials
        _googleSignInDesktop = all_platforms.GoogleSignIn(
          params: all_platforms.GoogleSignInParams(
            clientId: clientId,
          ),
        );
      }
      // Don't initialize regular _googleSignIn for desktop
      _googleSignIn = null;
    } else if (!kIsWeb && Platform.isIOS) {
      // iOS uses standard Google Sign-In with GoogleService-Info.plist
      debugPrint('Using standard Google Sign-In for iOS');
      _googleSignIn = GoogleSignIn();
    } else if (!kIsWeb && Platform.isAndroid) {
      // Android uses standard Google Sign-In with google-services.json
      debugPrint('Using standard Google Sign-In for Android');
      _googleSignIn = GoogleSignIn();
    } else if (kIsWeb) {
      // Web doesn't need client configuration (uses Firebase Auth popup)
      debugPrint('Using Firebase Auth popup for web');
      _googleSignIn = null;
    }
  }

  // Current user
  User? get currentUser => _auth?.currentUser;
  Stream<User?> get authStateChanges => _auth?.authStateChanges() ?? Stream.value(null);

  // Sign up
  Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    
    final cred = await _auth!.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (cred.user != null) {
      await cred.user!.updateDisplayName(displayName);

      // Parse name parts
      final nameParts = displayName?.split(' ') ?? [];
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // Create user document with proper structure
      await _firestore!.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': email,
        'displayName': displayName,
        'firstName': firstName,
        'lastName': lastName,
        'photoURL': null,
        'role': null, // Will be set during role selection
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
    }

    return cred.user;
  }

  // Sign in with email
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    if (_auth == null || _firestore == null) {
      throw UnsupportedError('Firebase not available on Windows. Use mock authentication.');
    }
    
    final cred = await _auth!.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update last active
    if (cred.user != null) {
      await _firestore!.collection('users').doc(cred.user!.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }

    return cred.user;
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    if (_auth == null || _firestore == null) {
      throw UnsupportedError('Firebase not available. Check Firebase initialization.');
    }
    
    User? user;

    if (kIsWeb) {
      // Web: Use Firebase Auth popup
      debugPrint('Google Sign-In: Using Firebase popup for web');
      final provider = GoogleAuthProvider();
      final cred = await _auth!.signInWithPopup(provider);
      user = cred.user;
    } else if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      // Desktop: Use manual OAuth flow
      debugPrint('Google Sign-In: Using OAuth flow for desktop');
      
      final clientId = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'] ?? '';
      final clientSecret = dotenv.env['GOOGLE_OAUTH_CLIENT_SECRET'] ?? '';
      
      if (clientId.isEmpty || clientSecret.isEmpty) {
        throw Exception('Google OAuth credentials not configured. Please check .env file.');
      }
      
      try {
        // Perform OAuth flow
        final credentials = await _desktopOAuthHandler.performOAuthFlow(
          clientId: clientId,
          clientSecret: clientSecret,
        );
        
        if (credentials == null) {
          debugPrint('Google Sign-In: User cancelled or flow failed');
          return null;
        }
        
        debugPrint('Google Sign-In: Got OAuth credentials');
        debugPrint('ID Token present: ${credentials.idToken != null}');
        debugPrint('Access Token present: ${credentials.accessToken != null}');
        
        // Create Firebase credential
        final authCredential = GoogleAuthProvider.credential(
          idToken: credentials.idToken,
          accessToken: credentials.accessToken,
        );
        
        // Sign in to Firebase
        final cred = await _auth!.signInWithCredential(authCredential);
        user = cred.user;
        
        debugPrint('Google Sign-In: Successfully signed in user ${user?.email}');
      } catch (e) {
        debugPrint('Google Sign-In error: $e');
        rethrow;
      }
    } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Mobile: Use standard Google Sign-In SDK
      debugPrint('Google Sign-In: Using standard SDK for mobile');
      
      if (_googleSignIn == null) {
        throw Exception('Google Sign-In not initialized for mobile platform');
      }
      
      final googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) return null;

      // Get authentication tokens
      final googleAuth = await googleUser.authentication;
      
      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth!.signInWithCredential(credential);
      user = cred.user;
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
        final lastName =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        // Create user document
        await _firestore!.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName':
              user.displayName ?? user.email?.split('@').first ?? 'User',
          'firstName': firstName,
          'lastName': lastName,
          'photoURL': user.photoURL,
          'role': null, // Will be set during role selection
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });
      } else {
        // Update last active
        await _firestore!.collection('users').doc(user.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
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
          if (appleCredential.givenName != null || appleCredential.familyName != null) {
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
      debugPrint('Apple Sign-In error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth!.signOut();

    // Platform-specific sign out
    if (!kIsWeb) {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop: Revoke OAuth token
        try {
          await _desktopOAuthHandler.signOutFromGoogle();
          debugPrint('Sign Out: Revoked desktop OAuth token');
        } catch (e) {
          debugPrint('Sign Out: Failed to revoke token: $e');
        }
      } else if (_googleSignIn != null) {
        // Mobile: Sign out from Google Sign-In SDK
        try {
          await _googleSignIn!.signOut();
          debugPrint('Sign Out: Signed out from Google SDK');
        } catch (e) {
          debugPrint('Sign Out: Failed to sign out from Google: $e');
        }
      }
    }
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    await _auth!.sendPasswordResetEmail(email: email);
  }

  // Email verification
  Future<void> sendEmailVerification() async {
    await currentUser?.sendEmailVerification();
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
          'uid': uid,
          'email': userData['email'] ?? '',
          'displayName': userData['displayName'] ?? 'Student',
          'firstName': userData['firstName'] ?? '',
          'lastName': userData['lastName'] ?? '',
          'isActive': true,
          'classIds': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  // Save user role
  Future<void> saveUserRole({
    required String uid,
    required String role,
    required String email,
    String? displayName,
    String? photoURL,
  }) async {
    await _firestore!.collection('users').doc(uid).set({
      'uid': uid,
      'role': role,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
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
        await _firestore!.collection('students').doc(uid).delete().catchError((_) {
          // Continue even if student document doesn't exist
        });
      }

      // Delete from any other collections that might contain user data
      // Note: In a production app, you'd want to implement a more comprehensive
      // cleanup that removes user data from all relevant collections
      
      // Delete Firebase Auth account (this must be done last)
      await user.delete();
      
      debugPrint('User account deleted successfully');
    } catch (e) {
      debugPrint('Error deleting account: $e');
      
      // Handle common deletion errors
      if (e.toString().contains('requires-recent-login')) {
        throw Exception(
          'For security reasons, please sign in again before deleting your account.'
        );
      } else if (e.toString().contains('network-request-failed')) {
        throw Exception(
          'Network error. Please check your connection and try again.'
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
      debugPrint('Re-authentication failed: $e');
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
        await user.reauthenticateWithPopup(provider);
      } else if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        // Desktop: Use OAuth flow for re-authentication
        final clientId = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'] ?? '';
        final clientSecret = dotenv.env['GOOGLE_OAUTH_CLIENT_SECRET'] ?? '';
        
        final credentials = await _desktopOAuthHandler.performOAuthFlow(
          clientId: clientId,
          clientSecret: clientSecret,
        );
        
        if (credentials == null) {
          throw Exception('Google re-authentication was cancelled');
        }
        
        final authCredential = GoogleAuthProvider.credential(
          idToken: credentials.idToken,
          accessToken: credentials.accessToken,
        );
        
        await user.reauthenticateWithCredential(authCredential);
      } else if (_googleSignIn != null) {
        // Mobile: Use standard Google Sign-In SDK
        final googleUser = await _googleSignIn!.signIn();
        if (googleUser == null) {
          throw Exception('Google sign-in was cancelled');
        }

        // Get authentication tokens
        final googleAuth = await googleUser.authentication;
        
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await user.reauthenticateWithCredential(credential);
      } else {
        throw Exception('Google re-authentication not available on this platform');
      }
    } catch (e) {
      debugPrint('Google re-authentication failed: $e');
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
      debugPrint('Apple re-authentication failed: $e');
      throw Exception('Apple authentication failed. Please try again.');
    }
  }
}
