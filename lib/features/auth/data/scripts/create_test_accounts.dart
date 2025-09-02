import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../firebase_options.dart';
import '../services/username_auth_service.dart';

/// Script to create test accounts and update existing users with usernames
/// 
/// Run this with: flutter run lib/features/auth/data/scripts/create_test_accounts.dart
void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  final usernameService = UsernameAuthService();
  
  print('Starting account creation and migration...\n');
  
  // 1. Update existing teacher account with username
  print('Updating existing teacher account...');
  try {
    await firestore.collection('users').doc('zxD9cZale9OHvFERivxx7WAixOB3').update({
      'username': 'teacher1',
    });
    print('✓ Updated teacher account with username: teacher1');
  } catch (e) {
    print('✗ Failed to update teacher: $e');
  }
  
  // 2. Create a test teacher account (if needed)
  print('\nCreating test teacher account...');
  try {
    final teacherEmail = usernameService.generateSyntheticEmail('testteacher');
    final teacherCred = await auth.createUserWithEmailAndPassword(
      email: teacherEmail,
      password: 'teacher123',
    );
    
    if (teacherCred.user != null) {
      await teacherCred.user!.updateDisplayName('Test Teacher');
      
      await firestore.collection('users').doc(teacherCred.user!.uid).set({
        'uid': teacherCred.user!.uid,
        'username': 'testteacher',
        'email': teacherEmail,
        'displayName': 'Test Teacher',
        'firstName': 'Test',
        'lastName': 'Teacher',
        'role': 'teacher',
        'photoURL': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
      
      print('✓ Created test teacher account:');
      print('  Username: testteacher');
      print('  Password: teacher123');
    }
  } catch (e) {
    if (e.toString().contains('email-already-in-use')) {
      print('✓ Test teacher account already exists');
    } else {
      print('✗ Failed to create test teacher: $e');
    }
  }
  
  // 3. Create a test student account
  print('\nCreating test student account...');
  try {
    final studentEmail = usernameService.generateSyntheticEmail('student1');
    final studentCred = await auth.createUserWithEmailAndPassword(
      email: studentEmail,
      password: 'student123',
    );
    
    if (studentCred.user != null) {
      await studentCred.user!.updateDisplayName('Test Student');
      
      await firestore.collection('users').doc(studentCred.user!.uid).set({
        'uid': studentCred.user!.uid,
        'username': 'student1',
        'email': studentEmail,
        'displayName': 'Test Student',
        'firstName': 'Test',
        'lastName': 'Student',
        'role': 'student',
        'teacherId': 'zxD9cZale9OHvFERivxx7WAixOB3', // Frank's teacher ID
        'photoURL': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
      
      print('✓ Created test student account:');
      print('  Username: student1');
      print('  Password: student123');
    }
  } catch (e) {
    if (e.toString().contains('email-already-in-use')) {
      print('✓ Test student account already exists');
    } else {
      print('✗ Failed to create test student: $e');
    }
  }
  
  // 4. Update existing student accounts with usernames
  print('\nUpdating existing student accounts...');
  try {
    final studentsSnapshot = await firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();
    
    int updatedCount = 0;
    for (final doc in studentsSnapshot.docs) {
      final data = doc.data();
      if (data['username'] == null) {
        // Generate username from name
        final firstName = data['firstName'] ?? '';
        final lastName = data['lastName'] ?? '';
        
        if (firstName.isNotEmpty && lastName.isNotEmpty) {
          final baseUsername = usernameService.generateUsername(firstName, lastName);
          final username = await usernameService.getNextAvailableUsername(baseUsername);
          
          await doc.reference.update({'username': username});
          print('  ✓ Updated ${data['displayName']} with username: $username');
          updatedCount++;
        }
      }
    }
    
    if (updatedCount == 0) {
      print('  ✓ All student accounts already have usernames');
    } else {
      print('  ✓ Updated $updatedCount student accounts');
    }
  } catch (e) {
    print('✗ Failed to update existing students: $e');
  }
  
  print('\n===== Account Setup Complete =====');
  print('\nYou can now log in with:');
  print('\nTeacher Account:');
  print('  Username: teacher1');
  print('  Password: [your existing password]');
  print('\nTest Student Account:');
  print('  Username: student1');
  print('  Password: student123');
  print('\n==================================');
}