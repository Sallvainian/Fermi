import 'package:flutter/foundation.dart';

class ErrorHandler {
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? customKeys,
  }) async {
    // Log to console only - no Crashlytics
    debugPrint('Error: $exception');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
    if (reason != null) {
      debugPrint('Reason: $reason');
    }
    if (customKeys != null) {
      debugPrint('Custom keys: $customKeys');
    }
  }

  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  }

  static Future<void> setUserIdentifier(String identifier) async {
    debugPrint('User identifier: $identifier');
  }

  static Future<void> log(String message) async {
    debugPrint('Log: $message');
  }

  static Future<void> setCustomKey(String key, dynamic value) async {
    debugPrint('Custom key: $key = $value');
  }

  static Future<void> testCrash() async {
    debugPrint('Test crash not executed (Crashlytics removed)');
  }
}
