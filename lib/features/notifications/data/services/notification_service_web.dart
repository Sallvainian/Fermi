/// Web implementation for notification permissions
library;

import 'dart:js_interop';
import 'package:web/web.dart' as web;

class WebNotification {
  static bool get supported {
    // Check if Notification API is available
    try {
      // Just try to access permission - if it throws, notifications aren't supported
      web.Notification.permission;
      return true;
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
      // requestPermission() returns JSPromise<JSString>
      final jsPromise = web.Notification.requestPermission();
      
      // Convert JSPromise<JSString> to Future<JSString> using .toDart
      final jsString = await jsPromise.toDart;
      
      // Convert JSString to Dart String using .toDart
      return jsString.toDart;
    } catch (e) {
      return 'denied';
    }
  }
}
