import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

/// A generic repository wrapper around Firestore collections.
///
/// This class extends the existing FirestoreService to provide
/// a more focused API for specific domain models. It centralizes
/// common CRUD and query operations while maintaining compatibility
/// with the existing service architecture.
class FirestoreRepository<T> extends FirestoreService<T> {
  /// The underlying Firestore instance (private for encapsulation)
  final FirebaseFirestore _firestore;
  
  FirestoreRepository({
    required super.collectionPath,
    required super.fromFirestore,
    required super.toFirestore,
    super.firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // Note: This repository inherits the following methods from FirestoreService:
  // - create(Map<String, dynamic> data) → Future<String>
  // - get(String id) → Future<T?>
  // - update(String id, Map<String, dynamic> data) → Future<void>
  // - delete(String id) → Future<void>
  // - getAll() → Future<List<T>>
  // - streamCollection() → Stream<List<T>>
  // - streamDocument(String id) → Stream<T?>

  /// Fetch all documents matching the supplied `queryBuilder`.
  Future<List<T>> getList(
    Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)
        queryBuilder,
  ) async {
    final typedCollection = collection as CollectionReference<Map<String, dynamic>>;
    final query = queryBuilder(typedCollection);
    final snapshot = await query.get();
    return snapshot.docs.map(fromFirestore).toList();
  }

  /// Return a stream of documents matching the supplied `queryBuilder`.
  Stream<List<T>> streamList([
    Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)?
        queryBuilder,
  ]) {
    final typedCollection = collection as CollectionReference<Map<String, dynamic>>;
    final query = queryBuilder != null ? queryBuilder(typedCollection) : typedCollection;
    return query
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
  }

  /// Create a batch write operation for atomic updates.
  /// Returns a WriteBatch that can be used to perform multiple operations atomically.
  WriteBatch createBatch() {
    return _firestore.batch();
  }

  /// Execute a batch update operation on multiple documents.
  /// 
  /// [updates] is a map where keys are document IDs and values are the update data.
  /// All updates are performed atomically - either all succeed or all fail.
  Future<void> batchUpdate(Map<String, Map<String, dynamic>> updates) async {
    if (updates.isEmpty) return;
    
    final batch = _firestore.batch();
    updates.forEach((docId, data) {
      batch.update(collection.doc(docId), data);
    });
    
    await batch.commit();
  }

  /// Execute a batch delete operation on multiple documents.
  /// 
  /// [docIds] is a list of document IDs to delete.
  /// All deletes are performed atomically.
  Future<void> batchDelete(List<String> docIds) async {
    if (docIds.isEmpty) return;
    
    final batch = _firestore.batch();
    for (final docId in docIds) {
      batch.delete(collection.doc(docId));
    }
    
    await batch.commit();
  }

  /// Execute a custom batch operation.
  /// 
  /// [operation] is a function that receives a WriteBatch and the collection reference
  /// to perform custom batch operations.
  Future<void> executeBatch(
    void Function(WriteBatch batch, CollectionReference<Map<String, dynamic>> collection) operation,
  ) async {
    final batch = _firestore.batch();
    final typedCollection = collection as CollectionReference<Map<String, dynamic>>;
    operation(batch, typedCollection);
    await batch.commit();
  }

  /// Check if any documents exist matching the specified field and values.
  /// 
  /// Useful for checking uniqueness constraints across multiple values.
  Future<Set<dynamic>> checkExistingValues({
    required String field,
    required List<dynamic> values,
    Map<String, dynamic>? additionalFilters,
  }) async {
    if (values.isEmpty) return {};
    
    final typedCollection = collection as CollectionReference<Map<String, dynamic>>;
    var query = typedCollection.where(field, whereIn: values);
    
    // Apply additional filters if provided
    if (additionalFilters != null) {
      for (final entry in additionalFilters.entries) {
        query = query.where(entry.key, isEqualTo: entry.value);
      }
    }
    
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => doc.data()[field])
        .toSet();
  }

  /// Get a reference to another collection.
  /// This is needed for cross-collection queries while maintaining encapsulation.
  CollectionReference<Map<String, dynamic>> getCollectionReference(String path) {
    return _firestore.collection(path);
  }

  /// Run a transaction with custom logic.
  /// The transaction function receives the transaction object and collection reference.
  Future<R> runTransaction<R>(
    Future<R> Function(Transaction transaction, CollectionReference<Map<String, dynamic>> collection) transactionHandler,
  ) async {
    final typedCollection = collection as CollectionReference<Map<String, dynamic>>;
    return _firestore.runTransaction((transaction) async {
      return transactionHandler(transaction, typedCollection);
    });
  }
}