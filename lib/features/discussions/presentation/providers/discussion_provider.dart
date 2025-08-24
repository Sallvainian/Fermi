/// Discussion board state management provider.
///
/// This module manages discussion boards, threads, and replies for the
/// education platform, providing forum-style collaborative discussions
/// with real-time updates and moderation features.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/discussion_board.dart';
// Repository removed - using direct Firestore access
import '../../../../shared/services/logger_service.dart';

/// Provider managing discussion boards and threads.
///
/// This provider serves as the central state manager for discussion forums,
/// coordinating hierarchical content organization. Key features:
/// - Three-tier structure: boards → threads → replies
/// - Real-time updates for all discussion levels
/// - Like/unlike functionality for engagement
/// - Moderation tools (pin, lock, delete)
/// - Tag-based organization and search
/// - Role-based permissions (teacher/student)
///
/// Maintains separate caches for boards, threads, and replies
/// with automatic stream management.
class DiscussionProvider with ChangeNotifier {
  /// Logger tag for this provider.
  static const String _tag = 'DiscussionProvider';

  /// Repository for discussion data operations.
  // Repository removed - using direct Firestore access
  
  /// Firestore instance for database access.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Firebase Auth for user identification.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables

  /// All available discussion boards.
  final List<DiscussionBoard> _boards = [];

  /// Threads grouped by board ID.
  final Map<String, List<DiscussionThread>> _boardThreads = {};

  /// Replies grouped by board_thread ID.
  final Map<String, List<ThreadReply>> _threadReplies = {};

  /// Currently selected board.
  DiscussionBoard? _currentBoard;

  /// Currently selected thread.
  DiscussionThread? _currentThread;

  /// Loading state for async operations.
  bool _isLoading = false;

  /// Latest error message for UI display.
  String? _error;

  // Stream subscriptions

  /// Subscription for board list updates.
  StreamSubscription<List<DiscussionBoard>>? _boardsSubscription;

  /// Thread subscriptions keyed by board ID.
  final Map<String, StreamSubscription<List<DiscussionThread>>>
      _threadSubscriptions = {};

  /// Reply subscriptions keyed by board_thread ID.
  final Map<String, StreamSubscription<List<ThreadReply>>> _replySubscriptions =
      {};

  /// Creates discussion provider with repository dependency.
  ///
  /// Retrieves discussion repository from dependency injection.
  DiscussionProvider() {
    // Repository initialization removed
  }

  // Getters

  /// List of all discussion boards.
  List<DiscussionBoard> get boards => _boards;

  /// Currently selected board or null.
  DiscussionBoard? get currentBoard => _currentBoard;

  /// Currently selected thread or null.
  DiscussionThread? get currentThread => _currentThread;

  /// Whether an operation is in progress.
  bool get isLoading => _isLoading;

  /// Latest error message or null.
  String? get error => _error;

  /// Current user's ID from Firebase Auth.
  String get currentUserId => _auth.currentUser?.uid ?? '';
  
  /// Current user's role (teacher or student).
  String _userRole = 'student';
  String get userRole => _userRole;
  
  /// Fetches and caches the user's role from Firestore.
  Future<void> _fetchUserRole() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          _userRole = userDoc.data()?['role'] ?? 'student';
          notifyListeners();
        }
      }
    } catch (e) {
      LoggerService.error('Failed to fetch user role', error: e, tag: _tag);
      _userRole = 'student'; // Default to student on error
    }
  }

  /// Gets threads for a specific board.
  ///
  /// Returns cached threads or empty list if not loaded.
  ///
  /// @param boardId Board to get threads from
  /// @return List of discussion threads
  List<DiscussionThread> getBoardThreads(String boardId) {
    return _boardThreads[boardId] ?? [];
  }

  /// Gets replies for a specific thread.
  ///
  /// Uses composite key of board and thread IDs.
  /// Returns cached replies or empty list if not loaded.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to get replies from
  /// @return List of thread replies
  List<ThreadReply> getThreadReplies(String boardId, String threadId) {
    final key = '${boardId}_$threadId';
    return _threadReplies[key] ?? [];
  }

  /// Initializes real-time board monitoring.
  ///
  /// Sets up stream subscription for discussion boards,
  /// automatically updating when boards are added, modified,
  /// or removed. Cancels any existing subscription first.
  void initializeBoards() async {
    _boardsSubscription?.cancel();
    
    // Fetch user role first
    await _fetchUserRole();
    
    // Set loading state
    _isLoading = true;
    notifyListeners();

    // Subscribe to boards collection
    _boardsSubscription = _firestore
        .collection('discussion_boards')
        .orderBy('isPinned', descending: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return DiscussionBoard.fromFirestore(doc);
            }).toList())
        .listen(
      (boardsList) {
        _boards.clear();
        _boards.addAll(boardsList);
        _error = null;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        LoggerService.error('Failed to load boards', tag: _tag, error: error);
        notifyListeners();
      },
    );
  }

  /// Loads and subscribes to threads for a board.
  ///
  /// Sets up real-time stream for thread updates including
  /// new threads, edits, and engagement metrics. Cancels
  /// any existing subscription for the board.
  ///
  /// @param boardId Board to load threads from
  void loadBoardThreads(String boardId) {
    _threadSubscriptions[boardId]?.cancel();

    _threadSubscriptions[boardId] =
        _firestore
            .collection('discussion_boards')
            .doc(boardId)
            .collection('threads')
            .orderBy('isPinned', descending: true)
            .orderBy('lastActivityAt', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs.map((doc) {
                  return DiscussionThread.fromFirestore(doc);
                }).toList())
            .listen(
      (threads) {
        _boardThreads[boardId] = threads;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        LoggerService.error('Failed to load threads', tag: _tag, error: error);
        notifyListeners();
      },
    );
  }

  /// Loads and subscribes to replies for a thread.
  ///
  /// Sets up real-time stream for reply updates including
  /// new replies, edits, and likes. Uses composite key
  /// for subscription management.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to load replies from
  void loadThreadReplies(String boardId, String threadId) {
    final key = '${boardId}_$threadId';
    _replySubscriptions[key]?.cancel();

    _replySubscriptions[key] =
        _firestore
            .collection('discussion_boards')
            .doc(boardId)
            .collection('threads')
            .doc(threadId)
            .collection('replies')
            .orderBy('createdAt')
            .snapshots()
            .map((snapshot) => snapshot.docs.map((doc) {
                  return ThreadReply.fromFirestore(doc);
                }).toList())
            .listen(
      (replies) {
        _threadReplies[key] = replies;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        LoggerService.error('Failed to load replies', tag: _tag, error: error);
        notifyListeners();
      },
    );
  }

  /// Sets the active discussion board.
  ///
  /// Automatically loads threads for the selected board
  /// and updates UI state.
  ///
  /// @param board Board to activate
  void setCurrentBoard(DiscussionBoard board) {
    _currentBoard = board;
    loadBoardThreads(board.id);
    notifyListeners();
  }

  /// Sets the active discussion thread.
  ///
  /// Automatically loads replies if a board is selected.
  /// Updates UI state for thread detail views.
  ///
  /// @param thread Thread to activate
  void setCurrentThread(DiscussionThread thread) {
    _currentThread = thread;
    if (_currentBoard != null) {
      loadThreadReplies(_currentBoard!.id, thread.id);
    }
    notifyListeners();
  }

  /// Creates a new discussion board.
  ///
  /// Board creation includes:
  /// - Automatic author attribution
  /// - Optional class association
  /// - Tag assignment for categorization
  /// - Pin status for importance
  ///
  /// @param title Board title
  /// @param description Board purpose/rules
  /// @param tags Category tags
  /// @param isPinned Whether to pin at top
  /// @param classId Optional class association
  /// @return Created board ID or null if failed
  Future<String?> createBoard({
    required String title,
    required String description,
    List<String> tags = const [],
    bool isPinned = false,
    String? classId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final board = {
        'title': title,
        'description': description,
        'createdBy': currentUserId,
        'createdByName': _auth.currentUser?.displayName ?? 'User',
        'classId': classId,
        'participantIds': [currentUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isPinned': isPinned,
        'tags': tags,
      };

      final docRef = await _firestore.collection('discussion_boards').add(board);
      final boardId = docRef.id;
      LoggerService.info('Created board: $boardId', tag: _tag);

      return boardId;
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to create board', tag: _tag, error: e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Deletes a discussion board and all its threads and replies.
  /// 
  /// Only teachers can delete boards. Performs batch deletion of:
  /// - All replies in all threads
  /// - All threads in the board
  /// - The board itself
  /// 
  /// @param boardId Board ID to delete
  /// @throws Exception if deletion fails
  Future<void> deleteBoard(String boardId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Get all threads in the board
      final threadsSnapshot = await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .get();
      
      // Delete all replies/comments in all threads
      for (var threadDoc in threadsSnapshot.docs) {
        // Try to delete 'replies' subcollection
        final repliesSnapshot = await _firestore
            .collection('discussion_boards')
            .doc(boardId)
            .collection('threads')
            .doc(threadDoc.id)
            .collection('replies')
            .get();
        
        for (var replyDoc in repliesSnapshot.docs) {
          await replyDoc.reference.delete();
        }
        
        // Also try to delete 'comments' subcollection (used by thread_detail_screen)
        final commentsSnapshot = await _firestore
            .collection('discussion_boards')
            .doc(boardId)
            .collection('threads')
            .doc(threadDoc.id)
            .collection('comments')
            .get();
        
        for (var commentDoc in commentsSnapshot.docs) {
          await commentDoc.reference.delete();
        }
        
        // Delete the thread itself
        await threadDoc.reference.delete();
      }
      
      // Delete the board
      await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .delete();
      
      // Remove from local state
      _boards.removeWhere((board) => board.id == boardId);
      _boardThreads.remove(boardId);
      
      // Clear thread replies for this board
      _threadReplies.removeWhere((key, value) => key.startsWith('${boardId}_'));
      
      LoggerService.info('Deleted board: $boardId', tag: _tag);
      
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to delete board', tag: _tag, error: e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new discussion thread.
  ///
  /// Thread creation includes:
  /// - Author attribution with role
  /// - Initial content as first post
  /// - Tag assignment for searchability
  /// - Automatic timestamp tracking
  ///
  /// @param boardId Parent board ID
  /// @param title Thread title
  /// @param content Initial post content
  /// @param tags Category tags
  /// @return Created thread ID or null if failed
  Future<String?> createThread({
    required String boardId,
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final thread = {
        'boardId': boardId,
        'title': title,
        'content': content,
        'authorId': currentUserId,
        'authorName': _auth.currentUser?.displayName ?? 'User',
        'authorRole': _userRole,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'tags': tags,
        'isPinned': false,
        'isLocked': false,
        'viewCount': 0,
        'replyCount': 0,
        'lastActivityAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .add(thread);
      final threadId = docRef.id;
      LoggerService.info('Created thread: $threadId', tag: _tag);

      return threadId;
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to create thread', tag: _tag, error: e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a reply to a thread.
  ///
  /// Reply features:
  /// - Nested reply support (reply to reply)
  /// - Author attribution with role
  /// - Automatic thread update timestamp
  /// - Real-time delivery to participants
  ///
  /// @param boardId Parent board ID
  /// @param threadId Parent thread ID
  /// @param content Reply content
  /// @param replyToId Optional parent reply ID
  /// @param replyToAuthor Optional parent author name
  /// @return Created reply ID or null if failed
  Future<String?> createReply({
    required String boardId,
    required String threadId,
    required String content,
    String? replyToId,
    String? replyToAuthor,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reply = {
        'threadId': threadId,
        'content': content,
        'authorId': currentUserId,
        'authorName': _auth.currentUser?.displayName ?? 'User',
        'authorRole': _userRole,
        'createdAt': FieldValue.serverTimestamp(),
        'replyToId': replyToId,
        'replyToAuthor': replyToAuthor,
        'likes': [],
        'isEdited': false,
      };

      final docRef = await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .doc(threadId)
          .collection('replies')
          .add(reply);
      final replyId = docRef.id;
      LoggerService.info('Created reply: $replyId', tag: _tag);

      return replyId;
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to create reply', tag: _tag, error: e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Like/unlike operations

  /// Toggles like status for a discussion thread.
  ///
  /// Adds or removes current user from thread's like list.
  /// Updates like count and UI state automatically through
  /// stream subscriptions.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to like/unlike
  /// @throws Exception if thread not found
  Future<void> toggleThreadLike(String boardId, String threadId) async {
    try {
      final thread = _boardThreads[boardId]?.firstWhere(
        (t) => t.id == threadId,
        orElse: () => throw Exception('Thread not found'),
      );

      if (thread?.likedBy.contains(currentUserId) ?? false) {
        // Remove like
        await _firestore
            .collection('discussion_boards')
            .doc(boardId)
            .collection('threads')
            .doc(threadId)
            .update({
          'likedBy': FieldValue.arrayRemove([currentUserId]),
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Add like
        await _firestore
            .collection('discussion_boards')
            .doc(boardId)
            .collection('threads')
            .doc(threadId)
            .update({
          'likedBy': FieldValue.arrayUnion([currentUserId]),
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to toggle thread like', tag: _tag, error: e);
      notifyListeners();
    }
  }

  /// Toggles like status for a thread reply.
  ///
  /// Adds or removes current user from reply's like list.
  /// Uses composite key for efficient lookup.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread containing the reply
  /// @param replyId Reply to like/unlike
  /// @throws Exception if reply not found
  Future<void> toggleReplyLike(
      String boardId, String threadId, String replyId) async {
    try {
      final key = '${boardId}_$threadId';
      final reply = _threadReplies[key]?.firstWhere(
        (r) => r.id == replyId,
        orElse: () => throw Exception('Reply not found'),
      );

      if (reply?.likedBy.contains(currentUserId) ?? false) {
        // Remove like from reply
        await _firestore
            .collection('discussion_boards')
            .doc(boardId)
            .collection('threads')
            .doc(threadId)
            .collection('replies')
            .doc(replyId)
            .update({
          'likedBy': FieldValue.arrayRemove([currentUserId]),
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Add like to reply
        await _firestore
            .collection('discussion_boards')
            .doc(boardId)
            .collection('threads')
            .doc(threadId)
            .collection('replies')
            .doc(replyId)
            .update({
          'likedBy': FieldValue.arrayUnion([currentUserId]),
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to toggle reply like', tag: _tag, error: e);
      notifyListeners();
    }
  }

  // Delete operations

  /// Permanently deletes a discussion thread.
  ///
  /// Removes thread and all associated replies from Firestore.
  /// This operation cannot be undone. Consider implementing
  /// soft deletion for content moderation.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to delete
  /// @throws Exception if deletion fails
  Future<void> deleteThread(String boardId, String threadId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Delete all replies first
      final repliesSnapshot = await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .doc(threadId)
          .collection('replies')
          .get();
      
      for (var replyDoc in repliesSnapshot.docs) {
        await replyDoc.reference.delete();
      }
      
      // Also delete all comments (used by thread_detail_screen)
      final commentsSnapshot = await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .doc(threadId)
          .collection('comments')
          .get();
      
      for (var commentDoc in commentsSnapshot.docs) {
        await commentDoc.reference.delete();
      }
      
      // Delete the thread
      await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .doc(threadId)
          .delete();
      
      // Remove from local state
      _boardThreads[boardId]?.removeWhere((thread) => thread.id == threadId);
      
      // Clear replies for this thread
      final replyKey = '${boardId}_$threadId';
      _threadReplies.remove(replyKey);
      
      LoggerService.info('Deleted thread: $threadId', tag: _tag);
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to delete thread', tag: _tag, error: e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Permanently deletes a thread reply.
  ///
  /// Removes reply from Firestore. Parent thread remains intact.
  /// This operation cannot be undone.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread containing the reply
  /// @param replyId Reply to delete
  /// @return true if deletion successful
  Future<bool> deleteReply(
      String boardId, String threadId, String replyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .doc(threadId)
          .collection('replies')
          .doc(replyId)
          .delete();
      LoggerService.info('Deleted reply: $replyId', tag: _tag);
      return true;
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to delete reply', tag: _tag, error: e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Admin operations

  /// Pins or unpins a discussion board.
  ///
  /// Pinned boards appear at the top of the board list.
  /// Typically restricted to teacher/admin roles.
  ///
  /// @param boardId Board to pin/unpin
  /// @param isPinned true to pin, false to unpin
  Future<void> pinBoard(String boardId, bool isPinned) async {
    try {
      await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .update({'isPinned': isPinned});
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to pin/unpin board', tag: _tag, error: e);
      notifyListeners();
    }
  }

  /// Pins or unpins a discussion thread.
  ///
  /// Pinned threads appear at the top of the thread list.
  /// Useful for important announcements or FAQs.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to pin/unpin
  /// @param isPinned true to pin, false to unpin
  Future<void> pinThread(String boardId, String threadId, bool isPinned) async {
    try {
      await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .doc(threadId)
          .update({'isPinned': isPinned});
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to pin/unpin thread', tag: _tag, error: e);
      notifyListeners();
    }
  }

  /// Locks or unlocks a discussion thread.
  ///
  /// Locked threads prevent new replies while preserving
  /// existing content. Useful for closing resolved discussions.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to lock/unlock
  /// @param isLocked true to lock, false to unlock
  Future<void> lockThread(
      String boardId, String threadId, bool isLocked) async {
    try {
      await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .doc(threadId)
          .update({'isLocked': isLocked});
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to lock/unlock thread', tag: _tag, error: e);
      notifyListeners();
    }
  }

  // Search

  /// Searches for threads across all boards.
  ///
  /// Performs text search on thread titles and content.
  /// Returns matching threads from any board. Consider
  /// implementing filters for board-specific search.
  ///
  /// @param query Search terms
  /// @return List of matching threads or empty list
  Future<List<Map<String, dynamic>>> searchThreads(String query) async {
    try {
      // Simple search implementation
      final results = <Map<String, dynamic>>[];
      for (final boardId in _boardThreads.keys) {
        final threads = _boardThreads[boardId] ?? [];
        for (final thread in threads) {
          // Convert DiscussionThread to Map for search results
          final title = thread.title.toLowerCase();
          final content = thread.content.toLowerCase();
          final searchQuery = query.toLowerCase();
          if (title.contains(searchQuery) || content.contains(searchQuery)) {
            // Convert to Map for compatibility with existing UI
            results.add({
              'id': thread.id,
              'title': thread.title,
              'content': thread.content,
              'boardId': thread.boardId,
              'authorName': thread.authorName,
              'createdAt': thread.createdAt.toIso8601String(),
            });
          }
        }
      }
      return results;
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to search threads', tag: _tag, error: e);
      notifyListeners();
      return [];
    }
  }

  // Clean up

  /// Clears the current board selection.
  ///
  /// Resets board context for navigation or refresh.
  void clearCurrentBoard() {
    _currentBoard = null;
    notifyListeners();
  }

  /// Clears the current thread selection.
  ///
  /// Resets thread context for navigation or refresh.
  void clearCurrentThread() {
    _currentThread = null;
    notifyListeners();
  }

  /// Cleans up resources when provider is disposed.
  ///
  /// Cancels all stream subscriptions for boards, threads,
  /// and replies to prevent memory leaks. Also disposes
  /// the repository instance.
  @override
  void dispose() {
    // Clean up subscriptions
    _boardsSubscription?.cancel();
    for (final subscription in _threadSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _replySubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }
}
