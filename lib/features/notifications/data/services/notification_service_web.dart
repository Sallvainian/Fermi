/// Web implementation for notification permissions
library;

import 'package:web/web.dart' as web;

class WebNotification {
  static bool get supported {
    // Check if Notification API is available
    try {
      return web.window.getProperty('Notification') != null;
    } catch (e) {
      return false;
    }
  }
  
  static String? get permission {
    try {
      final notification = web.window.getProperty('Notification');
      if (notification != null) {
        return notification.getProperty('permission')?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  static Future<String> requestPermission() async {
    try {
      final notification = web.window.getProperty('Notification');
      if (notification != null) {
        final requestPermission = notification.getProperty('requestPermission');
        if (requestPermission != null) {
          final promise = requestPermission.callAsFunction();
          // Wait for the promise to resolve
          await Future.delayed(const Duration(milliseconds: 100));
          return permission ?? 'denied';
        }
      }
      return 'denied';
    } catch (e) {
      return 'denied';
    }
  }
}
