import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teacher_dashboard_flutter/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      title: 'Simple DB Test',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  final _emailController = TextEditingController(text: 'test@example.com');
  final _passwordController = TextEditingController(text: 'test123');
  String _status = 'Not signed in';
  User? _user;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _user = user;
        _status = user != null ? 'Signed in as: ${user.email}' : 'Not signed in';
      });
    });
  }

  Future<void> _signUp() async {
    try {
      setState(() => _status = 'Creating account...');
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _signIn() async {
    try {
      setState(() => _status = 'Signing in...');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _testUserWrite() async {
    if (_user == null) {
      setState(() => _status = 'Must be signed in!');
      return;
    }

    try {
      setState(() => _status = 'Writing to users collection...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .set({
        'email': _user!.email,
        'displayName': 'Test User',
        'lastUpdated': FieldValue.serverTimestamp(),
        'testData': {
          'number': 42,
          'text': 'Hello Firestore!',
          'timestamp': DateTime.now().toIso8601String(),
        }
      });
      setState(() => _status = '✅ Write to users successful!');
    } catch (e) {
      setState(() => _status = '❌ Write failed: $e');
    }
  }

  Future<void> _testUserRead() async {
    if (_user == null) {
      setState(() => _status = 'Must be signed in!');
      return;
    }

    try {
      setState(() => _status = 'Reading from users collection...');
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      
      if (doc.exists) {
        setState(() => _status = '✅ Read successful: ${doc.data()}');
      } else {
        setState(() => _status = 'No user document found');
      }
    } catch (e) {
      setState(() => _status = '❌ Read failed: $e');
    }
  }

  Future<void> _testClassCreate() async {
    if (_user == null) {
      setState(() => _status = 'Must be signed in!');
      return;
    }

    try {
      setState(() => _status = 'Creating a class...');
      final classRef = await FirebaseFirestore.instance.collection('classes').add({
        'name': 'Test Class ${DateTime.now().millisecondsSinceEpoch}',
        'teacherId': _user!.uid,
        'teacherEmail': _user!.email,
        'subject': 'Mathematics',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      setState(() => _status = '✅ Class created with ID: ${classRef.id}');
    } catch (e) {
      setState(() => _status = '❌ Create class failed: $e');
    }
  }

  Future<void> _testClassRead() async {
    if (_user == null) {
      setState(() => _status = 'Must be signed in!');
      return;
    }

    try {
      setState(() => _status = 'Reading classes...');
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: _user!.uid)
          .get();
      
      setState(() => _status = '✅ Found ${snapshot.docs.length} classes');
    } catch (e) {
      setState(() => _status = '❌ Read classes failed: $e');
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Firebase Test'),
        actions: [
          if (_user != null)
            IconButton(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _status,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_user == null) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _signUp,
                      child: const Text('Sign Up'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _signIn,
                      child: const Text('Sign In'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'User Collection Tests:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _testUserWrite,
                child: const Text('Test Write to Users'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _testUserRead,
                child: const Text('Test Read from Users'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Classes Collection Tests:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _testClassCreate,
                child: const Text('Create a Class'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _testClassRead,
                child: const Text('Read My Classes'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}