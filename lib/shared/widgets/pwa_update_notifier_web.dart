import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../services/logger_service.dart';

// Optional JavaScript functions - may not exist
@JS('applyUpdate')
external void _applyUpdateJS();

@JS('flutterUpdateAvailable')
external set _flutterUpdateAvailableJS(JSFunction? f);

@JS('canAutoRefresh')
external set _canAutoRefreshJS(JSFunction? f);

// Safe wrapper to check if JavaScript functions exist
bool _jsFunctionsAvailable = false;

void _checkJSFunctions() {
  // Enable PWA update functionality now that JS functions are in place
  _jsFunctionsAvailable = true;
}

void _setFlutterUpdateAvailable(JSFunction? f) {
  if (!_jsFunctionsAvailable) return;
  try {
    _flutterUpdateAvailableJS = f;
  } catch (e) {
    LoggerService.warning(
      'PWA update functions not available',
      tag: 'PWAUpdate',
    );
  }
}

void _setCanAutoRefresh(JSFunction? f) {
  if (!_jsFunctionsAvailable) return;
  try {
    _canAutoRefreshJS = f;
  } catch (e) {
    LoggerService.warning(
      'PWA update functions not available',
      tag: 'PWAUpdate',
    );
  }
}

void _callApplyUpdate() {
  if (!_jsFunctionsAvailable) {
    // Fallback: reload the page
    web.window.location.reload();
    return;
  }
  try {
    _applyUpdateJS();
  } catch (e) {
    // Fallback: reload the page
    web.window.location.reload();
  }
}

/// PWA Update Notifier Widget
/// Displays a non-intrusive notification when app updates are available
/// and handles the update process smoothly
class PWAUpdateNotifier extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  const PWAUpdateNotifier({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
  });

  @override
  State<PWAUpdateNotifier> createState() => _PWAUpdateNotifierState();
}

class _PWAUpdateNotifierState extends State<PWAUpdateNotifier> {
  bool _updateAvailable = false;
  String _currentVersion = '';
  final String _newVersion = '';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _checkJSFunctions();
      _setupUpdateListener();
      _checkInitialVersion();
    }
  }

  void _setupUpdateListener() {
    // Listen for PWA update event from DOM
    final listener = ((web.Event event) {
      if (mounted) {
        setState(() {
          _updateAvailable = true;
          // Version info can be passed through event detail if needed
        });

        // Show update notification
        _showUpdateNotification();
      }
    }).toJS;

    web.document.addEventListener('pwa-update-available', listener);

    // Register Flutter callback for JavaScript to call (fallback)
    _setFlutterUpdateAvailable(
      ((JSAny? data) {
            if (mounted && data != null) {
              setState(() {
                _updateAvailable = true;
                // Parse version info from data if available
              });

              // Show update notification
              _showUpdateNotification();
            }
          }.toJS
          as JSFunction),
    );

    // Register auto-refresh check
    _setCanAutoRefresh(
      (() {
            // Return false if user has unsaved work or is in middle of something
            // For now, we'll always return false to let user decide
            return false.toJS;
          }.toJS
          as JSFunction),
    );
  }

  void _checkInitialVersion() {
    try {
      // Get current version from DOM if available
      final versionMeta = web.document.querySelector(
        'meta[name="app-version"]',
      );
      if (versionMeta != null) {
        _currentVersion = versionMeta.getAttribute('content') ?? '';
        LoggerService.info(
          'Current app version: $_currentVersion',
          tag: 'PWAUpdate',
        );
      }
    } catch (e) {
      LoggerService.warning(
        'Could not fetch version info: $e',
        tag: 'PWAUpdate',
      );
    }
  }

  void _showUpdateNotification() {
    if (!_updateAvailable || !mounted) return;

    // Defer until after MaterialApp is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = widget.scaffoldMessengerKey.currentState;
      if (messenger == null) return;

      messenger.showSnackBar(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  Future<void> _applyUpdate() async {
    if (_isRefreshing || !mounted) return;

    setState(() {
      _isRefreshing = true;
    });

    // Safe dialog via navigatorKey (no ancestor Navigator required)
    final ctx = widget.navigatorKey.currentContext;
    if (ctx != null) {
      showDialog(
        context: ctx,
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
    }

    // Give the dialog a beat, then trigger the JS update
    await Future.delayed(const Duration(seconds: 1));
    _callApplyUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter, // Use non-directional alignment
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
                      color: Colors.black.withValues(alpha: 0.2),
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
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
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
      _setFlutterUpdateAvailable(null);
      _setCanAutoRefresh(null);
    }
    super.dispose();
  }
}
