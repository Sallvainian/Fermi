import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/foundation.dart';

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
    _messageSubscription = html.window.onMessage.listen((event) {
      // Security: Validate the origin
      final allowedOrigins = [
        'https://accounts.google.com',
        'https://apis.google.com',
        // Add other OAuth provider origins as needed
      ];

      if (!allowedOrigins.contains(event.origin)) {
        if (kDebugMode) {
          print('WebAuthHelper: Ignored message from untrusted origin: ${event.origin}');
        }
        return;
      }

      // Handle the message
      if (event.data is Map) {
        final data = event.data as Map;
        if (kDebugMode) {
          print('WebAuthHelper: Received auth message: $data');
        }

        // Notify listeners
        _messageController?.add({
          'origin': event.origin,
          'data': data,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // Handle specific auth events
        if (data['type'] == 'auth-complete' || data['status'] == 'success') {
          // Auth completed successfully
          _handleAuthComplete(data);
        }
      }
    });

    if (kDebugMode) {
      print('WebAuthHelper: Initialized postMessage listener');
    }
  }

  /// Handle auth completion
  void _handleAuthComplete(Map data) {
    if (kDebugMode) {
      print('WebAuthHelper: Auth completed with data: $data');
    }

    // The popup should close itself, but we can't access window.close
    // due to COOP restrictions. The postMessage approach allows the
    // popup to notify us it's done without needing window.closed checks.
  }

  /// Stream of auth messages
  Stream<Map<String, dynamic>>? get authMessages => _messageController?.stream;

  /// Inject helper script into auth popups if possible
  /// This is called when opening OAuth popups
  void injectPopupHelper(html.WindowBase? popup) {
    if (popup == null || !kIsWeb) return;

    // We can't directly access the popup due to COOP, but we can
    // set up our listener to receive messages from it
    if (kDebugMode) {
      print('WebAuthHelper: Ready to receive messages from auth popup');
    }
  }

  /// Clean up resources
  void dispose() {
    _messageSubscription?.cancel();
    _messageController?.close();
    _messageSubscription = null;
    _messageController = null;
  }
}