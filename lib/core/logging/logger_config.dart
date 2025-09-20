import 'dart:developer' as developer;
import 'package:logger/logger.dart';
import 'package:logging/logging.dart' as logging;

/// Centralized logging configuration for Fermi Plus
///
/// This configuration provides:
/// - Hierarchical loggers per feature for tracking usage
/// - Dead code detection through usage analytics
/// - Performance monitoring for slow operations
/// - Error tracking and debugging support
class LoggerConfig {
  static final LoggerConfig _instance = LoggerConfig._internal();
  factory LoggerConfig() => _instance;
  LoggerConfig._internal();

  // Pretty logger for development with colorful output
  late final Logger _devLogger;

  // Production logger with structured output
  late final Logger _prodLogger;

  // Feature-specific loggers for usage tracking
  final Map<String, logging.Logger> _featureLoggers = {};

  // Track feature usage for dead code detection
  final Map<String, int> _featureUsageCount = {};

  // Track performance metrics
  final Map<String, List<int>> _performanceMetrics = {};

  bool _isInitialized = false;
  bool _isProduction = false;

  /// Initialize the logging system
  void initialize({bool isProduction = false}) {
    if (_isInitialized) return;

    _isProduction = isProduction;
    _isInitialized = true;

    // Configure logging package
    logging.Logger.root.level = isProduction ? logging.Level.INFO : logging.Level.ALL;
    logging.Logger.root.onRecord.listen((record) {
      // Track feature usage for dead code detection
      _trackFeatureUsage(record);

      // Log to console in development
      if (!isProduction) {
        developer.log(
          record.message,
          time: record.time,
          level: record.level.value,
          name: record.loggerName,
          error: record.error,
          stackTrace: record.stackTrace,
        );
      }
    });

    // Configure logger package for pretty output
    _devLogger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );

    _prodLogger = Logger(
      printer: SimplePrinter(colors: false),
      output: _ProductionOutput(),
    );
  }

  /// Get a logger for a specific feature
  /// This helps track which features are actually used in production
  logging.Logger getFeatureLogger(String feature) {
    if (!_featureLoggers.containsKey(feature)) {
      _featureLoggers[feature] = logging.Logger('fermi.$feature');
      _featureUsageCount[feature] = 0;
    }
    return _featureLoggers[feature]!;
  }

  /// Get the pretty logger for development
  Logger get logger => _isProduction ? _prodLogger : _devLogger;

  /// Log a performance metric
  void logPerformance(String operation, int milliseconds) {
    _performanceMetrics.putIfAbsent(operation, () => []).add(milliseconds);

    // Warn if operation is slow
    if (milliseconds > 1000) {
      getFeatureLogger('performance').warning(
        'Slow operation: $operation took ${milliseconds}ms',
      );
    }
  }

  /// Log dead code check marker
  /// Use this to mark potentially dead code
  void logDeadCodeCheck(String feature, String method) {
    getFeatureLogger('dead_code').info('DEAD_CODE_CHECK: $feature.$method');
  }

  /// Track feature usage for dead code detection
  void _trackFeatureUsage(logging.LogRecord record) {
    final parts = record.loggerName.split('.');
    if (parts.length >= 2 && parts[0] == 'fermi') {
      final feature = parts[1];
      _featureUsageCount[feature] = (_featureUsageCount[feature] ?? 0) + 1;
    }
  }

  /// Get feature usage statistics
  Map<String, int> getFeatureUsageStats() => Map.unmodifiable(_featureUsageCount);

  /// Get performance statistics
  Map<String, PerformanceStats> getPerformanceStats() {
    final stats = <String, PerformanceStats>{};
    _performanceMetrics.forEach((operation, times) {
      if (times.isNotEmpty) {
        final sorted = List<int>.from(times)..sort();
        stats[operation] = PerformanceStats(
          count: times.length,
          min: sorted.first,
          max: sorted.last,
          average: times.reduce((a, b) => a + b) ~/ times.length,
          median: sorted[sorted.length ~/ 2],
        );
      }
    });
    return stats;
  }

  /// Clear all tracked data (useful for testing)
  void clearStats() {
    _featureUsageCount.clear();
    _performanceMetrics.clear();
  }
}

/// Performance statistics for an operation
class PerformanceStats {
  final int count;
  final int min;
  final int max;
  final int average;
  final int median;

  PerformanceStats({
    required this.count,
    required this.min,
    required this.max,
    required this.average,
    required this.median,
  });

  @override
  String toString() => 'PerformanceStats(count: $count, min: ${min}ms, max: ${max}ms, avg: ${average}ms, median: ${median}ms)';
}

/// Production output handler
class _ProductionOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // In production, we could send logs to Firebase Crashlytics or other services
    // For now, just use developer.log
    for (final line in event.lines) {
      developer.log(line, name: 'fermi.production');
    }
  }
}

// Convenience functions for quick logging
final _config = LoggerConfig();

/// Get a feature logger
logging.Logger getLogger(String feature) => _config.getFeatureLogger(feature);

/// Log performance metric
void logPerformance(String operation, int milliseconds) =>
    _config.logPerformance(operation, milliseconds);

/// Mark potential dead code
void markDeadCode(String feature, String method) =>
    _config.logDeadCodeCheck(feature, method);

/// Get the main logger
Logger get mainLogger => _config.logger;

/// Initialize logging (call this in main.dart)
void initializeLogging({bool isProduction = false}) =>
    _config.initialize(isProduction: isProduction);

/// Get usage stats for analysis
Map<String, int> getUsageStats() => _config.getFeatureUsageStats();

/// Get performance stats for analysis
Map<String, PerformanceStats> getPerformanceStats() => _config.getPerformanceStats();