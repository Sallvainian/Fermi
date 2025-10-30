import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/services/logger_service.dart';
import 'package.window_to_front/window_to_front.dart';

/// A secure OAuth handler for desktop platforms that uses a Firebase Functions
/// backend to keep client secrets off the client.
///
/// This approach is more secure than embedding OAuth client secrets in a desktop
/// application. It communicates with a set of Firebase Functions to orchestrate
/// the OAuth flow.
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
      return '${const String.fromEnvironment('FIREBASE_FUNCTIONS_EMULATOR_URL', defaultValue: 'http://localhost:5001')}/$_projectId/$_region';
    } else {
      // Production URL - can be overridden via build configuration
      final customUrl = const String.fromEnvironment('FIREBASE_FUNCTIONS_URL');
      if (customUrl.isNotEmpty) {
        return customUrl;
      }
      return 'https://$_region-$_projectId.cloudfunctions.net';
    }
  }

  static final String _getOAuthUrlEndpoint = '$_baseUrl/getOAuthUrl';
  static final String _exchangeCodeEndpoint = '$_baseUrl/exchangeOAuthCode';
  static final String _refreshTokenEndpoint = '$_baseUrl/refreshOAuthToken';

  HttpServer? _redirectServer;
  String? _codeVerifier;
  String? _state;

  /// Performs a secure OAuth flow using a Firebase Functions backend.
  ///
  /// This method orchestrates the following steps:
  /// 1. Requests an OAuth URL from a Firebase Function.
  /// 2. Opens the URL in the user's browser.
  /// 3. Listens for the redirect on a local server.
  /// 4. Sends the received authorization code to another Firebase Function.
  /// 5. Receives a Firebase custom token from the function.
  /// 6. Signs into Firebase with the custom token.
  ///
  /// Returns a [UserCredential] on success, or `null` on failure.
  Future<UserCredential?> performSecureOAuthFlow() async {
    try {
      LoggerService.info('Starting secure OAuth flow with Firebase Functions', tag: 'SecureOAuth');

      // Close any existing redirect server
      await _redirectServer?.close();
      _redirectServer = null;

      // Start local redirect server
      _redirectServer = await HttpServer.bind('localhost', 0);
      final port = _redirectServer!.port;
      final redirectUri = 'http://localhost:$port';

      LoggerService.info('Started local server on port $port', tag: 'SecureOAuth');

      // Step 1: Get OAuth URL from Firebase Function
      final oauthUrlResponse = await _getOAuthUrl(redirectUri);

      if (oauthUrlResponse == null) {
        throw Exception('Failed to get OAuth URL from server');
      }

      LoggerService.debug('Received OAuth URL from server', tag: 'SecureOAuth');

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

      LoggerService.info('Opening browser for authorization', tag: 'SecureOAuth');

      // Step 2: Open browser for user authorization
      await _openBrowser(authUrl);

      // Step 3: Listen for redirect with authorization code
      final authCode = await _listenForAuthCode();

      if (authCode == null) {
        throw Exception('No authorization code received');
      }

      LoggerService.info('Received authorization code; exchanging for tokens', tag: 'SecureOAuth');

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

      LoggerService.info('Successfully received Firebase custom token', tag: 'SecureOAuth');

      // Step 5: Sign in to Firebase with custom token
      final credential = await FirebaseAuth.instance.signInWithCustomToken(
        tokenResponse['firebaseToken'],
      );

      LoggerService.info('Signed in to Firebase', tag: 'SecureOAuth');
      LoggerService.debug('User UID: ${credential.user?.uid}', tag: 'SecureOAuth');
      LoggerService.debug('User Email: ${credential.user?.email}', tag: 'SecureOAuth');

      return credential;
    } catch (e) {
      LoggerService.error('SecureOAuth error', tag: 'SecureOAuth', error: e);
      await _redirectServer?.close();
      _redirectServer = null;

      // Provide helpful error messages
      if (e.toString().contains('Failed to get OAuth URL')) {
        throw Exception(
          'Could not connect to authentication server. Please check:\\n'
          '1. Firebase Functions are deployed\\n'
          '2. Network connection is active\\n'
          '3. Firebase project is configured correctly',
        );
      } else if (e.toString().contains('authorization code')) {
        throw Exception(
          'Authorization was cancelled or failed. Please try again.',
        );
      }

      rethrow;
    }
  }

  /// Fetches the OAuth authorization URL from the backend Firebase Function.
  ///
  /// - [redirectUri]: The local URI to which the OAuth provider should redirect.
  ///
  /// Returns a map containing the `authUrl`, `state`, and `codeVerifier`.
  Future<Map<String, dynamic>?> _getOAuthUrl(String redirectUri) async {
    try {
      LoggerService.debug('Requesting OAuth URL from: $_getOAuthUrlEndpoint', tag: 'SecureOAuth');
      LoggerService.debug('Redirect URI: $redirectUri', tag: 'SecureOAuth');

      final response = await http
          .get(
            Uri.parse(
              '$_getOAuthUrlEndpoint?redirect_uri=${Uri.encodeComponent(redirectUri)}',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              LoggerService.warning('OAuth URL request timed out after 10 seconds', tag: 'SecureOAuth');
              throw Exception('Request to OAuth server timed out');
            },
          );

      LoggerService.debug('OAuth URL response status: ${response.statusCode}', tag: 'SecureOAuth');
      // SecureOAuth: Response body logging removed to avoid exposing sensitive data.

      if (response.statusCode == 200) {
        try {
          final decoded = json.decode(response.body);
          LoggerService.debug('Successfully decoded OAuth URL response', tag: 'SecureOAuth');
          return decoded;
        } catch (e) {
          LoggerService.warning('Failed to decode OAuth URL JSON response', tag: 'SecureOAuth');
          return null;
        }
      } else {
        LoggerService.error('Failed to get OAuth URL - ${response.statusCode}', tag: 'SecureOAuth');
        return null;
      }
    } catch (e) {
      LoggerService.error('Error getting OAuth URL', tag: 'SecureOAuth', error: e);
      return null;
    }
  }

  /// Exchanges the authorization code for a Firebase custom token via a backend function.
  ///
  /// - [code]: The authorization code.
  /// - [state]: The CSRF state token.
  /// - [codeVerifier]: The PKCE code verifier.
  /// - [redirectUri]: The original redirect URI.
  ///
  /// Returns a map containing the `firebaseToken`.
  Future<Map<String, dynamic>?> _exchangeAuthCode({
    required String code,
    required String state,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_exchangeCodeEndpoint),
        headers: {'Content-Type': 'application/json'},
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
        LoggerService.error('Failed to exchange code - ${response.statusCode}', tag: 'SecureOAuth');
        return null;
      }
    } catch (e) {
      LoggerService.error('Error exchanging auth code', tag: 'SecureOAuth', error: e);
      return null;
    }
  }

  /// Opens the authorization URI in the user's default browser.
  ///
  /// Includes platform-specific fallbacks.
  ///
  /// - [authorizationUri]: The URI to open.
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
      LoggerService.warning('url_launcher failed; trying fallback...', tag: 'SecureOAuth');
    }

    // Platform-specific fallbacks with validated URI
    final sanitizedUrl = authorizationUri.toString();

    if (Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '', sanitizedUrl]);
        LoggerService.info('Opened browser using Windows fallback', tag: 'SecureOAuth');
        return;
      } catch (e) {
        LoggerService.warning('Windows fallback failed', tag: 'SecureOAuth');
      }
    }

    if (Platform.isMacOS) {
      try {
        await Process.run('open', [sanitizedUrl]);
        LoggerService.info('Opened browser using macOS fallback', tag: 'SecureOAuth');
        return;
      } catch (e) {
        LoggerService.warning('macOS fallback failed', tag: 'SecureOAuth');
      }
    }

    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [sanitizedUrl]);
        LoggerService.info('Opened browser using Linux fallback', tag: 'SecureOAuth');
        return;
      } catch (e) {
        LoggerService.warning('Linux fallback failed', tag: 'SecureOAuth');
      }
    }

    throw Exception('Cannot launch authorization URL: $authorizationUri');
  }

  /// Validates the authorization URI to prevent potential command injection.
  ///
  /// - [uri]: The URI to validate.
  ///
  /// Returns `true` if the URI is considered safe.
  bool _isValidAuthorizationUri(Uri uri) {
    LoggerService.debug('Validating URI: $uri', tag: 'SecureOAuth');
    LoggerService.debug('URI scheme: ${uri.scheme}', tag: 'SecureOAuth');
    LoggerService.debug('URI host: ${uri.host}', tag: 'SecureOAuth');

    // Must be HTTPS (or HTTP for localhost during development)
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' && uri.host == 'localhost')) {
      LoggerService.warning('Invalid URI scheme: ${uri.scheme}', tag: 'SecureOAuth');
      return false;
    }

    // Must be a Google accounts domain
    if (!uri.host.endsWith('google.com') &&
        !uri.host.endsWith('googleapis.com') &&
        uri.host != 'localhost' &&
        uri.host != 'accounts.google.com') {
      LoggerService.warning('Invalid URI host: ${uri.host}', tag: 'SecureOAuth');
      return false;
    }

    // Check for shell metacharacters that could cause command injection
    // Note: We exclude '&' and '=' as they are valid URL query parameter separators
    // We also exclude '?' as it's the query string separator
    final uriString = uri.toString();
    // Only check for truly dangerous shell metacharacters
    final dangerousChars = RegExp('[;|`\$<>"\'\\n\\r]');
    if (dangerousChars.hasMatch(uriString)) {
      LoggerService.warning('URI contains dangerous characters', tag: 'SecureOAuth');
      LoggerService.debug('Matched URI: $uriString', tag: 'SecureOAuth');
      return false;
    }

    LoggerService.debug('URI validation passed', tag: 'SecureOAuth');
    return true;
  }

  /// Listens for the OAuth redirect and extracts the authorization code.
  ///
  /// Also verifies the state parameter to prevent CSRF attacks.
  ///
  /// Returns the authorization code.
  Future<String?> _listenForAuthCode() async {
    try {
      LoggerService.info('Waiting for redirect...', tag: 'SecureOAuth');

      // Wait for the first HTTP request to our local server
      final request = await _redirectServer!.first;

      LoggerService.debug('Received request to ${request.uri}', tag: 'SecureOAuth');

      // Extract query parameters
      final params = request.uri.queryParameters;

      // Check for authorization code
      final code = params['code'];
      final returnedState = params['state'];

      // Verify state for CSRF protection
      if (returnedState != _state) {
        LoggerService.warning('State mismatch - possible CSRF attack', tag: 'SecureOAuth');
        throw Exception('State mismatch - possible security issue');
      }

      if (code == null) {
        LoggerService.warning('No authorization code in response', tag: 'SecureOAuth');

        // Check for error
        if (params.containsKey('error')) {
          final error = params['error'];
          final errorDescription =
              params['error_description'] ?? 'No description';
          LoggerService.warning('Authorization error: $error - $errorDescription', tag: 'SecureOAuth');
          throw Exception(
            'OAuth authorization failed: $error - $errorDescription',
          );
        }

        return null;
      }

      // Bring app window to front
      if (!kIsWeb) {
        try {
          await WindowToFront.activate();
        } catch (e) {
          LoggerService.warning('Could not bring window to front', tag: 'SecureOAuth');
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
        LoggerService.warning('Error sending response to browser', tag: 'SecureOAuth');
      }

      // Close the server
      await _redirectServer!.close();
      _redirectServer = null;

      LoggerService.info('Successfully received authorization code', tag: 'SecureOAuth');
      return code;
    } catch (e) {
      LoggerService.error('Listen error', tag: 'SecureOAuth', error: e);
      await _redirectServer?.close();
      _redirectServer = null;
      rethrow;
    }
  }

  /// Refreshes the access token using a refresh token via a backend function.
  ///
  /// - [refreshToken]: The refresh token to use.
  ///
  /// Returns a map containing the new tokens.
  Future<Map<String, dynamic>?> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(_refreshTokenEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        LoggerService.error('Failed to refresh token - ${response.statusCode}', tag: 'SecureOAuth');
        return null;
      }
    } catch (e) {
      LoggerService.error('Error refreshing token', tag: 'SecureOAuth', error: e);
      return null;
    }
  }

  /// Cleans up resources used by the handler.
  void dispose() {
    _redirectServer?.close();
    _redirectServer = null;
    _codeVerifier = null;
    _state = null;
  }
}
