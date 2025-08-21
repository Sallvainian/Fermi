/// Generic Firestore repository implementation with comprehensive logging.
///
/// This module provides an abstract repository that wraps FirestoreService
/// with additional features like automatic logging, error handling, and
/// a consistent interface for data access operations.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/logger_service.dart';
import 'base_repository.dart';

/// Generic Firestore repository that provides common CRUD operations.
///
/// This abstract class serves as a foundation for concrete repositories,
/// offering:
/// - Type-safe CRUD operations with generic typing
/// - Automatic logging of all data operations
/// - Comprehensive error handling with stack traces
/// - Query support with filtering and ordering
/// - Real-time streaming capabilities
/// - Integration with FirestoreService for data persistence
///
/// Concrete repositories should extend this class and provide
/// domain-specific methods while leveraging the base functionality.
///
/// @param T The type of model this repository manages
abstract class FirestoreRepository<T> extends BaseRepository {
  /// Underlying service for Firestore operations.
  final FirestoreService<T> _firestoreService;

  /// Logging tag for identifying repository operations.
  final String tag;

  /// Creates a generic Firestore repository instance.
  ///
  /// Initializes the repository with required configuration for
  /// data serialization and collection management.
  ///
  /// @param firestore Firestore instance for database access
  /// @param collectionPath Path to the Firestore collection
  /// @param fromFirestore Function to deserialize documents to models
  /// @param toFirestore Function to serialize models to documents
  /// @param logTag Optional custom tag for logging (defaults to class name)
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

  /// Creates a new document in Firestore.
  ///
  /// Serializes the provided model and creates a new document
  /// with an auto-generated ID. Logs the operation and provides
  /// comprehensive error handling.
  ///
  /// @param item Model instance to create
  /// @return Generated document ID
  /// @throws Exception if creation fails
  Future<String> create(T item) async {
    try {
      LoggerService.debug('Creating document', tag: tag);
      return await _firestoreService
          .create(_firestoreService.toFirestore(item));
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

  /// Reads a document by ID from Firestore.
  ///
  /// Retrieves and deserializes a single document. Returns null
  /// if the document doesn't exist. Includes logging and error
  /// handling for debugging.
  ///
  /// @param id Document ID to retrieve
  /// @return Deserialized model or null if not found
  /// @throws Exception if read operation fails
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

  /// Updates an existing document in Firestore.
  ///
  /// Serializes the model and overwrites the document with
  /// the specified ID. The document must exist or the operation
  /// will fail. Includes comprehensive logging.
  ///
  /// @param id Document ID to update
  /// @param item Updated model instance
  /// @throws Exception if update fails or document doesn't exist
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

  /// Deletes a document from Firestore.
  ///
  /// Permanently removes the document with the specified ID.
  /// This operation cannot be undone. Logs the deletion for
  /// audit purposes.
  ///
  /// @param id Document ID to delete
  /// @throws Exception if deletion fails
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

  /// Lists documents with optional filtering and ordering.
  ///
  /// Performs a one-time query to retrieve documents matching
  /// the specified conditions. Results can be filtered, ordered,
  /// and limited. Uses the stream API internally but returns
  /// only the first emission.
  ///
  /// @param conditions Optional query filters
  /// @param orderBy Optional sorting specifications
  /// @param limit Optional result count limit
  /// @return List of matching documents
  /// @throws Exception if query fails
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

  /// Streams documents with real-time updates.
  ///
  /// Creates a stream that emits document lists whenever
  /// matching documents change in Firestore. Supports the
  /// same filtering and ordering options as list().
  ///
  /// The stream continues emitting updates until cancelled.
  /// Remember to cancel subscriptions to prevent memory leaks.
  ///
  /// @param conditions Optional query filters
  /// @param orderBy Optional sorting specifications
  /// @param limit Optional result count limit
  /// @return Stream of document lists with real-time updates
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

  /// Gets the underlying FirestoreService for advanced operations.
  ///
  /// Provides access to the wrapped service for operations not
  /// covered by the repository interface, such as batch operations
  /// or complex queries.
  ///
  /// @return The internal FirestoreService instance
  FirestoreService<T> get service => _firestoreService;
}
