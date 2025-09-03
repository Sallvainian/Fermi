import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fermi_plus/firebase_options.dart';

/// Development script to create/update test accounts.
/// Moved out of `lib/` to avoid shipping dev code in app builds.
Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Keep auth available for future scripted flows if needed.
  final auth = FirebaseAuth.instance; // ignore: unused_local_variable
  final db = FirebaseFirestore.instance;

  // Example: ensure a teacher and a student entry exist with usernames.
  // Keep verbose prints since this is a dev-only tool.
  print('Creating or updating dev accounts...');

  Future<void> ensureUser(
    String uid,
    String email,
    String displayName,
    String role,
    String username,
  ) async {
    await db.collection('users').doc(uid).set({
      'email': email,
      'displayName': displayName,
      'role': role,
      'username': username,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    print('✓ Ensured $role user: $displayName ($username)');
  }

  await ensureUser(
    'test_teacher_uid',
    'teacher@example.com',
    'Test Teacher',
    'teacher',
    'teacher1',
  );

  await ensureUser(
    'test_student_uid',
    'student@example.com',
    'Test Student',
    'student',
    'student1',
  );

  print('Done.');
}
