import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Utility to fix teacherId mismatch in Firestore classes
/// 
/// This updates all classes with the old teacherId to use the current user's uid
class FixTeacherId {
  static Future<void> updateClassesTeacherId() async {
    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return;
      }

      final String currentUid = currentUser.uid;
      final String oldTeacherId = 'zxD9cZale9OHvFERivxx7WAixOB3';
      
      if (currentUid == oldTeacherId) {
        return;
      }

      // Get all classes with the old teacherId
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: oldTeacherId)
          .get();


      // Update each class
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'teacherId': currentUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Commit the batch
      await batch.commit();
      
    } catch (e) {
      // Error updating teacherId
    }
  }
}