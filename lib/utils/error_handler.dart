import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class ErrorHandler {
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? customKeys,
  }) async {
    try {
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(
          exception,
          stackTrace,
          reason: reason,
          fatal: fatal,
        );

        if (customKeys != null) {
          for (final entry in customKeys.entries) {
            await FirebaseCrashlytics.instance.setCustomKey(
              entry.key,
              entry.value,
            );
          }
        }
      } else {
        // For web, just log to console since Crashlytics isn't supported
        debugPrint('Error: $exception');
        if (stackTrace != null) {
          debugPrint('Stack trace: $stackTrace');
        }
        if (reason != null) {
          debugPrint('Reason: $reason');
        }
      }
    } catch (e) {
      debugPrint('Failed to record error to Crashlytics: $e');
    }
  }

  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    try {
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordFlutterError(details);
      } else {
        debugPrint('Flutter Error: ${details.exception}');
        debugPrint('Stack trace: ${details.stack}');
      }
    } catch (e) {
      debugPrint('Failed to record Flutter error to Crashlytics: $e');
    }
  }

  static Future<void> setUserIdentifier(String identifier) async {
    try {
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setUserIdentifier(identifier);
      }
    } catch (e) {
      debugPrint('Failed to set user identifier: $e');
    }
  }

  static Future<void> log(String message) async {
    try {
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.log(message);
      } else {
        debugPrint('Log: $message');
      }
    } catch (e) {
      debugPrint('Failed to log message: $e');
    }
  }

  static Future<void> setCustomKey(String key, dynamic value) async {
    try {
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setCustomKey(key, value);
      }
    } catch (e) {
      debugPrint('Failed to set custom key: $e');
    }
  }

  static Future<void> testCrash() async {
    try {
      if (!kIsWeb && !kDebugMode) {
        // Only test crash in release mode and not on web
        FirebaseCrashlytics.instance.crash();
      } else {
        debugPrint('Test crash not executed (debug mode or web platform)');
      }
    } catch (e) {
      debugPrint('Failed to test crash: $e');
    }
  }
}