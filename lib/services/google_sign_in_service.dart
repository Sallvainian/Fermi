import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service class that manages Google Sign In using the singleton pattern.
/// 
/// This service wraps the GoogleSignIn singleton instance and provides
/// a centralized way to manage authentication with Google.
/// 
/// In google_sign_in 7.x:
/// - GoogleSignIn is now a singleton (GoogleSignIn.instance)
/// - Must call initialize() before any other operations
/// - signIn() → authenticate()
/// - signInSilently() → attemptLightweightAuthentication()
/// - currentUser getter → authenticationEvents stream
/// - Authentication (ID tokens) and Authorization (access tokens) are separate
class GoogleSignInService {
  // Private constructor for singleton pattern
  GoogleSignInService._internal();

  // Static instance
  static final GoogleSignInService _instance = GoogleSignInService._internal();

  // Factory constructor to return the singleton instance
  factory GoogleSignInService() {
    return _instance;
  }

  // Track initialization status
  bool _isInitialized = false;
  
  // Current user from the authentication events stream
  GoogleSignInAccount? _currentUser;
  
  // Stream subscription for authentication events
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventSubscription;
  
  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;
  
  /// Check if the current platform supports google_sign_in
  bool get isPlatformSupported {
    if (kIsWeb) return true;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) return true;
    // Windows and Linux are not supported by google_sign_in
    return false;
  }

  /// Initialize the GoogleSignIn instance.
  /// 
  /// This must be called once before using any other methods.
  /// Typically called from main() or during app initialization.
  /// 
  /// In google_sign_in 7.x, this calls GoogleSignIn.instance.initialize()
  /// Note: On Windows/Linux, this is a no-op as google_sign_in is not supported
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('GoogleSignInService already initialized');
      }
      return;
    }

    // Check platform support
    if (!isPlatformSupported) {
      if (kDebugMode) {
        print('GoogleSignInService: Platform not supported for google_sign_in. Will use Firebase Auth OAuth flow.');
      }
      _isInitialized = true; // Mark as initialized even on unsupported platforms
      return;
    }

    try {
      // Initialize the GoogleSignIn singleton
      await GoogleSignIn.instance.initialize();
      
      // Listen to authentication events to track current user
      // In 7.x, GoogleSignInAuthenticationEvent is a sealed class
      _authEventSubscription = GoogleSignIn.instance.authenticationEvents.listen((event) {
        // Use pattern matching to handle the sealed class
        _currentUser = switch (event) {
          GoogleSignInAuthenticationEventSignIn() => event.user,
          GoogleSignInAuthenticationEventSignOut() => null,
        };
        
        if (kDebugMode) {
          print('Google Sign In auth event: ${_currentUser?.email ?? "signed out"}');
        }
      });
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('GoogleSignInService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('GoogleSignInService initialization error: $e');
      }
      rethrow;
    }
  }

  /// Sign in with Google interactively.
  /// 
  /// Triggers the Google sign-in flow and returns the signed-in account.
  /// Returns null if the user cancels the sign-in.
  /// 
  /// In google_sign_in 7.x, this uses authenticate() instead of signIn()
  /// On unsupported platforms (Windows/Linux), returns null - use Firebase Auth instead
  Future<GoogleSignInAccount?> signIn() async {
    if (!_isInitialized) {
      throw StateError('GoogleSignInService not initialized. Call initialize() first.');
    }
    
    if (!isPlatformSupported) {
      if (kDebugMode) {
        print('Google sign in not supported on this platform. Use Firebase Auth OAuth flow instead.');
      }
      return null;
    }
    
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account;
    } catch (e) {
      if (kDebugMode) {
        print('Google sign in error: $e');
      }
      rethrow;
    }
  }

  /// Sign out from Google.
  /// 
  /// Signs out the current Google user.
  /// In 7.x, this returns Future&lt;void&gt; instead of Future&lt;GoogleSignInAccount?&gt;
  /// On unsupported platforms (Windows/Linux), this is a no-op
  Future<void> signOut() async {
    if (!_isInitialized) {
      throw StateError('GoogleSignInService not initialized. Call initialize() first.');
    }
    
    if (!isPlatformSupported) {
      if (kDebugMode) {
        print('Google sign out not needed on this platform (handled by Firebase Auth)');
      }
      return;
    }
    
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Google sign out error: $e');
      }
      rethrow;
    }
  }

  /// Disconnect from Google.
  /// 
  /// Signs out and disconnects the Google account, clearing cached authentication.
  /// In 7.x, this returns Future&lt;void&gt; instead of Future&lt;GoogleSignInAccount?&gt;
  /// On unsupported platforms (Windows/Linux), this is a no-op
  Future<void> disconnect() async {
    if (!_isInitialized) {
      throw StateError('GoogleSignInService not initialized. Call initialize() first.');
    }
    
    if (!isPlatformSupported) {
      if (kDebugMode) {
        print('Google disconnect not needed on this platform (handled by Firebase Auth)');
      }
      return;
    }
    
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      if (kDebugMode) {
        print('Google disconnect error: $e');
      }
      rethrow;
    }
  }

  /// Attempt lightweight authentication (silent sign in).
  /// 
  /// Attempts to sign in a previously authenticated user without interaction.
  /// Returns null if no previously authenticated user is available.
  /// 
  /// In google_sign_in 7.x, this uses attemptLightweightAuthentication()
  /// instead of signInSilently()
  /// On unsupported platforms (Windows/Linux), returns null
  Future<GoogleSignInAccount?> signInSilently() async {
    if (!_isInitialized) {
      throw StateError('GoogleSignInService not initialized. Call initialize() first.');
    }
    
    if (!isPlatformSupported) {
      if (kDebugMode) {
        print('Google silent sign in not supported on this platform');
      }
      return null;
    }
    
    try {
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      return account;
    } catch (e) {
      if (kDebugMode) {
        print('Google silent sign in error: $e');
      }
      rethrow;
    }
  }

  /// Get the current signed-in account.
  /// 
  /// Returns null if no user is signed in.
  /// In 7.x, currentUser is tracked via authenticationEvents stream
  GoogleSignInAccount? get currentUser {
    if (!_isInitialized) {
      return null;
    }
    return _currentUser;
  }

  /// Check if a user is currently signed in.
  bool get isSignedIn {
    return currentUser != null;
  }

  /// Request scopes from the user.
  /// 
  /// This is needed for accessing Google APIs beyond basic profile.
  /// In google_sign_in 7.x, scopes should be requested during sign-in
  /// by configuring them in GoogleSignIn.instance before authentication.
  /// 
  /// If you need additional scopes after sign-in, you may need to
  /// re-authenticate the user with the new scopes.
  /// On unsupported platforms (Windows/Linux), returns false
  Future<bool> requestScopes(List<String> scopes) async {
    if (!_isInitialized) {
      throw StateError('GoogleSignInService not initialized. Call initialize() first.');
    }
    
    if (!isPlatformSupported) {
      if (kDebugMode) {
        print('Google scope request not supported on this platform');
      }
      return false;
    }
    
    try {
      // In 7.x, scopes are configured before authentication
      // To request new scopes, typically need to sign out and sign in again
      // with the updated scopes configuration
      if (kDebugMode) {
        print('Note: In google_sign_in 7.x, scopes should be configured before authentication');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Request scopes error: $e');
      }
      rethrow;
    }
  }

  /// Clean up resources
  void dispose() {
    _authEventSubscription?.cancel();
    _authEventSubscription = null;
  }
}