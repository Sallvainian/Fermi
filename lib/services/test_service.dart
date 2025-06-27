import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Test writing data to Firestore
  Future<void> testWriteData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }

      // Test writing user data
      await _firestore.collection('users').doc(user.uid).set({
        'name': user.displayName ?? 'Test User',
        'email': user.email,
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Successfully wrote user data to Firestore');

      // Test writing a test class
      final classRef = await _firestore.collection('classes').add({
        'name': 'Test Class 101',
        'subject': 'Mathematics',
        'teacherId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Successfully created test class: ${classRef.id}');

      // Test writing a student to the class
      await _firestore
          .collection('classes')
          .doc(classRef.id)
          .collection('students')
          .add({
        'name': 'John Doe',
        'email': 'john.doe@example.com',
        'grade': 'A',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Successfully added test student');

    } catch (e) {
      print('❌ Error testing Firestore write: $e');
    }
  }

  // Test reading data from Firestore
  Future<void> testReadData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }

      // Test reading user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        print('✅ User data: ${userDoc.data()}');
      } else {
        print('❌ No user data found');
      }

      // Test reading classes
      final classesSnapshot = await _firestore
          .collection('classes')
          .where('teacherId', isEqualTo: user.uid)
          .get();

      print('✅ Found ${classesSnapshot.docs.length} classes');
      
      for (var classDoc in classesSnapshot.docs) {
        print('  Class: ${classDoc.data()['name']}');
        
        // Test reading students in this class
        final studentsSnapshot = await _firestore
            .collection('classes')
            .doc(classDoc.id)
            .collection('students')
            .get();
            
        print('    Students: ${studentsSnapshot.docs.length}');
      }

    } catch (e) {
      print('❌ Error testing Firestore read: $e');
    }
  }

  // Test real-time listening
  void testRealTimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      print('No user logged in');
      return;
    }

    _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      print('🔄 Real-time update: ${snapshot.docs.length} classes');
      for (var doc in snapshot.docs) {
        print('  ${doc.data()['name']}');
      }
    });

    print('✅ Started real-time listener');
  }

  // Clean up test data
  Future<void> cleanupTestData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }

      // Delete test classes and their subcollections
      final classesSnapshot = await _firestore
          .collection('classes')
          .where('teacherId', isEqualTo: user.uid)
          .get();

      for (var classDoc in classesSnapshot.docs) {
        // Delete students subcollection
        final studentsSnapshot = await _firestore
            .collection('classes')
            .doc(classDoc.id)
            .collection('students')
            .get();
            
        for (var studentDoc in studentsSnapshot.docs) {
          await studentDoc.reference.delete();
        }
        
        // Delete the class
        await classDoc.reference.delete();
      }

      print('✅ Cleaned up test data');

    } catch (e) {
      print('❌ Error cleaning up test data: $e');
    }
  }
}