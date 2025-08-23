import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_to_front/window_to_front.dart';

/// Custom HTTP client that accepts JSON responses
class JsonAcceptingHttpClient extends http.BaseClient {
  final _httpClient = http.Client();
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Accept'] = 'application/json';
    return _httpClient.send(request);
  }
}

/// Handles OAuth2 authentication flow for desktop platforms
class DesktopOAuthHandler {
  static const String _googleAuthApi = "https://accounts.google.com/o/oauth2/v2/auth";
  static const String _googleTokenApi = "https://oauth2.googleapis.com/token";
  static const String _revokeTokenUrl = 'https://oauth2.googleapis.com/revoke';
  static const String _emailScope = 'email';
  static const String _profileScope = 'profile';
  static const String _openIdScope = 'openid';
  
  HttpServer? _redirectServer;
  String? _lastAccessToken;
  
  /// Performs the complete OAuth2 flow and returns credentials
  Future<oauth2.Credentials?> performOAuthFlow({
    required String clientId,
    required String clientSecret,
  }) async {
    try {
      // Validate inputs
      if (clientId.isEmpty || clientSecret.isEmpty) {
        throw ArgumentError('OAuth client ID and secret are required');
      }
      
      debugPrint('OAuth: Starting flow with client ID: ${clientId.substring(0, 10)}...');
      
      // Close any existing redirect server
      await _redirectServer?.close();
      _redirectServer = null;
      
      // Start a new HTTP server on a random port
      _redirectServer = await HttpServer.bind('localhost', 0);
      final port = _redirectServer!.port;
      final redirectUrl = 'http://localhost:$port';
      
      debugPrint('OAuth: Started local server on port $port');
      debugPrint('OAuth: Redirect URI: $redirectUrl');
      debugPrint('');
      debugPrint('=== IMPORTANT: Google Cloud Console Configuration ===');
      debugPrint('1. OAuth 2.0 Client Type: Web application (NOT Desktop!)');
      debugPrint('2. Authorized JavaScript origins: http://localhost');
      debugPrint('3. Authorized redirect URIs: http://localhost');
      debugPrint('   (Both should be WITHOUT port number)');
      debugPrint('=====================================================');
      debugPrint('');
      
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
      debugPrint('OAuth flow error: $e');
      await _redirectServer?.close();
      _redirectServer = null;
      
      // Provide helpful error messages
      if (e.toString().contains('invalid_client')) {
        throw Exception(
          'Invalid OAuth client configuration. Please verify:\n'
          '1. Client ID and Secret in .env file match Google Cloud Console\n'
          '2. OAuth client type is "Web application" (NOT Desktop) in Google Cloud Console\n'
          '3. "http://localhost" is in both Authorized redirect URIs AND Authorized JavaScript origins'
        );
      } else if (e.toString().contains('invalid_grant')) {
        throw Exception(
          'Authorization failed. This usually means:\n'
          '1. The authorization code expired (try again)\n'
          '2. Redirect URI mismatch (check Google Cloud Console)\n'
          '3. Client credentials are incorrect'
        );
      }
      
      rethrow;
    }
  }
  
  /// Creates OAuth2 client and handles authorization
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
    
    debugPrint('OAuth: Opening browser for authorization');
    
    // Open browser for user authorization
    await _redirect(authorizationUrl);
    
    // Listen for redirect with authorization code
    final responseParams = await _listen();
    
    // Exchange authorization code for access token
    debugPrint('OAuth: Exchanging authorization code for tokens...');
    
    try {
      final client = await grant.handleAuthorizationResponse(responseParams);
      
      debugPrint('OAuth: Successfully obtained access token');
      debugPrint('OAuth: ID Token present: ${client.credentials.idToken != null}');
      debugPrint('OAuth: Access Token present: ${client.credentials.accessToken.isNotEmpty}');
      debugPrint('OAuth: Refresh Token present: ${client.credentials.refreshToken != null}');
      
      return client;
    } catch (e) {
      debugPrint('OAuth: Token exchange failed: $e');
      if (e.toString().contains('invalid_grant')) {
        throw Exception('Invalid authorization code. Please try signing in again.');
      } else if (e.toString().contains('invalid_client')) {
        throw Exception('Invalid OAuth client configuration. Please check your .env file.');
      }
      rethrow;
    }
  }
  
  /// Opens the authorization URL in the default browser
  Future<void> _redirect(Uri authorizationUri) async {
    if (await canLaunchUrl(authorizationUri)) {
      await launchUrl(authorizationUri);
    } else {
      throw Exception('Cannot launch authorization URL: $authorizationUri');
    }
  }
  
  /// Listens for the OAuth redirect and extracts query parameters
  Future<Map<String, String>> _listen() async {
    try {
      debugPrint('OAuth: Waiting for redirect...');
      
      // Wait for the first HTTP request to our local server
      final request = await _redirectServer!.first;
      
      debugPrint('OAuth: Received request to ${request.uri}');
      debugPrint('OAuth: Request method: ${request.method}');
      debugPrint('OAuth: Request path: ${request.uri.path}');
      debugPrint('OAuth: Query string: ${request.uri.query}');
      
      // Extract query parameters (includes authorization code)
      final params = request.uri.queryParameters;
      
      debugPrint('OAuth: Extracted parameters:');
      params.forEach((key, value) {
        // Don't log sensitive values in full
        final displayValue = (key == 'code' || key == 'access_token') 
            ? '${value.substring(0, 10)}...'
            : value;
        debugPrint('  $key: $displayValue');
      });
      
      // Check if we have an authorization code
      if (!params.containsKey('code')) {
        debugPrint('OAuth: ERROR - No authorization code in response');
        debugPrint('OAuth: Available parameters: ${params.keys.join(', ')}');
        
        // Check for error parameter
        if (params.containsKey('error')) {
          final error = params['error'];
          final errorDescription = params['error_description'] ?? 'No description';
          debugPrint('OAuth: Authorization error: $error - $errorDescription');
          throw Exception('OAuth authorization failed: $error - $errorDescription');
        }
      }
      
      // Bring app window to front
      if (!kIsWeb) {
        try {
          await WindowToFront.activate();
        } catch (e) {
          debugPrint('OAuth: Could not bring window to front: $e');
        }
      }
      
      // Send success response to browser
      try {
        request.response.statusCode = 200;
        request.response.headers.set('content-type', 'text/plain');
        request.response.write('Authentication successful! You can close this tab and return to the application.');
      
        // Close the response properly
        await request.response.close();
      } catch (e) {
        debugPrint('OAuth: Error sending response to browser: $e');
        // Continue anyway - we have the auth code
      }
      
      // Close the server
      await _redirectServer!.close();
      _redirectServer = null;
      
      // Validate we have required parameters
      if (!params.containsKey('code')) {
        throw Exception('No authorization code received from OAuth provider');
      }
      
      debugPrint('OAuth: Successfully received authorization code');
      return params;
    } catch (e) {
      debugPrint('OAuth listen error: $e');
      await _redirectServer?.close();
      _redirectServer = null;
      rethrow;
    }
  }
  
  /// Signs out from Google by revoking the access token
  Future<bool> signOutFromGoogle() async {
    if (_lastAccessToken == null) {
      debugPrint('OAuth: No access token to revoke');
      return true;
    }
    
    try {
      final uri = Uri.parse(_revokeTokenUrl).replace(
        queryParameters: {'token': _lastAccessToken},
      );
      
      final response = await http.post(uri);
      
      if (response.statusCode == 200) {
        debugPrint('OAuth: Successfully revoked access token');
        _lastAccessToken = null;
        return true;
      } else {
        debugPrint('OAuth: Failed to revoke token - status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('OAuth: Error revoking token: $e');
      return false;
    }
  }
  
  /// Cleans up resources
  void dispose() {
    _redirectServer?.close();
    _redirectServer = null;
    _lastAccessToken = null;
  }
}