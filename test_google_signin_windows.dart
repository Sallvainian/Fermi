import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/firebase_options.dart';
import 'lib/features/auth/data/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env file
  await dotenv.load(fileName: '.env');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Sign-In Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final AuthService _authService = AuthService();
  String _status = 'Not signed in';
  bool _isLoading = false;
  
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _status = 'Signing in...';
    });
    
    try {
      final user = await _authService.signInWithGoogle();
      
      setState(() {
        if (user != null) {
          _status = 'Signed in as: ${user.email}';
        } else {
          _status = 'Sign in cancelled';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
      _status = 'Signing out...';
    });
    
    try {
      await _authService.signOut();
      setState(() {
        _status = 'Signed out';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error signing out: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sign-In Test'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _status,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _signInWithGoogle,
                      child: const Text('Sign In with Google'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _signOut,
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}