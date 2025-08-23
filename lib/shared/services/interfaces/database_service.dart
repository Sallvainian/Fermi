import 'dart:async';

/// Abstract database service interface
/// Implementations can use Firestore, firebase_dart, or other databases
abstract class DatabaseService {
  /// Get a document by ID
  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  });

  /// Get all documents in a collection
  Future<List<Map<String, dynamic>>> getCollection({
    required String collection,
    QueryOptions? options,
  });

  /// Query documents with conditions
  Future<List<Map<String, dynamic>>> queryDocuments({
    required String collection,
    required List<QueryCondition> conditions,
    QueryOptions? options,
  });

  /// Stream a document
  Stream<Map<String, dynamic>?> streamDocument({
    required String collection,
    required String documentId,
  });

  /// Stream a collection
  Stream<List<Map<String, dynamic>>> streamCollection({
    required String collection,
    QueryOptions? options,
  });

  /// Stream query results
  Stream<List<Map<String, dynamic>>> streamQuery({
    required String collection,
    required List<QueryCondition> conditions,
    QueryOptions? options,
  });

  /// Create a document with auto-generated ID
  Future<String> createDocument({
    required String collection,
    required Map<String, dynamic> data,
  });

  /// Set a document with specific ID
  Future<void> setDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  });

  /// Update specific fields in a document
  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  });

  /// Delete a document
  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  });

  /// Batch write operations
  Future<void> batchWrite({
    required List<BatchOperation> operations,
  });

  /// Run a transaction
  Future<T> runTransaction<T>({
    required Future<T> Function(Transaction transaction) handler,
  });

  /// Get server timestamp
  dynamic get serverTimestamp;

  /// Delete field value
  dynamic get deleteField;

  /// Array union value
  dynamic arrayUnion(List<dynamic> elements);

  /// Array remove value
  dynamic arrayRemove(List<dynamic> elements);

  /// Increment value
  dynamic increment(num value);
}

/// Query condition for filtering documents
class QueryCondition {
  final String field;
  final QueryOperator operator;
  final dynamic value;

  QueryCondition({
    required this.field,
    required this.operator,
    required this.value,
  });
}

/// Query operators
enum QueryOperator {
  isEqualTo,
  isNotEqualTo,
  isLessThan,
  isLessThanOrEqualTo,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  arrayContains,
  arrayContainsAny,
  whereIn,
  whereNotIn,
  isNull,
  isNotNull,
}

/// Query options for sorting and limiting
class QueryOptions {
  final String? orderBy;
  final bool descending;
  final int? limit;
  final int? offset;
  final dynamic startAfter;
  final dynamic startAt;
  final dynamic endAt;
  final dynamic endBefore;

  QueryOptions({
    this.orderBy,
    this.descending = false,
    this.limit,
    this.offset,
    this.startAfter,
    this.startAt,
    this.endAt,
    this.endBefore,
  });
}

/// Batch operation for batch writes
class BatchOperation {
  final BatchOperationType type;
  final String collection;
  final String? documentId;
  final Map<String, dynamic>? data;

  BatchOperation({
    required this.type,
    required this.collection,
    this.documentId,
    this.data,
  });
}

/// Batch operation types
enum BatchOperationType {
  create,
  set,
  update,
  delete,
}

/// Transaction interface
abstract class Transaction {
  /// Get a document within the transaction
  Future<Map<String, dynamic>?> get({
    required String collection,
    required String documentId,
  });

  /// Set a document within the transaction
  void set({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  });

  /// Update a document within the transaction
  void update({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  });

  /// Delete a document within the transaction
  void delete({
    required String collection,
    required String documentId,
  });
}