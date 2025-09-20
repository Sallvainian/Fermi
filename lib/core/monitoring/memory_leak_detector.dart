import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../shared/services/logger_service.dart';
import 'package:flutter/material.dart';

/// Memory leak detector that identifies widgets and objects
/// that aren't properly disposed
class MemoryLeakDetector {
  static final MemoryLeakDetector _instance = MemoryLeakDetector._internal();
  factory MemoryLeakDetector() => _instance;
  MemoryLeakDetector._internal();

  final Map<Type, LeakMetrics> _leaksByType = {};
  final List<LeakEvent> _leakEvents = [];
  final Map<String, int> _widgetLeakCounts = {};
  final Map<String, int> _providerLeakCounts = {};

  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  DateTime? _startTime;
  File? _reportFile;

  /// Start monitoring for memory leaks
  void startMonitoring({
    Duration checkInterval = const Duration(minutes: 1),
    bool enableWidgetTracking = true,
    bool enableProviderTracking = true,
  }) {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _startTime = DateTime.now();
    _reportFile = File('memory_leak_report_${_startTime!.millisecondsSinceEpoch}.json');

    LoggerService.debug('🔍 Memory leak monitoring started');

    // Configure leak tracking - commented out due to API mismatch
    // TODO: Update to use correct leak_tracker API
    // LeakTracking.start(
    //   config: const LeakTrackingConfig(
    //     stdoutLeaks: false,
    //     notifyDevTools: false,
    //   ),
    // );

    // Setup periodic checking
    _monitoringTimer = Timer.periodic(checkInterval, (_) {
      _checkForLeaks();
    });

    // Track initial state
    _recordEvent('monitoring_started', {
      'timestamp': _startTime!.toIso8601String(),
      'widget_tracking': enableWidgetTracking,
      'provider_tracking': enableProviderTracking,
    });
  }

  /// Stop monitoring and generate report
  Future<MemoryLeakReport> stopMonitoring() async {
    if (!_isMonitoring) return MemoryLeakReport.empty();

    _isMonitoring = false;
    _monitoringTimer?.cancel();

    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime!);

    LoggerService.debug('🛑 Memory leak monitoring stopped');

    // Final leak check
    await _checkForLeaks();

    // Generate report
    final report = MemoryLeakReport(
      startTime: _startTime!,
      endTime: endTime,
      duration: duration,
      totalLeaks: _leakEvents.length,
      leaksByType: Map.from(_leaksByType),
      widgetLeaks: Map.from(_widgetLeakCounts),
      providerLeaks: Map.from(_providerLeakCounts),
      events: List.from(_leakEvents),
      summary: _generateSummary(),
    );

    // Save report
    await _reportFile?.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );

    LoggerService.debug('📊 Memory leak report saved to ${_reportFile?.path}');

    // Stop leak tracking - commented out due to API mismatch
    // LeakTracking.stop();

    return report;
  }

  /// Track a widget for potential leaks
  void trackWidget(String widgetName, {required bool isCreated}) {
    if (!_isMonitoring) return;

    final event = isCreated ? 'widget_created' : 'widget_disposed';
    _recordEvent(event, {'widget': widgetName});

    // Track potential leaks
    if (isCreated) {
      _widgetLeakCounts[widgetName] = (_widgetLeakCounts[widgetName] ?? 0) + 1;
    } else {
      _widgetLeakCounts[widgetName] = (_widgetLeakCounts[widgetName] ?? 1) - 1;
      if (_widgetLeakCounts[widgetName]! <= 0) {
        _widgetLeakCounts.remove(widgetName);
      }
    }
  }

  /// Track a provider for potential leaks
  void trackProvider(String providerName, {required bool isCreated}) {
    if (!_isMonitoring) return;

    final event = isCreated ? 'provider_created' : 'provider_disposed';
    _recordEvent(event, {'provider': providerName});

    // Track potential leaks
    if (isCreated) {
      _providerLeakCounts[providerName] = (_providerLeakCounts[providerName] ?? 0) + 1;
    } else {
      _providerLeakCounts[providerName] = (_providerLeakCounts[providerName] ?? 1) - 1;
      if (_providerLeakCounts[providerName]! <= 0) {
        _providerLeakCounts.remove(providerName);
      }
    }
  }

  /// Track a disposable object
  void trackDisposable(Object object, {required bool isCreated}) {
    if (!_isMonitoring) return;

    final type = object.runtimeType;
    final event = isCreated ? 'object_created' : 'object_disposed';

    _recordEvent(event, {
      'type': type.toString(),
      'identity': identityHashCode(object),
    });

    // Update metrics
    if (!_leaksByType.containsKey(type)) {
      _leaksByType[type] = LeakMetrics(type: type);
    }

    if (isCreated) {
      _leaksByType[type]!.created++;
    } else {
      _leaksByType[type]!.disposed++;
    }
  }

  Future<void> _checkForLeaks() async {
    if (!_isMonitoring) return;

    try {
      // Calculate potential leaks from our tracking
      int totalPotentialLeaks = 0;
      for (final metrics in _leaksByType.values) {
        final leaked = metrics.created - metrics.disposed;
        if (leaked > 0) {
          totalPotentialLeaks += leaked;
        }
      }

      if (totalPotentialLeaks > 0) {
        LoggerService.debug('⚠️  Found $totalPotentialLeaks potential memory leaks');

        // Record leak event
        _leakEvents.add(LeakEvent(
          timestamp: DateTime.now(),
          leakCount: totalPotentialLeaks,
          details: _formatLeakDetails(),
        ));

        // Log details
        _recordEvent('leaks_detected', {
          'count': totalPotentialLeaks,
          'timestamp': DateTime.now().toIso8601String(),
          'details': _formatLeakDetails(),
        });
      }
    } catch (e) {
      LoggerService.debug('Error checking for leaks: $e');
    }
  }

  void _recordEvent(String event, Map<String, dynamic> data) {
    if (_reportFile != null) {
      final entry = {
        'event': event,
        'timestamp': DateTime.now().toIso8601String(),
        ...data,
      };

      _reportFile!.writeAsStringSync(
        jsonEncode(entry) + '\n',
        mode: FileMode.append,
      );
    }
  }

  Map<String, dynamic> _formatLeakDetails() {
    // Calculate leak details from our tracking
    final leaksByType = <String, int>{};
    int total = 0;

    for (final entry in _leaksByType.entries) {
      final leaked = entry.value.created - entry.value.disposed;
      if (leaked > 0) {
        leaksByType[entry.key.toString()] = leaked;
        total += leaked;
      }
    }

    return {
      'total': total,
      'by_type': leaksByType,
      'widget_leaks': _widgetLeakCounts.entries
          .where((e) => e.value > 0)
          .map((e) => MapEntry(e.key, e.value))
          .toList(),
      'provider_leaks': _providerLeakCounts.entries
          .where((e) => e.value > 0)
          .map((e) => MapEntry(e.key, e.value))
          .toList(),
    };
  }

  Map<String, dynamic> _generateSummary() {
    // Calculate total leaks from our tracking
    int totalLeaks = 0;
    int leakTypes = 0;

    for (final metrics in _leaksByType.values) {
      final leaked = metrics.created - metrics.disposed;
      if (leaked > 0) {
        totalLeaks += leaked;
        leakTypes++;
      }
    }

    final summary = {
      'total_leaks': totalLeaks,
      'leak_types': leakTypes,
      'suspected_widget_leaks': _widgetLeakCounts.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key}: ${e.value} instances')
          .toList(),
      'suspected_provider_leaks': _providerLeakCounts.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key}: ${e.value} instances')
          .toList(),
      'top_leak_sources': _getTopLeakSources(),
    };

    return summary;
  }

  List<Map<String, dynamic>> _getTopLeakSources() {
    final sources = <Map<String, dynamic>>[];

    // Add type-based leaks
    for (final entry in _leaksByType.entries) {
      final metrics = entry.value;
      final leaked = metrics.created - metrics.disposed;

      if (leaked > 0) {
        sources.add({
          'type': entry.key.toString(),
          'leaked': leaked,
          'created': metrics.created,
          'disposed': metrics.disposed,
          'leak_rate': (leaked / metrics.created * 100).toStringAsFixed(1) + '%',
        });
      }
    }

    // Sort by leak count
    sources.sort((a, b) => (b['leaked'] as int).compareTo(a['leaked'] as int));

    return sources.take(10).toList();
  }

  /// Clear all tracking data
  void clear() {
    _leaksByType.clear();
    _leakEvents.clear();
    _widgetLeakCounts.clear();
    _providerLeakCounts.clear();
  }

  /// Get current statistics
  Map<String, dynamic> getStatistics() {
    final totalCreated = _leaksByType.values.fold(0, (sum, m) => sum + m.created);
    final totalDisposed = _leaksByType.values.fold(0, (sum, m) => sum + m.disposed);
    final potentialLeaks = totalCreated - totalDisposed;

    return {
      'is_monitoring': _isMonitoring,
      'total_created': totalCreated,
      'total_disposed': totalDisposed,
      'potential_leaks': potentialLeaks,
      'widget_leak_suspects': _widgetLeakCounts.length,
      'provider_leak_suspects': _providerLeakCounts.length,
      'leak_events': _leakEvents.length,
    };
  }
}

class LeakMetrics {
  final Type type;
  int created = 0;
  int disposed = 0;

  LeakMetrics({required this.type});

  int get leaked => created - disposed;

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'created': created,
    'disposed': disposed,
    'leaked': leaked,
  };
}

class LeakEvent {
  final DateTime timestamp;
  final int leakCount;
  final Map<String, dynamic> details;

  LeakEvent({
    required this.timestamp,
    required this.leakCount,
    required this.details,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'leak_count': leakCount,
    'details': details,
  };
}

class MemoryLeakReport {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final int totalLeaks;
  final Map<Type, LeakMetrics> leaksByType;
  final Map<String, int> widgetLeaks;
  final Map<String, int> providerLeaks;
  final List<LeakEvent> events;
  final Map<String, dynamic> summary;

  MemoryLeakReport({
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.totalLeaks,
    required this.leaksByType,
    required this.widgetLeaks,
    required this.providerLeaks,
    required this.events,
    required this.summary,
  });

  static MemoryLeakReport empty() => MemoryLeakReport(
    startTime: DateTime.now(),
    endTime: DateTime.now(),
    duration: Duration.zero,
    totalLeaks: 0,
    leaksByType: {},
    widgetLeaks: {},
    providerLeaks: {},
    events: [],
    summary: {},
  );

  Map<String, dynamic> toJson() => {
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'duration_seconds': duration.inSeconds,
    'total_leaks': totalLeaks,
    'leaks_by_type': leaksByType.map((k, v) => MapEntry(k.toString(), v.toJson())),
    'widget_leaks': widgetLeaks,
    'provider_leaks': providerLeaks,
    'events': events.map((e) => e.toJson()).toList(),
    'summary': summary,
  };
}

/// Mixin for widgets to auto-track memory leaks
mixin LeakTracking<T extends StatefulWidget> on State<T> {
  final _detector = MemoryLeakDetector();

  @override
  void initState() {
    super.initState();
    _detector.trackWidget(widget.runtimeType.toString(), isCreated: true);
  }

  @override
  void dispose() {
    _detector.trackWidget(widget.runtimeType.toString(), isCreated: false);
    super.dispose();
  }
}

/// Mixin for providers to auto-track memory leaks
mixin ProviderLeakTracking on ChangeNotifier {
  final _detector = MemoryLeakDetector();

  void initProviderTracking() {
    _detector.trackProvider(runtimeType.toString(), isCreated: true);
  }

  @override
  void dispose() {
    _detector.trackProvider(runtimeType.toString(), isCreated: false);
    super.dispose();
  }
}