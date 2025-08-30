import 'package:flutter/foundation.dart';
import '../services/logger_service.dart';

/// Centralized error handling utilities.
///
/// This refactored implementation uses the application's
/// [LoggerService] for all error reporting and logging instead of
/// directly printing to the console. By delegating to the logger,
/// we ensure consistent formatting, severity levels and respect
/// configuration such as minimum log level or colorized output.
class ErrorHandler {
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? customKeys,
  }) async {
    LoggerService.error(
      reason ?? 'Unhandled exception',
      error: exception,
      stackTrace: stackTrace,
    );
    if (customKeys != null) {
      customKeys.forEach((key, value) {
        LoggerService.debug('Context: $key = $value');
      });
    }
  }

  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    LoggerService.error(
      'Flutter Error: ${details.exception}',
      error: details.exception,
      stackTrace: details.stack,
    );
  }

  static Future<void> setUserIdentifier(String identifier) async {
    LoggerService.info('User identifier: $identifier');
  }

  static Future<void> log(String message) async {
    LoggerService.info(message);
  }

  static Future<void> setCustomKey(String key, dynamic value) async {
    LoggerService.debug('Custom key: $key = $value');
  }

  static Future<void> testCrash() async {
    LoggerService.warning('Test crash not executed (Crashlytics removed)');
  }
}
