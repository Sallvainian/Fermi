import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as fb;
import '../interfaces/database_service.dart';

/// Firebase Firestore implementation of DatabaseService
class FirebaseDatabaseService implements DatabaseService {
  final fb.FirebaseFirestore _firestore = fb.FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    final doc = await _firestore.collection(collection).doc(documentId).get();
    if (!doc.exists) return null;
    
    final data = doc.data();
    if (data != null) {
      data['id'] = doc.id;
    }
    return data;
  }

  @override
  Future<List<Map<String, dynamic>>> getCollection({
    required String collection,
    QueryOptions? options,
  }) async {
    fb.Query query = _firestore.collection(collection);
    query = _applyQueryOptions(query, options);
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> queryDocuments({
    required String collection,
    required List<QueryCondition> conditions,
    QueryOptions? options,
  }) async {
    fb.Query query = _firestore.collection(collection);
    
    for (final condition in conditions) {
      query = _applyCondition(query, condition);
    }
    
    query = _applyQueryOptions(query, options);
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  @override
  Stream<Map<String, dynamic>?> streamDocument({
    required String collection,
    required String documentId,
  }) {
    return _firestore
        .collection(collection)
        .doc(documentId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data != null) {
        data['id'] = doc.id;
      }
      return data;
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> streamCollection({
    required String collection,
    QueryOptions? options,
  }) {
    fb.Query query = _firestore.collection(collection);
    query = _applyQueryOptions(query, options);
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> streamQuery({
    required String collection,
    required List<QueryCondition> conditions,
    QueryOptions? options,
  }) {
    fb.Query query = _firestore.collection(collection);
    
    for (final condition in conditions) {
      query = _applyCondition(query, condition);
    }
    
    query = _applyQueryOptions(query, options);
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<String> createDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    final docRef = await _firestore.collection(collection).add(data);
    return docRef.id;
  }

  @override
  Future<void> setDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .set(data, fb.SetOptions(merge: merge));
  }

  @override
  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection(collection).doc(documentId).update(data);
  }

  @override
  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    await _firestore.collection(collection).doc(documentId).delete();
  }

  @override
  Future<void> batchWrite({
    required List<BatchOperation> operations,
  }) async {
    final fb.WriteBatch batch = _firestore.batch();
    
    for (final op in operations) {
      final docRef = op.documentId != null
          ? _firestore.collection(op.collection).doc(op.documentId)
          : _firestore.collection(op.collection).doc();
      
      switch (op.type) {
        case BatchOperationType.create:
        case BatchOperationType.set:
          batch.set(docRef, op.data!);
          break;
        case BatchOperationType.update:
          batch.update(docRef, op.data!);
          break;
        case BatchOperationType.delete:
          batch.delete(docRef);
          break;
      }
    }
    
    await batch.commit();
  }

  @override
  Future<T> runTransaction<T>({
    required Future<T> Function(Transaction transaction) handler,
  }) async {
    return await _firestore.runTransaction((fbTransaction) async {
      final wrapper = _FirebaseTransactionWrapper(fbTransaction, _firestore);
      return await handler(wrapper);
    });
  }

  @override
  dynamic get serverTimestamp => fb.FieldValue.serverTimestamp();

  @override
  dynamic get deleteField => fb.FieldValue.delete();

  @override
  dynamic arrayUnion(List<dynamic> elements) => fb.FieldValue.arrayUnion(elements);

  @override
  dynamic arrayRemove(List<dynamic> elements) => fb.FieldValue.arrayRemove(elements);

  @override
  dynamic increment(num value) => fb.FieldValue.increment(value);

  /// Apply query conditions to a Firestore query
  fb.Query _applyCondition(fb.Query query, QueryCondition condition) {
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
  fb.Query _applyQueryOptions(fb.Query query, QueryOptions? options) {
    if (options == null) return query;
    
    if (options.orderBy != null) {
      query = query.orderBy(options.orderBy!, descending: options.descending);
    }
    
    if (options.limit != null) {
      query = query.limit(options.limit!);
    }
    
    if (options.startAfter != null) {
      query = query.startAfter([options.startAfter]);
    }
    
    if (options.startAt != null) {
      query = query.startAt([options.startAt]);
    }
    
    if (options.endAt != null) {
      query = query.endAt([options.endAt]);
    }
    
    if (options.endBefore != null) {
      query = query.endBefore([options.endBefore]);
    }
    
    return query;
  }
}

/// Wrapper for Firebase transaction to implement our Transaction interface
class _FirebaseTransactionWrapper implements Transaction {
  final fb.FirebaseFirestore _firestore;
  final fb.Transaction _fbTransaction;

  _FirebaseTransactionWrapper(this._fbTransaction, this._firestore);

  @override
  Future<Map<String, dynamic>?> get({
    required String collection,
    required String documentId,
  }) async {
    final docRef = _firestore.collection(collection).doc(documentId);
    final doc = await _fbTransaction.get(docRef);
    if (!doc.exists) return null;
    
    final data = doc.data();
    if (data != null) {
      data['id'] = doc.id;
    }
    return data;
  }

  @override
  void set({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) {
    final docRef = _firestore.collection(collection).doc(documentId);
    _fbTransaction.set(docRef, data, fb.SetOptions(merge: merge));
  }

  @override
  void update({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final docRef = _firestore.collection(collection).doc(documentId);
    _fbTransaction.update(docRef, data);
  }

  @override
  void delete({
    required String collection,
    required String documentId,
  }) {
    final docRef = _firestore.collection(collection).doc(documentId);
    _fbTransaction.delete(docRef);
  }
}