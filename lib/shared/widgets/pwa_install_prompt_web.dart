import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

class PWAInstallPrompt extends StatefulWidget {
  const PWAInstallPrompt({super.key});

  @override
  State<PWAInstallPrompt> createState() => _PWAInstallPromptState();
}

class _PWAInstallPromptState extends State<PWAInstallPrompt> {
  bool _isIOSSafari = false;
  bool _isStandalone = false;
  bool _promptDismissed = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _checkPlatform();
    }
  }

  void _checkPlatform() {
    final userAgent = web.window.navigator.userAgent.toLowerCase();
    final isIOS = userAgent.contains('iphone') || userAgent.contains('ipad');
    final isSafari =
        userAgent.contains('safari') &&
        !userAgent.contains('chrome') &&
        !userAgent.contains('crios');

    // Check if app is already installed (running in standalone mode)
    // For iOS, we can only check via matchMedia since navigator.standalone requires JS interop
    final isStandalone = web.window
        .matchMedia('(display-mode: standalone)')
        .matches;

    setState(() {
      _isIOSSafari = kIsWeb && isIOS && isSafari;
      _isStandalone = isStandalone;
    });
  }

  void _dismissPrompt() {
    setState(() {
      _promptDismissed = true;
    });
    // Store dismissal in local storage
    web.window.localStorage.setItem('pwa_prompt_dismissed', 'true');
  }

  @override
  Widget build(BuildContext context) {
    // Only show on iOS Safari, not in standalone mode, and not dismissed
    if (!_isIOSSafari || _isStandalone || _promptDismissed) {
      return const SizedBox.shrink();
    }

    // Check if previously dismissed
    final previouslyDismissed =
        web.window.localStorage.getItem('pwa_prompt_dismissed') == 'true';
    if (previouslyDismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 8,
        color: Theme.of(context).primaryColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.install_mobile,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Install Teacher Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add to Home Screen for the best experience',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 230),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _dismissPrompt,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 38),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildInstallStep(
                      '1',
                      'Tap the Share button',
                      Icons.ios_share,
                    ),
                    const SizedBox(height: 8),
                    _buildInstallStep(
                      '2',
                      'Scroll down and tap "Add to Home Screen"',
                      Icons.add_box_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildInstallStep(
                      '3',
                      'Tap "Add" to install',
                      Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _dismissPrompt,
                    child: const Text(
                      'Maybe Later',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Show full instructions dialog
                      showDialog(
                        context: context,
                        builder: (context) =>
                            _buildDetailedInstructions(context),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                    child: const Text('Show Me How'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallStep(String number, String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedInstructions(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.install_mobile, color: Colors.blue),
          SizedBox(width: 8),
          Text('Install App Instructions'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Follow these steps to install Teacher Dashboard on your iOS device:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildDetailedStep(
              '1',
              'Find the Share Button',
              'Look for the square icon with an arrow pointing up at the bottom of Safari',
              Icons.ios_share,
            ),
            _buildDetailedStep(
              '2',
              'Tap "Add to Home Screen"',
              'Scroll down in the share menu and find this option',
              Icons.add_to_home_screen,
            ),
            _buildDetailedStep(
              '3',
              'Name Your App',
              'You can keep "Teacher Dashboard" or change it',
              Icons.edit,
            ),
            _buildDetailedStep(
              '4',
              'Tap "Add"',
              'The app icon will appear on your home screen',
              Icons.check_circle,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 77)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'After installation, the app will open in full-screen mode without Safari controls!',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got It!'),
        ),
      ],
    );
  }

  Widget _buildDetailedStep(
    String number,
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class to check if running as PWA
class PWAUtils {
  static bool get isRunningAsPWA {
    if (!kIsWeb) return false;

    return web.window.matchMedia('(display-mode: standalone)').matches ||
        web.window.matchMedia('(display-mode: fullscreen)').matches;
  }

  static bool get isIOS {
    if (!kIsWeb) return false;

    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod');
  }

  static bool get isIOSSafari {
    if (!kIsWeb) return false;

    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return isIOS &&
        userAgent.contains('safari') &&
        !userAgent.contains('chrome') &&
        !userAgent.contains('crios');
  }

  static void clearInstallPromptDismissal() {
    if (kIsWeb) {
      web.window.localStorage.removeItem('pwa_prompt_dismissed');
    }
  }
}
