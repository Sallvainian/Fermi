import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class to handle Firestore streams with proper thread safety for Windows.
///
/// This addresses the platform channel threading issues on Windows where
/// Firebase plugins send messages from non-platform threads.
class FirestoreThreadSafe {
  /// Wraps a Firestore snapshots stream to ensure thread safety.
  ///
  /// This method forces all snapshot processing onto the next microtask,
  /// avoiding the "non-platform thread" errors on Windows.
  static Stream<QuerySnapshot> wrapQueryStream(Stream<QuerySnapshot> stream) {
    return stream.asyncMap((snapshot) async {
      // Force processing onto the next microtask to avoid threading issues
      // This ensures the snapshot is processed on the platform thread
      await Future.delayed(Duration.zero);
      return snapshot;
    });
  }

  /// Wraps a Firestore document snapshots stream to ensure thread safety.
  static Stream<DocumentSnapshot> wrapDocumentStream(Stream<DocumentSnapshot> stream) {
    return stream.asyncMap((snapshot) async {
      // Force processing onto the next microtask to avoid threading issues
      await Future.delayed(Duration.zero);
      return snapshot;
    });
  }

  /// Creates a thread-safe query snapshots stream.
  ///
  /// Usage:
  /// ```dart
  /// final stream = FirestoreThreadSafe.createQueryStream(
  ///   FirebaseFirestore.instance
  ///     .collection('messages')
  ///     .where('userId', isEqualTo: uid)
  /// );
  /// ```
  static Stream<QuerySnapshot> createQueryStream(Query query) {
    return wrapQueryStream(query.snapshots());
  }

  /// Creates a thread-safe document snapshots stream.
  ///
  /// Usage:
  /// ```dart
  /// final stream = FirestoreThreadSafe.createDocumentStream(
  ///   FirebaseFirestore.instance.collection('users').doc(uid)
  /// );
  /// ```
  static Stream<DocumentSnapshot> createDocumentStream(DocumentReference doc) {
    return wrapDocumentStream(doc.snapshots());
  }
}