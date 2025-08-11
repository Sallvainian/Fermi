import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:async';

/// Special screen to force Crashlytics initial sync
class ForceCrashlyticsSync extends StatefulWidget {
  const ForceCrashlyticsSync({super.key});

  @override
  State<ForceCrashlyticsSync> createState() => _ForceCrashlyticsSyncState();
}

class _ForceCrashlyticsSyncState extends State<ForceCrashlyticsSync> {
  String _status = 'Initializing...';
  bool _isCrashlyticsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkCrashlyticsStatus();
  }

  Future<void> _checkCrashlyticsStatus() async {
    setState(() {
      _status = 'Checking Crashlytics status...';
    });

    // Check if Crashlytics collection is enabled
    final isEnabled = FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled;
    
    setState(() {
      _isCrashlyticsEnabled = isEnabled;
      _status = isEnabled 
        ? 'Crashlytics is ENABLED and ready' 
        : 'Crashlytics is DISABLED';
    });

    if (!isEnabled) {
      // Enable Crashlytics collection
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      setState(() {
        _isCrashlyticsEnabled = true;
        _status = 'Crashlytics has been ENABLED';
      });
    }
  }

  Future<void> _sendTestData() async {
    setState(() {
      _status = 'Sending test data to Crashlytics...';
    });

    try {
      // Set user identifier
      await FirebaseCrashlytics.instance.setUserIdentifier('test_user_${DateTime.now().millisecondsSinceEpoch}');
      
      // Set custom keys
      await FirebaseCrashlytics.instance.setCustomKey('test_timestamp', DateTime.now().toIso8601String());
      await FirebaseCrashlytics.instance.setCustomKey('test_platform', Theme.of(context).platform.toString());
      await FirebaseCrashlytics.instance.setCustomKey('sync_test', true);
      
      // Log multiple messages
      for (int i = 0; i < 5; i++) {
        FirebaseCrashlytics.instance.log('Test log message #$i at ${DateTime.now()}');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Record multiple non-fatal errors
      for (int i = 0; i < 3; i++) {
        try {
          throw Exception('Test exception #$i for Crashlytics sync');
        } catch (error, stack) {
          await FirebaseCrashlytics.instance.recordError(
            error,
            stack,
            reason: 'Intentional test error #$i',
            information: ['Test info #$i', 'Platform: ${Theme.of(context).platform}'],
            printDetails: true,
            fatal: false,
          );
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }

      setState(() {
        _status = 'Test data sent! Check Firebase Console in 2-5 minutes.';
      });

      // Force send pending reports
      await FirebaseCrashlytics.instance.sendUnsentReports();
      
      setState(() {
        _status = 'Unsent reports forced to send. Data should appear soon.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _forceRealCrash() async {
    // Record some data before crashing
    FirebaseCrashlytics.instance.log('About to force a real crash for sync');
    FirebaseCrashlytics.instance.setCustomKey('crash_type', 'forced_sync_crash');
    FirebaseCrashlytics.instance.setCustomKey('crash_time', DateTime.now().toIso8601String());
    
    // Small delay to ensure data is recorded
    await Future.delayed(const Duration(seconds: 1));
    
    // Force a real crash
    FirebaseCrashlytics.instance.crash();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Force Crashlytics Sync'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: _isCrashlyticsEnabled ? Colors.green : Colors.orange,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _isCrashlyticsEnabled ? Icons.check_circle : Icons.warning,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            ElevatedButton.icon(
              onPressed: _checkCrashlyticsStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Status'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
              ),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: _sendTestData,
              icon: const Icon(Icons.send),
              label: const Text('Send Test Data (No Crash)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
              ),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: () async {
                // Enable Crashlytics if not enabled
                if (!FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled) {
                  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
                }
                
                // Check collection status
                final enabled = FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled;
                
                if (!mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Collection enabled: $enabled'),
                    backgroundColor: enabled ? Colors.green : Colors.red,
                  ),
                );
              },
              icon: const Icon(Icons.toggle_on),
              label: const Text('Enable Collection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.purple,
              ),
            ),
            
            const SizedBox(height: 32),
            
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Force Real Crash'),
                    content: const Text(
                      'This will crash the app to complete Crashlytics initial sync.\n\n'
                      'The app will close immediately.\n\n'
                      'After restarting, data should appear in Firebase Console.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _forceRealCrash();
                        },
                        child: const Text(
                          'CRASH NOW',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.dangerous),
              label: const Text('FORCE REAL CRASH'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.red,
              ),
            ),
            
            const SizedBox(height: 32),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Troubleshooting Steps:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Make sure app is running in Release mode'),
                    Text('2. Click "Enable Collection" first'),
                    Text('3. Click "Send Test Data" to send non-fatal errors'),
                    Text('4. If still no data, click "FORCE REAL CRASH"'),
                    Text('5. Restart app after crash'),
                    Text('6. Wait 2-5 minutes and check Firebase Console'),
                    SizedBox(height: 8),
                    Text(
                      'Note: Debug mode may delay or prevent data upload.',
                      style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
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