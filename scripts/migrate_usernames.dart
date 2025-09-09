import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

/// Script to migrate existing usernames to public_usernames collection
/// Run with: dart run scripts/migrate_usernames.dart
void main() async {
  print('Starting username migration...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    final firestore = FirebaseFirestore.instance;
    
    // Get all users
    final usersSnapshot = await firestore.collection('users').get();
    
    print('Found ${usersSnapshot.docs.length} users to process');
    
    int migrated = 0;
    int skipped = 0;
    int errors = 0;
    
    for (final userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final username = userData['username'];
      
      if (username == null || username.isEmpty) {
        print('Skipping user ${userDoc.id} - no username');
        skipped++;
        continue;
      }
      
      final lowerUsername = username.toString().toLowerCase();
      
      try {
        // Check if already exists
        final existingDoc = await firestore
            .collection('public_usernames')
            .doc(lowerUsername)
            .get();
            
        if (existingDoc.exists) {
          print('Username $lowerUsername already migrated');
          skipped++;
          continue;
        }
        
        // Create public username entry
        await firestore.collection('public_usernames').doc(lowerUsername).set({
          'uid': userDoc.id,
          'role': userData['role'] ?? 'student',
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        print('✓ Migrated username: $lowerUsername');
        migrated++;
        
      } catch (e) {
        print('✗ Error migrating $lowerUsername: $e');
        errors++;
      }
    }
    
    print('\n=== Migration Complete ===');
    print('Migrated: $migrated');
    print('Skipped: $skipped');
    print('Errors: $errors');
    
  } catch (e) {
    print('Fatal error: $e');
    exit(1);
  }
  
  exit(0);
}