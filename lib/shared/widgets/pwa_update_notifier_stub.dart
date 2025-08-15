import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms
class PWAUpdateNotifier extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
  
  const PWAUpdateNotifier({
    super.key,
    required this.child,
    this.navigatorKey,
    this.scaffoldMessengerKey,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}