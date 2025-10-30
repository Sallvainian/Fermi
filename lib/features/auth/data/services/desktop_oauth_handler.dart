import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../shared/services/logger_service.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package.window_to_front/window_to_front.dart';

/// A custom HTTP client that adds an 'Accept: application/json' header
/// to every request, which is required by some OAuth2 token endpoints.
class JsonAcceptingHttpClient extends http.BaseClient {
  final _httpClient = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Accept'] = 'application/json';
    return _httpClient.send(request);
  }
}

/// Handles the OAuth2 authentication flow for desktop platforms (Windows, macOS, Linux).
///
/// This class orchestrates the process of opening a browser for user authorization,
/// listening for the redirect on a local server, and exchanging the authorization
/// code for an access token.
class DesktopOAuthHandler {
  static const String _googleAuthApi =
      "https://accounts.google.com/o/oauth2/v2/auth";
  static const String _googleTokenApi = "https://oauth2.googleapis.com/token";
  static const String _revokeTokenUrl = 'https://oauth2.googleapis.com/revoke';
  static const String _emailScope = 'email';
  static const String _profileScope = 'profile';
  static const String _openIdScope = 'openid';

  HttpServer? _redirectServer;
  String? _lastAccessToken;

  /// Performs the complete OAuth2 flow for desktop applications.
  ///
  /// This method starts a local server to listen for the OAuth redirect,
  /// opens the user's browser for authorization, and exchanges the received
  /// authorization code for OAuth2 credentials.
  ///
  /// - [clientId]: The OAuth2 client ID.
  /// - [clientSecret]: The OAuth2 client secret.
  ///
  /// Returns the [oauth2.Credentials] on success, or `null` on failure.
  Future<oauth2.Credentials?> performOAuthFlow({
    required String clientId,
    required String clientSecret,
  }) async {
    try {
      // Validate inputs
      if (clientId.isEmpty || clientSecret.isEmpty) {
        throw ArgumentError('OAuth client ID and secret are required');
      }

      LoggerService.info(
        'OAuth: Starting flow with client ID: ${clientId.substring(0, 10)}...',
        tag: 'DesktopOAuth',
      );

      // Close any existing redirect server
      await _redirectServer?.close();
      _redirectServer = null;

      // Start a new HTTP server on a random port
      _redirectServer = await HttpServer.bind('localhost', 0);
      final port = _redirectServer!.port;
      final redirectUrl = 'http://localhost:$port';

      LoggerService.info(
        'OAuth: Started local server on port $port',
        tag: 'DesktopOAuth',
      );
      LoggerService.info(
        'OAuth: Redirect URI: $redirectUrl',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        '=== IMPORTANT: Google Cloud Console Configuration ===',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        '1. OAuth 2.0 Client Type: Web application (NOT Desktop!)',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        '2. Authorized JavaScript origins: http://localhost',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        '3. Authorized redirect URIs: http://localhost',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        '   (Both should be WITHOUT port number)',
        tag: 'DesktopOAuth',
      );

      // Create OAuth2 client
      final client = await _getOauthClient(
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUri: Uri.parse(redirectUrl),
      );

      // Store access token for sign-out
      _lastAccessToken = client.credentials.accessToken;

      return client.credentials;
    } catch (e) {
      LoggerService.error('OAuth flow error', error: e, tag: 'DesktopOAuth');
      await _redirectServer?.close();
      _redirectServer = null;

      // Provide helpful error messages
      if (e.toString().contains('invalid_client')) {
        throw Exception(
          'Invalid OAuth client configuration. Please verify:\n'
          '1. Client ID and Secret in .env file match Google Cloud Console\n'
          '2. OAuth client type is "Web application" (NOT Desktop) in Google Cloud Console\n'
          '3. "http://localhost" is in both Authorized redirect URIs AND Authorized JavaScript origins',
        );
      } else if (e.toString().contains('invalid_grant')) {
        throw Exception(
          'Authorization failed. This usually means:\n'
          '1. The authorization code expired (try again)\n'
          '2. Redirect URI mismatch (check Google Cloud Console)\n'
          '3. Client credentials are incorrect',
        );
      }

      rethrow;
    }
  }

  /// Creates an OAuth2 client and handles the authorization code exchange.
  ///
  /// - [clientId]: The OAuth2 client ID.
  /// - [clientSecret]: The OAuth2 client secret.
  /// - [redirectUri]: The local redirect URI.
  ///
  /// Returns a fully authenticated [oauth2.Client].
  Future<oauth2.Client> _getOauthClient({
    required String clientId,
    required String clientSecret,
    required Uri redirectUri,
  }) async {
    // Create authorization grant
    final grant = oauth2.AuthorizationCodeGrant(
      clientId,
      Uri.parse(_googleAuthApi),
      Uri.parse(_googleTokenApi),
      httpClient: JsonAcceptingHttpClient(),
      secret: clientSecret,
    );

    // Get authorization URL with required scopes
    final authorizationUrl = grant.getAuthorizationUrl(
      redirectUri,
      scopes: [_emailScope, _profileScope, _openIdScope],
    );

    LoggerService.info(
      'OAuth: Opening browser for authorization',
      tag: 'DesktopOAuth',
    );

    // Open browser for user authorization
    await _redirect(authorizationUrl);

    // Listen for redirect with authorization code
    final responseParams = await _listen();

    // Exchange authorization code for access token
    LoggerService.info(
      'OAuth: Exchanging authorization code for tokens...',
      tag: 'DesktopOAuth',
    );

    try {
      final client = await grant.handleAuthorizationResponse(responseParams);

      LoggerService.info(
        'OAuth: Successfully obtained access token',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        'OAuth: ID Token present: ${client.credentials.idToken != null}',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        'OAuth: Access Token present: ${client.credentials.accessToken.isNotEmpty}',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        'OAuth: Refresh Token present: ${client.credentials.refreshToken != null}',
        tag: 'DesktopOAuth',
      );

      return client;
    } catch (e) {
      LoggerService.error(
        'OAuth: Token exchange failed',
        error: e,
        tag: 'DesktopOAuth',
      );
      if (e.toString().contains('invalid_grant')) {
        throw Exception(
          'Invalid authorization code. Please try signing in again.',
        );
      } else if (e.toString().contains('invalid_client')) {
        throw Exception(
          'Invalid OAuth client configuration. Please check your .env file.',
        );
      }
      rethrow;
    }
  }

  /// Opens the specified URI in the user's default browser.
  ///
  /// This method includes platform-specific fallbacks for Windows, macOS, and Linux
  /// in case the primary `url_launcher` package fails.
  ///
  /// - [authorizationUri]: The URI to open.
  Future<void> _redirect(Uri authorizationUri) async {
    try {
      // Try url_launcher first
      if (await canLaunchUrl(authorizationUri)) {
        await launchUrl(authorizationUri);
        return;
      }
    } catch (e) {
      LoggerService.warning(
        'url_launcher failed: $e, trying fallback...',
        tag: 'DesktopOAuth',
      );
    }

    // Fallback for Windows - directly open URL using system command
    if (Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', authorizationUri.toString()]);
        LoggerService.info(
          'OAuth: Opened browser using Windows fallback',
          tag: 'DesktopOAuth',
        );
        return;
      } catch (e) {
        LoggerService.warning(
          'Windows fallback failed: $e',
          tag: 'DesktopOAuth',
        );
      }
    }

    // Fallback for Mac
    if (Platform.isMacOS) {
      try {
        await Process.run('open', [authorizationUri.toString()]);
        LoggerService.info(
          'OAuth: Opened browser using macOS fallback',
          tag: 'DesktopOAuth',
        );
        return;
      } catch (e) {
        LoggerService.warning('macOS fallback failed: $e', tag: 'DesktopOAuth');
      }
    }

    // Fallback for Linux
    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [authorizationUri.toString()]);
        LoggerService.info(
          'OAuth: Opened browser using Linux fallback',
          tag: 'DesktopOAuth',
        );
        return;
      } catch (e) {
        LoggerService.warning('Linux fallback failed: $e', tag: 'DesktopOAuth');
      }
    }

    throw Exception('Cannot launch authorization URL: $authorizationUri');
  }

  /// Listens for the incoming redirect on the local server and extracts the
  /// authorization code from the query parameters.
  ///
  /// Returns a map of the query parameters from the redirect URI.
  Future<Map<String, String>> _listen() async {
    try {
      LoggerService.info('OAuth: Waiting for redirect...', tag: 'DesktopOAuth');

      // Wait for the first HTTP request to our local server
      final request = await _redirectServer!.first;

      LoggerService.debug(
        'OAuth: Received request to ${request.uri}',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        'OAuth: Request method: ${request.method}',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        'OAuth: Request path: ${request.uri.path}',
        tag: 'DesktopOAuth',
      );
      LoggerService.debug(
        'OAuth: Query string: ${request.uri.query}',
        tag: 'DesktopOAuth',
      );

      // Extract query parameters (includes authorization code)
      final params = request.uri.queryParameters;

      LoggerService.debug('OAuth: Extracted parameters:', tag: 'DesktopOAuth');
      params.forEach((key, value) {
        // Don't log sensitive values in full
        final displayValue = (key == 'code' || key == 'access_token')
            ? '${value.substring(0, 10)}...'
            : value;
        LoggerService.debug('  $key: $displayValue', tag: 'DesktopOAuth');
      });

      // Check if we have an authorization code
      if (!params.containsKey('code')) {
        LoggerService.error(
          'OAuth: No authorization code in response',
          tag: 'DesktopOAuth',
        );
        LoggerService.info(
          'OAuth: Available parameters: ${params.keys.join(', ')}',
          tag: 'DesktopOAuth',
        );

        // Check for error parameter
        if (params.containsKey('error')) {
          final error = params['error'];
          final errorDescription =
              params['error_description'] ?? 'No description';
          LoggerService.error(
            'OAuth: Authorization error: $error - $errorDescription',
            tag: 'DesktopOAuth',
          );
          throw Exception(
            'OAuth authorization failed: $error - $errorDescription',
          );
        }
      }

      // Bring app window to front
      if (!kIsWeb) {
        try {
          await WindowToFront.activate();
        } catch (e) {
          LoggerService.warning(
            'OAuth: Could not bring window to front: $e',
            tag: 'DesktopOAuth',
          );
        }
      }

      // Send success response to browser
      try {
        request.response.statusCode = 200;
        request.response.headers.set('content-type', 'text/plain');
        request.response.write(
          'Authentication successful! You can close this tab and return to the application.',
        );

        // Close the response properly
        await request.response.close();
      } catch (e) {
        LoggerService.warning(
          'OAuth: Error sending response to browser: $e',
          tag: 'DesktopOAuth',
        );
        // Continue anyway - we have the auth code
      }

      // Close the server
      await _redirectServer!.close();
      _redirectServer = null;

      // Validate we have required parameters
      if (!params.containsKey('code')) {
        throw Exception('No authorization code received from OAuth provider');
      }

      LoggerService.info(
        'OAuth: Successfully received authorization code',
        tag: 'DesktopOAuth',
      );
      return params;
    } catch (e) {
      LoggerService.error('OAuth listen error', error: e, tag: 'DesktopOAuth');
      await _redirectServer?.close();
      _redirectServer = null;
      rethrow;
    }
  }

  /// Signs out from Google by revoking the last used access token.
  ///
  /// This helps to ensure that the user is fully signed out from the desktop
  /// application's perspective.
  ///
  /// Returns `true` if the token was successfully revoked or if there was no
  /// token to revoke, `false` otherwise.
  Future<bool> signOutFromGoogle() async {
    if (_lastAccessToken == null) {
      LoggerService.debug(
        'OAuth: No access token to revoke',
        tag: 'DesktopOAuth',
      );
      return true;
    }

    try {
      final uri = Uri.parse(
        _revokeTokenUrl,
      ).replace(queryParameters: {'token': _lastAccessToken});

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        LoggerService.info(
          'OAuth: Successfully revoked access token',
          tag: 'DesktopOAuth',
        );
        _lastAccessToken = null;
        return true;
      } else {
        LoggerService.warning(
          'OAuth: Failed to revoke token - status ${response.statusCode}',
          tag: 'DesktopOAuth',
        );
        return false;
      }
    } catch (e) {
      LoggerService.error(
        'OAuth: Error revoking token',
        error: e,
        tag: 'DesktopOAuth',
      );
      return false;
    }
  }

  /// Cleans up resources used by the handler, such as the local HTTP server.
  void dispose() {
    _redirectServer?.close();
    _redirectServer = null;
    _lastAccessToken = null;
  }
}
