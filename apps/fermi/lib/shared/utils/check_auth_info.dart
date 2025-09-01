import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility to check authentication information and compare with Firestore data
class CheckAuthInfo {
  static Future<void> analyzeAuthSituation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      // Check Firestore for this user
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // Document doesn't exist - this might be a new account
      }

      // Check for classes with old UID
      final oldUid = 'zxD9cZale9OHvFERivxx7WAixOB3';

      // Try to find the old user document
      final oldUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(oldUid)
          .get();

      if (oldUserDoc.exists) {
        // Old user document exists
      }
    } catch (e) {
      // Error analyzing auth situation
    }
  }
}
