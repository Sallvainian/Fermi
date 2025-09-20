import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../shared/services/logger_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'runtime_analyzer.dart';
import 'runtime_coverage.dart';
import 'execution_logger.dart';
import 'memory_leak_detector.dart';

/// Central monitoring service that aggregates data from all monitoring tools
/// and provides WebSocket server capability for real-time data streaming
class MonitoringService {
  static final MonitoringService _instance = MonitoringService._internal();
  factory MonitoringService() => _instance;
  MonitoringService._internal();

  // Monitoring tools
  final RuntimeAnalyzer _analyzer = RuntimeAnalyzer();
  final RuntimeCoverageTracker _coverage = RuntimeCoverageTracker();
  final ExecutionLogger _executionLogger = ExecutionLogger();
  final MemoryLeakDetector _leakDetector = MemoryLeakDetector();

  // WebSocket management
  HttpServer? _server;
  final List<WebSocketChannel> _clients = [];
  StreamController<Map<String, dynamic>>? _broadcastController;
  Timer? _statusTimer;

  // State
  bool _isMonitoring = false;
  DateTime? _startTime;

  // Circular buffer for event history
  final List<Map<String, dynamic>> _eventHistory = [];
  static const int _maxHistorySize = 1000;

  /// Initialize monitoring service with optional WebSocket server
  Future<void> initialize({
    bool enableWebSocket = false,
    int port = 8080,
    bool enableCoverage = true,
    bool enableExecution = true,
    bool enableLeakDetection = true,
    bool debugMode = false,
  }) async {
    LoggerService.debug('🚀 Initializing Monitoring Service');

    // Initialize monitoring tools
    _analyzer.initialize(
      enableCoverage: enableCoverage,
      enableExecution: enableExecution,
      enableLeakDetection: enableLeakDetection,
      debugMode: debugMode,
    );

    if (enableWebSocket && !kIsWeb) {
      await _startWebSocketServer(port);
    }

    LoggerService.debug('✅ Monitoring Service initialized');
  }

  /// Start WebSocket server for real-time data streaming
  Future<void> _startWebSocketServer(int port) async {
    try {
      _broadcastController = StreamController<Map<String, dynamic>>.broadcast();

      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addMiddleware(_corsMiddleware())
          .addHandler(webSocketHandler((WebSocketChannel webSocket) {
        _handleWebSocketConnection(webSocket);
      }));

      _server = await io.serve(handler, 'localhost', port);
      LoggerService.debug('📡 WebSocket server listening on ws://localhost:$port');

      // Start periodic status updates
      _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _broadcastStatus();
      });
    } catch (e) {
      LoggerService.debug('❌ Failed to start WebSocket server: $e');
    }
  }

  /// CORS middleware for cross-origin requests
  shelf.Middleware _corsMiddleware() {
    return (shelf.Handler handler) {
      return (shelf.Request request) async {
        final response = await handler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        });
      };
    };
  }

  /// Handle new WebSocket connections
  void _handleWebSocketConnection(WebSocketChannel webSocket) {
    LoggerService.debug('🔌 New WebSocket client connected');
    _clients.add(webSocket);

    // Send initial state
    webSocket.sink.add(jsonEncode({
      'type': 'connection',
      'timestamp': DateTime.now().toIso8601String(),
      'message': 'Connected to Monitoring Service',
      'history': _eventHistory.take(100).toList(), // Send last 100 events
    }));

    // Handle client messages
    webSocket.stream.listen(
      (message) {
        _handleClientMessage(webSocket, message);
      },
      onDone: () {
        _clients.remove(webSocket);
        LoggerService.debug('🔌 WebSocket client disconnected');
      },
      onError: (error) {
        _clients.remove(webSocket);
        LoggerService.debug('❌ WebSocket error: $error');
      },
    );
  }

  /// Handle messages from WebSocket clients
  void _handleClientMessage(WebSocketChannel client, dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final command = data['command'] as String?;

      switch (command) {
        case 'start':
          startMonitoring(sessionName: data['sessionName'] as String?);
          break;
        case 'stop':
          stopMonitoring();
          break;
        case 'getStatus':
          _sendStatus(client);
          break;
        case 'getHistory':
          _sendHistory(client, data['limit'] as int? ?? 100);
          break;
        case 'clearHistory':
          _clearHistory();
          break;
        default:
          client.sink.add(jsonEncode({
            'type': 'error',
            'message': 'Unknown command: $command',
          }));
      }
    } catch (e) {
      client.sink.add(jsonEncode({
        'type': 'error',
        'message': 'Failed to process message: $e',
      }));
    }
  }

  /// Start monitoring session
  void startMonitoring({String? sessionName}) {
    if (_isMonitoring) {
      _broadcast({
        'type': 'warning',
        'message': 'Monitoring already in progress',
      });
      return;
    }

    _isMonitoring = true;
    _startTime = DateTime.now();

    // Start all monitors
    _analyzer.startAnalysis(
      sessionName: sessionName,
      metadata: {
        'started_from': 'MonitoringService',
        'websocket_enabled': _server != null,
      },
    );

    _broadcast({
      'type': 'monitoring_started',
      'timestamp': _startTime!.toIso8601String(),
      'session_name': sessionName,
    });

    LoggerService.debug('📊 Monitoring session started');
  }

  /// Stop monitoring session
  Future<Map<String, dynamic>> stopMonitoring() async {
    if (!_isMonitoring) {
      _broadcast({
        'type': 'warning',
        'message': 'No monitoring session in progress',
      });
      return {};
    }

    _isMonitoring = false;
    final report = await _analyzer.stopAnalysis();

    final summary = {
      'type': 'monitoring_stopped',
      'timestamp': DateTime.now().toIso8601String(),
      'duration': report.duration.inSeconds,
      'summary': {
        'dead_code_found': report.deadCode.length,
        'performance_issues': report.performanceIssues.length,
        'memory_leaks': report.memoryIssues.length,
        'recommendations': report.recommendations,
      },
    };

    _broadcast(summary);
    LoggerService.debug('📊 Monitoring session stopped');

    return summary;
  }

  /// Get current monitoring status
  Map<String, dynamic> getStatus() {
    return {
      'is_monitoring': _isMonitoring,
      'start_time': _startTime?.toIso8601String(),
      'websocket_enabled': _server != null,
      'connected_clients': _clients.length,
      'event_history_size': _eventHistory.length,
      'statistics': _analyzer.getStatistics(),
    };
  }

  /// Track an event in the monitoring system
  void trackEvent(String eventType, Map<String, dynamic> data) {
    if (!_isMonitoring) return;

    final event = {
      'type': eventType,
      'timestamp': DateTime.now().toIso8601String(),
      ...data,
    };

    // Add to history with circular buffer
    _eventHistory.add(event);
    if (_eventHistory.length > _maxHistorySize) {
      _eventHistory.removeAt(0);
    }

    // Broadcast to clients
    _broadcast(event);

    // Pass to appropriate monitor
    switch (eventType) {
      case 'function_execution':
        _analyzer.track(
          data['function'] as String,
          className: data['class'] as String?,
          parameters: data['parameters'] as Map<String, dynamic>?,
        );
        break;
      case 'widget_lifecycle':
        _leakDetector.trackWidget(
          data['widget'] as String,
          isCreated: data['created'] as bool,
        );
        break;
      case 'provider_lifecycle':
        _leakDetector.trackProvider(
          data['provider'] as String,
          isCreated: data['created'] as bool,
        );
        break;
    }
  }

  /// Track a timed operation
  Future<T> trackTimed<T>(
    String operationName,
    Future<T> Function() operation, {
    String? className,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isMonitoring) return operation();

    final stopwatch = Stopwatch()..start();

    _broadcast({
      'type': 'operation_started',
      'operation': operationName,
      'class': className,
      'metadata': metadata,
      'timestamp': DateTime.now().toIso8601String(),
    });

    try {
      final result = await _analyzer.trackTimedAsync(
        operationName,
        operation,
        className: className,
        parameters: metadata,
      );

      stopwatch.stop();

      _broadcast({
        'type': 'operation_completed',
        'operation': operationName,
        'class': className,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return result;
    } catch (e) {
      stopwatch.stop();

      _broadcast({
        'type': 'operation_failed',
        'operation': operationName,
        'class': className,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      rethrow;
    }
  }

  /// Broadcast message to all connected clients
  void _broadcast(Map<String, dynamic> data) {
    final message = jsonEncode(data);

    // Add to broadcast stream
    _broadcastController?.add(data);

    // Send to all WebSocket clients
    for (final client in _clients) {
      try {
        client.sink.add(message);
      } catch (e) {
        LoggerService.debug('Failed to send to client: $e');
      }
    }
  }

  /// Send current status to specific client
  void _sendStatus(WebSocketChannel client) {
    client.sink.add(jsonEncode({
      'type': 'status',
      ...getStatus(),
    }));
  }

  /// Send event history to specific client
  void _sendHistory(WebSocketChannel client, int limit) {
    client.sink.add(jsonEncode({
      'type': 'history',
      'events': _eventHistory.take(limit).toList(),
      'total': _eventHistory.length,
    }));
  }

  /// Broadcast status periodically
  void _broadcastStatus() {
    if (!_isMonitoring) return;

    _broadcast({
      'type': 'status_update',
      ...getStatus(),
    });
  }

  /// Clear event history
  void _clearHistory() {
    _eventHistory.clear();
    _broadcast({
      'type': 'history_cleared',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Get broadcast stream for real-time updates
  Stream<Map<String, dynamic>>? get broadcastStream =>
      _broadcastController?.stream;

  /// Shutdown monitoring service
  Future<void> shutdown() async {
    LoggerService.debug('🛑 Shutting down Monitoring Service');

    // Stop monitoring if active
    if (_isMonitoring) {
      await stopMonitoring();
    }

    // Stop status timer
    _statusTimer?.cancel();

    // Close WebSocket connections
    for (final client in _clients) {
      try {
        client.sink.add(jsonEncode({
          'type': 'shutdown',
          'message': 'Monitoring Service shutting down',
        }));
        await client.sink.close();
      } catch (_) {}
    }
    _clients.clear();

    // Close broadcast controller
    await _broadcastController?.close();

    // Stop WebSocket server
    await _server?.close(force: true);
    _server = null;

    LoggerService.debug('✅ Monitoring Service shutdown complete');
  }
}

/// Widget wrapper that enables monitoring for the app
class MonitoringServiceWidget extends StatefulWidget {
  final Widget child;
  final bool enableMonitoring;
  final bool enableWebSocket;
  final int webSocketPort;

  const MonitoringServiceWidget({
    super.key,
    required this.child,
    this.enableMonitoring = true,
    this.enableWebSocket = false,
    this.webSocketPort = 8080,
  });

  @override
  State<MonitoringServiceWidget> createState() => _MonitoringServiceWidgetState();
}

class _MonitoringServiceWidgetState extends State<MonitoringServiceWidget> {
  final MonitoringService _service = MonitoringService();

  @override
  void initState() {
    super.initState();
    if (widget.enableMonitoring) {
      _initializeMonitoring();
    }
  }

  Future<void> _initializeMonitoring() async {
    await _service.initialize(
      enableWebSocket: widget.enableWebSocket,
      port: widget.webSocketPort,
      debugMode: kDebugMode,
    );
    _service.startMonitoring(sessionName: 'app_session');
  }

  @override
  void dispose() {
    if (widget.enableMonitoring) {
      _service.shutdown();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}