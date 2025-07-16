/// Discussion board state management provider.
/// 
/// This module manages discussion boards, threads, and replies for the
/// education platform, providing forum-style collaborative discussions
/// with real-time updates and moderation features.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/discussion_board.dart';
import '../../domain/repositories/discussion_repository.dart';
import '../../../../shared/core/service_locator.dart';
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
  late final DiscussionRepository _repository;
  
  /// Firebase Auth for user identification.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  
  /// All available discussion boards.
  List<DiscussionBoard> _boards = [];
  
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
  final Map<String, StreamSubscription<List<DiscussionThread>>> _threadSubscriptions = {};
  
  /// Reply subscriptions keyed by board_thread ID.
  final Map<String, StreamSubscription<List<ThreadReply>>> _replySubscriptions = {};

  /// Creates discussion provider with repository dependency.
  /// 
  /// Retrieves discussion repository from dependency injection.
  DiscussionProvider() {
    _repository = getIt<DiscussionRepository>();
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
  void initializeBoards() {
    _boardsSubscription?.cancel();
    
    _boardsSubscription = _repository.streamBoards().listen(
      (boards) {
        _boards = boards;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
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
    
    _threadSubscriptions[boardId] = _repository.streamBoardThreads(boardId).listen(
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
    
    _replySubscriptions[key] = _repository.streamThreadReplies(boardId, threadId).listen(
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
      final board = DiscussionBoard(
        id: '',
        title: title,
        description: description,
        createdBy: currentUserId,
        createdByName: _auth.currentUser?.displayName ?? 'User',
        classId: classId,
        participantIds: [currentUserId],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: isPinned,
        tags: tags,
      );

      final boardId = await _repository.createBoard(board);
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
      final thread = DiscussionThread(
        id: '',
        boardId: boardId,
        title: title,
        content: content,
        authorId: currentUserId,
        authorName: _auth.currentUser?.displayName ?? 'User',
        authorRole: _auth.currentUser?.email?.endsWith('@teacher.edu') == true 
            ? 'teacher' 
            : 'student',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: tags,
      );

      final threadId = await _repository.createThread(boardId, thread);
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
      final reply = ThreadReply(
        id: '',
        threadId: threadId,
        content: content,
        authorId: currentUserId,
        authorName: _auth.currentUser?.displayName ?? 'User',
        authorRole: _auth.currentUser?.email?.endsWith('@teacher.edu') == true 
            ? 'teacher' 
            : 'student',
        createdAt: DateTime.now(),
        replyToId: replyToId,
        replyToAuthor: replyToAuthor,
      );

      final replyId = await _repository.createReply(boardId, threadId, reply);
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
        await _repository.unlikeThread(boardId, threadId, currentUserId);
      } else {
        await _repository.likeThread(boardId, threadId, currentUserId);
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
  Future<void> toggleReplyLike(String boardId, String threadId, String replyId) async {
    try {
      final key = '${boardId}_$threadId';
      final reply = _threadReplies[key]?.firstWhere(
        (r) => r.id == replyId,
        orElse: () => throw Exception('Reply not found'),
      );

      if (reply?.likedBy.contains(currentUserId) ?? false) {
        await _repository.unlikeReply(boardId, threadId, replyId, currentUserId);
      } else {
        await _repository.likeReply(boardId, threadId, replyId, currentUserId);
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
  /// @return true if deletion successful
  Future<bool> deleteThread(String boardId, String threadId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.deleteThread(boardId, threadId);
      LoggerService.info('Deleted thread: $threadId', tag: _tag);
      return true;
    } catch (e) {
      _error = e.toString();
      LoggerService.error('Failed to delete thread', tag: _tag, error: e);
      return false;
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
  Future<bool> deleteReply(String boardId, String threadId, String replyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.deleteReply(boardId, threadId, replyId);
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
      await _repository.pinBoard(boardId, isPinned);
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
      await _repository.pinThread(boardId, threadId, isPinned);
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
  Future<void> lockThread(String boardId, String threadId, bool isLocked) async {
    try {
      await _repository.lockThread(boardId, threadId, isLocked);
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
  Future<List<DiscussionThread>> searchThreads(String query) async {
    try {
      return await _repository.searchThreads(query);
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
    _boardsSubscription?.cancel();
    
    for (final subscription in _threadSubscriptions.values) {
      subscription.cancel();
    }
    
    for (final subscription in _replySubscriptions.values) {
      subscription.cancel();
    }
    
    _repository.dispose();
    super.dispose();
  }
}