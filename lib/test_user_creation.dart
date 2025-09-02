import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

/// Quick script to add test users to Firestore for testing user search
Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  
  // Test users data
  final testUsers = [
    {
      'uid': 'test_user_1',
      'email': 'alice@example.com',
      'displayName': 'Alice Johnson',
      'role': 'teacher',
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'uid': 'test_user_2',
      'email': 'bob@example.com',
      'displayName': 'Bob Smith',
      'role': 'student',
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'uid': 'test_user_3',
      'email': 'charlie@example.com',
      'displayName': 'Charlie Davis',
      'role': 'teacher',
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'uid': 'test_user_4',
      'email': 'diana@example.com',
      'displayName': 'Diana Wilson',
      'role': 'student',
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'uid': 'test_user_5',
      'email': 'edward@example.com',
      'displayName': 'Edward Brown',
      'role': 'teacher',
      'createdAt': FieldValue.serverTimestamp(),
    },
  ];

  debugPrint('Adding test users to Firestore...');
  
  for (final user in testUsers) {
    try {
      await firestore.collection('users').doc(user['uid'] as String).set(user);
      debugPrint('Added user: ${user['displayName']}');
    } catch (e) {
      debugPrint('Error adding user ${user['displayName']}: $e');
    }
  }
  
  debugPrint('\nTest users added successfully!');
  debugPrint('You can now test the user search functionality.');
}