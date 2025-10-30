import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../shared/services/logger_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_to_front/window_to_front.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';

/// Handles the desktop OAuth2 flow directly with Google's servers, using PKCE.
///
/// This implementation avoids the need for a backend function to handle the token
/// exchange, making it suitable for desktop applications where a client secret
/// can be securely stored. It retrieves credentials from compile-time environment
/// variables for release builds and falls back to a `.env` file for development.
class DirectDesktopOAuthHandler {
  // OAuth 2.0 Client ID and Secret from Google Cloud Console
  // These are injected at compile time via --dart-define flags
  // CRITICAL: Must be const for String.fromEnvironment to work in release builds!
  static const String _compiledClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue: '',
  );

  static const String _compiledClientSecret = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_SECRET',
    defaultValue: '',
  );

  /// The Google OAuth client ID.
  static String get _clientId {
    // First try compile-time constant (for production builds)
    if (_compiledClientId.isNotEmpty) {
      return _compiledClientId;
    }

    // Fall back to .env file (for local development)
    try {
      final envValue = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'];
      return envValue ?? ''; // Return empty string if not configured
    } catch (e) {
      // If dotenv isn't loaded
      return ''; // Return empty string instead of throwing
    }
  }

  /// The Google OAuth client secret.
  static String get _clientSecret {
    // First try compile-time constant (for production builds)
    if (_compiledClientSecret.isNotEmpty) {
      return _compiledClientSecret;
    }

    // Fall back to .env file (for local development)
    try {
      final envValue = dotenv.env['GOOGLE_OAUTH_CLIENT_SECRET'];
      return envValue ?? ''; // Return empty string if not configured
    } catch (e) {
      // If dotenv isn't loaded
      return ''; // Return empty string instead of throwing
    }
  }

  HttpServer? _redirectServer;
  String? _codeVerifier;

  /// Performs the complete direct OAuth2 flow with Google and signs into Firebase.
  ///
  /// This method orchestrates the PKCE flow:
  /// 1. Generates a code verifier and challenge.
  /// 2. Opens the browser for user authorization.
  /// 3. Listens for the redirect and captures the authorization code.
  /// 4. Exchanges the code for an ID token and access token.
  /// 5. Uses the tokens to create a Firebase [UserCredential].
  ///
  /// Returns the [UserCredential] on success, or `null` on failure.
  Future<UserCredential?> performDirectOAuthFlow() async {
    try {
      LoggerService.info('Starting direct OAuth flow', tag: 'DirectOAuth');
      LoggerService.debug('Platform: ${Platform.operatingSystem}', tag: 'DirectOAuth');

      // Debug: Check how credentials are loaded
      LoggerService.debug('Compiled Client ID present: ${_compiledClientId.isNotEmpty}', tag: 'DirectOAuth');
      LoggerService.debug('Compiled Secret present: ${_compiledClientSecret.isNotEmpty}', tag: 'DirectOAuth');

      // Check if credentials are configured
      if (_clientId.isEmpty || _clientSecret.isEmpty) {
        LoggerService.error('Missing OAuth credentials', tag: 'DirectOAuth');
        LoggerService.debug('Client ID empty: ${_clientId.isEmpty}', tag: 'DirectOAuth');
        LoggerService.debug('Client Secret empty: ${_clientSecret.isEmpty}', tag: 'DirectOAuth');
        LoggerService.debug('Compile-time: ClientID=${_compiledClientId.isNotEmpty}, Secret=${_compiledClientSecret.isNotEmpty}', tag: 'DirectOAuth');
        LoggerService.debug('Dotenv has GOOGLE_OAUTH_CLIENT_ID: ${dotenv.env.containsKey('GOOGLE_OAUTH_CLIENT_ID')}', tag: 'DirectOAuth');

        // More helpful error message
        throw Exception(
          'Google Sign-In is not available. The application was not built with OAuth credentials.\n\n'
          'For developers: Build with --dart-define flags or add .env file.\n'
          'For users: Please use email/password sign-in or contact support for an updated version.',
        );
      }

      LoggerService.debug('Client ID: ${_clientId.substring(0, 20)}...', tag: 'DirectOAuth');
      LoggerService.debug('Client Secret present: ${_clientSecret.isNotEmpty}', tag: 'DirectOAuth');

      // Close any existing redirect server
      await _redirectServer?.close();
      _redirectServer = null;

      // Start local redirect server
      _redirectServer = await HttpServer.bind('localhost', 0);
      final port = _redirectServer!.port;
      final redirectUri = 'http://localhost:$port';

      LoggerService.info('Started local server on port $port', tag: 'DirectOAuth');

      // Generate PKCE parameters
      _codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(_codeVerifier!);

      // Build authorization URL
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      LoggerService.info('Opening browser for authorization', tag: 'DirectOAuth');

      // Open browser
      if (!await launchUrl(authUrl)) {
        throw Exception('Could not launch authorization URL');
      }

      // Listen for redirect
      final code = await _listenForAuthCode();

      if (code == null) {
        throw Exception('No authorization code received');
      }

      LoggerService.info('Received authorization code', tag: 'DirectOAuth');

      // Exchange code for tokens
      final tokens = await _exchangeCodeForTokens(
        code: code,
        redirectUri: redirectUri,
        codeVerifier: _codeVerifier!,
      );

      if (tokens == null) {
        throw Exception('Failed to exchange authorization code');
      }

      LoggerService.info('Successfully received tokens', tag: 'DirectOAuth');

      // Sign in to Firebase with Google credential
      final credential = GoogleAuthProvider.credential(
        idToken: tokens['id_token'],
        accessToken: tokens['access_token'],
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      LoggerService.info('Successfully signed in to Firebase', tag: 'DirectOAuth');
      LoggerService.debug('User Email: ${userCredential.user?.email}', tag: 'DirectOAuth');

      return userCredential;
    } catch (e) {
      LoggerService.error('DirectOAuth error', tag: 'DirectOAuth', error: e);
      await _redirectServer?.close();
      _redirectServer = null;

      if (e.toString().contains('Could not launch')) {
        throw Exception('Failed to open browser for authentication');
      } else if (e.toString().contains('authorization code')) {
        throw Exception('Authorization was cancelled or failed');
      }

      rethrow;
    }
  }

  /// Exchanges the authorization code for an ID token and access token.
  ///
  /// - [code]: The authorization code.
  /// - [redirectUri]: The redirect URI used in the initial request.
  /// - [codeVerifier]: The PKCE code verifier.
  ///
  /// Returns a map containing the tokens.
  Future<Map<String, dynamic>?> _exchangeCodeForTokens({
    required String code,
    required String redirectUri,
    required String codeVerifier,
  }) async {
    try {
      final response = await http.post(
        Uri.https('oauth2.googleapis.com', '/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'code': code,
          'code_verifier': codeVerifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        LoggerService.error('Token exchange failed - ${response.statusCode}', tag: 'DirectOAuth');
        return null;
      }
    } catch (e) {
      LoggerService.error('Error exchanging code', tag: 'DirectOAuth', error: e);
      return null;
    }
  }

  /// Listens for the OAuth redirect on the local server and extracts the auth code.
  ///
  /// Returns the authorization code, or `null` if an error occurs.
  Future<String?> _listenForAuthCode() async {
    try {
      LoggerService.info('Waiting for redirect...', tag: 'DirectOAuth');

      final request = await _redirectServer!.first;
      LoggerService.debug('Received request to ${request.uri}', tag: 'DirectOAuth');

      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];
      final errorDescription = request.uri.queryParameters['error_description'];

      if (error != null) {
        LoggerService.warning('Authorization error: $error', tag: 'DirectOAuth');
        LoggerService.warning('Error description: $errorDescription', tag: 'DirectOAuth');

        // Provide user-friendly error messages
        if (error == 'invalid_client') {
          throw Exception(
            'OAuth client configuration error. The client ID may not be configured for desktop apps.',
          );
        } else if (error == 'redirect_uri_mismatch') {
          throw Exception(
            'Redirect URI mismatch. Add http://localhost to authorized redirect URIs in Google Cloud Console.',
          );
        } else if (error == 'access_denied') {
          throw Exception('Authorization was cancelled by the user.');
        } else {
          throw Exception(
            'OAuth authorization failed: ${errorDescription ?? error}',
          );
        }
      }

      // Bring app to front
      if (!kIsWeb) {
        try {
          await WindowToFront.activate();
        } catch (e) {
          LoggerService.warning('Could not bring window to front', tag: 'DirectOAuth');
        }
      }

      // Send success response
      request.response.statusCode = 200;
      request.response.headers.set('content-type', 'text/html; charset=utf-8');

      // Use add with UTF-8 bytes to avoid string encoding issues
      final successPage = '''
<!DOCTYPE html>
<html>
<head><title>Success</title></head>
<body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
<h1>Authentication Successful!</h1>
<p>You can close this window and return to Fermi.</p>
</body>
</html>''';

      request.response.add(utf8.encode(successPage));

      await request.response.close();
      await _redirectServer!.close();
      _redirectServer = null;

      return code;
    } catch (e) {
      LoggerService.error('Listen error', tag: 'DirectOAuth', error: e);
      await _redirectServer?.close();
      _redirectServer = null;
      rethrow;
    }
  }

  /// Generates a cryptographically random string for the PKCE code verifier.
  String _generateCodeVerifier() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List.generate(
      128,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Generates a SHA256 code challenge from a code verifier for PKCE.
  ///
  /// - [verifier]: The code verifier.
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Cleans up resources, such as the local HTTP server.
  void dispose() {
    _redirectServer?.close();
    _redirectServer = null;
    _codeVerifier = null;
  }
}
