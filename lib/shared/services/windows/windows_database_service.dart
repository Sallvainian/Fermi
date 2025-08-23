import 'dart:async';
import 'package:firebase_dart/firebase_dart.dart';
import '../interfaces/database_service.dart';
import '../logger_service.dart';

/// Windows implementation of DatabaseService using firebase_dart
/// Provides full Firestore functionality on Windows desktop
class WindowsDatabaseService implements DatabaseService {
  late FirebaseFirestore _firestore;
  
  static const String _logTag = 'WindowsDatabaseService';

  WindowsDatabaseService() {
    _initialize();
  }

  void _initialize() {
    try {
      _firestore = FirebaseFirestore.instance;
      LoggerService.info('Windows Firestore initialized', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to initialize Windows Firestore', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      LoggerService.debug('Getting document: $collection/$documentId', tag: _logTag);
      
      final docSnapshot = await _firestore
          .collection(collection)
          .doc(documentId)
          .get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          data['id'] = documentId;
          return data;
        }
      }
      
      return null;
    } catch (e) {
      LoggerService.error('Failed to get document: $collection/$documentId', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCollection({
    required String collection,
    QueryOptions? options,
  }) async {
    try {
      LoggerService.debug('Getting collection: $collection', tag: _logTag);
      
      Query query = _firestore.collection(collection);
      query = _applyQueryOptions(query, options);
      
      final querySnapshot = await query.get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      LoggerService.error('Failed to get collection: $collection', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> queryDocuments({
    required String collection,
    required List<QueryCondition> conditions,
    QueryOptions? options,
  }) async {
    try {
      LoggerService.debug('Querying documents in collection: $collection', tag: _logTag);
      
      Query query = _firestore.collection(collection);
      
      // Apply conditions
      for (final condition in conditions) {
        query = _applyCondition(query, condition);
      }
      
      // Apply options
      query = _applyQueryOptions(query, options);
      
      final querySnapshot = await query.get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      LoggerService.error('Failed to query documents in collection: $collection', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Stream<Map<String, dynamic>?> streamDocument({
    required String collection,
    required String documentId,
  }) {
    try {
      LoggerService.debug('Streaming document: $collection/$documentId', tag: _logTag);
      
      return _firestore
          .collection(collection)
          .doc(documentId)
          .snapshots()
          .map((docSnapshot) {
        if (docSnapshot.exists) {
          final data = docSnapshot.data();
          if (data != null) {
            data['id'] = documentId;
            return data;
          }
        }
        return null;
      });
    } catch (e) {
      LoggerService.error('Failed to stream document: $collection/$documentId', tag: _logTag, error: e);
      return Stream.error(e);
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> streamCollection({
    required String collection,
    QueryOptions? options,
  }) {
    try {
      LoggerService.debug('Streaming collection: $collection', tag: _logTag);
      
      Query query = _firestore.collection(collection);
      query = _applyQueryOptions(query, options);
      
      return query.snapshots().map((querySnapshot) {
        return querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      LoggerService.error('Failed to stream collection: $collection', tag: _logTag, error: e);
      return Stream.error(e);
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> streamQuery({
    required String collection,
    required List<QueryCondition> conditions,
    QueryOptions? options,
  }) {
    try {
      LoggerService.debug('Streaming query for collection: $collection', tag: _logTag);
      
      Query query = _firestore.collection(collection);
      
      // Apply conditions
      for (final condition in conditions) {
        query = _applyCondition(query, condition);
      }
      
      // Apply options
      query = _applyQueryOptions(query, options);
      
      return query.snapshots().map((querySnapshot) {
        return querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      LoggerService.error('Failed to stream query for collection: $collection', tag: _logTag, error: e);
      return Stream.error(e);
    }
  }

  @override
  Future<String> createDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    try {
      LoggerService.debug('Creating document in collection: $collection', tag: _logTag);
      
      final docData = Map<String, dynamic>.from(data);
      docData['createdAt'] = FieldValue.serverTimestamp();
      docData['updatedAt'] = FieldValue.serverTimestamp();
      
      final docRef = await _firestore.collection(collection).add(docData);
      
      LoggerService.debug('Document created with ID: ${docRef.id}', tag: _logTag);
      return docRef.id;
    } catch (e) {
      LoggerService.error('Failed to create document in collection: $collection', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> setDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    try {
      LoggerService.debug('Setting document: $collection/$documentId (merge: $merge)', tag: _logTag);
      
      final docData = Map<String, dynamic>.from(data);
      docData['updatedAt'] = FieldValue.serverTimestamp();
      
      if (!merge) {
        docData['createdAt'] = FieldValue.serverTimestamp();
      }
      
      await _firestore
          .collection(collection)
          .doc(documentId)
          .set(docData, SetOptions(merge: merge));
      
      LoggerService.debug('Document set successfully: $collection/$documentId', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to set document: $collection/$documentId', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      LoggerService.debug('Updating document: $collection/$documentId', tag: _logTag);
      
      final updateData = Map<String, dynamic>.from(data);
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore
          .collection(collection)
          .doc(documentId)
          .update(updateData);
      
      LoggerService.debug('Document updated successfully: $collection/$documentId', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to update document: $collection/$documentId', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      LoggerService.debug('Deleting document: $collection/$documentId', tag: _logTag);
      
      await _firestore
          .collection(collection)
          .doc(documentId)
          .delete();
      
      LoggerService.debug('Document deleted successfully: $collection/$documentId', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to delete document: $collection/$documentId', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> batchWrite({
    required List<BatchOperation> operations,
  }) async {
    try {
      LoggerService.debug('Executing batch write with ${operations.length} operations', tag: _logTag);
      
      final batch = _firestore.batch();
      
      for (final op in operations) {
        switch (op.type) {
          case BatchOperationType.create:
            final docRef = _firestore.collection(op.collection).doc();
            final data = Map<String, dynamic>.from(op.data!);
            data['createdAt'] = FieldValue.serverTimestamp();
            data['updatedAt'] = FieldValue.serverTimestamp();
            batch.set(docRef, data);
            break;
            
          case BatchOperationType.set:
            final docRef = _firestore.collection(op.collection).doc(op.documentId!);
            final data = Map<String, dynamic>.from(op.data!);
            data['updatedAt'] = FieldValue.serverTimestamp();
            batch.set(docRef, data);
            break;
            
          case BatchOperationType.update:
            final docRef = _firestore.collection(op.collection).doc(op.documentId!);
            final data = Map<String, dynamic>.from(op.data!);
            data['updatedAt'] = FieldValue.serverTimestamp();
            batch.update(docRef, data);
            break;
            
          case BatchOperationType.delete:
            final docRef = _firestore.collection(op.collection).doc(op.documentId!);
            batch.delete(docRef);
            break;
        }
      }
      
      await batch.commit();
      LoggerService.debug('Batch write completed successfully', tag: _logTag);
    } catch (e) {
      LoggerService.error('Failed to execute batch write', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  Future<T> runTransaction<T>({
    required Future<T> Function(Transaction transaction) handler,
  }) async {
    try {
      LoggerService.debug('Running transaction', tag: _logTag);
      
      return await _firestore.runTransaction((transaction) async {
        final txnWrapper = _FirestoreTransactionWrapper(transaction);
        return await handler(txnWrapper);
      });
    } catch (e) {
      LoggerService.error('Transaction failed', tag: _logTag, error: e);
      rethrow;
    }
  }

  @override
  dynamic get serverTimestamp => FieldValue.serverTimestamp();

  @override
  dynamic get deleteField => FieldValue.delete();

  @override
  dynamic arrayUnion(List<dynamic> elements) {
    return FieldValue.arrayUnion(elements);
  }

  @override
  dynamic arrayRemove(List<dynamic> elements) {
    return FieldValue.arrayRemove(elements);
  }

  @override
  dynamic increment(num value) {
    return FieldValue.increment(value);
  }

  /// Apply a query condition to a Firestore query
  Query _applyCondition(Query query, QueryCondition condition) {
    switch (condition.operator) {
      case QueryOperator.isEqualTo:
        return query.where(condition.field, isEqualTo: condition.value);
      case QueryOperator.isNotEqualTo:
        return query.where(condition.field, isNotEqualTo: condition.value);
      case QueryOperator.isLessThan:
        return query.where(condition.field, isLessThan: condition.value);
      case QueryOperator.isLessThanOrEqualTo:
        return query.where(condition.field, isLessThanOrEqualTo: condition.value);
      case QueryOperator.isGreaterThan:
        return query.where(condition.field, isGreaterThan: condition.value);
      case QueryOperator.isGreaterThanOrEqualTo:
        return query.where(condition.field, isGreaterThanOrEqualTo: condition.value);
      case QueryOperator.arrayContains:
        return query.where(condition.field, arrayContains: condition.value);
      case QueryOperator.arrayContainsAny:
        return query.where(condition.field, arrayContainsAny: condition.value);
      case QueryOperator.whereIn:
        return query.where(condition.field, whereIn: condition.value);
      case QueryOperator.whereNotIn:
        return query.where(condition.field, whereNotIn: condition.value);
      case QueryOperator.isNull:
        return query.where(condition.field, isNull: true);
      case QueryOperator.isNotNull:
        return query.where(condition.field, isNull: false);
    }
  }

  /// Apply query options to a Firestore query
  Query _applyQueryOptions(Query query, QueryOptions? options) {
    if (options == null) return query;
    
    // Apply ordering
    if (options.orderBy != null) {
      query = query.orderBy(options.orderBy!, descending: options.descending);
    }
    
    // Apply limit
    if (options.limit != null && options.limit! > 0) {
      query = query.limit(options.limit!);
    }
    
    // Note: offset is not directly supported in Firestore
    // It should be implemented using startAfter() with a cursor
    if (options.offset != null && options.offset! > 0) {
      LoggerService.warning('Query offset is not efficiently supported in Firestore. Consider using startAfter() with a cursor instead.', tag: _logTag);
    }
    
    return query;
  }

  /// Dispose resources
  void dispose() {
    // No explicit cleanup needed for firebase_dart
    LoggerService.info('Windows database service disposed', tag: _logTag);
  }
}

/// Firestore transaction wrapper
class _FirestoreTransactionWrapper implements Transaction {
  final FirebaseTransaction _transaction;

  _FirestoreTransactionWrapper(this._transaction);

  @override
  Future<Map<String, dynamic>?> get({
    required String collection,
    required String documentId,
  }) async {
    final docRef = FirebaseFirestore.instance.collection(collection).doc(documentId);
    final docSnapshot = await _transaction.get(docRef);
    
    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      if (data != null) {
        data['id'] = documentId;
        return data;
      }
    }
    return null;
  }

  @override
  void set({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) {
    final docRef = FirebaseFirestore.instance.collection(collection).doc(documentId);
    final setData = Map<String, dynamic>.from(data);
    setData['updatedAt'] = FieldValue.serverTimestamp();
    if (!merge) {
      setData['createdAt'] = FieldValue.serverTimestamp();
    }
    _transaction.set(docRef, setData, SetOptions(merge: merge));
  }

  @override
  void update({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final docRef = FirebaseFirestore.instance.collection(collection).doc(documentId);
    final updateData = Map<String, dynamic>.from(data);
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    _transaction.update(docRef, updateData);
  }

  @override
  void delete({
    required String collection,
    required String documentId,
  }) {
    final docRef = FirebaseFirestore.instance.collection(collection).doc(documentId);
    _transaction.delete(docRef);
  }
}