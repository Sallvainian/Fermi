/// Discussion repository interface for forum functionality.
///
/// This module defines the contract for discussion board operations
/// in the education platform, supporting threaded discussions,
/// replies, and community interaction features.
library;

import '../models/discussion_board.dart';

/// Abstract repository defining discussion board operations.
///
/// This interface provides a comprehensive contract for discussion
/// implementations, supporting:
/// - Discussion board creation and management
/// - Threaded conversation structure
/// - Reply chains with nested discussions
/// - Like/unlike functionality for engagement
/// - Pin and lock features for moderation
/// - Real-time streaming of discussions
/// - Search capabilities across boards and threads
///
/// Concrete implementations handle the actual forum
/// infrastructure and data persistence.
abstract class DiscussionRepository {
  // Board operations

  /// Creates a new discussion board.
  ///
  /// Initializes a board with title, description, and settings.
  /// Returns the generated board ID for reference.
  ///
  /// @param board Board model with configuration
  /// @return Generated unique board ID
  /// @throws Exception if creation fails
  Future<String> createBoard(DiscussionBoard board);

  /// Retrieves a discussion board by ID.
  ///
  /// Fetches complete board details including metadata
  /// and configuration. Returns null if not found.
  ///
  /// @param boardId Unique board identifier
  /// @return Board instance or null
  /// @throws Exception if retrieval fails
  Future<DiscussionBoard?> getBoard(String boardId);

  /// Retrieves all discussion boards.
  ///
  /// Fetches the complete list of boards, typically
  /// filtered by user permissions and visibility settings.
  ///
  /// @return List of accessible discussion boards
  /// @throws Exception if retrieval fails
  Future<List<DiscussionBoard>> getBoards();

  /// Updates discussion board information.
  ///
  /// Modifies board details such as title, description,
  /// or settings. Cannot change board type after creation.
  ///
  /// @param boardId Board to update
  /// @param board Updated board information
  /// @throws Exception if update fails
  Future<void> updateBoard(String boardId, DiscussionBoard board);

  /// Pins or unpins a discussion board.
  ///
  /// Pinned boards appear at the top of board lists
  /// for increased visibility and importance.
  ///
  /// @param boardId Board to pin/unpin
  /// @param isPinned Whether to pin the board
  /// @throws Exception if operation fails
  Future<void> pinBoard(String boardId, bool isPinned);

  // Thread operations

  /// Creates a new discussion thread in a board.
  ///
  /// Starts a new topic with title, content, and metadata.
  /// Returns the generated thread ID for reference.
  ///
  /// @param boardId Target board for the thread
  /// @param thread Thread model with content
  /// @return Generated unique thread ID
  /// @throws Exception if creation fails
  Future<String> createThread(String boardId, DiscussionThread thread);

  /// Retrieves a specific discussion thread.
  ///
  /// Fetches complete thread details including content,
  /// author info, and engagement metrics.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Unique thread identifier
  /// @return Thread instance or null if not found
  /// @throws Exception if retrieval fails
  Future<DiscussionThread?> getThread(String boardId, String threadId);

  /// Retrieves all threads in a discussion board.
  ///
  /// Fetches threads sorted by activity, creation date,
  /// or pinned status depending on board settings.
  ///
  /// @param boardId Board to get threads from
  /// @return List of discussion threads
  /// @throws Exception if retrieval fails
  Future<List<DiscussionThread>> getBoardThreads(String boardId);

  /// Updates thread information.
  ///
  /// Allows editing thread title or content. Typically
  /// restricted to thread author or moderators.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to update
  /// @param thread Updated thread information
  /// @throws Exception if update fails
  Future<void> updateThread(
      String boardId, String threadId, DiscussionThread thread);

  /// Deletes a discussion thread.
  ///
  /// Removes the thread and all associated replies.
  /// This operation cannot be undone.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to delete
  /// @throws Exception if deletion fails
  Future<void> deleteThread(String boardId, String threadId);

  /// Adds a like to a discussion thread.
  ///
  /// Records user engagement with the thread.
  /// Each user can only like a thread once.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to like
  /// @param userId User performing the like
  /// @throws Exception if like fails
  Future<void> likeThread(String boardId, String threadId, String userId);

  /// Removes a like from a discussion thread.
  ///
  /// Reverses a previous like action by the user.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to unlike
  /// @param userId User removing the like
  /// @throws Exception if unlike fails
  Future<void> unlikeThread(String boardId, String threadId, String userId);

  /// Pins or unpins a thread within a board.
  ///
  /// Pinned threads appear at the top of thread lists.
  /// Typically restricted to moderators.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to pin/unpin
  /// @param isPinned Whether to pin the thread
  /// @throws Exception if operation fails
  Future<void> pinThread(String boardId, String threadId, bool isPinned);

  /// Locks or unlocks a thread for replies.
  ///
  /// Locked threads prevent new replies but remain visible.
  /// Used for closing resolved discussions.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to lock/unlock
  /// @param isLocked Whether to lock the thread
  /// @throws Exception if operation fails
  Future<void> lockThread(String boardId, String threadId, bool isLocked);

  // Reply operations

  /// Creates a reply to a discussion thread.
  ///
  /// Adds a response to an ongoing discussion.
  /// Returns the generated reply ID.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to reply to
  /// @param reply Reply model with content
  /// @return Generated unique reply ID
  /// @throws Exception if creation fails
  Future<String> createReply(
      String boardId, String threadId, ThreadReply reply);

  /// Retrieves all replies for a thread.
  ///
  /// Fetches replies in chronological order with
  /// author information and engagement metrics.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to get replies for
  /// @return List of thread replies
  /// @throws Exception if retrieval fails
  Future<List<ThreadReply>> getThreadReplies(String boardId, String threadId);

  /// Updates reply content.
  ///
  /// Allows editing reply text. Typically restricted
  /// to reply author within a time window.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread containing the reply
  /// @param replyId Reply to update
  /// @param reply Updated reply information
  /// @throws Exception if update fails
  Future<void> updateReply(
      String boardId, String threadId, String replyId, ThreadReply reply);

  /// Deletes a reply from a thread.
  ///
  /// Removes the reply permanently. May show as
  /// "deleted" depending on implementation.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread containing the reply
  /// @param replyId Reply to delete
  /// @throws Exception if deletion fails
  Future<void> deleteReply(String boardId, String threadId, String replyId);

  /// Adds a like to a reply.
  ///
  /// Records user appreciation for a reply.
  /// Each user can only like a reply once.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread containing the reply
  /// @param replyId Reply to like
  /// @param userId User performing the like
  /// @throws Exception if like fails
  Future<void> likeReply(
      String boardId, String threadId, String replyId, String userId);

  /// Removes a like from a reply.
  ///
  /// Reverses a previous like action by the user.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread containing the reply
  /// @param replyId Reply to unlike
  /// @param userId User removing the like
  /// @throws Exception if unlike fails
  Future<void> unlikeReply(
      String boardId, String threadId, String replyId, String userId);

  // Stream operations

  /// Streams all discussion boards in real-time.
  ///
  /// Returns live updates when boards are created,
  /// updated, or deleted. Respects user permissions.
  ///
  /// @return Stream of discussion board lists
  Stream<List<DiscussionBoard>> streamBoards();

  /// Streams threads for a specific board.
  ///
  /// Returns real-time updates of threads including
  /// new posts, edits, and engagement changes.
  ///
  /// @param boardId Board to monitor
  /// @return Stream of thread lists
  Stream<List<DiscussionThread>> streamBoardThreads(String boardId);

  /// Streams replies for a specific thread.
  ///
  /// Returns real-time updates of replies including
  /// new responses, edits, and likes.
  ///
  /// @param boardId Board containing the thread
  /// @param threadId Thread to monitor
  /// @return Stream of reply lists
  Stream<List<ThreadReply>> streamThreadReplies(
      String boardId, String threadId);

  // Search operations

  /// Searches for threads across all boards.
  ///
  /// Performs text search on thread titles and content.
  /// Returns results ordered by relevance.
  ///
  /// @param query Search terms
  /// @return List of matching threads
  /// @throws Exception if search fails
  Future<List<DiscussionThread>> searchThreads(String query);

  /// Searches for threads within a specific board.
  ///
  /// Performs text search limited to a single board.
  /// Useful for focused topic searches.
  ///
  /// @param boardId Board to search within
  /// @param query Search terms
  /// @return List of matching threads
  /// @throws Exception if search fails
  Future<List<DiscussionThread>> searchBoardThreads(
      String boardId, String query);

  /// Disposes of repository resources.
  ///
  /// Cleans up streams, listeners, and connections.
  /// Should be called when repository is no longer needed.
  void dispose();
}
