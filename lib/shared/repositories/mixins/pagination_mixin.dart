import 'package:cloud_firestore/cloud_firestore.dart';

/// Mixin providing pagination functionality for Firestore repositories.
/// 
/// This mixin adds pagination capabilities to repository classes,
/// enabling efficient data loading for large collections while
/// maintaining performance and reducing bandwidth usage.
/// 
/// Features:
/// - Cursor-based pagination for consistent results
/// - Configurable page sizes
/// - Support for ordering and filtering
/// - Automatic query management
/// - Error handling and recovery
/// 
/// Example usage:
/// ```dart
/// class UserRepository extends BaseRepository with PaginationMixin {
///   Future<PaginatedResult<User>> getUsers({
///     int pageSize = 20,
///     DocumentSnapshot? startAfter,
///   }) async {
///     final query = FirebaseFirestore.instance
///         .collection('users')
///         .orderBy('createdAt', descending: true);
///     
///     return getPaginatedData(
///       query: query,
///       pageSize: pageSize,
///       startAfter: startAfter,
///       fromFirestore: (doc) => User.fromFirestore(doc),
///     );
///   }
/// }
/// ```
mixin PaginationMixin {
  /// Default page size if not specified
  static const int defaultPageSize = 20;
  
  /// Maximum allowed page size to prevent performance issues
  static const int maxPageSize = 100;

  /// Get paginated data from a Firestore query.
  /// 
  /// This method handles the common pagination logic for Firestore queries,
  /// including cursor management, result mapping, and metadata generation.
  /// 
  /// @param query The base Firestore query (must include orderBy)
  /// @param fromFirestore Function to convert DocumentSnapshot to model
  /// @param pageSize Number of documents per page
  /// @param startAfter Optional cursor for pagination continuation
  /// @return PaginatedResult containing data and pagination metadata
  Future<PaginatedResult<T>> getPaginatedData<T>({
    required Query query,
    required T Function(DocumentSnapshot) fromFirestore,
    int pageSize = defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    // Validate and constrain page size
    final effectivePageSize = pageSize.clamp(1, maxPageSize);
    
    // Apply pagination cursor if provided
    Query paginatedQuery = query.limit(effectivePageSize + 1); // +1 to check hasMore
    if (startAfter != null) {
      paginatedQuery = paginatedQuery.startAfterDocument(startAfter);
    }
    
    try {
      final snapshot = await paginatedQuery.get();
      final docs = snapshot.docs;
      
      // Check if there are more pages
      final hasMore = docs.length > effectivePageSize;
      
      // Remove the extra document used for hasMore check
      final resultDocs = hasMore 
          ? docs.sublist(0, effectivePageSize)
          : docs;
      
      // Map documents to models
      final items = resultDocs.map((doc) => fromFirestore(doc)).toList();
      
      return PaginatedResult<T>(
        items: items,
        hasMore: hasMore,
        lastDocument: resultDocs.isNotEmpty ? resultDocs.last : null,
        pageSize: effectivePageSize,
        totalFetched: items.length,
      );
    } catch (e) {
      // Return empty result on error
      return PaginatedResult<T>(
        items: [],
        hasMore: false,
        lastDocument: null,
        pageSize: effectivePageSize,
        totalFetched: 0,
        error: e.toString(),
      );
    }
  }

  /// Get paginated stream of data from Firestore.
  /// 
  /// Creates a stream that emits paginated results whenever the underlying
  /// data changes. Useful for real-time pagination scenarios.
  /// 
  /// @param query The base Firestore query (must include orderBy)
  /// @param fromFirestore Function to convert DocumentSnapshot to model
  /// @param pageSize Number of documents per page
  /// @param startAfter Optional cursor for pagination continuation
  /// @return Stream of PaginatedResult
  Stream<PaginatedResult<T>> getPaginatedStream<T>({
    required Query query,
    required T Function(DocumentSnapshot) fromFirestore,
    int pageSize = defaultPageSize,
    DocumentSnapshot? startAfter,
  }) {
    // Validate and constrain page size
    final effectivePageSize = pageSize.clamp(1, maxPageSize);
    
    // Apply pagination
    Query paginatedQuery = query.limit(effectivePageSize + 1);
    if (startAfter != null) {
      paginatedQuery = paginatedQuery.startAfterDocument(startAfter);
    }
    
    return paginatedQuery.snapshots().map((snapshot) {
      final docs = snapshot.docs;
      
      // Check if there are more pages
      final hasMore = docs.length > effectivePageSize;
      
      // Remove the extra document
      final resultDocs = hasMore 
          ? docs.sublist(0, effectivePageSize)
          : docs;
      
      // Map to models
      final items = resultDocs.map((doc) => fromFirestore(doc)).toList();
      
      return PaginatedResult<T>(
        items: items,
        hasMore: hasMore,
        lastDocument: resultDocs.isNotEmpty ? resultDocs.last : null,
        pageSize: effectivePageSize,
        totalFetched: items.length,
      );
    }).handleError((error) {
      // Emit error result
      return PaginatedResult<T>(
        items: [],
        hasMore: false,
        lastDocument: null,
        pageSize: effectivePageSize,
        totalFetched: 0,
        error: error.toString(),
      );
    });
  }

  /// Load all pages of data sequentially.
  /// 
  /// WARNING: Use with caution for large datasets. This method loads
  /// all documents from a collection, which can be expensive and slow.
  /// Consider using regular pagination for better performance.
  /// 
  /// @param query The base Firestore query
  /// @param fromFirestore Function to convert DocumentSnapshot to model
  /// @param onProgress Optional callback for progress updates
  /// @return List of all items in the collection
  Future<List<T>> getAllPaginated<T>({
    required Query query,
    required T Function(DocumentSnapshot) fromFirestore,
    void Function(int fetched, int total)? onProgress,
  }) async {
    final allItems = <T>[];
    DocumentSnapshot? lastDoc;
    bool hasMore = true;
    
    while (hasMore) {
      final result = await getPaginatedData(
        query: query,
        fromFirestore: fromFirestore,
        pageSize: maxPageSize, // Use max for efficiency
        startAfter: lastDoc,
      );
      
      allItems.addAll(result.items);
      hasMore = result.hasMore;
      lastDoc = result.lastDocument;
      
      // Report progress if callback provided
      onProgress?.call(allItems.length, -1); // -1 indicates unknown total
      
      // Add small delay to prevent rate limiting
      if (hasMore) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    return allItems;
  }
}

/// Result container for paginated queries.
/// 
/// Contains the fetched items along with pagination metadata
/// needed to fetch subsequent pages.
class PaginatedResult<T> {
  /// List of items in this page
  final List<T> items;
  
  /// Whether more pages are available
  final bool hasMore;
  
  /// Last document in this page (cursor for next page)
  final DocumentSnapshot? lastDocument;
  
  /// Page size used for this query
  final int pageSize;
  
  /// Number of items actually fetched
  final int totalFetched;
  
  /// Error message if query failed
  final String? error;
  
  /// Whether the query succeeded
  bool get isSuccess => error == null;
  
  /// Whether this is the last page
  bool get isLastPage => !hasMore;
  
  /// Whether this page is empty
  bool get isEmpty => items.isEmpty;

  const PaginatedResult({
    required this.items,
    required this.hasMore,
    required this.lastDocument,
    required this.pageSize,
    required this.totalFetched,
    this.error,
  });
  
  /// Create a copy with updated fields
  PaginatedResult<T> copyWith({
    List<T>? items,
    bool? hasMore,
    DocumentSnapshot? lastDocument,
    int? pageSize,
    int? totalFetched,
    String? error,
  }) {
    return PaginatedResult<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: lastDocument ?? this.lastDocument,
      pageSize: pageSize ?? this.pageSize,
      totalFetched: totalFetched ?? this.totalFetched,
      error: error ?? this.error,
    );
  }
}

/// Extension methods for Query to support pagination
extension QueryPaginationExtension on Query {
  /// Apply pagination parameters to a query
  Query paginate({
    required int pageSize,
    DocumentSnapshot? startAfter,
  }) {
    Query query = limit(pageSize);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query;
  }
}