/// Repository interface for Jeopardy game operations.
///
/// This module defines the contract for Jeopardy game data persistence
/// and retrieval operations in the education platform.
library;

import '../models/jeopardy_game.dart';

/// Abstract repository defining Jeopardy game operations.
///
/// This interface provides a comprehensive contract for Jeopardy
/// game implementations, supporting:
/// - Game creation and management
/// - Teacher-specific game collections
/// - Public game library access
/// - Real-time game streaming
/// - Search capabilities
///
/// Concrete implementations handle the actual game
/// storage infrastructure and data persistence.
abstract class JeopardyRepository {
  /// Creates a new Jeopardy game.
  ///
  /// Stores the game with generated ID and returns
  /// the ID for reference.
  ///
  /// @param game Game model with configuration
  /// @return Generated unique game ID
  /// @throws Exception if creation fails
  Future<String> createGame(JeopardyGame game);

  /// Updates an existing Jeopardy game.
  ///
  /// Modifies game content, settings, or categories.
  /// Updates the timestamp automatically.
  ///
  /// @param gameId Game to update
  /// @param game Updated game information
  /// @throws Exception if update fails
  Future<void> updateGame(String gameId, JeopardyGame game);

  /// Retrieves a specific Jeopardy game.
  ///
  /// Fetches complete game details including
  /// categories, questions, and settings.
  ///
  /// @param gameId Unique game identifier
  /// @return Game instance or null if not found
  /// @throws Exception if retrieval fails
  Future<JeopardyGame?> getGame(String gameId);

  /// Retrieves all games created by a teacher.
  ///
  /// Returns games sorted by last update time,
  /// newest first for easy access.
  ///
  /// @param teacherId Teacher's unique identifier
  /// @return List of teacher's games
  /// @throws Exception if retrieval fails
  Future<List<JeopardyGame>> getTeacherGames(String teacherId);

  /// Retrieves public games available to all.
  ///
  /// Returns games marked as public, useful for
  /// sharing educational content.
  ///
  /// @return List of public games
  /// @throws Exception if retrieval fails
  Future<List<JeopardyGame>> getPublicGames();

  /// Deletes a Jeopardy game.
  ///
  /// Permanently removes the game from storage.
  /// This operation cannot be undone.
  ///
  /// @param gameId Game to delete
  /// @throws Exception if deletion fails
  Future<void> deleteGame(String gameId);

  /// Toggles public visibility of a game.
  ///
  /// Makes game available to all users or
  /// restricts to creator only.
  ///
  /// @param gameId Game to toggle
  /// @param isPublic Whether game should be public
  /// @throws Exception if toggle fails
  Future<void> togglePublicStatus(String gameId, bool isPublic);

  /// Streams teacher's games in real-time.
  ///
  /// Returns live updates when games are created,
  /// updated, or deleted.
  ///
  /// @param teacherId Teacher to monitor
  /// @return Stream of game lists
  Stream<List<JeopardyGame>> streamTeacherGames(String teacherId);

  /// Searches games by title or content.
  ///
  /// Performs text search across game titles,
  /// categories, and questions.
  ///
  /// @param query Search terms
  /// @param teacherId Optional teacher filter
  /// @return List of matching games
  /// @throws Exception if search fails
  Future<List<JeopardyGame>> searchGames(String query, {String? teacherId});

  /// Disposes of repository resources.
  ///
  /// Cleans up streams and connections.
  void dispose();
}
