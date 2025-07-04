import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Generic Firestore service to handle common CRUD operations
/// This reduces code duplication across different services
class FirestoreService<T> {
  final FirebaseFirestore _firestore;
  final String collectionPath;
  final T Function(DocumentSnapshot doc) fromFirestore;
  final Map<String, dynamic> Function(T item) toFirestore;

  FirestoreService({
    FirebaseFirestore? firestore,
    required this.collectionPath,
    required this.fromFirestore,
    required this.toFirestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get collection => _firestore.collection(collectionPath);

  /// Create a new document
  Future<String> create(Map<String, dynamic> data) async {
    try {
      final docRef = await collection.add(data);
      return docRef.id;
    } catch (e) {
      if (kDebugMode) print('Error creating document: $e');
      rethrow;
    }
  }  /// Create a document with specific ID
  Future<void> createWithId(String id, Map<String, dynamic> data) async {
    try {
      await collection.doc(id).set(data);
    } catch (e) {
      if (kDebugMode) print('Error creating document with ID: $e');
      rethrow;
    }
  }

  /// Read a single document
  Future<T?> get(String id) async {
    try {
      final doc = await collection.doc(id).get();
      if (!doc.exists) return null;
      return fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) print('Error getting document: $e');
      rethrow;
    }
  }

  /// Read all documents
  Future<List<T>> getAll() async {
    try {
      final snapshot = await collection.get();
      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting all documents: $e');
      rethrow;
    }
  }  /// Update a document
  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      await collection.doc(id).update(data);
    } catch (e) {
      if (kDebugMode) print('Error updating document: $e');
      rethrow;
    }
  }

  /// Delete a document
  Future<void> delete(String id) async {
    try {
      await collection.doc(id).delete();
    } catch (e) {
      if (kDebugMode) print('Error deleting document: $e');
      rethrow;
    }
  }

  /// Query documents with conditions
  Stream<List<T>> query({
    List<QueryCondition>? conditions,
    List<OrderBy>? orderBy,
    int? limit,
  }) {
    try {
      Query query = collection;

      // Apply conditions
      if (conditions != null) {
        for (final condition in conditions) {
          query = query.where(
            condition.field,
            isEqualTo: condition.isEqualTo,
            isNotEqualTo: condition.isNotEqualTo,
            isLessThan: condition.isLessThan,
            isLessThanOrEqualTo: condition.isLessThanOrEqualTo,
            isGreaterThan: condition.isGreaterThan,
            isGreaterThanOrEqualTo: condition.isGreaterThanOrEqualTo,
            arrayContains: condition.arrayContains,
            arrayContainsAny: condition.arrayContainsAny,
            whereIn: condition.whereIn,
            whereNotIn: condition.whereNotIn,
            isNull: condition.isNull,
          );
        }
      }      // Apply ordering
      if (orderBy != null) {
        for (final order in orderBy) {
          query = query.orderBy(order.field, descending: order.descending);
        }
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      return query.snapshots().map((snapshot) =>
          snapshot.docs.map((doc) => fromFirestore(doc)).toList());
    } catch (e) {
      if (kDebugMode) print('Error querying documents: $e');
      rethrow;
    }
  }

  /// Delete multiple documents in a batch
  Future<void> deleteMany(List<String> ids) async {
    try {
      final batch = _firestore.batch();
      for (final id in ids) {
        batch.delete(collection.doc(id));
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) print('Error deleting multiple documents: $e');
      rethrow;
    }
  }

  /// Check if a document exists
  Future<bool> exists(String id) async {
    try {
      final doc = await collection.doc(id).get();
      return doc.exists;
    } catch (e) {
      if (kDebugMode) print('Error checking document existence: $e');
      rethrow;
    }
  }
}

/// Helper class for query conditions
class QueryCondition {
  final String field;
  final Object? isEqualTo;
  final Object? isNotEqualTo;
  final Object? isLessThan;
  final Object? isLessThanOrEqualTo;
  final Object? isGreaterThan;
  final Object? isGreaterThanOrEqualTo;
  final Object? arrayContains;
  final List<Object?>? arrayContainsAny;
  final List<Object?>? whereIn;
  final List<Object?>? whereNotIn;
  final bool? isNull;

  QueryCondition({
    required this.field,
    this.isEqualTo,
    this.isNotEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.arrayContains,
    this.arrayContainsAny,
    this.whereIn,
    this.whereNotIn,
    this.isNull,
  });
}

/// Helper class for ordering
class OrderBy {
  final String field;
  final bool descending;

  OrderBy({
    required this.field,
    this.descending = false,
  });
}