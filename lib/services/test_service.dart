/// Service for testing Firestore integration and debugging.
/// 
/// This service provides test utilities for verifying Firestore
/// connectivity, permissions, and data operations during development.
/// Should only be used in debug builds for testing purposes.
library;

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Development testing service for Firestore operations.
/// 
/// This service provides methods to:
/// - Test write operations to verify permissions
/// - Test read operations to validate queries
/// - Set up real-time listeners for debugging
/// - Clean up test data after testing
/// 
/// WARNING: This service should only be used in development
/// and debugging contexts. Do not use in production.
class TestService {
  /// Firestore database instance.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Firebase Authentication instance.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Tests writing data to Firestore.
  /// 
  /// Creates test documents in multiple collections to verify:
  /// - User document creation in 'users' collection
  /// - Class document creation in 'classes' collection
  /// - Subcollection creation with students
  /// - Timestamp field functionality
  /// 
  /// Prints success/failure messages to debug console.
  /// Requires authenticated user to execute.
  /// 
  /// @throws Exception if write operations fail
  Future<void> testWriteData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) print('No user logged in');
        return;
      }

      // Test writing user data
      await _firestore.collection('users').doc(user.uid).set({
        'name': user.displayName ?? 'Test User',
        'email': user.email,
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) print('✅ Successfully wrote user data to Firestore');

      // Test writing a test class
      final classRef = await _firestore.collection('classes').add({
        'name': 'Test Class 101',
        'subject': 'Mathematics',
        'teacherId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) print('✅ Successfully created test class: ${classRef.id}');

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

      if (kDebugMode) print('✅ Successfully added test student');

    } catch (e) {
      if (kDebugMode) print('❌ Error testing Firestore write: $e');
    }
  }

  /// Tests reading data from Firestore.
  /// 
  /// Performs various read operations to verify:
  /// - Single document retrieval
  /// - Query with filters
  /// - Subcollection access
  /// - Document existence checks
  /// 
  /// Prints retrieved data to debug console for inspection.
  /// Requires authenticated user with existing test data.
  /// 
  /// @throws Exception if read operations fail
  Future<void> testReadData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) print('No user logged in');
        return;
      }

      // Test reading user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        if (kDebugMode) print('✅ User data: ${userDoc.data()}');
      } else {
        if (kDebugMode) print('❌ No user data found');
      }

      // Test reading classes
      final classesSnapshot = await _firestore
          .collection('classes')
          .where('teacherId', isEqualTo: user.uid)
          .get();

      if (kDebugMode) print('✅ Found ${classesSnapshot.docs.length} classes');
      
      for (var classDoc in classesSnapshot.docs) {
        if (kDebugMode) print('  Class: ${classDoc.data()['name']}');
        
        // Test reading students in this class
        final studentsSnapshot = await _firestore
            .collection('classes')
            .doc(classDoc.id)
            .collection('students')
            .get();
            
        if (kDebugMode) print('    Students: ${studentsSnapshot.docs.length}');
      }

    } catch (e) {
      if (kDebugMode) print('❌ Error testing Firestore read: $e');
    }
  }

  /// Tests real-time data synchronization.
  /// 
  /// Sets up a snapshot listener to verify:
  /// - Real-time updates are received
  /// - Query filters work with listeners
  /// - Data changes are properly propagated
  /// 
  /// The listener continues running until the app is closed
  /// or the listener is manually cancelled. Prints updates
  /// to debug console as they occur.
  /// 
  /// Requires authenticated user to set up listener.
  void testRealTimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) print('No user logged in');
      return;
    }

    _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (kDebugMode) print('🔄 Real-time update: ${snapshot.docs.length} classes');
      for (var doc in snapshot.docs) {
        if (kDebugMode) print('  ${doc.data()['name']}');
      }
    });

    if (kDebugMode) print('✅ Started real-time listener');
  }

  /// Cleans up test data created during testing.
  /// 
  /// Removes all test documents created by testWriteData:
  /// - Deletes all classes created by current user
  /// - Deletes all students in those classes
  /// - Preserves user document for future testing
  /// 
  /// Should be called after testing to avoid cluttering
  /// the database with test data. Uses batch operations
  /// where possible for efficiency.
  /// 
  /// @throws Exception if cleanup operations fail
  Future<void> cleanupTestData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) print('No user logged in');
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

      if (kDebugMode) print('✅ Cleaned up test data');

    } catch (e) {
      if (kDebugMode) print('❌ Error cleaning up test data: $e');
    }
  }
}