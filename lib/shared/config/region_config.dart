/// Region-specific configuration for app features
/// This handles compliance with regional regulations like China's MIIT requirements
class RegionConfig {
  // Build-time configuration flags
  // These can be set via --dart-define during build for region-specific builds
  
  /// Whether to force China region mode (for China-specific App Store builds)
  static const bool forceChinaMode = bool.fromEnvironment(
    'FORCE_CHINA_MODE',
    defaultValue: false,
  );
  
  /// Whether to force enable CallKit (for testing, overrides region detection)
  static const bool forceEnableCallKit = bool.fromEnvironment(
    'FORCE_ENABLE_CALLKIT',
    defaultValue: false,
  );
  
  /// Whether to use verbose logging for region detection
  static const bool verboseRegionLogging = bool.fromEnvironment(
    'VERBOSE_REGION_LOGGING',
    defaultValue: false,
  );
  
  /// Get the app configuration based on region
  static AppConfiguration getConfiguration() {
    if (forceChinaMode) {
      return AppConfiguration.china();
    }
    return AppConfiguration.standard();
  }
}

/// App configuration based on region
class AppConfiguration {
  final bool allowCallKit;
  final bool allowVoIPPush;
  final bool requireStandardPush;
  final String notificationStrategy;
  final List<String> disabledFeatures;
  
  const AppConfiguration({
    required this.allowCallKit,
    required this.allowVoIPPush,
    required this.requireStandardPush,
    required this.notificationStrategy,
    required this.disabledFeatures,
  });
  
  /// Standard configuration for most regions
  factory AppConfiguration.standard() {
    return const AppConfiguration(
      allowCallKit: true,
      allowVoIPPush: true,
      requireStandardPush: false,
      notificationStrategy: 'native',
      disabledFeatures: [],
    );
  }
  
  /// China-specific configuration
  factory AppConfiguration.china() {
    return const AppConfiguration(
      allowCallKit: false,
      allowVoIPPush: false,
      requireStandardPush: true,
      notificationStrategy: 'standard',
      disabledFeatures: ['callkit', 'voip_push', 'pushkit'],
    );
  }
  
  /// Check if a feature is disabled
  bool isFeatureDisabled(String feature) {
    return disabledFeatures.contains(feature.toLowerCase());
  }
}