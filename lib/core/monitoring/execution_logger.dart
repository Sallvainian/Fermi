import 'dart:convert';
import 'dart:io';
import '../../shared/services/logger_service.dart';
import 'package:logger/logger.dart';
import 'package:logging/logging.dart' as logging;

/// Advanced execution logger that tracks all function calls
/// and generates heatmaps of code usage
class ExecutionLogger {
  static final ExecutionLogger _instance = ExecutionLogger._internal();
  factory ExecutionLogger() => _instance;
  ExecutionLogger._internal();

  late final Logger _logger;
  final Map<String, ExecutionMetrics> _metrics = {};
  final List<ExecutionEvent> _eventLog = [];

  bool _isLogging = false;
  DateTime? _sessionStart;
  File? _outputFile;

  void initialize({
    Level logLevel = Level.info,
    String? outputPath,
    bool consoleOutput = false,
  }) {
    _logger = Logger(
      filter: ProductionFilter(),
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: MultiOutput([
        if (consoleOutput) ConsoleOutput(),
        if (outputPath != null) FileOutput(file: File(outputPath)),
      ]),
    );

    // Setup logging bridge
    logging.Logger.root.level = logging.Level.ALL;
    logging.Logger.root.onRecord.listen((record) {
      _handleLogRecord(record);
    });
  }

  /// Start logging execution
  void startLogging() {
    if (_isLogging) return;

    _isLogging = true;
    _sessionStart = DateTime.now();
    _outputFile = File('execution_log_${_sessionStart!.millisecondsSinceEpoch}.jsonl');

    _logger.i('Execution logging started');

    // Write session header
    _writeEvent({
      'type': 'session_start',
      'timestamp': _sessionStart!.toIso8601String(),
      'platform': Platform.operatingSystem,
      'dart_version': Platform.version,
    });
  }

  /// Stop logging and generate report
  Future<ExecutionReport> stopLogging() async {
    if (!_isLogging) return ExecutionReport.empty();

    _isLogging = false;
    final sessionEnd = DateTime.now();
    final duration = sessionEnd.difference(_sessionStart!);

    _logger.i('Execution logging stopped');

    // Generate report
    final report = ExecutionReport(
      sessionStart: _sessionStart!,
      sessionEnd: sessionEnd,
      duration: duration,
      totalEvents: _eventLog.length,
      metrics: Map.from(_metrics),
      heatmap: _generateHeatmap(),
      deadCodeCandidates: _findDeadCodeCandidates(),
      performanceIssues: _findPerformanceIssues(),
    );

    // Write session footer
    _writeEvent({
      'type': 'session_end',
      'timestamp': sessionEnd.toIso8601String(),
      'duration_ms': duration.inMilliseconds,
      'total_events': _eventLog.length,
    });

    // Save report
    final reportFile = File('execution_report_${sessionEnd.millisecondsSinceEpoch}.json');
    await reportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );

    LoggerService.debug('📊 Execution report saved to ${reportFile.path}');

    return report;
  }

  /// Log a function execution
  void logExecution(
    String functionName, {
    String? className,
    Map<String, dynamic>? parameters,
    dynamic result,
    Duration? executionTime,
    String? error,
  }) {
    if (!_isLogging) return;

    final event = ExecutionEvent(
      timestamp: DateTime.now(),
      functionName: functionName,
      className: className,
      parameters: parameters,
      result: result?.toString(),
      executionTime: executionTime,
      error: error,
    );

    _eventLog.add(event);
    _updateMetrics(event);
    _writeEvent(event.toJson());

    // Log based on execution time
    if (executionTime != null) {
      if (executionTime.inMilliseconds > 1000) {
        _logger.w('Slow execution: $functionName took ${executionTime.inMilliseconds}ms');
      } else if (executionTime.inMilliseconds > 100) {
        _logger.d('${className ?? ""}::$functionName executed in ${executionTime.inMilliseconds}ms');
      }
    }

    if (error != null) {
      _logger.e('Error in $functionName: $error');
    }
  }

  /// Log with automatic timing
  T logTimed<T>(
    String functionName,
    T Function() action, {
    String? className,
    Map<String, dynamic>? parameters,
  }) {
    final stopwatch = Stopwatch()..start();

    try {
      final result = action();
      stopwatch.stop();

      logExecution(
        functionName,
        className: className,
        parameters: parameters,
        result: result,
        executionTime: stopwatch.elapsed,
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      logExecution(
        functionName,
        className: className,
        parameters: parameters,
        executionTime: stopwatch.elapsed,
        error: e.toString(),
      );

      rethrow;
    }
  }

  /// Log async with automatic timing
  Future<T> logTimedAsync<T>(
    String functionName,
    Future<T> Function() action, {
    String? className,
    Map<String, dynamic>? parameters,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await action();
      stopwatch.stop();

      logExecution(
        functionName,
        className: className,
        parameters: parameters,
        result: result,
        executionTime: stopwatch.elapsed,
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      logExecution(
        functionName,
        className: className,
        parameters: parameters,
        executionTime: stopwatch.elapsed,
        error: e.toString(),
      );

      rethrow;
    }
  }

  void _handleLogRecord(logging.LogRecord record) {
    if (!_isLogging) return;

    // Track logger usage
    final loggerName = record.loggerName;
    if (loggerName.isNotEmpty) {
      logExecution(
        'log',
        className: loggerName,
        parameters: {
          'level': record.level.name,
          'message': record.message,
        },
      );
    }
  }

  void _updateMetrics(ExecutionEvent event) {
    final key = '${event.className ?? "global"}::${event.functionName}';

    if (!_metrics.containsKey(key)) {
      _metrics[key] = ExecutionMetrics(
        functionName: event.functionName,
        className: event.className,
      );
    }

    _metrics[key]!.recordExecution(
      executionTime: event.executionTime,
      hasError: event.error != null,
    );
  }

  void _writeEvent(Map<String, dynamic> event) {
    if (_outputFile != null) {
      _outputFile!.writeAsStringSync(
        '${jsonEncode(event)}\n',
        mode: FileMode.append,
      );
    }
  }

  Map<String, int> _generateHeatmap() {
    final heatmap = <String, int>{};

    for (final entry in _metrics.entries) {
      heatmap[entry.key] = entry.value.executionCount;
    }

    return heatmap;
  }

  List<String> _findDeadCodeCandidates() {
    // Functions that were never executed during the session
    final candidates = <String>[];

    // This would need to be populated with all known functions
    // For now, return empty list
    return candidates;
  }

  List<PerformanceIssue> _findPerformanceIssues() {
    final issues = <PerformanceIssue>[];

    for (final entry in _metrics.entries) {
      final metrics = entry.value;

      // Slow functions
      if (metrics.maxExecutionTime.inMilliseconds > 1000) {
        issues.add(PerformanceIssue(
          type: 'slow_function',
          function: entry.key,
          description: 'Max execution time: ${metrics.maxExecutionTime.inMilliseconds}ms',
          severity: 'high',
        ));
      }

      // High error rate
      if (metrics.errorRate > 0.1) {
        issues.add(PerformanceIssue(
          type: 'high_error_rate',
          function: entry.key,
          description: 'Error rate: ${(metrics.errorRate * 100).toStringAsFixed(1)}%',
          severity: 'critical',
        ));
      }

      // Hot spots
      if (metrics.executionCount > 1000) {
        issues.add(PerformanceIssue(
          type: 'hot_spot',
          function: entry.key,
          description: 'Called ${metrics.executionCount} times',
          severity: 'info',
        ));
      }
    }

    return issues;
  }

  /// Get current execution statistics
  Map<String, dynamic> getStatistics() {
    return {
      'is_logging': _isLogging,
      'session_start': _sessionStart?.toIso8601String(),
      'total_metrics': _metrics.length,
      'total_events': _eventLog.length,
      'hot_functions': _metrics.values
          .where((m) => m.executionCount > 100)
          .map((m) => m.toJson())
          .toList(),
      'slow_functions': _metrics.values
          .where((m) => m.averageExecutionTime.inMilliseconds > 100)
          .map((m) => m.toJson())
          .toList(),
    };
  }
}

class ExecutionEvent {
  final DateTime timestamp;
  final String functionName;
  final String? className;
  final Map<String, dynamic>? parameters;
  final String? result;
  final Duration? executionTime;
  final String? error;

  ExecutionEvent({
    required this.timestamp,
    required this.functionName,
    this.className,
    this.parameters,
    this.result,
    this.executionTime,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'function': functionName,
    if (className != null) 'class': className,
    if (parameters != null) 'parameters': parameters,
    if (result != null) 'result': result,
    if (executionTime != null) 'execution_time_ms': executionTime!.inMilliseconds,
    if (error != null) 'error': error,
  };
}

class ExecutionMetrics {
  final String functionName;
  final String? className;

  int executionCount = 0;
  int errorCount = 0;
  Duration totalExecutionTime = Duration.zero;
  Duration maxExecutionTime = Duration.zero;
  Duration minExecutionTime = const Duration(days: 999);

  ExecutionMetrics({
    required this.functionName,
    this.className,
  });

  void recordExecution({
    Duration? executionTime,
    bool hasError = false,
  }) {
    executionCount++;
    if (hasError) errorCount++;

    if (executionTime != null) {
      totalExecutionTime += executionTime;
      if (executionTime > maxExecutionTime) maxExecutionTime = executionTime;
      if (executionTime < minExecutionTime) minExecutionTime = executionTime;
    }
  }

  Duration get averageExecutionTime =>
      executionCount > 0
          ? totalExecutionTime ~/ executionCount
          : Duration.zero;

  double get errorRate =>
      executionCount > 0
          ? errorCount / executionCount
          : 0.0;

  Map<String, dynamic> toJson() => {
    'function': functionName,
    if (className != null) 'class': className,
    'execution_count': executionCount,
    'error_count': errorCount,
    'error_rate': errorRate,
    'total_time_ms': totalExecutionTime.inMilliseconds,
    'avg_time_ms': averageExecutionTime.inMilliseconds,
    'max_time_ms': maxExecutionTime.inMilliseconds,
    'min_time_ms': minExecutionTime.inMilliseconds,
  };
}

class ExecutionReport {
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final Duration duration;
  final int totalEvents;
  final Map<String, ExecutionMetrics> metrics;
  final Map<String, int> heatmap;
  final List<String> deadCodeCandidates;
  final List<PerformanceIssue> performanceIssues;

  ExecutionReport({
    required this.sessionStart,
    required this.sessionEnd,
    required this.duration,
    required this.totalEvents,
    required this.metrics,
    required this.heatmap,
    required this.deadCodeCandidates,
    required this.performanceIssues,
  });

  static ExecutionReport empty() => ExecutionReport(
    sessionStart: DateTime.now(),
    sessionEnd: DateTime.now(),
    duration: Duration.zero,
    totalEvents: 0,
    metrics: {},
    heatmap: {},
    deadCodeCandidates: [],
    performanceIssues: [],
  );

  Map<String, dynamic> toJson() => {
    'session_start': sessionStart.toIso8601String(),
    'session_end': sessionEnd.toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'total_events': totalEvents,
    'metrics': metrics.map((k, v) => MapEntry(k, v.toJson())),
    'heatmap': heatmap,
    'dead_code_candidates': deadCodeCandidates,
    'performance_issues': performanceIssues.map((i) => i.toJson()).toList(),
  };
}

class PerformanceIssue {
  final String type;
  final String function;
  final String description;
  final String severity;

  PerformanceIssue({
    required this.type,
    required this.function,
    required this.description,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'function': function,
    'description': description,
    'severity': severity,
  };
}