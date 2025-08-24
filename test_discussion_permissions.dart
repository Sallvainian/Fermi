import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  
  // Get current user
  final user = auth.currentUser;
  if (user == null) {
    print('❌ No user logged in');
    return;
  }
  
  print('✅ Logged in as: ${user.email}');
  print('   UID: ${user.uid}');
  
  // Fetch user role from Firestore
  try {
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      final role = userData?['role'] ?? 'unknown';
      print('✅ User role from Firestore: $role');
      
      // Check if this matches the email-based assumption
      final emailBasedRole = user.email?.endsWith('@teacher.edu') == true 
          ? 'teacher' 
          : 'student';
      print('   Email-based role would be: $emailBasedRole');
      
      if (role != emailBasedRole) {
        print('⚠️  MISMATCH: Firestore role ($role) != Email-based role ($emailBasedRole)');
        print('   This was causing the permission issues!');
      } else {
        print('   Roles match - no issue here');
      }
      
      // Test permissions based on actual role
      print('\n📋 Expected permissions for $role:');
      if (role == 'teacher') {
        print('   ✅ Can delete any board');
        print('   ✅ Can delete any thread');
        print('   ✅ Can delete any reply/comment');
        print('   ✅ Can pin/lock threads');
      } else if (role == 'student') {
        print('   ❌ Cannot delete boards (teacher only)');
        print('   ✅ Can delete own threads');
        print('   ❌ Cannot delete other users\' threads');
        print('   ✅ Can delete own replies/comments');
        print('   ❌ Cannot delete other users\' replies/comments');
      }
      
      // Check if any test boards exist
      print('\n🔍 Checking discussion boards...');
      final boardsSnapshot = await firestore
          .collection('discussion_boards')
          .limit(1)
          .get();
      
      if (boardsSnapshot.docs.isNotEmpty) {
        final board = boardsSnapshot.docs.first;
        print('   Found board: ${board.data()['title']}');
        
        // Check threads in this board
        final threadsSnapshot = await firestore
            .collection('discussion_boards')
            .doc(board.id)
            .collection('threads')
            .limit(5)
            .get();
        
        print('   Found ${threadsSnapshot.docs.length} threads');
        
        for (var thread in threadsSnapshot.docs) {
          final threadData = thread.data();
          final isOwner = threadData['authorId'] == user.uid;
          print('     - Thread: ${threadData['title']}');
          print('       Author: ${threadData['authorName']} (${threadData['authorRole']})');
          print('       Can delete: ${role == 'teacher' || isOwner ? 'YES' : 'NO'}');
        }
      } else {
        print('   No boards found');
      }
      
    } else {
      print('❌ User document not found in Firestore');
    }
  } catch (e) {
    print('❌ Error fetching user data: $e');
  }
}