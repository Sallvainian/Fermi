import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/mixins/pagination_mixin.dart';
import 'firestore_service.dart';
import 'logger_service.dart';

/// Enhanced Firestore service with pagination support.
/// 
/// Extends the base FirestoreService to add pagination capabilities
/// while maintaining backward compatibility with existing code.
class FirestoreServiceEnhanced<T> extends FirestoreService<T> with PaginationMixin {
  /// Creates an enhanced Firestore service with pagination.
  FirestoreServiceEnhanced({
    required super.collectionPath,
    required super.fromFirestore,
    required super.toFirestore,
  });

  /// Get paginated documents from the collection.
  /// 
  /// Returns a page of documents with metadata for pagination.
  /// 
  /// @param pageSize Number of documents per page
  /// @param startAfter Optional cursor for pagination
  /// @param orderBy Field to order by (defaults to 'createdAt')
  /// @param descending Whether to order descending
  /// @param where Optional field for filtering
  /// @param isEqualTo Optional value for equality filtering
  /// @return PaginatedResult with documents and pagination info
  Future<PaginatedResult<T>> getPaginated({
    int pageSize = PaginationMixin.defaultPageSize,
    DocumentSnapshot? startAfter,
    String orderBy = 'createdAt',
    bool descending = true,
    String? where,
    dynamic isEqualTo,
  }) async {
    try {
      Query query = collection.orderBy(orderBy, descending: descending);
      
      // Apply filtering if provided
      if (where != null && isEqualTo != null) {
        query = query.where(where, isEqualTo: isEqualTo);
      }
      
      return await getPaginatedData(
        query: query,
        fromFirestore: fromFirestore,
        pageSize: pageSize,
        startAfter: startAfter,
      );
    } catch (e) {
      LoggerService.error(
        'Error getting paginated data from $collectionPath',
        error: e,
      );
      rethrow;
    }
  }

  /// Get paginated stream of documents.
  /// 
  /// Returns a stream that emits paginated results whenever
  /// the underlying data changes.
  Stream<PaginatedResult<T>> streamPaginated({
    int pageSize = PaginationMixin.defaultPageSize,
    DocumentSnapshot? startAfter,
    String orderBy = 'createdAt',
    bool descending = true,
    String? where,
    dynamic isEqualTo,
  }) {
    try {
      Query query = collection.orderBy(orderBy, descending: descending);
      
      // Apply filtering if provided
      if (where != null && isEqualTo != null) {
        query = query.where(where, isEqualTo: isEqualTo);
      }
      
      return getPaginatedStream(
        query: query,
        fromFirestore: fromFirestore,
        pageSize: pageSize,
        startAfter: startAfter,
      );
    } catch (e) {
      LoggerService.error(
        'Error streaming paginated data from $collectionPath',
        error: e,
      );
      rethrow;
    }
  }

  /// Get documents with compound queries and pagination.
  /// 
  /// Supports multiple where clauses and complex queries.
  Future<PaginatedResult<T>> queryPaginated({
    required List<QueryConstraint> constraints,
    int pageSize = PaginationMixin.defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = collection;
      
      // Apply all constraints
      for (final constraint in constraints) {
        query = constraint.apply(query);
      }
      
      return await getPaginatedData(
        query: query,
        fromFirestore: fromFirestore,
        pageSize: pageSize,
        startAfter: startAfter,
      );
    } catch (e) {
      LoggerService.error(
        'Error executing paginated query on $collectionPath',
        error: e,
      );
      rethrow;
    }
  }

  /// DEPRECATED: Use getPaginated() instead.
  /// Maintained for backward compatibility.
  @override
  Future<List<T>> getAll() async {
    LoggerService.warning(
      'getAll() is deprecated. Use getPaginated() for better performance.',
    );
    
    // Use pagination to load all documents
    final allItems = await getAllPaginated(
      query: collection.orderBy('createdAt', descending: true),
      fromFirestore: fromFirestore,
    );
    
    return allItems;
  }
}

/// Query constraint for building complex queries.
abstract class QueryConstraint {
  /// Apply this constraint to a query.
  Query apply(Query query);
}

/// Where clause constraint.
class WhereConstraint extends QueryConstraint {
  final String field;
  final dynamic isEqualTo;
  final dynamic isLessThan;
  final dynamic isLessThanOrEqualTo;
  final dynamic isGreaterThan;
  final dynamic isGreaterThanOrEqualTo;
  final dynamic arrayContains;
  final List<dynamic>? arrayContainsAny;
  final List<dynamic>? whereIn;
  final List<dynamic>? whereNotIn;
  final bool? isNull;

  WhereConstraint({
    required this.field,
    this.isEqualTo,
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

  @override
  Query apply(Query query) {
    if (isEqualTo != null) {
      return query.where(field, isEqualTo: isEqualTo);
    } else if (isLessThan != null) {
      return query.where(field, isLessThan: isLessThan);
    } else if (isLessThanOrEqualTo != null) {
      return query.where(field, isLessThanOrEqualTo: isLessThanOrEqualTo);
    } else if (isGreaterThan != null) {
      return query.where(field, isGreaterThan: isGreaterThan);
    } else if (isGreaterThanOrEqualTo != null) {
      return query.where(field, isGreaterThanOrEqualTo: isGreaterThanOrEqualTo);
    } else if (arrayContains != null) {
      return query.where(field, arrayContains: arrayContains);
    } else if (arrayContainsAny != null) {
      return query.where(field, arrayContainsAny: arrayContainsAny);
    } else if (whereIn != null) {
      return query.where(field, whereIn: whereIn);
    } else if (whereNotIn != null) {
      return query.where(field, whereNotIn: whereNotIn);
    } else if (isNull != null) {
      return query.where(field, isNull: isNull);
    }
    return query;
  }
}

/// Order by constraint.
class OrderByConstraint extends QueryConstraint {
  final String field;
  final bool descending;

  OrderByConstraint({
    required this.field,
    this.descending = false,
  });

  @override
  Query apply(Query query) {
    return query.orderBy(field, descending: descending);
  }
}

/// Limit constraint.
class LimitConstraint extends QueryConstraint {
  final int limit;

  LimitConstraint(this.limit);

  @override
  Query apply(Query query) {
    return query.limit(limit);
  }
}