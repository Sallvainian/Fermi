import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Utility to set custom claims for user roles.
/// This is needed for Storage security rules to work properly.
class UserRoleClaims {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Sets the custom role claim for a user.
  /// This should be called after a user's role is set in Firestore.
  /// 
  /// For new users: Call this after they complete signup and role selection.
  /// For existing users: The Cloud Function trigger will handle it automatically.
  static Future<void> setRoleClaim({
    required String uid,
    required String role,
  }) async {
    try {
      // Call the cloud function
      final callable = _functions.httpsCallable('setRoleClaim');
      final result = await callable.call({
        'uid': uid,
        'role': role,
      });

      print('Role claim set successfully: ${result.data['message']}');

      // If setting claim for current user, refresh their token
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        // Force token refresh to get new custom claims
        await currentUser.getIdToken(true);
        print('User token refreshed with new claims');
      }
    } catch (e) {
      print('Error setting role claim: $e');
      rethrow;
    }
  }

  /// Checks if the current user has a specific role claim.
  /// Useful for client-side permission checks.
  static Future<bool> hasRole(String role) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Get fresh token to ensure we have latest claims
      final idTokenResult = await user.getIdTokenResult();
      final claims = idTokenResult.claims;

      return claims?['role'] == role;
    } catch (e) {
      print('Error checking role claim: $e');
      return false;
    }
  }

  /// Gets the current user's role from custom claims.
  static Future<String?> getCurrentUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final idTokenResult = await user.getIdTokenResult();
      return idTokenResult.claims?['role'] as String?;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }
}

// Example usage in your auth flow:
// 
// After user signup and role selection in Firestore:
// await UserRoleClaims.setRoleClaim(
//   uid: user.uid,
//   role: 'student', // or 'teacher'
// );
//
// To check permissions client-side:
// final isTeacher = await UserRoleClaims.hasRole('teacher');
// if (isTeacher) {
//   // Show teacher-only features
// }