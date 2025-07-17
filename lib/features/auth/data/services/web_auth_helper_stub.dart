import 'dart:async';

/// Stub implementation for non-web platforms
class WebAuthHelper {
  static final WebAuthHelper _instance = WebAuthHelper._internal();
  factory WebAuthHelper() => _instance;
  WebAuthHelper._internal();

  void initialize() {
    // No-op on non-web platforms
  }

  Stream<Map<String, dynamic>>? get authMessages => null;

  void injectPopupHelper(dynamic popup) {
    // No-op on non-web platforms
  }

  void dispose() {
    // No-op on non-web platforms
  }
}