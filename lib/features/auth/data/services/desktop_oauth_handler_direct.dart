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

/// Direct OAuth handler for Windows desktop - no Firebase Functions needed
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

  /// Performs OAuth flow directly with Google
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

  /// Exchange authorization code for tokens
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

  /// Listen for OAuth redirect
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
            p { color: #666; }
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
            <p>You can close this tab and return to Fermi.</p>
            <script>setTimeout(() => window.close(), 2000);</script>
          </div>
        </body>
        </html>
      ''');

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

  /// Generate PKCE code verifier
  String _generateCodeVerifier() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List.generate(
      128,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Generate PKCE code challenge using SHA256
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Clean up resources
  void dispose() {
    _redirectServer?.close();
    _redirectServer = null;
    _codeVerifier = null;
  }
}
