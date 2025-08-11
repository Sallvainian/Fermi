import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:js' as js;

/// PWA Update Notifier Widget
/// Displays a non-intrusive notification when app updates are available
/// and handles the update process smoothly
class PWAUpdateNotifier extends StatefulWidget {
  final Widget child;
  
  const PWAUpdateNotifier({
    super.key,
    required this.child,
  });

  @override
  State<PWAUpdateNotifier> createState() => _PWAUpdateNotifierState();
}

class _PWAUpdateNotifierState extends State<PWAUpdateNotifier> {
  bool _updateAvailable = false;
  String _currentVersion = '';
  String _newVersion = '';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    
    if (kIsWeb) {
      _setupUpdateListener();
      _checkInitialVersion();
    }
  }

  void _setupUpdateListener() {
    // Register Flutter callback for JavaScript to call
    js.context['flutterUpdateAvailable'] = (dynamic data) {
      if (mounted) {
        setState(() {
          _updateAvailable = true;
          _currentVersion = data['currentVersion'] ?? '';
          _newVersion = data['newVersion'] ?? '';
        });
        
        // Show update notification
        _showUpdateNotification();
      }
    };
    
    // Register auto-refresh check
    js.context['canAutoRefresh'] = () {
      // Return false if user has unsaved work or is in middle of something
      // For now, we'll always return false to let user decide
      return false;
    };
  }

  void _checkInitialVersion() async {
    try {
      final response = await html.HttpRequest.getString('/version.json?t=${DateTime.now().millisecondsSinceEpoch}');
      // Parse and store version info if needed
      debugPrint('Current app version: $response');
    } catch (e) {
      debugPrint('Could not fetch version info: $e');
    }
  }

  void _showUpdateNotification() {
    if (!_updateAvailable || !mounted) return;
    
    // Show snackbar with update option
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Available!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_newVersion.isNotEmpty)
                    Text(
                      'Version $_currentVersion → $_newVersion',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(days: 1), // Keep visible until action
        action: SnackBarAction(
          label: 'Update Now',
          textColor: Colors.lightBlueAccent,
          onPressed: _applyUpdate,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blueGrey.shade800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _applyUpdate() {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Updating...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Applying update to version $_newVersion'),
              const SizedBox(height: 8),
              const Text(
                'The app will refresh automatically.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Delay slightly to show dialog, then refresh
    Future.delayed(const Duration(seconds: 1), () {
      js.context.callMethod('applyUpdate');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Floating update banner (alternative to snackbar)
        if (_updateAvailable && !_isRefreshing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.system_update,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'A new version is available!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_newVersion.isNotEmpty)
                                Text(
                                  'Update to version $_newVersion',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _applyUpdate,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                          ),
                          child: const Text('Update'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          iconSize: 20,
                          onPressed: () {
                            setState(() {
                              _updateAvailable = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    if (kIsWeb) {
      // Clean up JavaScript callbacks
      js.context['flutterUpdateAvailable'] = null;
      js.context['canAutoRefresh'] = null;
    }
    super.dispose();
  }
}