import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simplified Jeopardy provider with direct Firestore access
class SimpleJeopardyProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _games = [];
  Map<String, dynamic>? _currentGame;
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get games => _games;
  Map<String, dynamic>? get currentGame => _currentGame;
  List<Map<String, dynamic>> get questions => _questions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all Jeopardy games
  Future<void> loadGames() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _games = [];
        return;
      }

      // Query games created by this teacher or available to all
      final snapshot = await _firestore
          .collection('jeopardy_games')
          .where('createdBy', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      _games = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _error = null;
    } catch (e) {
      _error = e.toString();
      _games = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new Jeopardy game
  Future<bool> createGame({
    required String title,
    required String description,
    required List<Map<String, dynamic>> categories,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final gameData = {
        'title': title,
        'description': description,
        'categories': categories,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isPublished': false,
        'playCount': 0,
      };

      final docRef = await _firestore
          .collection('jeopardy_games')
          .add(gameData);

      // Add questions for each category
      for (final category in categories) {
        await _createCategoryQuestions(docRef.id, category);
      }

      await loadGames(); // Reload
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Create questions for a category
  Future<void> _createCategoryQuestions(
    String gameId,
    Map<String, dynamic> category,
  ) async {
    final categoryName = category['name'] ?? 'Category';
    final questions = category['questions'] ?? [];

    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      await _firestore.collection('jeopardy_questions').add({
        'gameId': gameId,
        'category': categoryName,
        'question': question['question'],
        'answer': question['answer'],
        'points': (i + 1) * 100, // 100, 200, 300, 400, 500
        'isAnswered': false,
        'answeredBy': null,
      });
    }
  }

  /// Load questions for a game
  Future<void> loadGameQuestions(String gameId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('jeopardy_questions')
          .where('gameId', isEqualTo: gameId)
          .orderBy('category')
          .orderBy('points')
          .get();

      _questions = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _error = null;
    } catch (e) {
      _error = e.toString();
      _questions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start a game session
  Future<String?> startGameSession(String gameId, String classId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final sessionData = {
        'gameId': gameId,
        'classId': classId,
        'hostId': user.uid,
        'startedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'teams': [],
        'currentQuestion': null,
      };

      final docRef = await _firestore
          .collection('jeopardy_sessions')
          .add(sessionData);
      return docRef.id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Join a game session
  Future<bool> joinSession(
    String sessionId,
    String teamName,
    List<String> playerIds,
  ) async {
    try {
      final teamData = {
        'name': teamName,
        'playerIds': playerIds,
        'score': 0,
        'joinedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('jeopardy_sessions').doc(sessionId).update({
        'teams': FieldValue.arrayUnion([teamData]),
      });

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Answer a question
  Future<bool> answerQuestion({
    required String sessionId,
    required String questionId,
    required String teamId,
    required String answer,
    required bool isCorrect,
  }) async {
    try {
      // Update question as answered
      await _firestore.collection('jeopardy_questions').doc(questionId).update({
        'isAnswered': true,
        'answeredBy': teamId,
        'answeredAt': FieldValue.serverTimestamp(),
      });

      // Update team score if correct
      if (isCorrect) {
        final questionDoc = await _firestore
            .collection('jeopardy_questions')
            .doc(questionId)
            .get();

        final points = questionDoc.data()?['points'] ?? 0;

        // Update team score in session
        final sessionDoc = await _firestore
            .collection('jeopardy_sessions')
            .doc(sessionId)
            .get();

        final teams = List<Map<String, dynamic>>.from(
          sessionDoc.data()?['teams'] ?? [],
        );
        final teamIndex = teams.indexWhere((t) => t['name'] == teamId);

        if (teamIndex != -1) {
          teams[teamIndex]['score'] = (teams[teamIndex]['score'] ?? 0) + points;

          await _firestore
              .collection('jeopardy_sessions')
              .doc(sessionId)
              .update({'teams': teams});
        }
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// End a game session
  Future<bool> endSession(String sessionId) async {
    try {
      await _firestore.collection('jeopardy_sessions').doc(sessionId).update({
        'status': 'completed',
        'endedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get session stream for real-time updates
  Stream<Map<String, dynamic>?> getSessionStream(String sessionId) {
    return _firestore
        .collection('jeopardy_sessions')
        .doc(sessionId)
        .snapshots()
        .asyncMap((snapshot) async {
          await Future.delayed(Duration.zero);
          return snapshot;
        })
        .map((doc) {
          if (doc.exists) {
            final data = doc.data()!;
            data['id'] = doc.id;
            return data;
          }
          return null;
        });
  }

  /// Update game
  Future<bool> updateGame(String gameId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('jeopardy_games').doc(gameId).update(updates);
      await loadGames(); // Reload
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete game
  Future<bool> deleteGame(String gameId) async {
    try {
      // Delete all questions first
      final questionsSnapshot = await _firestore
          .collection('jeopardy_questions')
          .where('gameId', isEqualTo: gameId)
          .get();

      for (final doc in questionsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the game
      await _firestore.collection('jeopardy_games').doc(gameId).delete();

      await loadGames(); // Reload
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get game by ID
  Future<Map<String, dynamic>?> getGameById(String gameId) async {
    try {
      final doc = await _firestore
          .collection('jeopardy_games')
          .doc(gameId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Set current game
  void setCurrentGame(Map<String, dynamic>? game) {
    _currentGame = game;
    notifyListeners();
  }
}
