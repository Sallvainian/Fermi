/// Simplified discussion board provider with direct Firestore integration.
/// 
/// Removes repository pattern for simpler, more maintainable code.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/models/user_model.dart';

/// Simple discussion board model
class SimpleDiscussionBoard {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final int threadCount;
  final bool isPinned;
  final List<String> tags;

  SimpleDiscussionBoard({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.threadCount = 0,
    this.isPinned = false,
    this.tags = const [],
  });

  factory SimpleDiscussionBoard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SimpleDiscussionBoard(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      threadCount: data['threadCount'] ?? 0,
      isPinned: data['isPinned'] ?? false,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'threadCount': threadCount,
      'isPinned': isPinned,
      'tags': tags,
    };
  }
}

/// Simple discussion thread model
class SimpleDiscussionThread {
  final String id;
  final String boardId;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final int replyCount;
  final int likeCount;
  final bool isPinned;
  final bool isLocked;

  SimpleDiscussionThread({
    required this.id,
    required this.boardId,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.replyCount = 0,
    this.likeCount = 0,
    this.isPinned = false,
    this.isLocked = false,
  });

  factory SimpleDiscussionThread.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SimpleDiscussionThread(
      id: doc.id,
      boardId: data['boardId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyCount: data['replyCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      isPinned: data['isPinned'] ?? false,
      isLocked: data['isLocked'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'boardId': boardId,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'replyCount': replyCount,
      'likeCount': likeCount,
      'isPinned': isPinned,
      'isLocked': isLocked,
    };
  }
}

/// Simplified discussion provider with direct Firestore access
class SimpleDiscussionProvider with ChangeNotifier {
  static const String _tag = 'SimpleDiscussionProvider';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SimpleDiscussionProvider() {
  SimpleDiscussionProvider._();

  /// Factory constructor to handle async initialization
  static Future<SimpleDiscussionProvider> create() async {
    final provider = SimpleDiscussionProvider._();
    await provider._loadUserModel();
    return provider;
  }
  
  /// Load and cache the user model for display name
  Future<void> _loadUserModel() async {
    try {
      final userId = currentUserId;
      if (userId.isEmpty) return;
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        _cachedUserModel = UserModel.fromFirestore(doc);
        _cachedDisplayName = _cachedUserModel.displayNameOrFallback;
        notifyListeners();
      }
    } catch (e) {
      LoggerService.error('Failed to load user model for display name', tag: _tag, error: e);
      // Fallback to Firebase Auth display name
      _cachedDisplayName = _auth.currentUser?.displayName ?? 'Unknown User';
    }
  }
  
  /// Clear cached user data (call on logout)
  void clearUserCache() {
    _cachedDisplayName = null;
    _cachedUserModel = null;
  }

  // State
  List<SimpleDiscussionBoard> _boards = [];
  final Map<String, List<SimpleDiscussionThread>> _boardThreads = {};
  SimpleDiscussionBoard? _currentBoard;
  SimpleDiscussionThread? _currentThread;
  bool _isLoading = false;
  String? _error;
  
  // Cache for user display name to avoid repeated Firestore calls
  // Addresses Copilot PR recommendation for performance optimization
  String? _cachedDisplayName;
  UserModel? _cachedUserModel;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _boardsSubscription;
  final Map<String, StreamSubscription<QuerySnapshot>> _threadSubscriptions = {};

  // Getters
  List<SimpleDiscussionBoard> get boards => _boards;
  SimpleDiscussionBoard? get currentBoard => _currentBoard;
  SimpleDiscussionThread? get currentThread => _currentThread;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentUserId => _auth.currentUser?.uid ?? '';
  
  /// Returns cached display name or fetches and caches it
  String get currentUserName {
    // Return cached name if available
    if (_cachedDisplayName != null) {
      return _cachedDisplayName!;
    }
    
    // Use UserModel extension for consistent display name logic
    _cachedDisplayName = _cachedUserModel.displayNameOrFallback;
    return _cachedDisplayName!;
  }

  List<SimpleDiscussionThread> getThreadsForBoard(String boardId) {
    return _boardThreads[boardId] ?? [];
  }

  /// Load all discussion boards
  Future<void> loadBoards() async {
    _setLoading(true);
    _error = null;
    
    try {
      // Cancel existing subscription
      await _boardsSubscription?.cancel();
      
      // Listen to boards collection
      _boardsSubscription = _firestore
          .collection('discussion_boards')
          .orderBy('isPinned', descending: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          LoggerService.debug('Loaded ${snapshot.docs.length} boards', tag: _tag);
          _boards = snapshot.docs
              .map((doc) {
                final board = SimpleDiscussionBoard.fromFirestore(doc);
                LoggerService.debug('Board loaded - ID: ${board.id}, Title: ${board.title}', tag: _tag);
                return board;
              })
              .toList();
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          LoggerService.error('Failed to load boards', tag: _tag, error: error);
          _error = 'Failed to load discussion boards';
          _setLoading(false);
          notifyListeners();
        },
      );
    } catch (e) {
      LoggerService.error('Failed to setup board listener', tag: _tag, error: e);
      _error = 'Failed to load discussion boards';
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Create a new discussion board (teacher only)
  Future<void> createBoard({
    required String title,
    required String description,
    List<String> tags = const [],
  }) async {
    _setLoading(true);
    _error = null;
    
    try {
      final board = SimpleDiscussionBoard(
        id: '', // Will be set by Firestore
        title: title,
        description: description,
        createdBy: currentUserId,
        createdAt: DateTime.now(),
        tags: tags,
      );

      await _firestore
          .collection('discussion_boards')
          .add(board.toFirestore());

      LoggerService.info('Created discussion board: $title', tag: _tag);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to create board', tag: _tag, error: e);
      _error = 'Failed to create discussion board';
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Load threads for a specific board
  Future<void> loadThreadsForBoard(String boardId) async {
    try {
      // Cancel existing subscription for this board
      await _threadSubscriptions[boardId]?.cancel();
      
      // Listen to threads subcollection
      _threadSubscriptions[boardId] = _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .orderBy('isPinned', descending: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          _boardThreads[boardId] = snapshot.docs
              .map((doc) => SimpleDiscussionThread.fromFirestore(doc))
              .toList();
          notifyListeners();
        },
        onError: (error) {
          LoggerService.error('Failed to load threads for board $boardId', 
              tag: _tag, error: error);
        },
      );
    } catch (e) {
      LoggerService.error('Failed to setup thread listener', tag: _tag, error: e);
    }
  }

  /// Create a new thread in a board (simplified - no count update)
  Future<void> createThread({
    required String boardId,
    required String title,
    required String content,
  }) async {
    _setLoading(true);
    _error = null;
    
    try {
      final thread = SimpleDiscussionThread(
        id: '', // Will be set by Firestore
        boardId: boardId,
        title: title,
        content: content,
        authorId: currentUserId,
        authorName: currentUserName,
        createdAt: DateTime.now(),
      );

      // Single write operation - no secondary updates
      await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .add(thread.toFirestore());

      LoggerService.info('Created thread in board $boardId', tag: _tag);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to create thread', tag: _tag, error: e);
      _error = 'Failed to create thread';
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  /// Select a board
  void selectBoard(SimpleDiscussionBoard board) {
    _currentBoard = board;
    // Don't load threads here - let the detail screen handle it
    notifyListeners();
  }

  /// Select a thread
  void selectThread(SimpleDiscussionThread thread) {
    _currentThread = thread;
    notifyListeners();
  }

  /// Clear current selections
  void clearSelection() {
    _currentBoard = null;
    _currentThread = null;
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Clean up resources
  @override
  void dispose() {
    _boardsSubscription?.cancel();
    for (var subscription in _threadSubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }
}