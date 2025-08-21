/// Generic Firestore service providing reusable CRUD operations.
///
/// This module implements a generic service pattern for Firestore
/// operations, reducing code duplication across different data services
/// in the education platform.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';

/// Generic Firestore service to handle common CRUD operations.
///
/// This service provides a type-safe, reusable implementation for:
/// - Create, Read, Update, Delete operations
/// - Complex queries with multiple conditions
/// - Batch operations for efficiency
/// - Stream-based real-time updates
///
/// The service uses generic typing to work with any data model
/// that can be serialized to/from Firestore documents.
///
/// @param T The type of model this service manages
class FirestoreService<T> {
  /// Firestore database instance.
  final FirebaseFirestore _firestore;

  /// Path to the Firestore collection this service manages.
  final String collectionPath;

  /// Function to deserialize Firestore documents into model instances.
  final T Function(DocumentSnapshot doc) fromFirestore;

  /// Function to serialize model instances into Firestore data.
  final Map<String, dynamic> Function(T item) toFirestore;

  /// Creates a generic Firestore service instance.
  ///
  /// @param firestore Optional Firestore instance for dependency injection
  /// @param collectionPath Path to the target collection
  /// @param fromFirestore Deserialization function for documents
  /// @param toFirestore Serialization function for models
  FirestoreService({
    FirebaseFirestore? firestore,
    required this.collectionPath,
    required this.fromFirestore,
    required this.toFirestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Gets the Firestore collection reference.
  ///
  /// @return Reference to the managed collection
  CollectionReference get collection => _firestore.collection(collectionPath);

  /// Creates a new document with auto-generated ID.
  ///
  /// Adds the document to Firestore and returns the generated
  /// document ID. The data should be pre-serialized before
  /// calling this method.
  ///
  /// @param data Serialized document data
  /// @return Generated document ID
  /// @throws Exception if creation fails
  Future<String> create(Map<String, dynamic> data) async {
    try {
      final docRef = await collection.add(data);
      return docRef.id;
    } catch (e) {
      LoggerService.error('Error creating document', error: e);
      rethrow;
    }
  }

  /// Creates a document with a specific ID.
  ///
  /// Use this when you need to control the document ID,
  /// such as for user profiles or deterministic IDs.
  ///
  /// @param id Document ID to use
  /// @param data Serialized document data
  /// @throws Exception if creation fails
  Future<void> createWithId(String id, Map<String, dynamic> data) async {
    try {
      await collection.doc(id).set(data);
    } catch (e) {
      LoggerService.error('Error creating document with ID', error: e);
      rethrow;
    }
  }

  /// Retrieves a single document by ID.
  ///
  /// Fetches the document and deserializes it using the
  /// provided fromFirestore function. Returns null if
  /// the document doesn't exist.
  ///
  /// @param id Document ID to retrieve
  /// @return Deserialized model instance or null
  /// @throws Exception if retrieval fails
  Future<T?> get(String id) async {
    try {
      final doc = await collection.doc(id).get();
      if (!doc.exists) return null;
      return fromFirestore(doc);
    } catch (e) {
      LoggerService.error('Error getting document', error: e);
      rethrow;
    }
  }

  /// Retrieves all documents in the collection.
  ///
  /// Fetches the entire collection and deserializes each
  /// document. Use with caution for large collections as
  /// this loads all data into memory.
  ///
  /// @return List of all deserialized model instances
  /// @throws Exception if retrieval fails
  Future<List<T>> getAll() async {
    try {
      final snapshot = await collection.get();
      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      LoggerService.error('Error getting all documents', error: e);
      rethrow;
    }
  }

  /// Updates an existing document.
  ///
  /// Performs a partial update - only fields included in
  /// the data parameter are modified. Other fields remain
  /// unchanged.
  ///
  /// @param id Document ID to update
  /// @param data Fields to update (pre-serialized)
  /// @throws Exception if update fails or document doesn't exist
  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      await collection.doc(id).update(data);
    } catch (e) {
      LoggerService.error('Error updating document', error: e);
      rethrow;
    }
  }

  /// Deletes a single document.
  ///
  /// Permanently removes the document from Firestore.
  /// This operation cannot be undone.
  ///
  /// @param id Document ID to delete
  /// @throws Exception if deletion fails
  Future<void> delete(String id) async {
    try {
      await collection.doc(id).delete();
    } catch (e) {
      LoggerService.error('Error deleting document', error: e);
      rethrow;
    }
  }

  /// Performs complex queries with real-time updates.
  ///
  /// Supports multiple query conditions, ordering, and limits.
  /// Returns a stream that updates when matching documents change.
  ///
  /// Example usage:
  /// ```dart
  /// query(
  ///   conditions: [QueryCondition(field: 'age', isGreaterThan: 18)],
  ///   orderBy: [OrderBy(field: 'name')],
  ///   limit: 10
  /// )
  /// ```
  ///
  /// @param conditions List of query conditions to apply
  /// @param orderBy List of ordering specifications
  /// @param limit Maximum number of results
  /// @return Stream of matching documents
  /// @throws Exception if query construction fails
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
      }

      // Apply ordering
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
      LoggerService.error('Error querying documents', error: e);
      rethrow;
    }
  }

  /// Deletes multiple documents in a single batch operation.
  ///
  /// Efficiently removes multiple documents using Firestore
  /// batch writes. All deletions succeed or fail together
  /// (atomic operation).
  ///
  /// @param ids List of document IDs to delete
  /// @throws Exception if batch deletion fails
  Future<void> deleteMany(List<String> ids) async {
    try {
      final batch = _firestore.batch();
      for (final id in ids) {
        batch.delete(collection.doc(id));
      }
      await batch.commit();
    } catch (e) {
      LoggerService.error('Error deleting multiple documents', error: e);
      rethrow;
    }
  }

  /// Checks if a document exists without retrieving its data.
  ///
  /// Useful for validation before performing operations
  /// that require the document to exist.
  ///
  /// @param id Document ID to check
  /// @return true if document exists, false otherwise
  /// @throws Exception if check fails
  Future<bool> exists(String id) async {
    try {
      final doc = await collection.doc(id).get();
      return doc.exists;
    } catch (e) {
      LoggerService.error('Error checking document existence', error: e);
      rethrow;
    }
  }
}

/// Represents a single query condition for Firestore queries.
///
/// Supports all Firestore query operators including:
/// - Equality and inequality comparisons
/// - Range queries (less than, greater than)
/// - Array queries (contains, contains any)
/// - Set membership queries (in, not in)
/// - Null checks
///
/// Only one condition type should be set per instance.
class QueryCondition {
  /// Field name to apply the condition to.
  final String field;

  /// Value for equality comparison.
  final Object? isEqualTo;

  /// Value for inequality comparison.
  final Object? isNotEqualTo;

  /// Value for less-than comparison.
  final Object? isLessThan;

  /// Value for less-than-or-equal comparison.
  final Object? isLessThanOrEqualTo;

  /// Value for greater-than comparison.
  final Object? isGreaterThan;

  /// Value for greater-than-or-equal comparison.
  final Object? isGreaterThanOrEqualTo;

  /// Value to check if array field contains.
  final Object? arrayContains;

  /// Values to check if array field contains any.
  final List<Object?>? arrayContainsAny;

  /// Values to check if field is in the set.
  final List<Object?>? whereIn;

  /// Values to check if field is not in the set.
  final List<Object?>? whereNotIn;

  /// Whether to check if field is null.
  final bool? isNull;

  /// Creates a query condition.
  ///
  /// Only set one condition type per instance. Multiple conditions
  /// on the same field require separate QueryCondition instances.
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

/// Specifies ordering for query results.
///
/// Used to sort query results by one or more fields
/// in ascending or descending order.
class OrderBy {
  /// Field name to order by.
  final String field;

  /// Whether to sort in descending order (default: false for ascending).
  final bool descending;

  /// Creates an ordering specification.
  ///
  /// @param field Field name to sort by
  /// @param descending Whether to sort in descending order (default: false)
  OrderBy({
    required this.field,
    this.descending = false,
  });
}
