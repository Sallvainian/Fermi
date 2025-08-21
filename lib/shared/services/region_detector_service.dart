import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'logger_service.dart';
import '../config/region_config.dart';

/// Service to detect the device's region and determine feature availability
/// Specifically handles China region restrictions for CallKit (iOS) and similar features
class RegionDetectorService {
  static final RegionDetectorService _instance = RegionDetectorService._internal();
  factory RegionDetectorService() => _instance;
  RegionDetectorService._internal();

  // Cache the region check result
  bool? _isInRestrictedRegion;
  bool? _isCallKitAllowed;
  
  // China region identifiers
  static const List<String> _chinaRegionCodes = [
    'CN', 'CHN',     // Mainland China
    'HK', 'HKG',     // Hong Kong SAR
    'MO', 'MAC',     // Macau SAR
    'TW', 'TWN',     // Taiwan (some restrictions may apply)
  ];
  
  // China timezone identifiers
  static const List<String> _chinaTimeZones = [
    'Asia/Shanghai',
    'Asia/Beijing',
    'Asia/Chongqing',
    'Asia/Harbin',
    'Asia/Kashgar',
    'Asia/Urumqi',
    'Asia/Hong_Kong',
    'Asia/Macau',
    'Asia/Taipei',
  ];

  /// Initialize the region detection service
  Future<void> initialize() async {
    try {
      // Check build-time configuration first
      if (RegionConfig.forceChinaMode) {
        LoggerService.info('Force China mode enabled via build configuration', tag: 'RegionDetectorService');
        _isInRestrictedRegion = true;
        _isCallKitAllowed = false;
        return;
      }
      
      if (RegionConfig.forceEnableCallKit) {
        LoggerService.info('Force CallKit enabled via build configuration (testing mode)', tag: 'RegionDetectorService');
        _isInRestrictedRegion = false;
        _isCallKitAllowed = true;
        return;
      }
      
      // Perform runtime detection
      await _detectRegion();
      
      if (RegionConfig.verboseRegionLogging) {
        LoggerService.info(
          'Region detection initialized. Restricted region: $_isInRestrictedRegion, CallKit allowed: $_isCallKitAllowed',
          tag: 'RegionDetectorService',
        );
      }
    } catch (e) {
      LoggerService.error('Failed to initialize region detection', error: e, tag: 'RegionDetectorService');
      // Default to safe mode (restrictions enabled) if detection fails
      _isInRestrictedRegion = true;
      _isCallKitAllowed = false;
    }
  }

  /// Detect if the device is in a restricted region (China)
  Future<void> _detectRegion() async {
    // Web platform doesn't have region restrictions
    if (kIsWeb) {
      _isInRestrictedRegion = false;
      _isCallKitAllowed = true;
      return;
    }

    // Only iOS has CallKit restrictions
    if (!Platform.isIOS) {
      _isInRestrictedRegion = false;
      _isCallKitAllowed = true;
      return;
    }

    try {
      // Method 1: Check system locale
      final locale = PlatformDispatcher.instance.locale;
      final countryCode = locale.countryCode?.toUpperCase() ?? '';
      
      if (_chinaRegionCodes.contains(countryCode)) {
        LoggerService.info('China region detected via locale: $countryCode', tag: 'RegionDetectorService');
        _isInRestrictedRegion = true;
        _isCallKitAllowed = false;
        return;
      }

      // Method 2: Check timezone
      final timeZoneIdentifier = _getCurrentTimeZoneIdentifier();
      
      if (_isChineseTimeZone(timeZoneIdentifier)) {
        LoggerService.info('China region detected via timezone: $timeZoneIdentifier', tag: 'RegionDetectorService');
        _isInRestrictedRegion = true;
        _isCallKitAllowed = false;
        return;
      }

      // Method 3: Platform channel for native detection
      final isInChina = await _checkNativeRegion();
      if (isInChina) {
        LoggerService.info('China region detected via native platform check', tag: 'RegionDetectorService');
        _isInRestrictedRegion = true;
        _isCallKitAllowed = false;
        return;
      }

      // Method 4: Check if CallKit is available (iOS will disable it in China)
      final callKitAvailable = await _checkCallKitAvailability();
      if (!callKitAvailable) {
        LoggerService.info('CallKit not available - likely in restricted region', tag: 'RegionDetectorService');
        _isInRestrictedRegion = true;
        _isCallKitAllowed = false;
        return;
      }

      // No restrictions detected
      _isInRestrictedRegion = false;
      _isCallKitAllowed = true;
      
    } catch (e) {
      LoggerService.error('Error during region detection', error: e, tag: 'RegionDetectorService');
      // Default to restricted mode for safety
      _isInRestrictedRegion = true;
      _isCallKitAllowed = false;
    }
  }

  /// Get current timezone identifier
  String _getCurrentTimeZoneIdentifier() {
    // This is a simplified approach - in production, you might want to use
    // a more robust timezone detection library
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    
    // Check for China Standard Time (UTC+8)
    if (offset.inHours == 8) {
      // Could be China, Hong Kong, Taiwan, Singapore, etc.
      // Need additional checks
      return 'Asia/Shanghai'; // Placeholder
    }
    
    return '';
  }

  /// Check if timezone indicates China region
  bool _isChineseTimeZone(String timeZone) {
    final lowerTimeZone = timeZone.toLowerCase();
    return _chinaTimeZones.any((tz) => lowerTimeZone.contains(tz.toLowerCase()));
  }

  /// Platform channel to check native region
  Future<bool> _checkNativeRegion() async {
    if (!Platform.isIOS) return false;
    
    try {
      const platform = MethodChannel('com.academic-tools.fermi/region');
      final bool isInChina = await platform.invokeMethod('isInChinaRegion') ?? false;
      return isInChina;
    } catch (e) {
      LoggerService.warning('Native region check failed: $e', tag: 'RegionDetectorService');
      return false;
    }
  }

  /// Check if CallKit is available on the device
  Future<bool> _checkCallKitAvailability() async {
    if (!Platform.isIOS) return true;
    
    try {
      // Try to access CallKit - it will fail in China
      const platform = MethodChannel('com.academic-tools.fermi/callkit');
      final bool isAvailable = await platform.invokeMethod('isCallKitAvailable') ?? false;
      return isAvailable;
    } catch (e) {
      LoggerService.warning('CallKit availability check failed: $e', tag: 'RegionDetectorService');
      return false;
    }
  }

  /// Check if device is in a restricted region (China)
  bool get isInRestrictedRegion {
    if (_isInRestrictedRegion == null) {
      LoggerService.warning('Region detection not initialized, defaulting to restricted', tag: 'RegionDetectorService');
      return true; // Default to restricted for safety
    }
    return _isInRestrictedRegion!;
  }

  /// Check if CallKit is allowed (not in China region for iOS)
  bool get isCallKitAllowed {
    if (_isCallKitAllowed == null) {
      LoggerService.warning('CallKit availability not determined, defaulting to disabled', tag: 'RegionDetectorService');
      return false; // Default to disabled for safety
    }
    return _isCallKitAllowed!;
  }

  /// Force refresh region detection (e.g., after language/region change)
  Future<void> refreshRegionDetection() async {
    _isInRestrictedRegion = null;
    _isCallKitAllowed = null;
    await _detectRegion();
  }

  /// Get region status for debugging
  Map<String, dynamic> getRegionStatus() {
    return {
      'isInRestrictedRegion': _isInRestrictedRegion,
      'isCallKitAllowed': _isCallKitAllowed,
      'platform': Platform.operatingSystem,
      'isWeb': kIsWeb,
      'locale': PlatformDispatcher.instance.locale.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}