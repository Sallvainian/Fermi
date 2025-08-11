import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Debug screen for testing Firebase Crashlytics integration
class CrashlyticsTestScreen extends StatelessWidget {
  const CrashlyticsTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crashlytics Test'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              color: Colors.orange,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning,
                      size: 48,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Crashlytics Test Screen',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use the buttons below to test Crashlytics.\n'
                      'After triggering a crash, restart the app for data to sync.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Log a message to Crashlytics
                FirebaseCrashlytics.instance.log('Test log message from Flutter');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Log message sent to Crashlytics'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.message),
              label: const Text('Send Test Log'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Record a non-fatal error
                try {
                  throw Exception('This is a test non-fatal exception');
                } catch (error, stack) {
                  FirebaseCrashlytics.instance.recordError(
                    error,
                    stack,
                    reason: 'Testing non-fatal error recording',
                    fatal: false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Non-fatal error recorded to Crashlytics'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.error_outline),
              label: const Text('Record Non-Fatal Error'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Set custom keys for crash reports
                FirebaseCrashlytics.instance.setCustomKey('test_key', 'test_value');
                FirebaseCrashlytics.instance.setCustomKey('test_number', 42);
                FirebaseCrashlytics.instance.setCustomKey('test_bool', true);
                FirebaseCrashlytics.instance.setUserIdentifier('test_user_123');
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Custom keys and user ID set'),
                    backgroundColor: Colors.purple,
                  ),
                );
              },
              icon: const Icon(Icons.key),
              label: const Text('Set Custom Keys'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.purple,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Show confirmation dialog before crashing
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Force Test Crash'),
                    content: const Text(
                      'This will crash the app immediately.\n\n'
                      'The crash data will be sent to Crashlytics when you restart the app.\n\n'
                      'Are you sure you want to proceed?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Force a crash to test Crashlytics
                          FirebaseCrashlytics.instance.crash();
                        },
                        child: const Text(
                          'CRASH APP',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.dangerous),
              label: const Text('FORCE TEST CRASH'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.red,
              ),
            ),
            const SizedBox(height: 32),
            const Card(
              color: Colors.grey,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'Note: After crashing, restart the app and wait a few minutes '
                      'for the data to appear in the Firebase Console.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}