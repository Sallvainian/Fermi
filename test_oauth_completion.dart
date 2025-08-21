/// Test script to verify OAuth completion flow
/// This tests the fix for infinite loading spinner after OAuth sign-in

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:teacher_dashboard_flutter/features/auth/providers/auth_provider.dart';
import 'package:teacher_dashboard_flutter/shared/models/user_model.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(TestApp());
}

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: TestScreen(),
      ),
    );
  }
}

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  void _testOAuthFlow() async {
    final auth = context.read<AuthProvider>();
    
    print('Starting OAuth flow test...');
    print('Initial status: ${auth.status}');
    
    // Simulate OAuth sign-in (sets status to authenticating)
    print('\n1. Simulating OAuth sign-in...');
    // This would normally be signInWithGoogle() or signInWithApple()
    // For testing, we'll manually set the status
    
    // Simulate role selection completion
    print('\n2. Simulating role selection (completeOAuthSignUp)...');
    try {
      await auth.completeOAuthSignUp(
        role: UserRole.student,
        parentEmail: null,
        gradeLevel: null,
      );
      
      print('\n3. After completion:');
      print('   Status: ${auth.status}');
      print('   Is Authenticated: ${auth.isAuthenticated}');
      print('   User Model: ${auth.userModel}');
      print('   User Role: ${auth.userModel?.role}');
      
      if (auth.status == AuthStatus.authenticated) {
        print('\n✅ SUCCESS: Status correctly set to authenticated');
        print('   Dashboard should now load properly without infinite spinner');
      } else {
        print('\n❌ ISSUE: Status is not authenticated after completion');
        print('   This would cause the infinite spinner issue');
      }
    } catch (e) {
      print('\n❌ ERROR during OAuth completion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OAuth Flow Test')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Current Status: ${auth.status}',
                    style: TextStyle(fontSize: 18)),
                SizedBox(height: 10),
                Text('Is Authenticated: ${auth.isAuthenticated}',
                    style: TextStyle(fontSize: 16)),
                SizedBox(height: 10),
                Text('User Role: ${auth.userModel?.role ?? "None"}',
                    style: TextStyle(fontSize: 16)),
                SizedBox(height: 10),
                Text('Error: ${auth.errorMessage ?? "None"}',
                    style: TextStyle(fontSize: 16, color: Colors.red)),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _testOAuthFlow,
                  child: Text('Test OAuth Flow'),
                ),
                SizedBox(height: 20),
                if (auth.status == AuthStatus.authenticated)
                  Container(
                    padding: EdgeInsets.all(10),
                    color: Colors.green.shade100,
                    child: Text(
                      '✅ Dashboard would load successfully',
                      style: TextStyle(color: Colors.green.shade900),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (auth.status == AuthStatus.authenticating)
                  Container(
                    padding: EdgeInsets.all(10),
                    color: Colors.orange.shade100,
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          '⚠️ This would show infinite spinner in dashboard',
                          style: TextStyle(color: Colors.orange.shade900),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}