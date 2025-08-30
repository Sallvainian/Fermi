import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

/// A generic repository wrapper around Firestore collections.
///
/// This class extends the existing FirestoreService to provide
/// a more focused API for specific domain models. It centralizes
/// common CRUD and query operations while maintaining compatibility
/// with the existing service architecture.
class FirestoreRepository<T> extends FirestoreService<T> {
  /// The underlying Firestore instance
  final FirebaseFirestore firestore;
  
  FirestoreRepository({
    required super.collectionPath,
    required super.fromFirestore,
    required super.toFirestore,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
        super(
          firestore: firestore,
        );

  /// Create a new document and return it with the generated ID
  Future<T> createEntity(T entity) async {
    final id = await create(toFirestore(entity));
    return await get(id) ?? entity;
  }

  /// Fetch a document by its document ID using inherited method
  Future<T?> getById(String id) async => await get(id);

  /// Update an existing document using inherited method
  Future<void> updateEntity(String id, T entity) async {
    await update(id, toFirestore(entity));
  }

  /// Delete a document by its document ID using inherited method
  Future<void> deleteEntity(String id) async {
    await delete(id);
  }

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
}