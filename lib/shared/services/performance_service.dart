import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'logger_service.dart';

/// Production performance monitoring service using Firebase Performance.
/// Provides real performance tracking for network requests, custom traces,
/// and automatic performance monitoring.
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();

  /// Firebase Performance instance
  late final FirebasePerformance _performance;

  /// Active traces map for management
  final Map<String, Trace> _activeTraces = {};

  /// Active HTTP metrics map
  final Map<String, HttpMetric> _activeHttpMetrics = {};

  /// Performance thresholds for alerting
  static const Duration _slowOperationThreshold = Duration(seconds: 3);
  static const Duration _criticalOperationThreshold = Duration(seconds: 10);

  /// Factory constructor returns singleton
  factory PerformanceService() => _instance;

  /// Private constructor
  PerformanceService._internal();

  /// Initialize the performance service with Firebase Performance
  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        // Firebase Performance is not supported on web
        LoggerService.debug(
          'Performance monitoring not available on web platform',
          tag: 'PerformanceService',
        );
        return;
      }

      _performance = FirebasePerformance.instance;

      // Enable/disable performance collection based on debug mode
      // In production, this should be controlled by user consent
      await _performance.setPerformanceCollectionEnabled(!kDebugMode);

      LoggerService.info(
        'Firebase Performance initialized (collection: ${!kDebugMode})',
        tag: 'PerformanceService',
      );
    } catch (e) {
      LoggerService.error(
        'Failed to initialize Firebase Performance',
        tag: 'PerformanceService',
        error: e,
      );
    }
  }

  /// Start a custom trace for performance monitoring.
  /// Returns null on web platform where performance monitoring is not available.
  Future<Trace?> startTrace(String name, {Map<String, String>? attributes}) async {
    if (kIsWeb) return null;

    try {
      // Check if trace already exists
      if (_activeTraces.containsKey(name)) {
        LoggerService.warning(
          'Trace $name already active, stopping previous trace',
          tag: 'PerformanceService',
        );
        await stopTrace(name);
      }

      final trace = _performance.newTrace(name);

      // Add custom attributes if provided
      if (attributes != null) {
        attributes.forEach((key, value) {
          trace.putAttribute(key, value);
        });
      }

      await trace.start();
      _activeTraces[name] = trace;

      LoggerService.debug(
        'Started performance trace: $name',
        tag: 'PerformanceService',
      );

      return trace;
    } catch (e) {
      LoggerService.error(
        'Failed to start trace: $name',
        tag: 'PerformanceService',
        error: e,
      );
      return null;
    }
  }

  /// Stop a trace and record metrics.
  Future<void> stopTrace(String name, {Map<String, int>? metrics}) async {
    if (kIsWeb) return;

    try {
      final trace = _activeTraces[name];
      if (trace == null) {
        LoggerService.warning(
          'No active trace found: $name',
          tag: 'PerformanceService',
        );
        return;
      }

      // Add custom metrics if provided
      if (metrics != null) {
        metrics.forEach((key, value) {
          trace.setMetric(key, value);
        });
      }

      await trace.stop();
      _activeTraces.remove(name);

      LoggerService.debug(
        'Stopped performance trace: $name',
        tag: 'PerformanceService',
      );
    } catch (e) {
      LoggerService.error(
        'Failed to stop trace: $name',
        tag: 'PerformanceService',
        error: e,
      );
    }
  }

  /// Increment a metric value for an active trace
  void incrementMetric(String traceName, String metricName, {int value = 1}) {
    if (kIsWeb) return;

    final trace = _activeTraces[traceName];
    if (trace != null) {
      trace.incrementMetric(metricName, value);
    }
  }

  /// Start monitoring an HTTP request
  Future<HttpMetric?> startHttpMetric(
    String url,
    HttpMethod method,
  ) async {
    if (kIsWeb) return null;

    try {
      final metric = _performance.newHttpMetric(url, method);
      await metric.start();

      final key = '${method.toString()}_$url';
      _activeHttpMetrics[key] = metric;

      LoggerService.debug(
        'Started HTTP metric: ${method.toString()} $url',
        tag: 'PerformanceService',
      );

      return metric;
    } catch (e) {
      LoggerService.error(
        'Failed to start HTTP metric',
        tag: 'PerformanceService',
        error: e,
      );
      return null;
    }
  }

  /// Stop monitoring an HTTP request
  Future<void> stopHttpMetric(
    String url,
    HttpMethod method, {
    int? httpResponseCode,
    int? requestPayloadSize,
    int? responsePayloadSize,
    String? responseContentType,
  }) async {
    if (kIsWeb) return;

    try {
      final key = '${method.toString()}_$url';
      final metric = _activeHttpMetrics[key];

      if (metric == null) {
        LoggerService.warning(
          'No active HTTP metric found: $key',
          tag: 'PerformanceService',
        );
        return;
      }

      // Set HTTP-specific attributes
      if (httpResponseCode != null) {
        metric.httpResponseCode = httpResponseCode;
      }
      if (requestPayloadSize != null) {
        metric.requestPayloadSize = requestPayloadSize;
      }
      if (responsePayloadSize != null) {
        metric.responsePayloadSize = responsePayloadSize;
      }
      if (responseContentType != null) {
        metric.responseContentType = responseContentType;
      }

      await metric.stop();
      _activeHttpMetrics.remove(key);

      LoggerService.debug(
        'Stopped HTTP metric: $key (status: $httpResponseCode)',
        tag: 'PerformanceService',
      );
    } catch (e) {
      LoggerService.error(
        'Failed to stop HTTP metric',
        tag: 'PerformanceService',
        error: e,
      );
    }
  }

  /// Measure the execution time of an async operation
  Future<T> measureAsync<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
    Map<String, int>? metrics,
  }) async {
    final trace = await startTrace(operationName, attributes: attributes);

    try {
      final stopwatch = Stopwatch()..start();
      final result = await operation();
      stopwatch.stop();

      // Add duration as a metric
      final customMetrics = {
        'duration_ms': stopwatch.elapsedMilliseconds,
        ...?metrics,
      };

      // Log slow operations
      if (stopwatch.elapsed > _criticalOperationThreshold) {
        LoggerService.warning(
          'Critical slow operation: $operationName took ${stopwatch.elapsed.inSeconds}s',
          tag: 'PerformanceService',
        );
      } else if (stopwatch.elapsed > _slowOperationThreshold) {
        LoggerService.info(
          'Slow operation: $operationName took ${stopwatch.elapsed.inMilliseconds}ms',
          tag: 'PerformanceService',
        );
      }

      await stopTrace(operationName, metrics: customMetrics);
      return result;
    } catch (e) {
      // Still stop the trace on error
      await stopTrace(operationName, metrics: {
        'error': 1,
        ...?metrics,
      });
      rethrow;
    }
  }

  /// Clean up all active traces (call on app termination)
  Future<void> dispose() async {
    // Stop all active traces
    final traceNames = _activeTraces.keys.toList();
    for (final name in traceNames) {
      await stopTrace(name);
    }

    // Stop all active HTTP metrics
    for (final metric in _activeHttpMetrics.values) {
      try {
        await metric.stop();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    _activeHttpMetrics.clear();

    LoggerService.info(
      'Performance service disposed',
      tag: 'PerformanceService',
    );
  }
}