import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service_enhanced.dart';
import '../services/logger_service.dart';
import 'mixins/pagination_mixin.dart';
import 'base_repository.dart';

/// Enhanced base repository with pagination support.
/// 
/// This abstract class extends the base repository pattern to include
/// pagination capabilities while maintaining backward compatibility.
/// All repositories that need pagination should extend this class.
abstract class FirestoreRepositoryEnhanced<T> extends BaseRepository {
  /// Enhanced Firestore service with pagination
  late final FirestoreServiceEnhanced<T> _service;
  
  /// Logging tag for this repository
  final String tag;
  
  /// Function to serialize model instances into Firestore data
  late final Map<String, dynamic> Function(T) _toFirestore;
  
  /// Creates an enhanced repository with pagination support
  FirestoreRepositoryEnhanced({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) fromFirestore,
    required Map<String, dynamic> Function(T) toFirestore,
    required this.tag,
  }) {
    _toFirestore = toFirestore;
    _service = FirestoreServiceEnhanced<T>(
      collectionPath: collectionPath,
      fromFirestore: (DocumentSnapshot doc) => fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>),
      toFirestore: toFirestore,
    );
  }
  
  /// Get paginated items from the collection.
  /// 
  /// @param pageSize Number of items per page
  /// @param startAfter Optional cursor for pagination
  /// @param orderBy Field to order by
  /// @param descending Whether to order descending
  /// @return PaginatedResult with items and metadata
  Future<PaginatedResult<T>> getPaginated({
    int pageSize = PaginationMixin.defaultPageSize,
    DocumentSnapshot? startAfter,
    String orderBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      LoggerService.info(
        'Getting paginated items (pageSize: $pageSize, orderBy: $orderBy)',
        tag: tag,
      );
      
      return await _service.getPaginated(
        pageSize: pageSize,
        startAfter: startAfter,
        orderBy: orderBy,
        descending: descending,
      );
    } catch (e) {
      LoggerService.error(
        'Failed to get paginated items',
        tag: tag,
        error: e,
      );
      rethrow;
    }
  }
  
  /// Get paginated stream of items.
  /// 
  /// Returns a stream that emits paginated results whenever
  /// the underlying data changes.
  Stream<PaginatedResult<T>> streamPaginated({
    int pageSize = PaginationMixin.defaultPageSize,
    DocumentSnapshot? startAfter,
    String orderBy = 'createdAt',
    bool descending = true,
  }) {
    LoggerService.info(
      'Starting paginated stream (pageSize: $pageSize, orderBy: $orderBy)',
      tag: tag,
    );
    
    return _service.streamPaginated(
      pageSize: pageSize,
      startAfter: startAfter,
      orderBy: orderBy,
      descending: descending,
    );
  }
  
  /// Query with pagination and filters.
  /// 
  /// Supports complex queries with multiple constraints.
  Future<PaginatedResult<T>> queryPaginated({
    required List<QueryConstraint> constraints,
    int pageSize = PaginationMixin.defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      LoggerService.info(
        'Executing paginated query (pageSize: $pageSize, constraints: ${constraints.length})',
        tag: tag,
      );
      
      return await _service.queryPaginated(
        constraints: constraints,
        pageSize: pageSize,
        startAfter: startAfter,
      );
    } catch (e) {
      LoggerService.error(
        'Failed to execute paginated query',
        tag: tag,
        error: e,
      );
      rethrow;
    }
  }
  
  // Standard CRUD operations (maintained for compatibility)
  
  /// Create a new document
  Future<String> create(T item) async {
    try {
      LoggerService.info('Creating new document', tag: tag);
      return await _service.create(_toFirestore(item));
    } catch (e) {
      LoggerService.error('Failed to create document', tag: tag, error: e);
      rethrow;
    }
  }
  
  /// Read a document by ID
  Future<T?> read(String id) async {
    try {
      LoggerService.info('Reading document (id: $id)', tag: tag);
      return await _service.get(id);
    } catch (e) {
      LoggerService.error('Failed to read document', tag: tag, error: e);
      rethrow;
    }
  }
  
  /// Update a document
  Future<void> update(String id, T item) async {
    try {
      LoggerService.info('Updating document (id: $id)', tag: tag);
      await _service.update(id, _toFirestore(item));
    } catch (e) {
      LoggerService.error('Failed to update document', tag: tag, error: e);
      rethrow;
    }
  }
  
  /// Delete a document
  Future<void> delete(String id) async {
    try {
      LoggerService.info('Deleting document (id: $id)', tag: tag);
      await _service.delete(id);
    } catch (e) {
      LoggerService.error('Failed to delete document', tag: tag, error: e);
      rethrow;
    }
  }
  
  /// Get all documents (DEPRECATED - use getPaginated instead)
  @Deprecated('Use getPaginated() for better performance')
  Future<List<T>> getAll() async {
    LoggerService.warning(
      'getAll() is deprecated. Consider using getPaginated() for better performance.',
      tag: tag,
    );
    
    // Load all using pagination internally
    final result = await _service.getAll();
    return result;
  }
  
  /// Stream all documents
  Stream<List<T>> streamAll() {
    LoggerService.info('Starting stream for all documents', tag: tag);
    return _service.query();
  }
  
  /// Query documents
  Future<List<T>> query({
    required String field,
    required dynamic isEqualTo,
  }) async {
    try {
      LoggerService.info(
        'Querying documents (field: $field, value: $isEqualTo)',
        tag: tag,
      );
      
      // Use pagination for queries too
      final result = await _service.getPaginated(
        where: field,
        isEqualTo: isEqualTo,
        pageSize: PaginationMixin.maxPageSize,
      );
      
      return result.items;
    } catch (e) {
      LoggerService.error('Failed to query documents', tag: tag, error: e);
      rethrow;
    }
  }
  
  /// Batch write operations
  Future<void> batchWrite(List<BatchOperation<T>> operations) async {
    try {
      LoggerService.info(
        'Executing batch write (operations: ${operations.length})',
        tag: tag,
      );
      
      final batch = FirebaseFirestore.instance.batch();
      
      for (final op in operations) {
        final docRef = _service.collection.doc(op.id);
        
        switch (op.type) {
          case BatchOperationType.create:
            batch.set(docRef, _toFirestore(op.data as T));
            break;
          case BatchOperationType.update:
            batch.update(docRef, _toFirestore(op.data as T));
            break;
          case BatchOperationType.delete:
            batch.delete(docRef);
            break;
        }
      }
      
      await batch.commit();
      LoggerService.info('Batch write completed successfully', tag: tag);
    } catch (e) {
      LoggerService.error('Failed to execute batch write', tag: tag, error: e);
      rethrow;
    }
  }
  
  @override
  void dispose() {
    LoggerService.info('Disposing repository', tag: tag);
    super.dispose();
  }
}

/// Batch operation types
enum BatchOperationType { create, update, delete }

/// Batch operation container
class BatchOperation<T> {
  final String? id;
  final BatchOperationType type;
  final T? data;
  
  const BatchOperation({
    this.id,
    required this.type,
    this.data,
  });
}