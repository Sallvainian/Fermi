/// Web implementation for notification permissions
library;

import 'dart:html' as html show Notification;

class WebNotification {
  static bool get supported => html.Notification.supported;
  static String? get permission => html.Notification.permission;
  static Future<String> requestPermission() =>
      html.Notification.requestPermission();
}
