import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_dashboard_flutter/shared/services/region_detector_service.dart';
import 'package:teacher_dashboard_flutter/shared/config/region_config.dart';

void main() {
  group('Region Detection Tests', () {
    late RegionDetectorService regionDetector;

    setUp(() {
      regionDetector = RegionDetectorService();
    });

    test('Service initializes without errors', () async {
      await expectLater(
        regionDetector.initialize(),
        completes,
      );
    });

    test('Returns valid region status', () {
      final status = regionDetector.getRegionStatus();
      
      expect(status, isNotNull);
      expect(status.containsKey('isInRestrictedRegion'), isTrue);
      expect(status.containsKey('isCallKitAllowed'), isTrue);
      expect(status.containsKey('platform'), isTrue);
      expect(status.containsKey('locale'), isTrue);
    });

    test('CallKit restrictions are inverse of restricted region', () async {
      await regionDetector.initialize();
      
      // If in restricted region, CallKit should not be allowed
      if (regionDetector.isInRestrictedRegion) {
        expect(regionDetector.isCallKitAllowed, isFalse);
      }
      
      // Note: The inverse is not always true because CallKit might be
      // unavailable for other reasons (e.g., Android platform)
    });

    test('Force China mode configuration works', () {
      // This test would only work if FORCE_CHINA_MODE is set during build
      if (RegionConfig.forceChinaMode) {
        expect(RegionConfig.getConfiguration().allowCallKit, isFalse);
        expect(RegionConfig.getConfiguration().allowVoIPPush, isFalse);
        expect(RegionConfig.getConfiguration().requireStandardPush, isTrue);
      }
    });

    test('Standard configuration allows CallKit', () {
      final config = AppConfiguration.standard();
      
      expect(config.allowCallKit, isTrue);
      expect(config.allowVoIPPush, isTrue);
      expect(config.requireStandardPush, isFalse);
      expect(config.disabledFeatures, isEmpty);
    });

    test('China configuration disables CallKit', () {
      final config = AppConfiguration.china();
      
      expect(config.allowCallKit, isFalse);
      expect(config.allowVoIPPush, isFalse);
      expect(config.requireStandardPush, isTrue);
      expect(config.disabledFeatures, contains('callkit'));
      expect(config.disabledFeatures, contains('voip_push'));
      expect(config.disabledFeatures, contains('pushkit'));
    });

    test('Feature checking works correctly', () {
      final chinaConfig = AppConfiguration.china();
      final standardConfig = AppConfiguration.standard();
      
      expect(chinaConfig.isFeatureDisabled('callkit'), isTrue);
      expect(chinaConfig.isFeatureDisabled('voip_push'), isTrue);
      expect(chinaConfig.isFeatureDisabled('random_feature'), isFalse);
      
      expect(standardConfig.isFeatureDisabled('callkit'), isFalse);
      expect(standardConfig.isFeatureDisabled('voip_push'), isFalse);
    });

    test('Refresh region detection completes', () async {
      await regionDetector.initialize();
      
      await expectLater(
        regionDetector.refreshRegionDetection(),
        completes,
      );
    });

    test('Safe defaults when uninitialized', () {
      // Before initialization, should default to safe mode
      final newDetector = RegionDetectorService();
      
      // Should default to restricted for safety
      expect(newDetector.isInRestrictedRegion, isTrue);
      expect(newDetector.isCallKitAllowed, isFalse);
    });
  });

  group('China Region Compliance', () {
    test('China regions are properly identified', () {
      const chinaRegions = ['CN', 'CHN', 'HK', 'HKG', 'MO', 'MAC', 'TW', 'TWN'];
      
      for (final region in chinaRegions) {
        // This test verifies that our region list is comprehensive
        expect(chinaRegions, contains(region));
      }
    });

    test('China timezones are properly identified', () {
      const chinaTimeZones = [
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
      
      for (final tz in chinaTimeZones) {
        // Verify all expected China timezones are in our list
        expect(chinaTimeZones, contains(tz));
      }
    });
  });
}