import 'dart:convert';
import 'dart:io';
import '../../shared/services/logger_service.dart';
import 'package:flutter/material.dart';

import 'runtime_coverage.dart';
import 'execution_logger.dart';
import 'memory_leak_detector.dart';

/// Integrated runtime analyzer that combines all monitoring tools
/// to provide comprehensive dead code and performance analysis
class RuntimeAnalyzer {
  static final RuntimeAnalyzer _instance = RuntimeAnalyzer._internal();
  factory RuntimeAnalyzer() => _instance;
  RuntimeAnalyzer._internal();

  final RuntimeCoverageTracker _coverage = RuntimeCoverageTracker();
  final ExecutionLogger _executionLogger = ExecutionLogger();
  final MemoryLeakDetector _leakDetector = MemoryLeakDetector();

  bool _isAnalyzing = false;
  DateTime? _analysisStart;

  /// Initialize all monitoring tools
  void initialize({
    bool enableCoverage = true,
    bool enableExecution = true,
    bool enableLeakDetection = true,
    bool debugMode = false,
  }) {
    LoggerService.debug('🚀 Initializing Runtime Analyzer');

    if (enableExecution) {
      _executionLogger.initialize(
        consoleOutput: debugMode,
        outputPath: 'logs/execution.log',
      );
    }

    LoggerService.debug('✅ Runtime Analyzer initialized');
  }

  /// Start comprehensive runtime analysis
  void startAnalysis({
    String? sessionName,
    Map<String, dynamic>? metadata,
  }) {
    if (_isAnalyzing) {
      LoggerService.debug('⚠️  Analysis already in progress');
      return;
    }

    _isAnalyzing = true;
    _analysisStart = DateTime.now();

    LoggerService.debug('📊 Starting runtime analysis session');
    LoggerService.debug('   Session: ${sessionName ?? "unnamed"}');

    // Ensure analysis directory exists
    final analysisDir = Directory('analysis');
    if (!analysisDir.existsSync()) {
      analysisDir.createSync(recursive: true);
    }

    // Start all monitors
    _coverage.startTracking(
      outputPath: 'analysis/coverage_${_analysisStart!.millisecondsSinceEpoch}.json',
    );

    _executionLogger.startLogging();

    _leakDetector.startMonitoring(
      checkInterval: const Duration(seconds: 30),
    );

    // Log session start
    _writeSessionEvent('analysis_started', {
      'session_name': sessionName,
      'timestamp': _analysisStart!.toIso8601String(),
      'metadata': metadata,
    });
  }

  /// Stop analysis and generate comprehensive report
  Future<AnalysisReport> stopAnalysis() async {
    if (!_isAnalyzing) {
      LoggerService.debug('⚠️  No analysis in progress');
      return AnalysisReport.empty();
    }

    LoggerService.debug('🛑 Stopping runtime analysis');

    _isAnalyzing = false;
    final analysisEnd = DateTime.now();
    final duration = analysisEnd.difference(_analysisStart!);

    // Stop all monitors and collect reports
    final coverageReport = await _coverage.stopTracking();
    final executionReport = await _executionLogger.stopLogging();
    final leakReport = await _leakDetector.stopMonitoring();

    // Generate combined analysis
    final deadCode = _findDeadCode(coverageReport, executionReport);
    final performanceIssues = _findPerformanceIssues(executionReport);
    final memoryIssues = _findMemoryIssues(leakReport);

    // Create comprehensive report
    final report = AnalysisReport(
      sessionStart: _analysisStart!,
      sessionEnd: analysisEnd,
      duration: duration,
      coverage: coverageReport,
      execution: executionReport.toJson(),
      leaks: leakReport.toJson(),
      deadCode: deadCode,
      performanceIssues: performanceIssues,
      memoryIssues: memoryIssues,
      recommendations: _generateRecommendations(
        deadCode,
        performanceIssues,
        memoryIssues,
      ),
    );

    // Save report
    await _saveReport(report);

    LoggerService.debug('✅ Analysis complete');
    LoggerService.debug('📊 Report saved to: analysis/report_${analysisEnd.millisecondsSinceEpoch}.json');

    return report;
  }

  /// Track a function for all monitors
  void track(
    String functionName, {
    String? className,
    Map<String, dynamic>? parameters,
  }) {
    _coverage.trackExecution(functionName, className: className);
    _executionLogger.logExecution(functionName, className: className, parameters: parameters);
  }

  /// Track with timing
  T trackTimed<T>(
    String functionName,
    T Function() action, {
    String? className,
    Map<String, dynamic>? parameters,
  }) {
    return _executionLogger.logTimed(
      functionName,
      () {
        _coverage.trackExecution(functionName, className: className);
        return action();
      },
      className: className,
      parameters: parameters,
    );
  }

  /// Track async with timing
  Future<T> trackTimedAsync<T>(
    String functionName,
    Future<T> Function() action, {
    String? className,
    Map<String, dynamic>? parameters,
  }) {
    return _executionLogger.logTimedAsync(
      functionName,
      () async {
        _coverage.trackExecution(functionName, className: className);
        return await action();
      },
      className: className,
      parameters: parameters,
    );
  }

  List<DeadCodeItem> _findDeadCode(
    Map<String, dynamic> coverage,
    ExecutionReport execution,
  ) {
    final deadCode = <DeadCodeItem>[];

    // Find functions that were never executed
    final executedFunctions = coverage['unique_functions'] as Set<String>? ?? {};
    final hotFunctions = execution.heatmap;

    // Compare with known functions (would need to be populated)
    // For now, identify cold functions
    for (final entry in hotFunctions.entries) {
      if (entry.value == 0) {
        deadCode.add(DeadCodeItem(
          type: 'function',
          identifier: entry.key,
          reason: 'Never executed during analysis',
        ));
      }
    }

    // Add candidates from execution logger
    for (final candidate in execution.deadCodeCandidates) {
      deadCode.add(DeadCodeItem(
        type: 'candidate',
        identifier: candidate,
        reason: 'Not found in execution logs',
      ));
    }

    return deadCode;
  }

  List<Map<String, dynamic>> _findPerformanceIssues(ExecutionReport execution) {
    final issues = <Map<String, dynamic>>[];

    for (final issue in execution.performanceIssues) {
      issues.add(issue.toJson());
    }

    // Add slow function analysis
    for (final entry in execution.metrics.entries) {
      final metrics = entry.value;
      if (metrics.averageExecutionTime.inMilliseconds > 100) {
        issues.add({
          'type': 'slow_average',
          'function': entry.key,
          'average_ms': metrics.averageExecutionTime.inMilliseconds,
          'severity': 'warning',
        });
      }
    }

    return issues;
  }

  List<Map<String, dynamic>> _findMemoryIssues(MemoryLeakReport leaks) {
    final issues = <Map<String, dynamic>>[];

    // Widget leaks
    for (final entry in leaks.widgetLeaks.entries) {
      if (entry.value > 0) {
        issues.add({
          'type': 'widget_leak',
          'widget': entry.key,
          'instances': entry.value,
          'severity': 'high',
        });
      }
    }

    // Provider leaks
    for (final entry in leaks.providerLeaks.entries) {
      if (entry.value > 0) {
        issues.add({
          'type': 'provider_leak',
          'provider': entry.key,
          'instances': entry.value,
          'severity': 'high',
        });
      }
    }

    // Type-based leaks
    for (final entry in leaks.leaksByType.entries) {
      final metrics = entry.value;
      if (metrics.leaked > 0) {
        issues.add({
          'type': 'object_leak',
          'class': entry.key.toString(),
          'leaked': metrics.leaked,
          'severity': 'critical',
        });
      }
    }

    return issues;
  }

  List<String> _generateRecommendations(
    List<DeadCodeItem> deadCode,
    List<Map<String, dynamic>> performanceIssues,
    List<Map<String, dynamic>> memoryIssues,
  ) {
    final recommendations = <String>[];

    // Dead code recommendations
    if (deadCode.isNotEmpty) {
      recommendations.add('Remove ${deadCode.length} unused functions/classes');
      recommendations.add('Consider using tree-shaking to eliminate dead code');
    }

    // Performance recommendations
    final slowFunctions = performanceIssues.where((i) => i['type'] == 'slow_function').length;
    if (slowFunctions > 0) {
      recommendations.add('Optimize $slowFunctions slow functions');
      recommendations.add('Consider implementing caching for frequently called functions');
    }

    // Memory recommendations
    if (memoryIssues.isNotEmpty) {
      recommendations.add('Fix ${memoryIssues.length} memory leaks');
      recommendations.add('Implement proper dispose() methods for widgets and providers');
    }

    // General recommendations
    if (recommendations.isEmpty) {
      recommendations.add('No major issues detected - code is well optimized');
    }

    return recommendations;
  }

  Future<void> _saveReport(AnalysisReport report) async {
    final directory = Directory('analysis');
    if (!directory.existsSync()) {
      directory.createSync();
    }

    final file = File('analysis/report_${report.sessionEnd.millisecondsSinceEpoch}.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );

    // Also save a summary
    final summaryFile = File('analysis/summary_${report.sessionEnd.millisecondsSinceEpoch}.md');
    await summaryFile.writeAsString(report.toMarkdown());
  }

  void _writeSessionEvent(String event, Map<String, dynamic> data) {
    final directory = Directory('analysis');
    if (!directory.existsSync()) {
      directory.createSync();
    }

    final file = File('analysis/session_${_analysisStart?.millisecondsSinceEpoch}.jsonl');
    file.writeAsStringSync(
      jsonEncode({'event': event, ...data}) + '\n',
      mode: FileMode.append,
    );
  }

  /// Get current statistics from all monitors
  Map<String, dynamic> getStatistics() {
    return {
      'is_analyzing': _isAnalyzing,
      'coverage': _coverage.getStatistics(),
      'execution': _executionLogger.getStatistics(),
      'memory': _leakDetector.getStatistics(),
    };
  }
}

class DeadCodeItem {
  final String type;
  final String identifier;
  final String reason;

  DeadCodeItem({
    required this.type,
    required this.identifier,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'identifier': identifier,
    'reason': reason,
  };
}

class AnalysisReport {
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final Duration duration;
  final Map<String, dynamic> coverage;
  final Map<String, dynamic> execution;
  final Map<String, dynamic> leaks;
  final List<DeadCodeItem> deadCode;
  final List<Map<String, dynamic>> performanceIssues;
  final List<Map<String, dynamic>> memoryIssues;
  final List<String> recommendations;

  AnalysisReport({
    required this.sessionStart,
    required this.sessionEnd,
    required this.duration,
    required this.coverage,
    required this.execution,
    required this.leaks,
    required this.deadCode,
    required this.performanceIssues,
    required this.memoryIssues,
    required this.recommendations,
  });

  static AnalysisReport empty() => AnalysisReport(
    sessionStart: DateTime.now(),
    sessionEnd: DateTime.now(),
    duration: Duration.zero,
    coverage: {},
    execution: {},
    leaks: {},
    deadCode: [],
    performanceIssues: [],
    memoryIssues: [],
    recommendations: [],
  );

  Map<String, dynamic> toJson() => {
    'session_start': sessionStart.toIso8601String(),
    'session_end': sessionEnd.toIso8601String(),
    'duration_seconds': duration.inSeconds,
    'coverage': coverage,
    'execution': execution,
    'leaks': leaks,
    'dead_code': deadCode.map((d) => d.toJson()).toList(),
    'performance_issues': performanceIssues,
    'memory_issues': memoryIssues,
    'recommendations': recommendations,
  };

  String toMarkdown() {
    final buffer = StringBuffer();

    buffer.writeln('# Runtime Analysis Report');
    buffer.writeln();
    buffer.writeln('## Session Info');
    buffer.writeln('- Start: $sessionStart');
    buffer.writeln('- End: $sessionEnd');
    buffer.writeln('- Duration: ${duration.inMinutes} minutes');
    buffer.writeln();

    buffer.writeln('## Dead Code Found');
    if (deadCode.isEmpty) {
      buffer.writeln('✅ No dead code detected');
    } else {
      buffer.writeln('Found ${deadCode.length} unused items:');
      for (final item in deadCode.take(10)) {
        buffer.writeln('- ${item.identifier}: ${item.reason}');
      }
      if (deadCode.length > 10) {
        buffer.writeln('... and ${deadCode.length - 10} more');
      }
    }
    buffer.writeln();

    buffer.writeln('## Performance Issues');
    if (performanceIssues.isEmpty) {
      buffer.writeln('✅ No performance issues detected');
    } else {
      buffer.writeln('Found ${performanceIssues.length} issues:');
      for (final issue in performanceIssues.take(10)) {
        buffer.writeln('- ${issue['type']}: ${issue['description'] ?? issue['function']}');
      }
    }
    buffer.writeln();

    buffer.writeln('## Memory Leaks');
    if (memoryIssues.isEmpty) {
      buffer.writeln('✅ No memory leaks detected');
    } else {
      buffer.writeln('⚠️  Found ${memoryIssues.length} potential leaks:');
      for (final issue in memoryIssues.take(10)) {
        buffer.writeln('- ${issue['type']}: ${issue['widget'] ?? issue['provider'] ?? issue['class']}');
      }
    }
    buffer.writeln();

    buffer.writeln('## Recommendations');
    for (final rec in recommendations) {
      buffer.writeln('- $rec');
    }

    return buffer.toString();
  }
}

/// Widget wrapper to enable runtime analysis for a widget tree
class RuntimeAnalyzerWidget extends StatefulWidget {
  final Widget child;
  final bool enableAnalysis;

  const RuntimeAnalyzerWidget({
    Key? key,
    required this.child,
    this.enableAnalysis = true,
  }) : super(key: key);

  @override
  State<RuntimeAnalyzerWidget> createState() => _RuntimeAnalyzerWidgetState();
}

class _RuntimeAnalyzerWidgetState extends State<RuntimeAnalyzerWidget> {
  final RuntimeAnalyzer _analyzer = RuntimeAnalyzer();

  @override
  void initState() {
    super.initState();
    if (widget.enableAnalysis) {
      _analyzer.initialize(debugMode: true);
      _analyzer.startAnalysis(sessionName: 'app_session');
    }
  }

  @override
  void dispose() {
    if (widget.enableAnalysis) {
      _analyzer.stopAnalysis();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}