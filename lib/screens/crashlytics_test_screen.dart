import 'package:flutter/material.dart';
import '../utils/error_handler.dart';

class CrashlyticsTestScreen extends StatelessWidget {
  const CrashlyticsTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crashlytics Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Firebase Crashlytics Test Functions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use these buttons to test Crashlytics functionality. Note: Test crash only works in release mode.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: () async {
                await ErrorHandler.log('Test log message from Crashlytics test screen');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log message sent to Crashlytics')),
                  );
                }
              },
              child: const Text('Send Log Message'),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () async {
                await ErrorHandler.setCustomKey('test_key', 'test_value_${DateTime.now().millisecondsSinceEpoch}');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Custom key set in Crashlytics')),
                  );
                }
              },
              child: const Text('Set Custom Key'),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () async {
                try {
                  throw Exception('Test non-fatal exception from Crashlytics test');
                } catch (e, stackTrace) {
                  await ErrorHandler.recordError(
                    e,
                    stackTrace,
                    reason: 'User triggered test exception',
                    customKeys: {
                      'test_screen': 'crashlytics_test',
                      'timestamp': DateTime.now().toIso8601String(),
                    },
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Non-fatal error sent to Crashlytics')),
                    );
                  }
                }
              },
              child: const Text('Send Non-Fatal Error'),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                // Show confirmation dialog
                final shouldCrash = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test Fatal Crash'),
                    content: const Text(
                      'This will cause the app to crash (only works in release mode). '
                      'Are you sure you want to proceed?'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Crash App'),
                      ),
                    ],
                  ),
                );
                
                if (shouldCrash == true) {
                  await ErrorHandler.testCrash();
                }
              },
              child: const Text('Test Fatal Crash (Release Only)'),
            ),
            
            const SizedBox(height: 32),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crashlytics Setup Complete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('✅ Android configuration'),
                    Text('✅ iOS configuration'),
                    Text('✅ Web configuration (logs only)'),
                    Text('✅ Error handling utilities'),
                    Text('✅ Test functions'),
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