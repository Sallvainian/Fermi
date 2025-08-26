import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_to_front/window_to_front.dart';

/// Secure OAuth handler for desktop platforms using Firebase Functions backend
/// This implementation keeps OAuth client secrets on the server side
class SecureDesktopOAuthHandler {
  // Get project ID and region from environment variables, with sensible defaults
  static String get _projectId => const String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'teacher-dashboard-flutterfire',
  );
  
  static String get _region => const String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'us-east4',
  );
  
  // Firebase Functions endpoints - configure via environment or use defaults
  static String get _baseUrl {
    if (kDebugMode) {
      // Local emulator for development
      return const String.fromEnvironment(
        'FIREBASE_FUNCTIONS_EMULATOR_URL',
        defaultValue: 'http://localhost:5001',
      ) + '/$_projectId/$_region';
    } else {
      // Production URL - can be overridden via build configuration
      final customUrl = const String.fromEnvironment('FIREBASE_FUNCTIONS_URL');
      if (customUrl.isNotEmpty) {
        return customUrl;
      }
      return 'https://$_region-$_projectId.cloudfunctions.net';
    }
  }
  
  static late final String _getOAuthUrlEndpoint = '$_baseUrl/getOAuthUrl';
  static late final String _exchangeCodeEndpoint = '$_baseUrl/exchangeOAuthCode';
  static late final String _refreshTokenEndpoint = '$_baseUrl/refreshOAuthToken';
  
  HttpServer? _redirectServer;
  String? _codeVerifier;
  String? _state;
  
  /// Performs secure OAuth flow using Firebase Functions backend
  Future<UserCredential?> performSecureOAuthFlow() async {
    try {
      debugPrint('SecureOAuth: Starting secure OAuth flow with Firebase Functions');
      
      // Close any existing redirect server
      await _redirectServer?.close();
      _redirectServer = null;
      
      // Start local redirect server
      _redirectServer = await HttpServer.bind('localhost', 0);
      final port = _redirectServer!.port;
      final redirectUri = 'http://localhost:$port';
      
      debugPrint('SecureOAuth: Started local server on port $port');
      
      // Step 1: Get OAuth URL from Firebase Function
      final oauthUrlResponse = await _getOAuthUrl(redirectUri);
      
      if (oauthUrlResponse == null) {
        throw Exception('Failed to get OAuth URL from server');
      }
      
      debugPrint('SecureOAuth: Received OAuth URL response: $oauthUrlResponse');
      
      if (!oauthUrlResponse.containsKey('authUrl')) {
        throw Exception('OAuth response missing authUrl field');
      }
      
      final authUrlString = oauthUrlResponse['authUrl'];
      if (authUrlString == null || authUrlString.isEmpty) {
        throw Exception('OAuth authUrl is empty');
      }
      
      final authUrl = Uri.parse(authUrlString);
      _state = oauthUrlResponse['state'];
      _codeVerifier = oauthUrlResponse['codeVerifier'];
      
      debugPrint('SecureOAuth: Opening browser for authorization');
      
      // Step 2: Open browser for user authorization
      await _openBrowser(authUrl);
      
      // Step 3: Listen for redirect with authorization code
      final authCode = await _listenForAuthCode();
      
      if (authCode == null) {
        throw Exception('No authorization code received');
      }
      
      debugPrint('SecureOAuth: Received authorization code, exchanging for tokens');
      
      // Step 4: Exchange code for tokens via Firebase Function
      final tokenResponse = await _exchangeAuthCode(
        code: authCode,
        state: _state!,
        codeVerifier: _codeVerifier!,
        redirectUri: redirectUri,
      );
      
      if (tokenResponse == null) {
        throw Exception('Failed to exchange authorization code');
      }
      
      debugPrint('SecureOAuth: Successfully received Firebase custom token');
      
      // Step 5: Sign in to Firebase with custom token
      final credential = await FirebaseAuth.instance.signInWithCustomToken(
        tokenResponse['firebaseToken'],
      );
      
      debugPrint('SecureOAuth: Successfully signed in to Firebase');
      debugPrint('SecureOAuth: User UID: ${credential.user?.uid}');
      debugPrint('SecureOAuth: User Email: ${credential.user?.email}');
      
      return credential;
      
    } catch (e) {
      debugPrint('SecureOAuth Error: $e');
      await _redirectServer?.close();
      _redirectServer = null;
      
      // Provide helpful error messages
      if (e.toString().contains('Failed to get OAuth URL')) {
        throw Exception(
          'Could not connect to authentication server. Please check:\\n'
          '1. Firebase Functions are deployed\\n'
          '2. Network connection is active\\n'
          '3. Firebase project is configured correctly'
        );
      } else if (e.toString().contains('authorization code')) {
        throw Exception(
          'Authorization was cancelled or failed. Please try again.'
        );
      }
      
      rethrow;
    }
  }
  
  /// Gets OAuth URL from Firebase Function
  Future<Map<String, dynamic>?> _getOAuthUrl(String redirectUri) async {
    try {
      debugPrint('SecureOAuth: Requesting OAuth URL from: $_getOAuthUrlEndpoint');
      debugPrint('SecureOAuth: Redirect URI: $redirectUri');
      
      final response = await http.get(
        Uri.parse('$_getOAuthUrlEndpoint?redirect_uri=${Uri.encodeComponent(redirectUri)}'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('SecureOAuth: Request timed out after 10 seconds');
          throw Exception('Request to OAuth server timed out');
        },
      );
      
      debugPrint('SecureOAuth: Response status: ${response.statusCode}');
      debugPrint('SecureOAuth: Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          final decoded = json.decode(response.body);
          debugPrint('SecureOAuth: Successfully decoded response');
          return decoded;
        } catch (e) {
          debugPrint('SecureOAuth: Failed to decode JSON response: $e');
          return null;
        }
      } else {
        debugPrint('SecureOAuth: Failed to get OAuth URL - ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('SecureOAuth: Error getting OAuth URL: $e');
      debugPrint('SecureOAuth: Error type: ${e.runtimeType}');
      return null;
    }
  }
  
  /// Exchanges authorization code for tokens via Firebase Function
  Future<Map<String, dynamic>?> _exchangeAuthCode({
    required String code,
    required String state,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_exchangeCodeEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'code': code,
          'state': state,
          'codeVerifier': codeVerifier,
          'redirectUri': redirectUri,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('SecureOAuth: Failed to exchange code - ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('SecureOAuth: Error exchanging auth code: $e');
      return null;
    }
  }
  
  /// Opens the authorization URL in the default browser
  Future<void> _openBrowser(Uri authorizationUri) async {
    // Validate URI to prevent command injection
    if (!_isValidAuthorizationUri(authorizationUri)) {
      throw Exception('Invalid authorization URI format');
    }
    
    try {
      // Try url_launcher first
      if (await canLaunchUrl(authorizationUri)) {
        await launchUrl(authorizationUri);
        return;
      }
    } catch (e) {
      debugPrint('url_launcher failed: $e, trying fallback...');
    }
    
    // Platform-specific fallbacks with validated URI
    final sanitizedUrl = authorizationUri.toString();
    
    if (Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '', sanitizedUrl]);
        debugPrint('SecureOAuth: Opened browser using Windows fallback');
        return;
      } catch (e) {
        debugPrint('Windows fallback failed: $e');
      }
    }
    
    if (Platform.isMacOS) {
      try {
        await Process.run('open', [sanitizedUrl]);
        debugPrint('SecureOAuth: Opened browser using macOS fallback');
        return;
      } catch (e) {
        debugPrint('macOS fallback failed: $e');
      }
    }
    
    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [sanitizedUrl]);
        debugPrint('SecureOAuth: Opened browser using Linux fallback');
        return;
      } catch (e) {
        debugPrint('Linux fallback failed: $e');
      }
    }
    
    throw Exception('Cannot launch authorization URL: $authorizationUri');
  }
  
  /// Validates that the authorization URI is safe to pass to shell commands
  bool _isValidAuthorizationUri(Uri uri) {
    debugPrint('SecureOAuth: Validating URI: $uri');
    debugPrint('SecureOAuth: URI scheme: ${uri.scheme}');
    debugPrint('SecureOAuth: URI host: ${uri.host}');
    
    // Must be HTTPS (or HTTP for localhost during development)
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && uri.host == 'localhost')) {
      debugPrint('SecureOAuth: Invalid URI scheme: ${uri.scheme}');
      return false;
    }
    
    // Must be a Google accounts domain
    if (!uri.host.endsWith('google.com') && !uri.host.endsWith('googleapis.com') && 
        uri.host != 'localhost' && uri.host != 'accounts.google.com') {
      debugPrint('SecureOAuth: Invalid URI host: ${uri.host}');
      return false;
    }
    
    // Check for shell metacharacters that could cause command injection
    // Note: We exclude '&' and '=' as they are valid URL query parameter separators
    // We also exclude '?' as it's the query string separator
    final uriString = uri.toString();
    // Only check for truly dangerous shell metacharacters
    final dangerousChars = RegExp('[;|`\$<>"\'\\n\\r]');
    if (dangerousChars.hasMatch(uriString)) {
      debugPrint('SecureOAuth: URI contains dangerous characters');
      debugPrint('SecureOAuth: Matched character in URI: $uriString');
      return false;
    }
    
    debugPrint('SecureOAuth: URI validation passed');
    return true;
  }
  
  /// Listens for the OAuth redirect and extracts the authorization code
  Future<String?> _listenForAuthCode() async {
    try {
      debugPrint('SecureOAuth: Waiting for redirect...');
      
      // Wait for the first HTTP request to our local server
      final request = await _redirectServer!.first;
      
      debugPrint('SecureOAuth: Received request to ${request.uri}');
      
      // Extract query parameters
      final params = request.uri.queryParameters;
      
      // Check for authorization code
      final code = params['code'];
      final returnedState = params['state'];
      
      // Verify state for CSRF protection
      if (returnedState != _state) {
        debugPrint('SecureOAuth: State mismatch - possible CSRF attack');
        throw Exception('State mismatch - possible security issue');
      }
      
      if (code == null) {
        debugPrint('SecureOAuth: No authorization code in response');
        
        // Check for error
        if (params.containsKey('error')) {
          final error = params['error'];
          final errorDescription = params['error_description'] ?? 'No description';
          debugPrint('SecureOAuth: Authorization error: $error - $errorDescription');
          throw Exception('OAuth authorization failed: $error - $errorDescription');
        }
        
        return null;
      }
      
      // Bring app window to front
      if (!kIsWeb) {
        try {
          await WindowToFront.activate();
        } catch (e) {
          debugPrint('SecureOAuth: Could not bring window to front: $e');
        }
      }
      
      // Send success response to browser
      try {
        request.response.statusCode = 200;
        request.response.headers.set('content-type', 'text/html');
        request.response.write('''
          <!DOCTYPE html>
          <html>
          <head>
            <title>Authentication Successful</title>
            <style>
              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              }
              .container {
                text-align: center;
                padding: 2rem;
                background: white;
                border-radius: 10px;
                box-shadow: 0 10px 25px rgba(0,0,0,0.1);
              }
              h1 { color: #333; margin-bottom: 1rem; }
              p { color: #666; margin-bottom: 1.5rem; }
              .checkmark { 
                width: 60px; 
                height: 60px; 
                margin: 0 auto 1rem;
                background: #4CAF50;
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
              }
              .checkmark:after {
                content: '✓';
                color: white;
                font-size: 30px;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="checkmark"></div>
              <h1>Authentication Successful!</h1>
              <p>You can close this tab and return to the Fermi application.</p>
              <script>setTimeout(() => window.close(), 3000);</script>
            </div>
          </body>
          </html>
        ''');
        
        await request.response.close();
      } catch (e) {
        debugPrint('SecureOAuth: Error sending response to browser: $e');
      }
      
      // Close the server
      await _redirectServer!.close();
      _redirectServer = null;
      
      debugPrint('SecureOAuth: Successfully received authorization code');
      return code;
      
    } catch (e) {
      debugPrint('SecureOAuth listen error: $e');
      await _redirectServer?.close();
      _redirectServer = null;
      rethrow;
    }
  }
  
  /// Refreshes the access token using a refresh token
  Future<Map<String, dynamic>?> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(_refreshTokenEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'refreshToken': refreshToken,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('SecureOAuth: Failed to refresh token - ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('SecureOAuth: Error refreshing token: $e');
      return null;
    }
  }
  
  /// Cleans up resources
  void dispose() {
    _redirectServer?.close();
    _redirectServer = null;
    _codeVerifier = null;
    _state = null;
  }
}