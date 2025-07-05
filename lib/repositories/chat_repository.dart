/// Chat repository interface for messaging functionality.
/// 
/// This module defines the contract for chat operations in the
/// education platform, supporting real-time messaging between
/// teachers, students, and parents.
library;

import '../models/message.dart';
import '../models/chat_room.dart';
import 'base_repository.dart';

/// Abstract repository defining chat and messaging operations.
/// 
/// This interface provides a comprehensive contract for chat
/// implementations, supporting:
/// - Chat room creation and management
/// - Real-time message sending and receiving
/// - Direct and group chat functionality
/// - Message status tracking and read receipts
/// - Typing indicators and presence
/// - Search capabilities
/// - Unread message counting
/// - Batch operations for efficiency
/// 
/// Concrete implementations handle the actual messaging
/// infrastructure and real-time synchronization.
abstract class ChatRepository extends BaseRepository {
  // Chat room operations
  
  /// Creates a new chat room.
  /// 
  /// Initializes a chat room with participants and settings.
  /// Returns the generated chat room ID.
  /// 
  /// @param chatRoom Chat room model to create
  /// @return Generated chat room ID
  /// @throws Exception if creation fails
  Future<String> createChatRoom(ChatRoom chatRoom);
  
  /// Retrieves a chat room by ID.
  /// 
  /// Fetches complete chat room details including participants
  /// and metadata. Returns null if not found.
  /// 
  /// @param id Chat room identifier
  /// @return Chat room instance or null
  /// @throws Exception if retrieval fails
  Future<ChatRoom?> getChatRoom(String id);
  
  /// Updates chat room information.
  /// 
  /// Modifies chat room details such as name, participants,
  /// or settings. Cannot change room type after creation.
  /// 
  /// @param id Chat room identifier
  /// @param chatRoom Updated chat room model
  /// @throws Exception if update fails
  Future<void> updateChatRoom(String id, ChatRoom chatRoom);
  
  /// Deletes a chat room and all messages.
  /// 
  /// Permanently removes the chat room and message history.
  /// This operation cannot be undone.
  /// 
  /// @param id Chat room identifier
  /// @throws Exception if deletion fails
  Future<void> deleteChatRoom(String id);
  
  // Create or get direct chat
  
  /// Creates or retrieves a direct chat between two users.
  /// 
  /// If a direct chat already exists between the current user
  /// and the specified user, returns the existing chat room.
  /// Otherwise, creates a new direct chat room.
  /// 
  /// @param otherUserId ID of the other participant
  /// @param otherUserName Display name of the other user
  /// @param otherUserRole Role of the other user
  /// @return Created or existing chat room
  /// @throws Exception if operation fails
  Future<ChatRoom> createOrGetDirectChat(
    String otherUserId,
    String otherUserName,
    String otherUserRole,
  );
  
  // Create group chat
  
  /// Creates a new group chat room.
  /// 
  /// Initializes a group chat with multiple participants.
  /// Can be class-specific or general purpose group.
  /// 
  /// @param name Display name for the group
  /// @param type Chat room type (group/class/announcement)
  /// @param participantIds List of user IDs to include
  /// @param participants Detailed participant information
  /// @param classId Optional class association
  /// @return Created group chat room
  /// @throws Exception if creation fails
  Future<ChatRoom> createGroupChat({
    required String name,
    required String type,
    required List<String> participantIds,
    required List<ParticipantInfo> participants,
    String? classId,
  });
  
  // Message operations
  
  /// Sends a message to a chat room.
  /// 
  /// Creates and delivers a message with optional attachments.
  /// Updates last message and unread counts automatically.
  /// 
  /// @param chatRoomId Target chat room ID
  /// @param content Message text content
  /// @param attachmentUrl Optional file attachment URL
  /// @param attachmentType Optional attachment MIME type
  /// @return Generated message ID
  /// @throws Exception if sending fails
  Future<String> sendMessage({
    required String chatRoomId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  });
  
  /// Deletes a message from a chat room.
  /// 
  /// Removes the message for all participants. May show
  /// as "deleted message" depending on implementation.
  /// 
  /// @param chatRoomId Chat room containing the message
  /// @param messageId Message to delete
  /// @throws Exception if deletion fails
  Future<void> deleteMessage(String chatRoomId, String messageId);
  
  /// Edits an existing message.
  /// 
  /// Updates message content and marks as edited with
  /// timestamp. Original sender only can edit.
  /// 
  /// @param chatRoomId Chat room containing the message
  /// @param messageId Message to edit
  /// @param newContent Updated message content
  /// @throws Exception if edit fails
  Future<void> editMessage(String chatRoomId, String messageId, String newContent);
  
  // Streams
  
  /// Streams chat rooms for the current user.
  /// 
  /// Returns real-time updates of all chat rooms where
  /// the user is a participant. Includes unread counts
  /// and last message information.
  /// 
  /// @return Stream of user's chat room lists
  Stream<List<ChatRoom>> getUserChatRooms();
  
  /// Streams messages for a specific chat room.
  /// 
  /// Returns real-time message updates ordered by timestamp.
  /// Includes new messages, edits, and deletions.
  /// 
  /// @param chatRoomId Chat room to monitor
  /// @return Stream of message lists
  Stream<List<Message>> getChatMessages(String chatRoomId);
  
  // Chat room management
  
  /// Adds a participant to a group chat.
  /// 
  /// Only admins can add participants to existing groups.
  /// Updates participant list and sends system message.
  /// 
  /// @param chatRoomId Target chat room
  /// @param userId User to add
  /// @param participantInfo User's participant details
  /// @throws Exception if addition fails
  Future<void> addParticipant(String chatRoomId, String userId, ParticipantInfo participantInfo);
  
  /// Removes a participant from a group chat.
  /// 
  /// Only admins can remove other participants.
  /// Sends system message about removal.
  /// 
  /// @param chatRoomId Target chat room
  /// @param userId User to remove
  /// @throws Exception if removal fails
  Future<void> removeParticipant(String chatRoomId, String userId);
  
  /// Leaves a chat room.
  /// 
  /// Current user voluntarily exits the chat room.
  /// Cannot leave direct chats, only groups.
  /// 
  /// @param chatRoomId Chat room to leave
  /// @throws Exception if leaving fails
  Future<void> leaveChatRoom(String chatRoomId);
  
  /// Updates the last message in a chat room.
  /// 
  /// Internal method to maintain chat room metadata.
  /// Called automatically when messages are sent.
  /// 
  /// @param chatRoomId Chat room to update
  /// @param message Latest message
  /// @throws Exception if update fails
  Future<void> updateLastMessage(String chatRoomId, Message message);
  
  // Message status
  
  /// Marks all messages in a chat as read.
  /// 
  /// Updates read status for all unread messages from
  /// other participants. Resets unread count to zero.
  /// 
  /// @param chatRoomId Chat room to mark as read
  /// @throws Exception if marking fails
  Future<void> markMessagesAsRead(String chatRoomId);
  
  /// Marks a specific message as delivered.
  /// 
  /// Updates delivery status when message reaches recipient.
  /// Usually called automatically by the messaging system.
  /// 
  /// @param chatRoomId Chat room containing message
  /// @param messageId Message to mark delivered
  /// @throws Exception if update fails
  Future<void> markMessageAsDelivered(String chatRoomId, String messageId);
  
  // Search and query
  
  /// Searches messages within a chat room.
  /// 
  /// Performs text search on message content.
  /// Returns matching messages ordered by relevance.
  /// 
  /// @param chatRoomId Chat room to search
  /// @param query Search terms
  /// @return List of matching messages
  /// @throws Exception if search fails
  Future<List<Message>> searchMessages(String chatRoomId, String query);
  
  /// Searches across all user's chat rooms.
  /// 
  /// Searches chat room names and participant names.
  /// Useful for finding specific conversations.
  /// 
  /// @param query Search terms
  /// @return List of matching chat rooms
  /// @throws Exception if search fails
  Future<List<ChatRoom>> searchChatRooms(String query);
  
  /// Finds existing direct chat between two users.
  /// 
  /// Checks if a direct chat exists between specified users.
  /// Order of user IDs doesn't matter.
  /// 
  /// @param userId1 First user ID
  /// @param userId2 Second user ID
  /// @return Existing chat room or null
  /// @throws Exception if search fails
  Future<ChatRoom?> findDirectChat(String userId1, String userId2);
  
  // Typing indicators
  
  /// Sets typing status for current user.
  /// 
  /// Updates real-time typing indicator shown to other
  /// participants. Should be called on text input changes.
  /// 
  /// @param chatRoomId Chat room where typing
  /// @param isTyping Whether user is currently typing
  /// @throws Exception if update fails
  Future<void> setTypingStatus(String chatRoomId, bool isTyping);
  
  /// Streams typing statuses for a chat room.
  /// 
  /// Returns real-time updates of which users are typing.
  /// Map keys are user IDs, values are typing status.
  /// 
  /// @param chatRoomId Chat room to monitor
  /// @return Stream of typing status maps
  Stream<Map<String, bool>> getTypingStatuses(String chatRoomId);
  
  // Unread counts
  
  /// Gets unread message count for a chat room.
  /// 
  /// Returns number of messages received since last read.
  /// Used for notification badges.
  /// 
  /// @param chatRoomId Chat room to check
  /// @return Number of unread messages
  /// @throws Exception if count fails
  Future<int> getUnreadCount(String chatRoomId);
  
  /// Gets unread counts for all user's chats.
  /// 
  /// Returns map of chat room IDs to unread counts.
  /// Efficient way to get all badges at once.
  /// 
  /// @return Map of chat room IDs to unread counts
  /// @throws Exception if retrieval fails
  Future<Map<String, int>> getAllUnreadCounts();
  
  // Batch operations
  
  /// Deletes multiple messages in one operation.
  /// 
  /// Efficiently removes multiple messages using batch writes.
  /// All deletions succeed or fail together.
  /// 
  /// @param chatRoomId Chat room containing messages
  /// @param messageIds List of messages to delete
  /// @throws Exception if batch deletion fails
  Future<void> batchDeleteMessages(String chatRoomId, List<String> messageIds);
  
  /// Updates status for multiple messages.
  /// 
  /// Batch updates message status (delivered/read) for efficiency.
  /// Commonly used when marking multiple messages as read.
  /// 
  /// @param chatRoomId Chat room containing messages
  /// @param messageIds List of messages to update
  /// @param status New status to apply
  /// @throws Exception if batch update fails
  Future<void> batchUpdateMessageStatus(String chatRoomId, List<String> messageIds, MessageStatus status);
}