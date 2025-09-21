import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for thread-safe Firestore operations
///
/// This class provides wrappers around Firestore stream operations to ensure
/// callbacks are executed on the platform thread, preventing threading errors
/// that occur when Firebase operations complete on background threads.
///
/// Optimized for performance with Future.microtask and includes platform-aware
/// execution, priority scheduling, and callback deduplication.
class FirestoreThreadSafe {
  // Priority queue for callback execution
  static final List<_PrioritizedCallback> _callbackQueue = [];
  static bool _isProcessingQueue = false;

  // Callback deduplication tracking
  static final Map<String, DateTime> _recentCallbacks = {};
  static const Duration _deduplicationWindow = Duration(milliseconds: 16);

  // Metrics tracking
  static int _totalCallbacks = 0;
  static int _dedupedCallbacks = 0;
  static int _queueDepth = 0;
  static int _maxQueueDepth = 0;

  // Platform detection - only apply workaround on Windows/Linux
  static bool get _needsThreadWorkaround {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isLinux;
    } catch (_) {
      return false; // Fallback for platforms where Platform isn't available
    }
  }

  /// Creates a thread-safe stream listener for Firestore queries
  ///
  /// This wrapper ensures that all stream callbacks are executed on the
  /// platform thread using optimized scheduling with Future.microtask.
  ///
  /// Features:
  /// - Platform-aware execution (only applies workaround on Windows/Linux)
  /// - Priority-based scheduling for critical updates
  /// - Callback deduplication to prevent queue accumulation
  /// - Metrics tracking for monitoring performance
  ///
  /// Usage:
  /// ```dart
  /// _subscription = FirestoreThreadSafe.listen(
  ///   _firestore.collection('users').snapshots(),
  ///   onData: (snapshot) {
  ///     // Handle data safely on platform thread
  ///   },
  ///   onError: (error) {
  ///     // Handle errors safely on platform thread
  ///   },
  ///   priority: CallbackPriority.high, // Optional
  /// );
  /// ```
  static StreamSubscription<T> listen<T>(
    Stream<T> stream, {
    required void Function(T data) onData,
    void Function(Object error)? onError,
    void Function()? onDone,
    bool? cancelOnError,
    CallbackPriority priority = CallbackPriority.normal,
    String? deduplicationKey,
  }) {
    // If platform doesn't need workaround, use direct listener
    if (!_needsThreadWorkaround) {
      return stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
    }
    return stream.listen(
      (data) {
        executeWithPriority(
          () => onData(data),
          priority: priority,
          deduplicationKey:
              deduplicationKey ??
              'data_${data.runtimeType}_${DateTime.now().microsecondsSinceEpoch}',
        );
      },
      onError: onError != null
          ? (error) {
              executeWithPriority(
                () => onError(error),
                priority: CallbackPriority.high, // Errors get high priority
                deduplicationKey:
                    'error_${error.runtimeType}_${DateTime.now().microsecondsSinceEpoch}',
              );
            }
          : null,
      onDone: onDone != null
          ? () {
              executeWithPriority(
                onDone,
                priority: priority,
                deduplicationKey:
                    'done_${stream.runtimeType}_${DateTime.now().microsecondsSinceEpoch}',
              );
            }
          : null,
      cancelOnError: cancelOnError,
    );
  }

  /// Safely executes a callback on the platform thread with priority
  ///
  /// This is useful for one-off operations that need to update UI state
  /// from Firestore callbacks. Uses Future.microtask for faster execution.
  static void runOnPlatformThread(
    VoidCallback callback, {
    CallbackPriority priority = CallbackPriority.normal,
  }) {
    if (!_needsThreadWorkaround) {
      callback();
      return;
    }

    executeWithPriority(callback, priority: priority);
  }

  /// Execute callbacks with priority and deduplication (exposed for testing)
  @visibleForTesting
  static void executeWithPriority(
    VoidCallback callback, {
    required CallbackPriority priority,
    String? deduplicationKey,
  }) {
    _totalCallbacks++;

    // Check for deduplication
    if (deduplicationKey != null) {
      final lastExecution = _recentCallbacks[deduplicationKey];
      if (lastExecution != null) {
        final timeSince = DateTime.now().difference(lastExecution);
        if (timeSince < _deduplicationWindow) {
          _dedupedCallbacks++;
          return; // Skip duplicate callback
        }
      }
      _recentCallbacks[deduplicationKey] = DateTime.now();

      // Clean old entries periodically
      if (_recentCallbacks.length > 100) {
        final cutoff = DateTime.now().subtract(_deduplicationWindow * 2);
        _recentCallbacks.removeWhere((_, time) => time.isBefore(cutoff));
      }
    }

    // Check if we can execute immediately
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      callback();
      return;
    }

    // Add to priority queue
    final prioritizedCallback = _PrioritizedCallback(callback, priority);
    _callbackQueue.add(prioritizedCallback);
    _callbackQueue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    // Update metrics
    _queueDepth = _callbackQueue.length;
    if (_queueDepth > _maxQueueDepth) {
      _maxQueueDepth = _queueDepth;
    }

    // Process queue if not already processing
    if (!_isProcessingQueue) {
      _processCallbackQueue();
    }
  }

  /// Process the callback queue with Future.microtask for optimal performance
  static void _processCallbackQueue() {
    if (_callbackQueue.isEmpty || _isProcessingQueue) return;

    _isProcessingQueue = true;

    // Use Future.microtask for fastest possible execution on event loop
    Future.microtask(() {
      while (_callbackQueue.isNotEmpty) {
        final callback = _callbackQueue.removeAt(0);
        _queueDepth = _callbackQueue.length;

        try {
          callback.execute();
        } catch (e, stack) {
          // Log error but continue processing queue
          debugPrint('Error in FirestoreThreadSafe callback: $e\n$stack');
        }
      }
      _isProcessingQueue = false;
    });
  }

  /// Creates a thread-safe wrapper for notifying listeners
  ///
  /// This ensures the callback is called on the platform thread,
  /// preventing setState during build errors.
  ///
  /// Usage: Instead of calling notifyListeners() directly in your ChangeNotifier,
  /// call: FirestoreThreadSafe.safeNotify(() => notifyListeners());
  static void safeNotify(
    VoidCallback notifyCallback, {
    CallbackPriority priority =
        CallbackPriority.high, // UI updates get high priority
  }) {
    runOnPlatformThread(notifyCallback, priority: priority);
  }

  /// Get current metrics for monitoring
  static FirestoreMetrics getMetrics() {
    return FirestoreMetrics(
      totalCallbacks: _totalCallbacks,
      dedupedCallbacks: _dedupedCallbacks,
      currentQueueDepth: _queueDepth,
      maxQueueDepth: _maxQueueDepth,
      deduplicationRate: _totalCallbacks > 0
          ? (_dedupedCallbacks / _totalCallbacks * 100).toStringAsFixed(2)
          : '0.00',
    );
  }

  /// Reset metrics (useful for testing or monitoring windows)
  static void resetMetrics() {
    _totalCallbacks = 0;
    _dedupedCallbacks = 0;
    _queueDepth = 0;
    _maxQueueDepth = 0;
  }

  /// Wraps a Firestore document snapshot stream for thread safety
  static Stream<DocumentSnapshot<Map<String, dynamic>>> documentStream(
    DocumentReference<Map<String, dynamic>> reference, {
    CallbackPriority priority = CallbackPriority.normal,
  }) {
    // Skip wrapper on platforms that don't need it
    if (!_needsThreadWorkaround) {
      return reference.snapshots();
    }

    final controller =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();

    final subscription = reference.snapshots().listen(
      (snapshot) {
        runOnPlatformThread(() {
          if (!controller.isClosed) {
            controller.add(snapshot);
          }
        }, priority: priority);
      },
      onError: (error) {
        runOnPlatformThread(() {
          if (!controller.isClosed) {
            controller.addError(error);
          }
        }, priority: CallbackPriority.high);
      },
    );

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Wraps a Firestore query snapshot stream for thread safety
  static Stream<QuerySnapshot<Map<String, dynamic>>> queryStream(
    Query<Map<String, dynamic>> query, {
    CallbackPriority priority = CallbackPriority.normal,
  }) {
    // Skip wrapper on platforms that don't need it
    if (!_needsThreadWorkaround) {
      return query.snapshots();
    }

    final controller =
        StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

    final subscription = query.snapshots().listen(
      (snapshot) {
        runOnPlatformThread(() {
          if (!controller.isClosed) {
            controller.add(snapshot);
          }
        }, priority: priority);
      },
      onError: (error) {
        runOnPlatformThread(() {
          if (!controller.isClosed) {
            controller.addError(error);
          }
        }, priority: CallbackPriority.high);
      },
    );

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }
}

/// Priority levels for callback execution
enum CallbackPriority { low, normal, high, critical }

/// Internal class to hold prioritized callbacks
class _PrioritizedCallback {
  final VoidCallback callback;
  final CallbackPriority priority;
  final DateTime timestamp;

  _PrioritizedCallback(this.callback, this.priority)
    : timestamp = DateTime.now();

  void execute() => callback();
}

/// Metrics class for monitoring FirestoreThreadSafe performance
class FirestoreMetrics {
  final int totalCallbacks;
  final int dedupedCallbacks;
  final int currentQueueDepth;
  final int maxQueueDepth;
  final String deduplicationRate;

  const FirestoreMetrics({
    required this.totalCallbacks,
    required this.dedupedCallbacks,
    required this.currentQueueDepth,
    required this.maxQueueDepth,
    required this.deduplicationRate,
  });

  @override
  String toString() {
    return 'FirestoreMetrics(total: $totalCallbacks, deduped: $dedupedCallbacks ($deduplicationRate%), '
        'queue: $currentQueueDepth, maxQueue: $maxQueueDepth)';
  }
}
