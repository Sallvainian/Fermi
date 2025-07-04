import '../models/message.dart';
import '../models/chat_room.dart';
import 'base_repository.dart';

abstract class ChatRepository extends BaseRepository {
  // Chat room operations
  Future<String> createChatRoom(ChatRoom chatRoom);
  Future<ChatRoom?> getChatRoom(String id);
  Future<void> updateChatRoom(String id, ChatRoom chatRoom);
  Future<void> deleteChatRoom(String id);
  
  // Create or get direct chat
  Future<ChatRoom> createOrGetDirectChat(
    String otherUserId,
    String otherUserName,
    String otherUserRole,
  );
  
  // Create group chat
  Future<ChatRoom> createGroupChat({
    required String name,
    required String type,
    required List<String> participantIds,
    required List<ParticipantInfo> participants,
    String? classId,
  });
  
  // Message operations
  Future<String> sendMessage({
    required String chatRoomId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  });
  
  Future<void> deleteMessage(String chatRoomId, String messageId);
  Future<void> editMessage(String chatRoomId, String messageId, String newContent);
  
  // Streams
  Stream<List<ChatRoom>> getUserChatRooms();
  Stream<List<Message>> getChatMessages(String chatRoomId);
  
  // Chat room management
  Future<void> addParticipant(String chatRoomId, String userId, ParticipantInfo participantInfo);
  Future<void> removeParticipant(String chatRoomId, String userId);
  Future<void> leaveChatRoom(String chatRoomId);
  Future<void> updateLastMessage(String chatRoomId, Message message);
  
  // Message status
  Future<void> markMessagesAsRead(String chatRoomId);
  Future<void> markMessageAsDelivered(String chatRoomId, String messageId);
  
  // Search and query
  Future<List<Message>> searchMessages(String chatRoomId, String query);
  Future<List<ChatRoom>> searchChatRooms(String query);
  Future<ChatRoom?> findDirectChat(String userId1, String userId2);
  
  // Typing indicators
  Future<void> setTypingStatus(String chatRoomId, bool isTyping);
  Stream<Map<String, bool>> getTypingStatuses(String chatRoomId);
  
  // Unread counts
  Future<int> getUnreadCount(String chatRoomId);
  Future<Map<String, int>> getAllUnreadCounts();
  
  // Batch operations
  Future<void> batchDeleteMessages(String chatRoomId, List<String> messageIds);
  Future<void> batchUpdateMessageStatus(String chatRoomId, List<String> messageIds, MessageStatus status);
}