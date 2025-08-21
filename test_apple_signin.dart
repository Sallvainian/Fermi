import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AppleSignInTestApp());
}

class AppleSignInTestApp extends StatelessWidget {
  const AppleSignInTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apple Sign-In Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AppleSignInTestScreen(),
    );
  }
}

class AppleSignInTestScreen extends StatefulWidget {
  const AppleSignInTestScreen({super.key});

  @override
  State<AppleSignInTestScreen> createState() => _AppleSignInTestScreenState();
}

class _AppleSignInTestScreenState extends State<AppleSignInTestScreen> {
  String _status = 'Not started';
  String _errorDetails = '';
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      setState(() {
        _isAvailable = isAvailable;
        _status = isAvailable 
            ? 'Apple Sign-In is available' 
            : 'Apple Sign-In is NOT available';
      });
    } catch (e) {
      setState(() {
        _status = 'Error checking availability';
        _errorDetails = e.toString();
      });
    }
  }

  Future<void> _testAppleSignIn() async {
    setState(() {
      _status = 'Starting Apple Sign-In...';
      _errorDetails = '';
    });

    try {
      // Step 1: Check availability
      final isAvailable = await SignInWithApple.isAvailable();
      setState(() {
        _status = 'Availability: $isAvailable';
      });

      if (!isAvailable) {
        setState(() {
          _errorDetails = 'Apple Sign-In is not available on this device';
        });
        return;
      }

      // Step 2: Request Apple ID credential
      setState(() {
        _status = 'Requesting Apple ID credential...';
      });

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      setState(() {
        _status = 'Success! Apple Sign-In worked!';
        _errorDetails = '''
User ID: ${credential.userIdentifier}
Email: ${credential.email ?? 'Not provided'}
Given Name: ${credential.givenName ?? 'Not provided'}
Family Name: ${credential.familyName ?? 'Not provided'}
Auth Code: ${credential.authorizationCode.substring(0, 20)}...
ID Token: ${credential.identityToken?.substring(0, 20) ?? 'None'}...
        ''';
      });
    } catch (e) {
      setState(() {
        _status = 'Apple Sign-In Failed';
        _errorDetails = '''
Error Type: ${e.runtimeType}
Error Message: $e

Debugging Info:
- Bundle ID: com.academic-tools.fermi
- Make sure the app is properly provisioned
- Check if Sign in with Apple capability is enabled in Xcode
- Verify entitlements file is linked in project settings
- Ensure you're using a real Apple ID (not simulator account)
        ''';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apple Sign-In Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: _isAvailable ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _isAvailable ? Icons.check_circle : Icons.error,
                      size: 48,
                      color: _isAvailable ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Availability Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isAvailable ? _testAppleSignIn : null,
              icon: const Icon(Icons.apple),
              label: const Text('Test Apple Sign-In'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            if (_errorDetails.isNotEmpty)
              Card(
                color: Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _errorDetails,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuration Checklist:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('✓ Bundle ID: com.academic-tools.fermi'),
                    Text('✓ Entitlements file: Runner.entitlements'),
                    Text('✓ CODE_SIGN_ENTITLEMENTS added to project.pbxproj'),
                    Text('✓ Sign in with Apple capability in entitlements'),
                    Text('✓ Development Team: W778837A9L'),
                    Text('✓ Firebase Apple provider enabled'),
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