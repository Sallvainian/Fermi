/// Web implementation for notification permissions
library;

import 'dart:js_interop';
import 'package:web/web.dart' as web;

class WebNotification {
  static bool get supported {
    // Check if Notification API is available
    try {
      return web.Notification.permission.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  static String? get permission {
    try {
      return web.Notification.permission;
    } catch (e) {
      return null;
    }
  }
  
  static Future<String> requestPermission() async {
    try {
      final jsPromise = web.Notification.requestPermission();
      final permission = await jsPromise.toDart;
      return permission.toDart;
    } catch (e) {
      return 'denied';
    }
  }
}
