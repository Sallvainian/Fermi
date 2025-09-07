import 'dart:async';
import 'package:flutter/services.dart';
import 'logger_service.dart';

/// Service for detecting caps lock state across platforms
/// Encapsulates platform-specific logic and provides debouncing
class CapsLockService {
  static CapsLockService? _instance;
  
  /// Singleton instance
  static CapsLockService get instance {
    _instance ??= CapsLockService._();
    return _instance!;
  }
  
  CapsLockService._();
  
  Timer? _debounceTimer;
  bool _lastKnownState = false;
  
  /// Default debounce duration to prevent excessive checks
  static const Duration defaultDebounceDuration = Duration(milliseconds: 150);
  
  /// Check caps lock state with optional debouncing
  /// Returns null if platform doesn't support detection
  Future<bool?> checkCapsLockState({
    Duration debounce = defaultDebounceDuration,
    required Function(bool) onStateChanged,
  }) async {
    // Cancel any existing timer
    _debounceTimer?.cancel();
    
    // If debounce is zero, check immediately
    if (debounce == Duration.zero) {
      return _performCapsLockCheck(onStateChanged);
    }
    
    // Otherwise debounce the check
    _debounceTimer = Timer(debounce, () async {
      await _performCapsLockCheck(onStateChanged);
    });
    
    return null; // Debounced, will callback later
  }
  
  /// Perform the actual caps lock check
  Future<bool?> _performCapsLockCheck(Function(bool) onStateChanged) async {
    try {
      // Use HardwareKeyboard API - most reliable method
      final capsLockOn = HardwareKeyboard.instance.lockModesEnabled
          .contains(KeyboardLockMode.capsLock);
      
      // Only trigger callback if state actually changed
      if (capsLockOn != _lastKnownState) {
        _lastKnownState = capsLockOn;
        onStateChanged(capsLockOn);
      }
      
      return capsLockOn;
    } catch (e) {
      // Platform doesn't support HardwareKeyboard API
      LoggerService.debug(
        'Platform does not support caps lock detection: $e',
        tag: 'CapsLockService',
      );
      
      // Clear state if we can't detect
      if (_lastKnownState) {
        _lastKnownState = false;
        onStateChanged(false);
      }
      
      return null;
    }
  }
  
  /// Check caps lock synchronously (no debouncing)
  bool checkCapsLockSync() {
    try {
      return HardwareKeyboard.instance.lockModesEnabled
          .contains(KeyboardLockMode.capsLock);
    } catch (e) {
      return false;
    }
  }
  
  /// Cancel any pending debounced checks
  void cancelPendingChecks() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
  
  /// Reset the service state
  void reset() {
    cancelPendingChecks();
    _lastKnownState = false;
  }
  
  /// Dispose of resources
  void dispose() {
    cancelPendingChecks();
  }
}