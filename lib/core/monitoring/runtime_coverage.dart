import 'dart:convert';
import 'dart:io';
import '../../shared/services/logger_service.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

/// Runtime coverage tracker that logs all executed functions
/// to identify dead code paths in production
class RuntimeCoverageTracker {
  static final RuntimeCoverageTracker _instance = RuntimeCoverageTracker._internal();
  factory RuntimeCoverageTracker() => _instance;
  RuntimeCoverageTracker._internal();

  final Logger _logger = Logger('RuntimeCoverage');
  final Map<String, int> _executionCounts = {};
  final Map<String, DateTime> _lastExecuted = {};
  final Map<String, List<String>> _callPaths = {};
  final Set<String> _uniqueFunctions = {};

  bool _isTracking = false;
  IOSink? _logSink;

  /// Start tracking runtime coverage
  void startTracking({String? outputPath}) {
    if (_isTracking) return;

    _isTracking = true;
    _logger.info('Starting runtime coverage tracking');

    // Open file for writing coverage data
    final path = outputPath ?? 'runtime_coverage_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(path);

    // Ensure parent directory exists
    final parentDir = file.parent;
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }

    _logSink = file.openWrite();

    // Log initial timestamp
    _logSink?.writeln(jsonEncode({
      'event': 'start',
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }

  /// Stop tracking and save results
  Future<Map<String, dynamic>> stopTracking() async {
    if (!_isTracking) return {};

    _isTracking = false;
    _logger.info('Stopping runtime coverage tracking');

    // Generate summary
    final summary = {
      'timestamp': DateTime.now().toIso8601String(),
      'total_functions_executed': _uniqueFunctions.length,
      'execution_counts': _executionCounts,
      'last_executed': _lastExecuted.map((k, v) => MapEntry(k, v.toIso8601String())),
      'call_paths': _callPaths,
      'hot_functions': _getHotFunctions(),
      'cold_functions': _getColdFunctions(),
    };

    // Write summary and close
    _logSink?.writeln(jsonEncode({
      'event': 'summary',
      'data': summary,
    }));

    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;

    // Save summary to dedicated file
    final summaryFile = File('runtime_coverage_summary.json');
    await summaryFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary),
    );

    LoggerService.debug('📊 Coverage summary saved to runtime_coverage_summary.json');

    return summary;
  }

  /// Track a function execution
  void trackExecution(String functionName, {String? className, String? filePath}) {
    if (!_isTracking) return;

    final identifier = _buildIdentifier(functionName, className, filePath);

    // Update counts
    _executionCounts[identifier] = (_executionCounts[identifier] ?? 0) + 1;
    _lastExecuted[identifier] = DateTime.now();
    _uniqueFunctions.add(identifier);

    // Track call path
    final trace = Trace.current();
    final callPath = _extractCallPath(trace);
    _callPaths.putIfAbsent(identifier, () => []).add(callPath);

    // Log execution
    if (_logSink != null) {
      _logSink!.writeln(jsonEncode({
        'event': 'execution',
        'timestamp': DateTime.now().toIso8601String(),
        'function': identifier,
        'count': _executionCounts[identifier],
        'call_path': callPath,
      }));
    }
  }

  /// Track widget builds
  void trackWidgetBuild(String widgetName) {
    trackExecution('build', className: widgetName, filePath: 'widgets');
  }

  /// Track provider calls
  void trackProviderCall(String providerName, String method) {
    trackExecution(method, className: providerName, filePath: 'providers');
  }

  /// Track service calls
  void trackServiceCall(String serviceName, String method) {
    trackExecution(method, className: serviceName, filePath: 'services');
  }

  /// Track API calls
  void trackApiCall(String endpoint, String method) {
    trackExecution(endpoint, className: 'API', filePath: method);
  }

  String _buildIdentifier(String functionName, String? className, String? filePath) {
    final parts = <String>[];

    if (filePath != null) parts.add(filePath);
    if (className != null) parts.add(className);
    parts.add(functionName);

    return parts.join('::');
  }

  String _extractCallPath(Trace trace) {
    final frames = trace.frames.take(3);
    return frames
        .map((f) => '${f.library}:${f.line}')
        .where((s) => !s.contains('package:flutter'))
        .join(' -> ');
  }

  List<Map<String, dynamic>> _getHotFunctions() {
    final sorted = _executionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(20).map((e) => {
      'function': e.key,
      'count': e.value,
      'last_executed': _lastExecuted[e.key]?.toIso8601String(),
    }).toList();
  }

  List<String> _getColdFunctions() {
    final now = DateTime.now();
    final cold = <String>[];

    for (final entry in _lastExecuted.entries) {
      final timeSince = now.difference(entry.value);
      if (timeSince.inMinutes > 30) {
        cold.add(entry.key);
      }
    }

    return cold;
  }

  /// Get current statistics
  Map<String, dynamic> getStatistics() {
    return {
      'is_tracking': _isTracking,
      'functions_tracked': _uniqueFunctions.length,
      'total_executions': _executionCounts.values.fold(0, (a, b) => a + b),
      'average_executions': _executionCounts.isEmpty
          ? 0
          : _executionCounts.values.fold(0, (a, b) => a + b) ~/ _executionCounts.length,
    };
  }

  /// Clear all tracking data
  void clear() {
    _executionCounts.clear();
    _lastExecuted.clear();
    _callPaths.clear();
    _uniqueFunctions.clear();
  }
}

/// Mixin to auto-track function execution in classes
mixin RuntimeTracking {
  final _tracker = RuntimeCoverageTracker();

  void track(String method) {
    _tracker.trackExecution(
      method,
      className: runtimeType.toString(),
    );
  }

  T trackMethod<T>(String method, T Function() action) {
    track(method);
    return action();
  }

  Future<T> trackAsync<T>(String method, Future<T> Function() action) async {
    track(method);
    return await action();
  }
}