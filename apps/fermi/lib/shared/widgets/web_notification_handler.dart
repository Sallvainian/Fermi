import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../features/notifications/data/services/web_in_app_notification_service.dart';

/// Widget that handles displaying in-app notifications on web
class WebNotificationHandler extends StatefulWidget {
  final Widget child;

  const WebNotificationHandler({
    super.key,
    required this.child,
  });

  @override
  State<WebNotificationHandler> createState() => _WebNotificationHandlerState();
}

class _WebNotificationHandlerState extends State<WebNotificationHandler> {
  final WebInAppNotificationService _notificationService =
      WebInAppNotificationService();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _setupNotificationListener();
    }
  }

  void _setupNotificationListener() {
    // Set up the callback to show notifications
    _notificationService.onNotificationReceived = (title, body, data) {
      // Show notification using SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ],
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).primaryColor,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    };
  }

  @override
  void dispose() {
    if (kIsWeb) {
      _notificationService.onNotificationReceived = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
