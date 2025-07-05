/// Discussion board models for educational forum functionality.
/// 
/// This module contains data models for discussion boards, threads,
/// and replies, enabling structured academic discussions within the
/// education platform.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Core discussion board model representing a forum category.
/// 
/// Discussion boards serve as top-level containers for organizing
/// academic discussions by topic, class, or subject area. Features:
/// - Class-specific or general discussion areas
/// - Thread counting for activity tracking
/// - Pinning capability for important boards
/// - Tag support for content categorization
/// - Participant tracking for access control
class DiscussionBoard {
  /// Unique identifier for the discussion board
  final String id;
  
  /// Board title displayed in listings
  final String title;
  
  /// Detailed description of board purpose and guidelines
  final String description;
  
  /// User ID of the board creator
  final String createdBy;
  
  /// Cached name of the board creator for display
  final String createdByName;
  
  /// Optional class ID for class-specific boards
  final String? classId;
  
  /// List of user IDs allowed to participate
  final List<String> participantIds;
  
  /// Timestamp when the board was created
  final DateTime createdAt;
  
  /// Timestamp of last activity or modification
  final DateTime updatedAt;
  
  /// Number of threads in this board
  final int threadCount;
  
  /// Whether this board is pinned to top of listings
  final bool isPinned;
  
  /// Tags for categorizing board content
  final List<String> tags;

  DiscussionBoard({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdByName,
    this.classId,
    required this.participantIds,
    required this.createdAt,
    required this.updatedAt,
    this.threadCount = 0,
    this.isPinned = false,
    this.tags = const [],
  });

  /// Factory constructor to create DiscussionBoard from Firestore document.
  /// 
  /// Handles data parsing with safe defaults including:
  /// - Timestamp conversions for date fields
  /// - List casting for participant IDs and tags
  /// - Default values for counts and flags
  /// - Null safety for optional fields
  /// 
  /// @param doc Firestore document snapshot containing board data
  /// @return Parsed DiscussionBoard instance
  factory DiscussionBoard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DiscussionBoard(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      classId: data['classId'],
      participantIds: List<String>.from(data['participantIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      threadCount: data['threadCount'] ?? 0,
      isPinned: data['isPinned'] ?? false,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  /// Converts the DiscussionBoard instance to a Map for Firestore storage.
  /// 
  /// Serializes all board data including:
  /// - DateTime fields to Firestore Timestamps
  /// - Direct storage of lists and primitive types
  /// - Preservation of null values for optional fields
  /// 
  /// @return Map containing all board data for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'classId': classId,
      'participantIds': participantIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'threadCount': threadCount,
      'isPinned': isPinned,
      'tags': tags,
    };
  }

  /// Creates a copy of the DiscussionBoard with updated fields.
  /// 
  /// Follows immutable data pattern for state management.
  /// Useful for:
  /// - Updating board metadata
  /// - Managing participant lists
  /// - Toggling pin status
  /// - Updating thread counts
  /// 
  /// All parameters are optional - only provided fields will be updated.
  /// 
  /// @return New DiscussionBoard instance with updated fields
  DiscussionBoard copyWith({
    String? id,
    String? title,
    String? description,
    String? createdBy,
    String? createdByName,
    String? classId,
    List<String>? participantIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? threadCount,
    bool? isPinned,
    List<String>? tags,
  }) {
    return DiscussionBoard(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      classId: classId ?? this.classId,
      participantIds: participantIds ?? this.participantIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      threadCount: threadCount ?? this.threadCount,
      isPinned: isPinned ?? this.isPinned,
      tags: tags ?? this.tags,
    );
  }
}

/// Discussion thread model representing individual topics within boards.
/// 
/// Threads are the primary discussion units where users post topics
/// and engage in conversations. Features include:
/// - Author tracking with role information
/// - Reply and engagement counters
/// - Like/reaction support
/// - Thread locking for moderation
/// - Pinning for important discussions
/// - Tag support for categorization
class DiscussionThread {
  /// Unique identifier for the thread
  final String id;
  
  /// ID of the parent discussion board
  final String boardId;
  
  /// Thread title/subject
  final String title;
  
  /// Main content/body of the thread post
  final String content;
  
  /// User ID of the thread author
  final String authorId;
  
  /// Cached name of the thread author
  final String authorName;
  
  /// Role of the author (teacher/student)
  final String authorRole;
  
  /// Timestamp when the thread was created
  final DateTime createdAt;
  
  /// Timestamp of last activity (new reply or edit)
  final DateTime updatedAt;
  
  /// Number of replies to this thread
  final int replyCount;
  
  /// Number of likes/reactions
  final int likeCount;
  
  /// List of user IDs who liked this thread
  final List<String> likedBy;
  
  /// Whether this thread is pinned to top
  final bool isPinned;
  
  /// Whether new replies are disabled
  final bool isLocked;
  
  /// Tags for categorizing thread content
  final List<String> tags;

  DiscussionThread({
    required this.id,
    required this.boardId,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    required this.updatedAt,
    this.replyCount = 0,
    this.likeCount = 0,
    this.likedBy = const [],
    this.isPinned = false,
    this.isLocked = false,
    this.tags = const [],
  });

  /// Factory constructor to create DiscussionThread from Firestore document.
  /// 
  /// Handles data parsing with comprehensive defaults:
  /// - Timestamp conversions for date fields
  /// - Safe list casting for likedBy and tags
  /// - Default values for counters and flags
  /// - Author information caching
  /// 
  /// @param doc Firestore document snapshot containing thread data
  /// @return Parsed DiscussionThread instance
  factory DiscussionThread.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DiscussionThread(
      id: doc.id,
      boardId: data['boardId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorRole: data['authorRole'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      replyCount: data['replyCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      isPinned: data['isPinned'] ?? false,
      isLocked: data['isLocked'] ?? false,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  /// Converts the DiscussionThread instance to a Map for Firestore storage.
  /// 
  /// Serializes all thread data including:
  /// - DateTime fields to Firestore Timestamps
  /// - Lists and engagement data
  /// - Boolean flags for thread state
  /// 
  /// @return Map containing all thread data for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'boardId': boardId,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'replyCount': replyCount,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'isPinned': isPinned,
      'isLocked': isLocked,
      'tags': tags,
    };
  }

  /// Creates a copy of the DiscussionThread with updated fields.
  /// 
  /// Follows immutable data pattern for state management.
  /// Useful for:
  /// - Updating engagement counters
  /// - Managing like states
  /// - Toggling pin/lock status
  /// - Editing thread content
  /// 
  /// All parameters are optional - only provided fields will be updated.
  /// 
  /// @return New DiscussionThread instance with updated fields
  DiscussionThread copyWith({
    String? id,
    String? boardId,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    String? authorRole,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? replyCount,
    int? likeCount,
    List<String>? likedBy,
    bool? isPinned,
    bool? isLocked,
    List<String>? tags,
  }) {
    return DiscussionThread(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      replyCount: replyCount ?? this.replyCount,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      tags: tags ?? this.tags,
    );
  }
}

/// Reply model for thread responses and nested discussions.
/// 
/// Replies represent individual responses within discussion threads,
/// supporting nested conversations and engagement tracking. Features:
/// - Nested reply support (reply to specific comments)
/// - Edit tracking with timestamps
/// - Like/reaction functionality
/// - Author role preservation
/// - Content moderation capabilities
class ThreadReply {
  /// Unique identifier for the reply
  final String id;
  
  /// ID of the parent thread
  final String threadId;
  
  /// Reply content/message
  final String content;
  
  /// User ID of the reply author
  final String authorId;
  
  /// Cached name of the reply author
  final String authorName;
  
  /// Role of the author (teacher/student)
  final String authorRole;
  
  /// Timestamp when the reply was posted
  final DateTime createdAt;
  
  /// Whether the reply has been edited
  final bool isEdited;
  
  /// Timestamp of last edit (null if never edited)
  final DateTime? editedAt;
  
  /// Number of likes/reactions
  final int likeCount;
  
  /// List of user IDs who liked this reply
  final List<String> likedBy;
  
  /// ID of the reply being responded to (for nested replies)
  final String? replyToId;
  
  /// Cached author name of the reply being responded to
  final String? replyToAuthor;

  ThreadReply({
    required this.id,
    required this.threadId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    this.isEdited = false,
    this.editedAt,
    this.likeCount = 0,
    this.likedBy = const [],
    this.replyToId,
    this.replyToAuthor,
  });

  /// Factory constructor to create ThreadReply from Firestore document.
  /// 
  /// Handles data parsing including:
  /// - Timestamp conversions with null safety
  /// - Edit tracking field management
  /// - Nested reply reference preservation
  /// - Engagement data casting
  /// 
  /// @param doc Firestore document snapshot containing reply data
  /// @return Parsed ThreadReply instance
  factory ThreadReply.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ThreadReply(
      id: doc.id,
      threadId: data['threadId'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorRole: data['authorRole'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isEdited: data['isEdited'] ?? false,
      editedAt: data['editedAt'] != null 
          ? (data['editedAt'] as Timestamp).toDate() 
          : null,
      likeCount: data['likeCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      replyToId: data['replyToId'],
      replyToAuthor: data['replyToAuthor'],
    );
  }

  /// Converts the ThreadReply instance to a Map for Firestore storage.
  /// 
  /// Serializes all reply data including:
  /// - DateTime fields to Firestore Timestamps
  /// - Edit tracking with conditional timestamp
  /// - Engagement and nested reply data
  /// 
  /// @return Map containing all reply data for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'threadId': threadId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'replyToId': replyToId,
      'replyToAuthor': replyToAuthor,
    };
  }

  /// Creates a copy of the ThreadReply with updated fields.
  /// 
  /// Follows immutable data pattern for state management.
  /// Useful for:
  /// - Marking replies as edited
  /// - Updating engagement counters
  /// - Managing like states
  /// - Updating content after edits
  /// 
  /// All parameters are optional - only provided fields will be updated.
  /// 
  /// @return New ThreadReply instance with updated fields
  ThreadReply copyWith({
    String? id,
    String? threadId,
    String? content,
    String? authorId,
    String? authorName,
    String? authorRole,
    DateTime? createdAt,
    bool? isEdited,
    DateTime? editedAt,
    int? likeCount,
    List<String>? likedBy,
    String? replyToId,
    String? replyToAuthor,
  }) {
    return ThreadReply(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      createdAt: createdAt ?? this.createdAt,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
      replyToId: replyToId ?? this.replyToId,
      replyToAuthor: replyToAuthor ?? this.replyToAuthor,
    );
  }
}