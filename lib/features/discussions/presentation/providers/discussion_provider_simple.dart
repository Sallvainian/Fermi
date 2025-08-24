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
  final bool isLikedByCurrentUser;

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
    this.isLikedByCurrentUser = false,
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

  // State variables
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
  DateTime? _cacheTimestamp;
  static const Duration _cacheTTL = Duration(minutes: 5);
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _boardsSubscription;
  final Map<String, StreamSubscription<QuerySnapshot>> _threadSubscriptions =
      {};

  // Default constructor for Provider
  SimpleDiscussionProvider();

  // Private constructor
  SimpleDiscussionProvider._();

  /// Factory constructor to handle async initialization
  static Future<SimpleDiscussionProvider> create() async {
    final provider = SimpleDiscussionProvider._();
    await provider._loadUserModel();
    return provider;
  }

  // Getters
  List<SimpleDiscussionBoard> get boards => _boards;
  SimpleDiscussionBoard? get currentBoard => _currentBoard;
  SimpleDiscussionThread? get currentThread => _currentThread;
  bool get isLoading => _isLoading;
  String? get error => _error;
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

  /// Returns cached display name or fetches and caches it
  String get currentUserName {
    // Check if cache is still valid
    if (_cachedDisplayName != null && 
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTTL) {
      return _cachedDisplayName!;
    }

    // Use UserModel extension for consistent display name logic
    if (_cachedUserModel != null) {
      _cachedDisplayName = _cachedUserModel!.displayNameOrFallback;
      _cacheTimestamp = DateTime.now();
      return _cachedDisplayName!;
    }

    // Fallback to Firebase Auth display name with extension
    final user = _auth.currentUser;
    if (user != null) {
      // Create a temporary UserModel from Firebase Auth user
      final tempUser = UserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
      );
      _cachedDisplayName = tempUser.displayNameOrFallback;
      _cacheTimestamp = DateTime.now();
      return _cachedDisplayName!;
    }
    
    return 'Unknown User';
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Load and cache the user model for display name
  Future<void> _loadUserModel() async {
    try {
      final userId = currentUserId;
      if (userId.isEmpty) return;

      // Cancel existing subscription
      await _userDocSubscription?.cancel();
      
      // Listen to user document changes for cache invalidation
      _userDocSubscription = _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.exists) {
            _cachedUserModel = UserModel.fromFirestore(snapshot);
            _cachedDisplayName = _cachedUserModel!.displayNameOrFallback;
            _cacheTimestamp = DateTime.now();
            notifyListeners();
          }
        },
        onError: (error) {
          LoggerService.error('Failed to listen to user document',
              tag: _tag, error: error);
          // Fallback to Firebase Auth display name
          final user = _auth.currentUser;
          if (user != null) {
            final tempUser = UserModel(
              uid: user.uid,
              email: user.email,
              displayName: user.displayName,
            );
            _cachedDisplayName = tempUser.displayNameOrFallback;
            _cacheTimestamp = DateTime.now();
          }
        },
      );
    } catch (e) {
      LoggerService.error('Failed to load user model for display name',
          tag: _tag, error: e);
      // Fallback to Firebase Auth display name
      final user = _auth.currentUser;
      if (user != null) {
        final tempUser = UserModel(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
        );
        _cachedDisplayName = tempUser.displayNameOrFallback;
        _cacheTimestamp = DateTime.now();
      }
    }
  }

  /// Clear cached user data (call on logout)
  void clearUserCache() {
    _cachedDisplayName = null;
    _cachedUserModel = null;
    _cacheTimestamp = null;
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
  }

  List<SimpleDiscussionThread> getThreadsForBoard(String boardId) {
    return _boardThreads[boardId] ?? [];
  }

  /// Initialize boards (alias for loadBoards for compatibility)
  Future<void> initializeBoards() async {
    await loadBoards();
  }
  
  /// Load all discussion boards
  Future<void> loadBoards() async {
    _setLoading(true);
    _error = null;
    
    // Fetch user role first
    await _fetchUserRole();

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
        (snapshot) async {
          LoggerService.debug('Loaded ${snapshot.docs.length} boards',
              tag: _tag);
          
          // Load boards and resolve user IDs to display names
          final boardsList = <SimpleDiscussionBoard>[];
          
          for (final doc in snapshot.docs) {
            var board = SimpleDiscussionBoard.fromFirestore(doc);
            
            // Check if createdBy looks like a user ID (typically 28 chars)
            if (board.createdBy.length == 28 && !board.createdBy.contains(' ')) {
              // Try to resolve user ID to display name
              try {
                final userDoc = await _firestore
                    .collection('users')
                    .doc(board.createdBy)
                    .get();
                    
                if (userDoc.exists) {
                  final userData = userDoc.data();
                  if (userData != null) {
                    String displayName = board.createdBy; // Keep ID as fallback
                    
                    // Try firstName + lastName first
                    final firstName = userData['firstName'] as String?;
                    final lastName = userData['lastName'] as String?;
                    if (firstName != null && lastName != null) {
                      displayName = '$firstName $lastName'.trim();
                    } else if (userData['displayName'] != null) {
                      displayName = userData['displayName'] as String;
                    } else if (userData['email'] != null) {
                      final email = userData['email'] as String;
                      displayName = email.split('@').first;
                    }
                    
                    // Create new board with resolved display name
                    board = SimpleDiscussionBoard(
                      id: board.id,
                      title: board.title,
                      description: board.description,
                      createdBy: displayName,
                      createdAt: board.createdAt,
                      threadCount: board.threadCount,
                      isPinned: board.isPinned,
                      tags: board.tags,
                    );
                  }
                }
              } catch (e) {
                LoggerService.debug('Failed to resolve user name for board ${board.id}',
                    tag: _tag);
              }
            }
            
            LoggerService.debug(
                'Board loaded - ID: ${board.id}, Title: ${board.title}',
                tag: _tag);
            boardsList.add(board);
          }
          
          _boards = boardsList;
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
      LoggerService.error('Failed to setup board listener',
          tag: _tag, error: e);
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
      // Get the display name instead of user ID
      final displayName = await _getCurrentUserDisplayName();
      
      final board = SimpleDiscussionBoard(
        id: '', // Will be set by Firestore
        title: title,
        description: description,
        createdBy: displayName,
        createdAt: DateTime.now(),
        tags: tags,
        threadCount: 0, // Initialize with 0
      );

      await _firestore.collection('discussion_boards').add(board.toFirestore());

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
          // Simple load first, then check likes asynchronously
          _boardThreads[boardId] = snapshot.docs
              .map((doc) => SimpleDiscussionThread.fromFirestore(doc))
              .toList();
          notifyListeners();
          
          // Then update with like status
          _updateThreadLikes(boardId, snapshot.docs);
        },
        onError: (error) {
          LoggerService.error('Failed to load threads for board $boardId',
              tag: _tag, error: error);
        },
      );
    } catch (e) {
      LoggerService.error('Failed to setup thread listener',
          tag: _tag, error: e);
    }
  }

  /// Helper method to get the current user's display name from Firestore
  Future<String> _getCurrentUserDisplayName() async {
    try {
      final userId = currentUserId;
      if (userId.isEmpty) return 'Unknown User';

      // Try to get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          // Try firstName + lastName first
          final firstName = data['firstName'] as String?;
          final lastName = data['lastName'] as String?;
          if (firstName != null && lastName != null) {
            return '$firstName $lastName'.trim();
          }
          // Then try displayName
          final displayName = data['displayName'] as String?;
          if (displayName != null && displayName.isNotEmpty) {
            return displayName;
          }
          // Fallback to email prefix
          final email = data['email'] as String?;
          if (email != null && email.isNotEmpty) {
            return email.split('@').first;
          }
        }
      }

      // Fallback to Firebase Auth displayName
      return _auth.currentUser?.displayName ?? 'Unknown User';
    } catch (e) {
      LoggerService.error('Failed to get user display name',
          tag: _tag, error: e);
      return _auth.currentUser?.displayName ?? 'Unknown User';
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
      // Get the proper user display name
      final authorName = await _getCurrentUserDisplayName();

      final thread = SimpleDiscussionThread(
        id: '', // Will be set by Firestore
        boardId: boardId,
        title: title,
        content: content,
        authorId: currentUserId,
        authorName: authorName,
        createdAt: DateTime.now(),
      );

      // Add the thread
      await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .add(thread.toFirestore());

      // Update the thread count on the board
      await _firestore
          .collection('discussion_boards')
          .doc(boardId)
          .update({
        'threadCount': FieldValue.increment(1),
      });

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

  /// Update thread like status for current user
  Future<void> _updateThreadLikes(String boardId, List<QueryDocumentSnapshot> threadDocs) async {
    try {
      final userId = currentUserId;
      if (userId.isEmpty) return;
      
      // Create a list to hold updated threads
      final updatedThreads = <SimpleDiscussionThread>[];
      
      for (final doc in threadDocs) {
        var thread = SimpleDiscussionThread.fromFirestore(doc);
        
        // Check if current user has liked this thread
        try {
          final likeDoc = await _firestore
              .collection('discussion_boards')
              .doc(boardId)
              .collection('threads')
              .doc(thread.id)
              .collection('likes')
              .doc(userId)
              .get();
          
          // Create a new thread with updated like status
          thread = SimpleDiscussionThread(
            id: thread.id,
            boardId: thread.boardId,
            title: thread.title,
            content: thread.content,
            authorId: thread.authorId,
            authorName: thread.authorName,
            createdAt: thread.createdAt,
            replyCount: thread.replyCount,
            likeCount: thread.likeCount,
            isPinned: thread.isPinned,
            isLocked: thread.isLocked,
            isLikedByCurrentUser: likeDoc.exists,
          );
        } catch (e) {
          LoggerService.debug('Failed to check like status for thread ${thread.id}: $e', 
              tag: _tag);
        }
        
        updatedThreads.add(thread);
      }
      
      // Update the threads list with like status
      _boardThreads[boardId] = updatedThreads;
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to update thread likes', tag: _tag, error: e);
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    _boardsSubscription?.cancel();
    _userDocSubscription?.cancel();
    for (var subscription in _threadSubscriptions.values) {
      subscription.cancel();
    }
    clearUserCache();
    super.dispose();
  }
}
