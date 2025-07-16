import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'logger_service.dart';

/// Service for handling retries with exponential backoff.
/// 
/// Provides resilient error handling for network operations,
/// API calls, and other potentially failing operations.
class RetryService {
  /// Default retry configuration
  static const RetryConfig defaultConfig = RetryConfig();
  
  /// Execute an operation with retry logic.
  /// 
  /// Attempts to execute the provided operation with automatic
  /// retry on failure using exponential backoff.
  /// 
  /// @param operation The async operation to execute
  /// @param config Retry configuration options
  /// @param onRetry Optional callback called before each retry
  /// @return Result of the operation
  /// @throws The last error if all retries fail
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    RetryConfig config = defaultConfig,
    void Function(int attempt, Duration delay, dynamic error)? onRetry,
  }) async {
    int attempt = 0;
    dynamic lastError;
    
    while (attempt < config.maxAttempts) {
      try {
        // Attempt the operation
        return await operation();
      } catch (error) {
        lastError = error;
        attempt++;
        
        // Check if error is retryable
        if (!_isRetryableError(error, config)) {
          LoggerService.error(
            'Non-retryable error encountered (attempt: $attempt)',
            error: error,
          );
          rethrow;
        }
        
        // Check if we've exhausted retries
        if (attempt >= config.maxAttempts) {
          LoggerService.error(
            'Max retry attempts reached (attempts: $attempt, max: ${config.maxAttempts})',
            error: error,
          );
          break;
        }
        
        // Calculate delay with exponential backoff
        final delay = _calculateDelay(
          attempt: attempt,
          baseDelay: config.baseDelay,
          maxDelay: config.maxDelay,
          jitter: config.useJitter,
        );
        
        // Log retry attempt
        LoggerService.warning(
          'Retrying operation (attempt: $attempt/${config.maxAttempts}, delay: ${delay.inMilliseconds}ms, error: ${error.toString()})',
        );
        
        // Call retry callback if provided
        onRetry?.call(attempt, delay, error);
        
        // Wait before retrying
        await Future.delayed(delay);
      }
    }
    
    // All retries exhausted
    throw RetryException(
      'Operation failed after $attempt attempts',
      lastError: lastError,
      attempts: attempt,
    );
  }
  
  /// Execute an operation with timeout and retry.
  /// 
  /// Combines timeout handling with retry logic for operations
  /// that might hang or take too long.
  static Future<T> withTimeoutAndRetry<T>(
    Future<T> Function() operation, {
    required Duration timeout,
    RetryConfig config = defaultConfig,
    void Function(int attempt, Duration delay, dynamic error)? onRetry,
  }) async {
    return withRetry(
      () => operation().timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Operation timed out after ${timeout.inSeconds} seconds',
            timeout,
          );
        },
      ),
      config: config,
      onRetry: onRetry,
    );
  }
  
  /// Execute multiple operations with retry.
  /// 
  /// Attempts all operations and retries only the failed ones.
  /// Useful for batch operations where partial success is acceptable.
  static Future<List<RetryResult<T>>> withRetryBatch<T>(
    List<Future<T> Function()> operations, {
    RetryConfig config = defaultConfig,
    bool stopOnFirstError = false,
  }) async {
    final results = <RetryResult<T>>[];
    
    for (int i = 0; i < operations.length; i++) {
      try {
        final result = await withRetry(
          operations[i],
          config: config,
        );
        results.add(RetryResult.success(result, index: i));
      } catch (error) {
        results.add(RetryResult.failure(error, index: i));
        
        if (stopOnFirstError) {
          // Add remaining operations as skipped
          for (int j = i + 1; j < operations.length; j++) {
            results.add(RetryResult.skipped(index: j));
          }
          break;
        }
      }
    }
    
    return results;
  }
  
  /// Create a retry-enabled function wrapper.
  /// 
  /// Wraps a function to automatically retry on failure.
  /// Useful for creating resilient API clients.
  static Future<T> Function() createRetryable<T>(
    Future<T> Function() operation, {
    RetryConfig config = defaultConfig,
  }) {
    return () => withRetry(operation, config: config);
  }
  
  /// Calculate delay with exponential backoff.
  static Duration _calculateDelay({
    required int attempt,
    required Duration baseDelay,
    required Duration maxDelay,
    required bool jitter,
  }) {
    // Calculate exponential delay
    final exponentialDelay = baseDelay * pow(2, attempt - 1);
    
    // Cap at max delay
    var delay = exponentialDelay > maxDelay ? maxDelay : exponentialDelay;
    
    // Add jitter if enabled
    if (jitter) {
      final random = Random();
      final jitterAmount = delay * random.nextDouble() * 0.3; // Up to 30% jitter
      delay = delay + jitterAmount;
    }
    
    return delay;
  }
  
  /// Check if an error is retryable.
  static bool _isRetryableError(dynamic error, RetryConfig config) {
    // Check custom retry condition
    if (config.retryIf != null) {
      return config.retryIf!(error);
    }
    
    // Default retryable errors
    final errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unavailable') ||
        errorString.contains('deadline')) {
      return true;
    }
    
    // Firebase errors
    if (errorString.contains('firebase') &&
        (errorString.contains('unavailable') ||
         errorString.contains('internal') ||
         errorString.contains('deadline-exceeded'))) {
      return true;
    }
    
    // HTTP errors (5xx are retryable, 4xx are not)
    if (error is Exception) {
      final message = error.toString();
      if (message.contains('500') ||
          message.contains('502') ||
          message.contains('503') ||
          message.contains('504')) {
        return true;
      }
    }
    
    return false;
  }
}

/// Configuration for retry behavior.
@immutable
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxAttempts;
  
  /// Base delay between retries
  final Duration baseDelay;
  
  /// Maximum delay between retries
  final Duration maxDelay;
  
  /// Whether to add jitter to delays
  final bool useJitter;
  
  /// Custom condition for retryable errors
  final bool Function(dynamic error)? retryIf;
  
  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.useJitter = true,
    this.retryIf,
  });
  
  /// Create a copy with updated values
  RetryConfig copyWith({
    int? maxAttempts,
    Duration? baseDelay,
    Duration? maxDelay,
    bool? useJitter,
    bool Function(dynamic error)? retryIf,
  }) {
    return RetryConfig(
      maxAttempts: maxAttempts ?? this.maxAttempts,
      baseDelay: baseDelay ?? this.baseDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      useJitter: useJitter ?? this.useJitter,
      retryIf: retryIf ?? this.retryIf,
    );
  }
}

/// Result of a batch retry operation.
class RetryResult<T> {
  /// Whether the operation succeeded
  final bool success;
  
  /// The result value (if successful)
  final T? value;
  
  /// The error (if failed)
  final dynamic error;
  
  /// Whether the operation was skipped
  final bool skipped;
  
  /// Index in the original batch
  final int index;
  
  const RetryResult._({
    required this.success,
    this.value,
    this.error,
    required this.skipped,
    required this.index,
  });
  
  /// Create a successful result
  factory RetryResult.success(T value, {required int index}) {
    return RetryResult._(
      success: true,
      value: value,
      skipped: false,
      index: index,
    );
  }
  
  /// Create a failed result
  factory RetryResult.failure(dynamic error, {required int index}) {
    return RetryResult._(
      success: false,
      error: error,
      skipped: false,
      index: index,
    );
  }
  
  /// Create a skipped result
  factory RetryResult.skipped({required int index}) {
    return RetryResult._(
      success: false,
      skipped: true,
      index: index,
    );
  }
}

/// Exception thrown when all retry attempts fail.
class RetryException implements Exception {
  /// Error message
  final String message;
  
  /// The last error encountered
  final dynamic lastError;
  
  /// Number of attempts made
  final int attempts;
  
  const RetryException(
    this.message, {
    this.lastError,
    required this.attempts,
  });
  
  @override
  String toString() {
    return 'RetryException: $message (attempts: $attempts, lastError: $lastError)';
  }
}

/// Common retry configurations.
class RetryConfigs {
  /// Fast retry for quick operations
  static const fast = RetryConfig(
    maxAttempts: 3,
    baseDelay: Duration(milliseconds: 100),
    maxDelay: Duration(seconds: 2),
  );
  
  /// Standard retry for network operations
  static const standard = RetryConfig(
    maxAttempts: 3,
    baseDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
  );
  
  /// Aggressive retry for critical operations
  static const aggressive = RetryConfig(
    maxAttempts: 5,
    baseDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 60),
  );
  
  /// No retry (single attempt)
  static const noRetry = RetryConfig(
    maxAttempts: 1,
  );
}