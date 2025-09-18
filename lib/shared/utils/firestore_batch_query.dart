import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for handling batch queries with Firestore's whereIn limitation
class FirestoreBatchQuery {
  /// Maximum number of items allowed in a single whereIn query
  static const int maxBatchSize = 30;

  /// Performs batch queries for whereIn operations that may exceed Firestore's limit
  ///
  /// [collection] - The Firestore collection to query
  /// [field] - The field to filter on
  /// [values] - The list of values to filter by (can exceed 30 items)
  /// [additionalQueries] - Additional query constraints to apply
  ///
  /// Returns a list of all documents matching the query
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> batchWhereIn({
    required CollectionReference<Map<String, dynamic>> collection,
    required dynamic field,
    required List<dynamic> values,
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)? additionalQueries,
  }) async {
    if (values.isEmpty) {
      return [];
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> allResults = [];

    // Process in batches of maxBatchSize
    for (int i = 0; i < values.length; i += maxBatchSize) {
      // Get the batch of values (max 30)
      final batchValues = values.sublist(
        i,
        i + maxBatchSize > values.length ? values.length : i + maxBatchSize,
      );

      // Create the query with whereIn
      Query<Map<String, dynamic>> query = collection.where(field, whereIn: batchValues);

      // Apply additional query constraints if provided
      if (additionalQueries != null) {
        query = additionalQueries(query);
      }

      // Execute the query and add results
      final snapshot = await query.get();
      allResults.addAll(snapshot.docs);
    }

    return allResults;
  }

  /// Performs batch queries for whereIn operations with FieldPath
  ///
  /// This is specifically for document ID queries
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> batchWhereInDocumentId({
    required CollectionReference<Map<String, dynamic>> collection,
    required List<String> documentIds,
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)? additionalQueries,
  }) async {
    return batchWhereIn(
      collection: collection,
      field: FieldPath.documentId,
      values: documentIds,
      additionalQueries: additionalQueries,
    );
  }

  /// Splits a list into batches of the specified size
  static List<List<T>> splitIntoBatches<T>(List<T> list, [int batchSize = maxBatchSize]) {
    final List<List<T>> batches = [];

    for (int i = 0; i < list.length; i += batchSize) {
      batches.add(
        list.sublist(
          i,
          i + batchSize > list.length ? list.length : i + batchSize,
        ),
      );
    }

    return batches;
  }
}