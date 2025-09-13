import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fermi_plus/firebase_options.dart';

/// Script to migrate existing usernames to public_usernames collection
/// Run with: dart run scripts/migrate_usernames.dart
void main() async {
  stdout.writeln('Starting username migration...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    final firestore = FirebaseFirestore.instance;
    
    // Get all users
    final usersSnapshot = await firestore.collection('users').get();
    
    stdout.writeln('Found ${usersSnapshot.docs.length} users to process');
    
    int migrated = 0;
    int skipped = 0;
    int errors = 0;
    
    for (final userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final username = userData['username'];
      
      if (username == null || username.isEmpty) {
        stdout.writeln('Skipping user ${userDoc.id} - no username');
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
          stdout.writeln('Username $lowerUsername already migrated');
          skipped++;
          continue;
        }
        
        // Create public username entry
        await firestore.collection('public_usernames').doc(lowerUsername).set({
          'uid': userDoc.id,
          'role': userData['role'] ?? 'student',
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        stdout.writeln('✓ Migrated username: $lowerUsername');
        migrated++;
        
      } catch (e) {
        stderr.writeln('✗ Error migrating $lowerUsername: $e');
        errors++;
      }
    }
    
    stdout.writeln('\n=== Migration Complete ===');
    stdout.writeln('Migrated: $migrated');
    stdout.writeln('Skipped: $skipped');
    stdout.writeln('Errors: $errors');
    
  } catch (e) {
    stderr.writeln('Fatal error: $e');
    exit(1);
  }
  
  exit(0);
}