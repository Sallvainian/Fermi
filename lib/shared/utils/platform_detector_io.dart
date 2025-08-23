import 'dart:io';
import 'platform_utils.dart';

/// Get the current platform type using dart:io
PlatformType getPlatformType() {
  if (Platform.isAndroid) return PlatformType.android;
  if (Platform.isIOS) return PlatformType.ios;
  if (Platform.isWindows) return PlatformType.windows;
  if (Platform.isMacOS) return PlatformType.macos;
  if (Platform.isLinux) return PlatformType.linux;
  return PlatformType.unknown;
}