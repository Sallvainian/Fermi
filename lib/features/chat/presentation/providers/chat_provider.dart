/// Chat and messaging state management provider.
/// 
/// This module manages real-time chat functionality for the education
/// platform, handling direct messages, group chats, and class-based
/// discussions with comprehensive state management.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/message.dart';
import '../../domain/models/chat_room.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../shared/core/service_locator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Provider managing chat rooms and messages.
/// 
/// This provider serves as the central state manager for chat functionality,
/// coordinating real-time messaging features. Key capabilities:
/// - Direct and group chat management
/// - Real-time message streaming
/// - Read receipt tracking
/// - Message search functionality
/// - Chat room discovery and creation
/// - Automatic unread count management
/// 
/// Maintains active streams for chat rooms and messages with
/// automatic cleanup to prevent memory leaks.
class ChatProvider with ChangeNotifier {
  /// Repository for chat data operations.
  late final ChatRepository _chatRepository;
  
  /// Auth provider for user identification.
  late AuthProvider _authProvider;
  
  /// Creates chat provider with repository dependency.
  /// 
  /// Retrieves chat repository from dependency injection.
  /// Auth provider must be set separately via setAuthProvider.
  ChatProvider() {
    _chatRepository = getIt<ChatRepository>();
  }
  
  /// User's chat rooms list.
  List<ChatRoom> _chatRooms = [];
  
  /// Messages in current chat room.
  List<Message> _currentMessages = [];
  
  /// Currently active chat room.
  ChatRoom? _currentChatRoom;
  
  /// Loading state for async operations.
  bool _isLoading = false;
  
  /// Latest error message for UI display.
  String? _error;
  
  // Stream subscriptions
  
  /// Subscription for chat rooms list updates.
  StreamSubscription<List<ChatRoom>>? _chatRoomsSubscription;
  
  /// Subscription for current chat messages.
  StreamSubscription<List<Message>>? _messagesSubscription;
  
  /// Sets the authentication provider reference.
  /// 
  /// Required for user identification in chat operations.
  /// Must be called after provider initialization.
  /// 
  /// @param authProvider Authentication provider instance
  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  // Getters
  
  /// List of user's chat rooms.
  List<ChatRoom> get chatRooms => _chatRooms;
  
  /// Messages in active chat room.
  List<Message> get currentMessages => _currentMessages;
  
  /// Currently selected chat room or null.
  ChatRoom? get currentChatRoom => _currentChatRoom;
  
  /// Whether an operation is in progress.
  bool get isLoading => _isLoading;
  
  /// Latest error message or null.
  String? get error => _error;

  /// Initializes real-time chat room monitoring.
  /// 
  /// Sets up stream subscription for user's chat rooms,
  /// automatically updating when rooms are added/removed
  /// or when last messages change. Cancels any existing
  /// subscription before creating new one.
  void initializeChatRooms() {
    // Cancel existing subscription before creating new one
    _chatRoomsSubscription?.cancel();
    
    // Store the subscription
    _chatRoomsSubscription = _chatRepository.getUserChatRooms().listen(
      (rooms) {
        _chatRooms = rooms;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  /// Loads and subscribes to messages for a chat room.
  /// 
  /// Sets up real-time stream for message updates including
  /// new messages, edits, and deletions. Returns latest 100
  /// messages ordered by most recent first.
  /// 
  /// @param chatRoomId Chat room to load messages from
  void loadChatMessages(String chatRoomId) {
    // Cancel existing subscription before creating new one
    _messagesSubscription?.cancel();
    
    // Store the subscription
    _messagesSubscription = _chatRepository.getChatMessages(chatRoomId).listen(
      (messages) {
        _currentMessages = messages;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  /// Sets the active chat room and loads its messages.
  /// 
  /// Automatically:
  /// - Loads message history
  /// - Marks unread messages as read
  /// - Updates UI state
  /// 
  /// @param chatRoom Chat room to activate
  void setCurrentChatRoom(ChatRoom chatRoom) {
    _currentChatRoom = chatRoom;
    loadChatMessages(chatRoom.id);
    markMessagesAsRead(chatRoom.id);
    notifyListeners();
  }
  
  /// Retrieves a specific chat room by ID.
  /// 
  /// Fetches fresh data from repository for accuracy.
  /// 
  /// @param chatRoomId Chat room identifier
  /// @return Chat room instance or null if not found/error
  Future<ChatRoom?> getChatRoom(String chatRoomId) async {
    try {
      return await _chatRepository.getChatRoom(chatRoomId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Creates or retrieves existing direct chat.
  /// 
  /// Intelligent handling prevents duplicate direct chats:
  /// - Checks for existing chat between users
  /// - Returns existing if found
  /// - Creates new if none exists
  /// 
  /// Automatically loads messages and sets as current chat.
  /// 
  /// @param otherUserId ID of other participant
  /// @param otherUserName Display name of other user
  /// @param otherUserRole Role of other user
  /// @return Created or existing chat room
  /// @throws Exception if operation fails
  Future<ChatRoom> createOrGetDirectChat(
    String otherUserId,
    String otherUserName,
    String otherUserRole,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final chatRoom = await _chatRepository.createOrGetDirectChat(
        otherUserId,
        otherUserName,
        otherUserRole,
      );
      _currentChatRoom = chatRoom;
      loadChatMessages(chatRoom.id);
      return chatRoom;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new group chat room.
  /// 
  /// Supports different group types:
  /// - 'group': General purpose groups
  /// - 'class': Class-specific discussions
  /// - 'announcement': Broadcast channels
  /// 
  /// @param name Display name for the group
  /// @param type Group type identifier
  /// @param participantIds List of participant user IDs
  /// @param participants List of participant info objects
  /// @param classId Optional class association
  /// @return Created group chat room
  /// @throws Exception if creation fails
  Future<ChatRoom> createGroupChat({
    required String name,
    required String type,
    required List<String> participantIds,
    required List<ParticipantInfo> participants,
    String? classId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final chatRoom = await _chatRepository.createGroupChat(
        name: name,
        type: type,
        participantIds: participantIds,
        participants: participants,
        classId: classId,
      );
      return chatRoom;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a message to the current chat room.
  /// 
  /// Requires an active chat room to be set.
  /// Supports text messages and file attachments.
  /// Updates last message info and triggers real-time
  /// delivery to all participants.
  /// 
  /// @param content Message text content
  /// @param attachmentUrl Optional file attachment URL
  /// @param attachmentType Optional attachment MIME type
  /// @throws Exception if sending fails
  Future<void> sendMessage({
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    if (_currentChatRoom == null) {
      return;
    }

    try {
      await _chatRepository.sendMessage(
        chatRoomId: _currentChatRoom!.id,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Marks all unread messages in a chat as read.
  /// 
  /// Updates message statuses and resets unread count
  /// for the current user. Called automatically when
  /// entering a chat room.
  /// 
  /// @param chatRoomId Chat room to mark as read
  Future<void> markMessagesAsRead(String chatRoomId) async {
    try {
      await _chatRepository.markMessagesAsRead(chatRoomId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Deletes a message from the current chat.
  /// 
  /// Permanently removes the message. Consider implementing
  /// soft deletion for audit trails in production.
  /// 
  /// @param messageId Message to delete
  /// @throws Exception if deletion fails
  Future<void> deleteMessage(String messageId) async {
    if (_currentChatRoom == null) return;

    try {
      await _chatRepository.deleteMessage(_currentChatRoom!.id, messageId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Removes current user from a chat room.
  /// 
  /// For group chats, removes user from participants.
  /// If leaving current chat, clears active state.
  /// Direct chats typically cannot be left.
  /// 
  /// @param chatRoomId Chat room to leave
  /// @throws Exception if leaving fails
  Future<void> leaveChatRoom(String chatRoomId) async {
    try {
      await _chatRepository.leaveChatRoom(chatRoomId);
      if (_currentChatRoom?.id == chatRoomId) {
        _currentChatRoom = null;
        _currentMessages = [];
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Toggles mute status for notifications in a chat room.
  /// 
  /// Adds or removes current user from mutedUsers list.
  /// Updates Firestore directly assuming repository method.
  /// 
  /// @param chatRoomId Chat room to toggle mute for
  Future<void> toggleMute(String chatRoomId) async {
    final currentUserId = _authProvider.userModel?.uid;
    if (currentUserId == null) return;

    try {
      final chatRoom = await getChatRoom(chatRoomId);
      if (chatRoom == null) return;

      final mutedUsers = List<String>.from(chatRoom.mutedUsers);
      if (mutedUsers.contains(currentUserId)) {
        mutedUsers.remove(currentUserId);
      } else {
        mutedUsers.add(currentUserId);
      }

      // Assuming _chatRepository has updateChatRoom, or implement directly
      final updatedChatRoom = chatRoom.copyWith(mutedUsers: mutedUsers);
await _chatRepository.updateChatRoom(chatRoomId, updatedChatRoom);
final index = _chatRooms.indexWhere((room) => room.id == chatRoomId);
if (index != -1) {
  _chatRooms[index] = updatedChatRoom;
}

      // Update local state if current
      if (_currentChatRoom?.id == chatRoomId) {
        _currentChatRoom = chatRoom.copyWith(mutedUsers: mutedUsers);
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Legacy wrapper for chat room creation.
  /// 
  /// Converts map-based participant format to structured
  /// ParticipantInfo objects. Maintained for backward
  /// compatibility with older UI code.
  /// 
  /// @param name Chat room name
  /// @param type Chat room type
  /// @param participants Map of user ID to display name
  /// @param classId Optional class association
  /// @return Created chat room ID or null
  /// @deprecated Use createGroupChat instead
  Future<String?> createChatRoom({
    required String name,
    required String type,
    required Map<String, String> participants,
    String? classId,
  }) async {
    final participantIds = participants.keys.toList();
    final participantInfoList = participants.entries.map((entry) => 
      ParticipantInfo(
        id: entry.key,
        name: entry.value,
        role: 'user', // Default role, can be enhanced later
      )
    ).toList();
    
    final chatRoom = await createGroupChat(
      name: name,
      type: type,
      participantIds: participantIds,
      participants: participantInfoList,
      classId: classId,
    );
    return chatRoom.id;
  }

  /// Searches for existing direct chat with a user.
  /// 
  /// Two-phase search:
  /// 1. Checks locally cached chat rooms for performance
  /// 2. Falls back to repository search if not found
  /// 
  /// @param otherUserId Other participant's ID
  /// @return Existing chat room or null if none exists
  Future<ChatRoom?> findDirectChat(String otherUserId) async {
    try {
      final currentUserId = _authProvider.userModel?.uid;
      if (currentUserId == null) return null;

      // Check loaded chat rooms first
      for (final chatRoom in _chatRooms) {
        if (chatRoom.type == 'direct' &&
            chatRoom.participantIds.contains(currentUserId) &&
            chatRoom.participantIds.contains(otherUserId) &&
            chatRoom.participantIds.length == 2) {
          return chatRoom;
        }
      }

      // If not found in loaded rooms, use repository to find it
      return await _chatRepository.findDirectChat(currentUserId, otherUserId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Searches messages in current chat room.
  /// 
  /// Performs case-insensitive search through message content.
  /// Requires an active chat room. Current implementation
  /// searches client-side; consider server-side search for
  /// large message volumes.
  /// 
  /// @param query Search terms
  /// @return List of matching messages
  Future<List<Message>> searchMessages(String query) async {
    if (_currentChatRoom == null) return [];

    try {
      final results = await _chatRepository.searchMessages(
        _currentChatRoom!.id,
        query,
      );
      return results;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Clears the current chat selection.
  /// 
  /// Resets active chat room and message list.
  /// Useful when navigating away from chat views.
  void clearCurrentChat() {
    _currentChatRoom = null;
    _currentMessages = [];
    notifyListeners();
  }

  /// Cleans up resources when provider is disposed.
  /// 
  /// Cancels all stream subscriptions and disposes
  /// repository to prevent memory leaks.
  @override
  void dispose() {
    // Cancel all subscriptions
    _chatRoomsSubscription?.cancel();
    _messagesSubscription?.cancel();
    
    // Dispose repository
    _chatRepository.dispose();
    
    super.dispose();
  }
}