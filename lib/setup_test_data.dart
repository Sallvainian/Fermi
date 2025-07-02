import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SetupApp());
}

class SetupApp extends StatelessWidget {
  const SetupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Setup',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SetupScreen(),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _status = 'Ready to set up test accounts';
  
  Future<void> _createTeacherAccount() async {
    try {
      setState(() => _status = 'Creating teacher account...');
      
      // Create auth account
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'teacher@test.com',
        password: 'test123',
      );
      
      // Create user document with teacher role
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'uid': credential.user!.uid,
        'email': 'teacher@test.com',
        'displayName': 'Test Teacher',
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
      
      setState(() => _status = '✅ Teacher account created: teacher@test.com / test123');
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
    }
  }
  
  Future<void> _createStudentAccount() async {
    try {
      setState(() => _status = 'Creating student account...');
      
      // Create auth account
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'student@test.com',
        password: 'test123',
      );
      
      // Create user document with student role
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'uid': credential.user!.uid,
        'email': 'student@test.com',
        'displayName': 'Test Student',
        'role': 'student',
        'gradeLevel': 5,
        'parentEmail': 'parent@test.com',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
      
      setState(() => _status = '✅ Student account created: student@test.com / test123');
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
    }
  }
  
  Future<void> _testTeacherOperations() async {
    try {
      setState(() => _status = 'Testing teacher operations...');
      
      // Sign in as teacher
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'teacher@test.com',
        password: 'test123',
      );
      
      final user = FirebaseAuth.instance.currentUser!;
      
      // Create a class
      final classRef = await FirebaseFirestore.instance.collection('classes').add({
        'name': 'Test Class',
        'teacherId': user.uid,
        'teacherName': 'Test Teacher',
        'subject': 'Mathematics',
        'gradeLevel': 5,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Add a student to the class
      await classRef.collection('students').add({
        'name': 'Test Student',
        'email': 'student@test.com',
        'gradeLevel': 5,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      
      // Create an assignment
      await classRef.collection('assignments').add({
        'title': 'Math Homework',
        'description': 'Complete problems 1-10',
        'dueDate': DateTime.now().add(const Duration(days: 7)),
        'totalPoints': 100,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      setState(() => _status = '✅ Teacher operations successful!');
    } catch (e) {
      setState(() => _status = '❌ Teacher operations failed: $e');
    }
  }
  
  Future<void> _testStudentOperations() async {
    try {
      setState(() => _status = 'Testing student operations...');
      
      // Sign in as student
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'student@test.com',
        password: 'test123',
      );
      
      final user = FirebaseAuth.instance.currentUser!;
      
      // Read classes (should work)
      final classes = await FirebaseFirestore.instance.collection('classes').get();
      
      // Try to write to a class (should fail)
      try {
        await classes.docs.first.reference.update({'test': 'fail'});
        setState(() => _status = '❌ Security rules not working - student could write!');
        return;
      } catch (e) {
        // Expected to fail
      }
      
      // Read own user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        setState(() => _status = '✅ Student operations successful! Can read but not write to classes.');
      } else {
        setState(() => _status = '❌ Could not read own user document');
      }
    } catch (e) {
      setState(() => _status = '❌ Student operations failed: $e');
    }
  }
  
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    setState(() => _status = 'Signed out');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Setup & Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _status,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _createTeacherAccount,
              child: const Text('1. Create Teacher Account'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createStudentAccount,
              child: const Text('2. Create Student Account'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _testTeacherOperations,
              child: const Text('3. Test Teacher Operations'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _testStudentOperations,
              child: const Text('4. Test Student Operations'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _signOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}