import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/logger_service.dart';
import 'base_repository.dart';

/// Generic Firestore repository that provides common CRUD operations
abstract class FirestoreRepository<T> extends BaseRepository {
  final FirestoreService<T> _firestoreService;
  final String tag;
  
  FirestoreRepository({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required T Function(DocumentSnapshot doc) fromFirestore,
    required Map<String, dynamic> Function(T item) toFirestore,
    String? logTag,
  })  : _firestoreService = FirestoreService<T>(
          firestore: firestore,
          collectionPath: collectionPath,
          fromFirestore: fromFirestore,
          toFirestore: toFirestore,
        ),
        tag = logTag ?? 'FirestoreRepository<$T>';
  
  /// Create a new document
  Future<String> create(T item) async {
    try {
      LoggerService.debug('Creating document', tag: tag);
      return await _firestoreService.create(_firestoreService.toFirestore(item));
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to create document',
        tag: tag,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }  
  /// Read a document by ID
  Future<T?> read(String id) async {
    try {
      LoggerService.debug('Reading document: $id', tag: tag);
      return await _firestoreService.get(id);
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to read document: $id',
        tag: tag,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
  
  /// Update an existing document
  Future<void> update(String id, T item) async {
    try {
      LoggerService.debug('Updating document: $id', tag: tag);
      await _firestoreService.update(id, _firestoreService.toFirestore(item));
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to update document: $id',
        tag: tag,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }  
  /// Delete a document
  Future<void> delete(String id) async {
    try {
      LoggerService.debug('Deleting document: $id', tag: tag);
      await _firestoreService.delete(id);
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to delete document: $id',
        tag: tag,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
  
  /// List documents with optional filters
  Future<List<T>> list({
    List<QueryCondition>? conditions,
    List<OrderBy>? orderBy,
    int? limit,
  }) async {
    try {
      LoggerService.debug('Listing documents', tag: tag);
      final stream = _firestoreService.query(
        conditions: conditions,
        orderBy: orderBy,
        limit: limit,
      );
      return await stream.first;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to list documents',
        tag: tag,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
  
  /// Stream documents with optional filters
  Stream<List<T>> stream({
    List<QueryCondition>? conditions,
    List<OrderBy>? orderBy,
    int? limit,
  }) {
    LoggerService.debug('Streaming documents', tag: tag);
    return _firestoreService.query(
      conditions: conditions,
      orderBy: orderBy,
      limit: limit,
    );
  }
  
  /// Get the underlying FirestoreService for advanced operations
  FirestoreService<T> get service => _firestoreService;
}