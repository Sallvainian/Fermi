import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  /// Log a debug message (only in debug mode)
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      _log(LogLevel.debug, message, tag: tag);
    }
  }

  /// Log an info message
  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Log a warning message
  static void warning(String message, {String? tag}) {
    _log(LogLevel.warning, message, tag: tag);
  }  /// Log an error message
  static void error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
    
    // Send to Crashlytics in production
    if (!kDebugMode && error != null) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: message,
        information: tag != null ? ['Tag: $tag'] : [],
      );
    }
  }

  /// Internal logging method
  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.toString().split('.').last.toUpperCase();
    final tagStr = tag != null ? '[$tag] ' : '';
    
    final logMessage = '$timestamp [$levelStr] $tagStr$message';
    
    if (kDebugMode) {
      // In debug mode, print to console
      switch (level) {
        case LogLevel.debug:
        case LogLevel.info:
          debugPrint(logMessage);
          break;
        case LogLevel.warning:
          debugPrint('\x1B[33m$logMessage\x1B[0m'); // Yellow
          break;
        case LogLevel.error:
          debugPrint('\x1B[31m$logMessage\x1B[0m'); // Red
          if (error != null) {
            debugPrint('Error: $error');
          }
          if (stackTrace != null) {
            debugPrint('Stack trace:\n$stackTrace');
          }
          break;
      }
    } else {
      // In production, only log warnings and errors
      if (level == LogLevel.warning || level == LogLevel.error) {
        // You could send to Firebase Analytics or other logging service here
        FirebaseCrashlytics.instance.log(logMessage);
      }
    }
  }
}

/// Extension for easier logging with context
extension LoggerExtension on Object {
  LoggerService get logger => LoggerService();
  
  void logDebug(String message) => LoggerService.debug(message, tag: runtimeType.toString());
  void logInfo(String message) => LoggerService.info(message, tag: runtimeType.toString());
  void logWarning(String message) => LoggerService.warning(message, tag: runtimeType.toString());
  void logError(String message, {dynamic error, StackTrace? stackTrace}) => 
      LoggerService.error(message, tag: runtimeType.toString(), error: error, stackTrace: stackTrace);
}