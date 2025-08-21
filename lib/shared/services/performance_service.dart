import 'dart:async';
import 'logger_service.dart';

/// Comprehensive performance monitoring service.
///
/// Provides performance monitoring with custom metrics,
/// trace management, and performance analysis capabilities.
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();

  /// Factory constructor returns singleton
  factory PerformanceService() => _instance;

  /// Private constructor
  PerformanceService._internal();

  /// Active traces map
  final Map<String, MockTrace> _activeTraces = {};

  /// Performance metrics storage
  final Map<String, PerformanceMetric> _metrics = {};

  /// Performance thresholds for alerting
  static const Duration _slowOperationThreshold = Duration(seconds: 3);

  /// Initialize the performance service
  Future<void> initialize() async {
    try {
      LoggerService.info('Performance service initialized (mock mode)');
    } catch (e) {
      LoggerService.error('Failed to initialize performance service', error: e);
    }
  }

  /// Start a custom trace for performance monitoring.
  ///
  /// @param name Unique trace name
  /// @param attributes Optional attributes for the trace
  /// @return Trace object for stopping
  MockTrace? startTrace(String name, {Map<String, String>? attributes}) {
    try {
      final trace = MockTrace(name);
      _activeTraces[name] = trace;

      LoggerService.debug('Started trace: $name');
      return trace;
    } catch (e) {
      LoggerService.error('Failed to start trace: $name', error: e);
      return null;
    }
  }

  /// Stop a trace and record metrics.
  ///
  /// @param name Trace name to stop
  /// @param metrics Optional custom metrics to record
  Future<void> stopTrace(String name, {Map<String, int>? metrics}) async {
    try {
      final trace = _activeTraces[name];
      if (trace != null) {
        trace.stop();
        _activeTraces.remove(name);

        LoggerService.debug('Stopped trace: $name');
      }
    } catch (e) {
      LoggerService.error('Failed to stop trace: $name', error: e);
    }
  }

  /// Time an async operation with automatic trace management.
  ///
  /// @param name Operation name for tracing
  /// @param operation The async operation to time
  /// @param attributes Optional trace attributes
  /// @return Result of the operation
  Future<T> timeOperation<T>(
    String name,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();

      stopwatch.stop();
      final duration = stopwatch.elapsed;

      // Record metrics
      recordMetric('${name}_duration_ms', duration.inMilliseconds.toDouble());
      recordMetric('${name}_success', 1);

      // Log slow operations
      if (duration > _slowOperationThreshold) {
        LoggerService.warning(
          'Slow operation detected: $name (${duration.inMilliseconds}ms > ${_slowOperationThreshold.inMilliseconds}ms)',
        );
      }

      return result;
    } catch (error) {
      stopwatch.stop();
      final duration = stopwatch.elapsed;

      // Record error metrics
      recordMetric('${name}_duration_ms', duration.inMilliseconds.toDouble());
      recordMetric('${name}_error', 1);

      LoggerService.error(
        'Operation failed: $name (${duration.inMilliseconds}ms)',
        error: error,
      );

      rethrow;
    }
  }

  /// Record a custom metric value.
  ///
  /// @param name Metric name
  /// @param value Metric value
  void recordMetric(String name, double value) {
    _metrics[name] = PerformanceMetric(
      name: name,
      value: value,
      timestamp: DateTime.now(),
    );

    LoggerService.debug('Recorded metric: $name = $value');
  }

  /// Get performance statistics.
  ///
  /// @return Map of performance metrics and statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'activeTraces': _activeTraces.length,
      'totalMetrics': _metrics.length,
      'metrics': _metrics.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  /// Clear all performance data.
  void clearPerformanceData() {
    _activeTraces.clear();
    _metrics.clear();
    LoggerService.debug('Performance data cleared');
  }
}

/// Mock trace implementation for performance monitoring.
class MockTrace {
  final String name;
  final DateTime _startTime;
  DateTime? _stopTime;

  MockTrace(this.name) : _startTime = DateTime.now();

  void stop() {
    _stopTime = DateTime.now();
  }

  Duration get duration => _stopTime?.difference(_startTime) ?? Duration.zero;
}

/// Performance metric data container.
class PerformanceMetric {
  final String name;
  final double value;
  final DateTime timestamp;

  PerformanceMetric({
    required this.name,
    required this.value,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
