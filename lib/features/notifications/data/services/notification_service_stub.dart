/// Stub implementation for non-web platforms
class WebNotification {
  static bool get supported => false;
  static String? get permission => null;
  static Future<String> requestPermission() async => 'denied';
}
