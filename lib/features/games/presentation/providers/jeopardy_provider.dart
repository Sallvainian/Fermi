/// Jeopardy game state management provider.
///
/// This module manages Jeopardy game state for the education platform,
/// handling game creation, updates, and real-time synchronization.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/jeopardy_game.dart';
import '../../domain/repositories/jeopardy_repository.dart';
import '../../../../shared/core/service_locator.dart';
import '../../../../shared/services/logger_service.dart';

/// Provider managing Jeopardy game state.
///
/// This provider serves as the central state manager for Jeopardy games,
/// coordinating between the UI and repository. Key features:
/// - Real-time game updates for teachers
/// - Public game library access
/// - Game creation and editing workflows
/// - Search functionality
/// - Automatic stream management
///
/// Maintains separate caches for teacher games and public games
/// with automatic synchronization.
class JeopardyProvider with ChangeNotifier {
  /// Logger tag for this provider.
  static const String _tag = 'JeopardyProvider';

  /// Repository for game data operations.
  late final JeopardyRepository _repository;

  /// Firebase Auth for user identification.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables

  /// Teacher's games.
  List<JeopardyGame> _teacherGames = [];

  /// Public games available to all.
  List<JeopardyGame> _publicGames = [];

  /// Currently selected/editing game.
  JeopardyGame? _currentGame;

  /// Loading state for async operations.
  bool _isLoading = false;

  /// Latest error message for UI display.
  String? _error;

  /// Search query for filtering games.
  String _searchQuery = '';

  // Stream subscriptions

  /// Subscription for teacher games updates.
  StreamSubscription<List<JeopardyGame>>? _teacherGamesSubscription;

  /// Creates provider with repository dependency.
  ///
  /// Retrieves repository from dependency injection.
  JeopardyProvider() {
    _repository = getIt<JeopardyRepository>();
  }

  // Getters

  /// Teacher's games list.
  List<JeopardyGame> get teacherGames => _teacherGames;

  /// Public games list.
  List<JeopardyGame> get publicGames => _publicGames;

  /// Currently selected game or null.
  JeopardyGame? get currentGame => _currentGame;

  /// Whether an operation is in progress.
  bool get isLoading => _isLoading;

  /// Latest error message or null.
  String? get error => _error;

  /// Current search query.
  String get searchQuery => _searchQuery;

  /// Current user's ID from Firebase Auth.
  String get currentUserId => _auth.currentUser?.uid ?? '';

  /// Filtered teacher games based on search query.
  List<JeopardyGame> get filteredTeacherGames {
    if (_searchQuery.isEmpty) return _teacherGames;

    final query = _searchQuery.toLowerCase();
    return _teacherGames.where((game) {
      return game.title.toLowerCase().contains(query) ||
          game.categories.any((cat) =>
              cat.name.toLowerCase().contains(query) ||
              cat.questions.any((q) =>
                  q.question.toLowerCase().contains(query) ||
                  q.answer.toLowerCase().contains(query)));
    }).toList();
  }

  /// Filtered public games based on search query.
  List<JeopardyGame> get filteredPublicGames {
    if (_searchQuery.isEmpty) return _publicGames;

    final query = _searchQuery.toLowerCase();
    return _publicGames.where((game) {
      return game.title.toLowerCase().contains(query) ||
          game.categories.any((cat) =>
              cat.name.toLowerCase().contains(query) ||
              cat.questions.any((q) =>
                  q.question.toLowerCase().contains(query) ||
                  q.answer.toLowerCase().contains(query)));
    }).toList();
  }

  /// Initializes provider and loads teacher games.
  ///
  /// Sets up real-time stream for teacher's games.
  /// Should be called when teacher dashboard opens.
  Future<void> initialize() async {
    _setLoading(true);
    _error = null;

    try {
      // Set up real-time stream for teacher games
      _teacherGamesSubscription?.cancel();
      _teacherGamesSubscription =
          _repository.streamTeacherGames(currentUserId).listen(
        (games) {
          _teacherGames = games;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          _error = error.toString();
          LoggerService.error(
            'Failed to stream teacher games',
            tag: _tag,
            error: error,
          );
          notifyListeners();
        },
      );

      // Load public games
      await loadPublicGames();
    } catch (e) {
      _error = e.toString();
      LoggerService.error(
        'Failed to initialize JeopardyProvider',
        tag: _tag,
        error: e,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// Loads public games from repository.
  ///
  /// Fetches games marked as public for sharing.
  Future<void> loadPublicGames() async {
    try {
      _publicGames = await _repository.getPublicGames();
      notifyListeners();
    } catch (e) {
      LoggerService.error(
        'Failed to load public games',
        tag: _tag,
        error: e,
      );
    }
  }

  /// Creates a new Jeopardy game.
  ///
  /// Saves game to Firestore and updates local cache.
  ///
  /// @param game Game data to create
  /// @return Created game ID or null if failed
  Future<String?> createGame(JeopardyGame game) async {
    _setLoading(true);
    _error = null;

    try {
      // Ensure teacherId is set
      final gameToCreate = JeopardyGame(
        id: '',
        title: game.title,
        teacherId: currentUserId,
        categories: game.categories,
        finalJeopardy: game.finalJeopardy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPublic: game.isPublic,
      );

      final gameId = await _repository.createGame(gameToCreate);
      LoggerService.info('Created Jeopardy game: $gameId', tag: _tag);

      return gameId;
    } catch (e) {
      _error = e.toString();
      LoggerService.error(
        'Failed to create game',
        tag: _tag,
        error: e,
      );
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Updates an existing Jeopardy game.
  ///
  /// Modifies game in Firestore and updates local cache.
  ///
  /// @param gameId Game to update
  /// @param game Updated game data
  /// @return true if update successful
  Future<bool> updateGame(String gameId, JeopardyGame game) async {
    _setLoading(true);
    _error = null;

    try {
      // Update with new timestamp
      final gameToUpdate = JeopardyGame(
        id: gameId,
        title: game.title,
        teacherId: game.teacherId,
        categories: game.categories,
        finalJeopardy: game.finalJeopardy,
        createdAt: game.createdAt,
        updatedAt: DateTime.now(),
        isPublic: game.isPublic,
      );

      await _repository.updateGame(gameId, gameToUpdate);
      LoggerService.info('Updated Jeopardy game: $gameId', tag: _tag);

      return true;
    } catch (e) {
      _error = e.toString();
      LoggerService.error(
        'Failed to update game',
        tag: _tag,
        error: e,
      );
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Loads a specific game by ID.
  ///
  /// Fetches game from repository and sets as current.
  ///
  /// @param gameId Game to load
  /// @return Game instance or null if not found
  Future<JeopardyGame?> loadGame(String gameId) async {
    _setLoading(true);
    _error = null;

    try {
      _currentGame = await _repository.getGame(gameId);
      notifyListeners();
      return _currentGame;
    } catch (e) {
      _error = e.toString();
      LoggerService.error(
        'Failed to load game',
        tag: _tag,
        error: e,
      );
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Deletes a Jeopardy game.
  ///
  /// Removes game from Firestore and local cache.
  ///
  /// @param gameId Game to delete
  /// @return true if deletion successful
  Future<bool> deleteGame(String gameId) async {
    _setLoading(true);
    _error = null;

    try {
      await _repository.deleteGame(gameId);
      LoggerService.info('Deleted Jeopardy game: $gameId', tag: _tag);

      return true;
    } catch (e) {
      _error = e.toString();
      LoggerService.error(
        'Failed to delete game',
        tag: _tag,
        error: e,
      );
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Toggles public visibility of a game.
  ///
  /// Makes game available to all users or restricts to creator.
  ///
  /// @param gameId Game to toggle
  /// @param isPublic Whether game should be public
  /// @return true if toggle successful
  Future<bool> togglePublicStatus(String gameId, bool isPublic) async {
    try {
      await _repository.togglePublicStatus(gameId, isPublic);

      // Reload public games if making public
      if (isPublic) {
        await loadPublicGames();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      LoggerService.error(
        'Failed to toggle public status',
        tag: _tag,
        error: e,
      );
      notifyListeners();
      return false;
    }
  }

  /// Updates search query and notifies listeners.
  ///
  /// @param query New search query
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Sets the current game for editing or playing.
  ///
  /// @param game Game to set as current
  void setCurrentGame(JeopardyGame? game) {
    _currentGame = game;
    notifyListeners();
  }

  /// Clears the current game selection.
  void clearCurrentGame() {
    _currentGame = null;
    notifyListeners();
  }

  /// Clears error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper methods

  /// Sets loading state and notifies listeners.
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Cleans up resources when provider is disposed.
  @override
  void dispose() {
    _teacherGamesSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
