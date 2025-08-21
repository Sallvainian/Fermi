import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:teacher_dashboard_flutter/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Account deletion test', (WidgetTester tester) async {
    // Start the app - this initializes Firebase
    app.main();
    await tester.pumpAndSettle();
    
    // Wait for Firebase to be ready
    await Future.delayed(const Duration(seconds: 2));
    
    // Now Firebase should be initialized by the app
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    
    // Create a test account
    final testEmail = 'test${DateTime.now().millisecondsSinceEpoch}@test.com';
    final testPassword = 'TestPassword123!';
    
    print('Creating test user: $testEmail');
    
    try {
      // Create user
      final credential = await auth.createUserWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
      
      expect(credential.user, isNotNull);
      print('User created with UID: ${credential.user!.uid}');
      
      // Delete the account
      await credential.user!.delete();
      print('User deleted successfully');
      
      // Verify deletion
      expect(auth.currentUser, isNull);
      print('Account deletion verified');
      
    } catch (e) {
      print('Error during test: $e');
      rethrow;
    }
  });
}