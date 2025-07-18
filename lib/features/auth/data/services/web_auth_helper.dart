import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../shared/services/logger_service.dart';

/// Web-specific helper for handling authentication popups
/// This eliminates COOP (Cross-Origin-Opener-Policy) warnings
class WebAuthHelper {
  static final WebAuthHelper _instance = WebAuthHelper._internal();
  factory WebAuthHelper() => _instance;
  WebAuthHelper._internal();

  StreamController<Map<String, dynamic>>? _messageController;
  StreamSubscription? _messageSubscription;

  /// Initialize the postMessage listener for auth popups
  void initialize() {
    if (!kIsWeb) return;

    // Clean up any existing listener
    dispose();

    _messageController = StreamController<Map<String, dynamic>>.broadcast();

    // Listen for postMessage events from auth popups
    _messageSubscription = web.window.onMessage.listen((event) {
      // Security: Validate the origin
      final allowedOrigins = [
        'https://accounts.google.com',
        'https://apis.google.com',
        'https://teacher-dashboard-flutterfire.firebaseapp.com',
        'http://localhost:3000',
        'http://localhost:8080',
        'http://localhost:49896',
        'http://localhost:62290',
        // Add other OAuth provider origins as needed
      ];

      if (!allowedOrigins.contains(event.origin)) {
        LoggerService.debug('Ignored message from untrusted origin: ${event.origin}', tag: 'WebAuthHelper');
        return;
      }

      // Handle the message safely using js_interop_utils for proper JS interop
      if (kIsWeb) {
        try {
          final data = event.data;
          if (data != null) {
            // Use dart:js_interop for safe JS-to-Dart conversion
            String dataString;
            Map<String, dynamic>? parsedData;
            
            // Convert JS object to Dart safely using dart:js_interop
            try {
              // Try to convert as JSString first
              final jsString = data as JSString;
              dataString = jsString.toDart;  // Safe JS-to-Dart conversion
            } catch (e) {
              // Fallback to string conversion for other JS types
              dataString = data.toString();
            }
            
            LoggerService.debug('Received auth message: $dataString', tag: 'WebAuthHelper');

            // Try to parse as JSON if it looks like structured data
            try {
              if (dataString.startsWith('{') && dataString.endsWith('}')) {
                final Map<dynamic, dynamic> decoded = json.decode(dataString);
                parsedData = decoded.cast<String, dynamic>();
              }
            } catch (jsonError) {
              // Not JSON, treat as plain string data
              parsedData = {'message': dataString};
            }

            // Convert to message format
            final messageData = <String, dynamic>{
              'origin': event.origin,
              'data': parsedData ?? {'raw': dataString},
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            };

            // Notify listeners
            _messageController?.add(messageData);

            // Handle specific auth events
            if (dataString.contains('auth-complete') || dataString.contains('success')) {
              // Auth completed successfully
              _handleAuthComplete(messageData);
            }
          }
        } catch (e) {
          LoggerService.debug('Error processing auth message: $e', tag: 'WebAuthHelper');
        }
      }
    });

    LoggerService.debug('Initialized postMessage listener', tag: 'WebAuthHelper');
  }

  /// Handle auth completion
  void _handleAuthComplete(Map data) {
    LoggerService.debug('Auth completed with data: $data', tag: 'WebAuthHelper');

    // The popup should close itself, but we can't access window.close
    // due to COOP restrictions. The postMessage approach allows the
    // popup to notify us it's done without needing window.closed checks.
  }

  /// Stream of auth messages
  Stream<Map<String, dynamic>>? get authMessages => _messageController?.stream;

  /// Inject helper script into auth popups if possible
  /// This is called when opening OAuth popups
  void injectPopupHelper(web.Window? popup) {
    if (popup == null || !kIsWeb) return;

    // We can't directly access the popup due to COOP, but we can
    // set up our listener to receive messages from it
    LoggerService.debug('Ready to receive messages from auth popup', tag: 'WebAuthHelper');
  }

  /// Clean up resources
  void dispose() {
    _messageSubscription?.cancel();
    _messageController?.close();
    _messageSubscription = null;
    _messageController = null;
  }
}