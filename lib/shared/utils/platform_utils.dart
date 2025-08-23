import 'package:flutter/foundation.dart';
import 'platform_detector_stub.dart'
    if (dart.library.io) 'platform_detector_io.dart'
    if (dart.library.html) 'platform_detector_web.dart';

/// Utility class for safe platform detection across all platforms
class PlatformUtils {
  /// Check if running on web
  static bool get isWeb => kIsWeb;

  /// Check if running on Windows (safely handles web)
  static bool get isWindows {
    if (kIsWeb) return false;
    return getPlatformType() == PlatformType.windows;
  }

  /// Check if running on Android (safely handles web)
  static bool get isAndroid {
    if (kIsWeb) return false;
    return getPlatformType() == PlatformType.android;
  }

  /// Check if running on iOS (safely handles web)
  static bool get isIOS {
    if (kIsWeb) return false;
    return getPlatformType() == PlatformType.ios;
  }

  /// Check if running on macOS (safely handles web)
  static bool get isMacOS {
    if (kIsWeb) return false;
    return getPlatformType() == PlatformType.macos;
  }

  /// Check if running on Linux (safely handles web)
  static bool get isLinux {
    if (kIsWeb) return false;
    return getPlatformType() == PlatformType.linux;
  }

  /// Check if platform supports native Firebase
  static bool get isFirebaseSupported {
    return isWeb || isAndroid || isIOS || isMacOS;
  }

  /// Check if platform needs Windows-specific services
  static bool get needsWindowsServices {
    return isWindows || isLinux;
  }

  /// Check if running on desktop (Windows, macOS, Linux)
  static bool get isDesktop {
    return isWindows || isMacOS || isLinux;
  }

  /// Check if running on mobile (Android, iOS)
  static bool get isMobile {
    return isAndroid || isIOS;
  }

  /// Get a human-readable platform name
  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Check if running in debug mode
  static bool get isDebugMode => kDebugMode;

  /// Check if running in release mode
  static bool get isReleaseMode => kReleaseMode;

  /// Check if running in profile mode
  static bool get isProfileMode => kProfileMode;
}

/// Enum for platform types
enum PlatformType {
  android,
  ios,
  windows,
  macos,
  linux,
  web,
  unknown,
}