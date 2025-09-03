import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Temporary utility to run the user role migration.
/// This calls the Cloud Function to migrate all existing users to use custom claims.
///
/// Usage:
/// 1. Deploy the functions first: `deploy-functions.cmd`
/// 2. Sign in as a teacher in your app
/// 3. Call this function from somewhere in your app (e.g., settings screen)
/// 4. Remove this utility after migration is complete
Future<void> runUserRoleMigration(BuildContext context) async {
  try {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to run migration'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Running migration...'),
            ],
          ),
        ),
      );
    }

    // Call the migration function
    final functions = FirebaseFunctions.instanceFor(region: 'us-east4');
    final callable = functions.httpsCallable('migrateAllUserRoles');

    final result = await callable.call();
    final data = result.data as Map<String, dynamic>;

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading dialog

      // Show result
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            data['success'] == true ? 'Migration Complete' : 'Migration Failed',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${data['message']}'),
              const SizedBox(height: 8),
              Text('Total users: ${data['totalUsers']}'),
              Text('Success: ${data['successCount']}'),
              Text('Errors: ${data['errorCount']}'),
              if (data['errors'] != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Errors:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...((data['errors'] as List).map((e) => Text('• $e'))),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading dialog if open

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Migration failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
