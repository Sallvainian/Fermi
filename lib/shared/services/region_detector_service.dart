import 'dart:io';
import 'package:flutter/foundation.dart';
import 'logger_service.dart';

/// Service to detect the device's region
/// Helps determine region-specific features and restrictions
class RegionDetectorService {
  static final RegionDetectorService _instance = RegionDetectorService._internal();
  factory RegionDetectorService() => _instance;
  RegionDetectorService._internal();

  // Cache the region check result
  bool? _isInRestrictedRegion;
  
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
      // Perform runtime detection
      // Determine if device is in a restricted region
      await _detectRestrictedRegion();
      
      LoggerService.info(
        'Region detection initialized. Restricted region: $_isInRestrictedRegion',
        tag: 'RegionDetectorService',
      );
    } catch (e) {
      LoggerService.error('Failed to initialize region detection', error: e, tag: 'RegionDetectorService');
      // Default to safe mode (restrictions enabled) if detection fails
      _isInRestrictedRegion = true;
    }
  }

  /// Detect if the device is in a restricted region (China)
  Future<void> _detectRegion() async {
    // Web platform doesn't have region restrictions
    if (kIsWeb) {
      _isInRestrictedRegion = false;
      return;
    }

    // Only iOS has certain restrictions
    if (!Platform.isIOS) {
      _isInRestrictedRegion = false;
      return;
    }

    try {
      // Method 1: Check system locale
      final locale = PlatformDispatcher.instance.locale;
      final countryCode = locale.countryCode?.toUpperCase() ?? '';
      
      if (_chinaRegionCodes.contains(countryCode)) {
        LoggerService.info('China region detected via locale: $countryCode', tag: 'RegionDetectorService');
        _isInRestrictedRegion = true;
        return;
      }

      // Method 2: Check timezone
      final timeZoneIdentifier = _getCurrentTimeZoneIdentifier();
      
      if (_isChineseTimeZone(timeZoneIdentifier)) {
        LoggerService.info('China region detected via timezone: $timeZoneIdentifier', tag: 'RegionDetectorService');
        _isInRestrictedRegion = true;
        return;
      }

      // No restrictions detected
      _isInRestrictedRegion = false;
      
    } catch (e) {
      LoggerService.error('Error during region detection', error: e, tag: 'RegionDetectorService');
      // Default to restricted mode for safety
      _isInRestrictedRegion = true;
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

  /// Check if device is in a restricted region (China)
  bool get isInRestrictedRegion {
    if (_isInRestrictedRegion == null) {
      LoggerService.warning('Region detection not initialized, defaulting to restricted', tag: 'RegionDetectorService');
      return true; // Default to restricted for safety
    }
    return _isInRestrictedRegion!;
  }

  /// Force refresh region detection (e.g., after language/region change)
  Future<void> refreshRegionDetection() async {
    _isInRestrictedRegion = null;
    await _detectRegion();
  }

  /// Get region status for debugging
  Map<String, dynamic> getRegionStatus() {
    return {
      'isInRestrictedRegion': _isInRestrictedRegion,
      'platform': Platform.operatingSystem,
      'isWeb': kIsWeb,
      'locale': PlatformDispatcher.instance.locale.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}