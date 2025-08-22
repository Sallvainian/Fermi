/// Firebase implementation of JeopardyRepository.
///
/// This module provides Firebase Firestore-based persistence
/// for Jeopardy game data in the education platform.
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/jeopardy_game.dart';
import '../../domain/repositories/jeopardy_repository.dart';
import '../../../../shared/services/logger_service.dart';

/// Firebase implementation for Jeopardy game operations.
///
/// Handles all Jeopardy game data persistence using Firestore,
/// providing real-time synchronization and scalable storage.
///
/// Collection structure:
/// - /jeopardy_games/{gameId} - Individual game documents
///
/// Indexes recommended:
/// - teacherId + updatedAt (descending) - For teacher game lists
/// - isPublic + updatedAt (descending) - For public game lists
/// - title (text search) - For game searching
class FirebaseJeopardyRepository implements JeopardyRepository {
  /// Logger tag for this repository.
  static const String _tag = 'FirebaseJeopardyRepository';

  /// Firestore instance for database operations.
  final FirebaseFirestore _firestore;

  /// Active stream subscriptions for cleanup.
  final List<StreamSubscription> _subscriptions = [];

  /// Collection reference for Jeopardy games.
  late final CollectionReference<Map<String, dynamic>> _gamesCollection;

  /// Creates repository with Firestore dependency.
  ///
  /// @param firestore Firestore instance (optional for testing)
  FirebaseJeopardyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _gamesCollection = _firestore.collection('jeopardy_games');
  }

  @override
  Future<String> createGame(JeopardyGame game) async {
    try {
      final docRef = await _gamesCollection.add(game.toFirestore());
      LoggerService.info('Created Jeopardy game: ${docRef.id}', tag: _tag);
      return docRef.id;
    } catch (e, stack) {
      LoggerService.error(
        'Failed to create Jeopardy game',
        tag: _tag,
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to create game: $e');
    }
  }

  @override
  Future<void> updateGame(String gameId, JeopardyGame game) async {
    try {
      await _gamesCollection.doc(gameId).update(game.toFirestore());
      LoggerService.info('Updated Jeopardy game: $gameId', tag: _tag);
    } catch (e, stack) {
      LoggerService.error(
        'Failed to update Jeopardy game',
        tag: _tag,
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to update game: $e');
    }
  }

  @override
  Future<JeopardyGame?> getGame(String gameId) async {
    try {
      final doc = await _gamesCollection.doc(gameId).get();

      if (!doc.exists) {
        LoggerService.warning('Jeopardy game not found: $gameId', tag: _tag);
        return null;
      }

      return _gameFromFirestore(doc);
    } catch (e, stack) {
      LoggerService.error(
        'Failed to get Jeopardy game',
        tag: _tag,
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to get game: $e');
    }
  }

  @override
  Future<List<JeopardyGame>> getTeacherGames(String teacherId) async {
    try {
      final query = _gamesCollection
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('updatedAt', descending: true);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => _gameFromFirestore(doc))
          .where((game) => game != null)
          .cast<JeopardyGame>()
          .toList();
    } catch (e, stack) {
      LoggerService.error(
        'Failed to get teacher games',
        tag: _tag,
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to get teacher games: $e');
    }
  }

  @override
  Future<List<JeopardyGame>> getPublicGames() async {
    try {
      final query = _gamesCollection
          .where('isPublic', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .limit(50); // Limit public games to prevent large downloads

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => _gameFromFirestore(doc))
          .where((game) => game != null)
          .cast<JeopardyGame>()
          .toList();
    } catch (e, stack) {
      LoggerService.error(
        'Failed to get public games',
        tag: _tag,
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to get public games: $e');
    }
  }

  @override
  Future<void> deleteGame(String gameId) async {
    try {
      await _gamesCollection.doc(gameId).delete();
      LoggerService.info('Deleted Jeopardy game: $gameId', tag: _tag);
    } catch (e, stack) {
      LoggerService.error(
        'Failed to delete Jeopardy game',
        tag: _tag,
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to delete game: $e');
    }
  }

  @override
  Future<void> togglePublicStatus(String gameId, bool isPublic) async {
    try {
      await _gamesCollection.doc(gameId).update({
        'isPublic': isPublic,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      LoggerService.info(
        'Toggled public status for game $gameId to $isPublic',
        tag: _tag,
      );
    } catch (e, stack) {
      LoggerService.error(
        'Failed to toggle public status',
        tag: _tag,
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to toggle public status: $e');
    }
  }

  @override
  Stream<List<JeopardyGame>> streamTeacherGames(String teacherId) {
    try {
      final query = _gamesCollection
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('updatedAt', descending: true);

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => _gameFromFirestore(doc))
            .where((game) => game != null)
            .cast<JeopardyGame>()
            .toList();
      });
    } catch (e, stack) {
      LoggerService.error(
        'Failed to stream teacher games',
        tag: _tag,
        error: e,
        stackTrace: stack,
      );
      return Stream.error('Failed to stream teacher games: $e');
    }
  }

  @override
  Future<List<JeopardyGame>> searchGames(String query,
      {String? teacherId}) async {
    try {
      // Note: This is a simple implementation. For production,
      // consider using a dedicated search service like Algolia
      Query<Map<String, dynamic>> searchQuery = _gamesCollection;

      if (teacherId != null) {
        searchQuery = searchQuery.where('teacherId', isEqualTo: teacherId);
      }

      final snapshot = await searchQuery.get();

      final lowercaseQuery = query.toLowerCase();
      return snapshot.docs
          .map((doc) => _gameFromFirestore(doc))
          .where((game) => game != null)
          .cast<JeopardyGame>()
          .where((game) {
        // Search in title
        if (game.title.toLowerCase().contains(lowercaseQuery)) {
          return true;
        }
        // Search in categories
        for (final category in game.categories) {
          if (category.name.toLowerCase().contains(lowercaseQuery)) {
            return true;
          }
          // Search in questions
          for (final question in category.questions) {
            if (question.question.toLowerCase().contains(lowercaseQuery) ||
                question.answer.toLowerCase().contains(lowercaseQuery)) {
              return true;
            }
          }
        }
        return false;
      }).toList();
    } catch (e, stack) {
      LoggerService.error(
        'Failed to search games',
        tag: _tag,
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to search games: $e');
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    LoggerService.info('Disposed FirebaseJeopardyRepository', tag: _tag);
  }

  /// Converts Firestore document to JeopardyGame model.
  ///
  /// Handles data parsing and validation with proper
  /// error handling for malformed data.
  ///
  /// @param doc Firestore document
  /// @return JeopardyGame instance or null if parsing fails
  JeopardyGame? _gameFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      if (data == null) return null;

      return JeopardyGame.fromFirestore(data, doc.id);
    } catch (e) {
      LoggerService.error(
        'Failed to parse Jeopardy game from Firestore',
        tag: _tag,
        error: e,
      );
      return null;
    }
  }
}
