import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../models/chat_room.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();
  late AuthProvider _authProvider;
  
  List<ChatRoom> _chatRooms = [];
  List<Message> _currentMessages = [];
  ChatRoom? _currentChatRoom;
  bool _isLoading = false;
  String? _error;
  
  // Stream subscription objects to prevent memory leaks
  StreamSubscription<List<ChatRoom>>? _chatRoomsSubscription;
  StreamSubscription<List<Message>>? _messagesSubscription;
  
  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  // Getters
  List<ChatRoom> get chatRooms => _chatRooms;
  List<Message> get currentMessages => _currentMessages;
  ChatRoom? get currentChatRoom => _currentChatRoom;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize chat rooms stream
  void initializeChatRooms() {
    // Cancel existing subscription before creating new one
    _chatRoomsSubscription?.cancel();
    
    // Store the subscription
    _chatRoomsSubscription = _chatService.getUserChatRooms().listen(
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

  // Load messages for a specific chat room
  void loadChatMessages(String chatRoomId) {
    // Cancel existing subscription before creating new one
    _messagesSubscription?.cancel();
    
    // Store the subscription
    _messagesSubscription = _chatService.getChatMessages(chatRoomId).listen(
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

  // Set current chat room
  void setCurrentChatRoom(ChatRoom chatRoom) {
    _currentChatRoom = chatRoom;
    loadChatMessages(chatRoom.id);
    markMessagesAsRead(chatRoom.id);
    notifyListeners();
  }

  // Create or get direct chat
  Future<ChatRoom> createOrGetDirectChat(
    String otherUserId,
    String otherUserName,
    String otherUserRole,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final chatRoom = await _chatService.createOrGetDirectChat(
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

  // Create group chat
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
      final chatRoom = await _chatService.createGroupChat(
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

  // Send message
  Future<void> sendMessage({
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    if (_currentChatRoom == null) return;

    try {
      await _chatService.sendMessage(
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

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId) async {
    try {
      await _chatService.markMessagesAsRead(chatRoomId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    if (_currentChatRoom == null) return;

    try {
      await _chatService.deleteMessage(_currentChatRoom!.id, messageId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Leave chat room
  Future<void> leaveChatRoom(String chatRoomId) async {
    try {
      await _chatService.leaveChatRoom(chatRoomId);
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

  // Create chat room (wrapper for compatibility)
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

  // Find existing direct chat with a user
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

      // If not found in loaded rooms, query Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('type', isEqualTo: 'direct')
          .where('participantIds', arrayContains: currentUserId)
          .get();

      for (final doc in querySnapshot.docs) {
        final chatRoom = ChatRoom.fromFirestore(doc);
        if (chatRoom.participantIds.contains(otherUserId) &&
            chatRoom.participantIds.length == 2) {
          return chatRoom;
        }
      }

      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Search messages
  Future<List<Message>> searchMessages(String query) async {
    if (_currentChatRoom == null) return [];

    try {
      final results = await _chatService.searchMessages(
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

  // Clear current chat
  void clearCurrentChat() {
    _currentChatRoom = null;
    _currentMessages = [];
    notifyListeners();
  }

  // Clean up
  @override
  void dispose() {
    // Cancel all subscriptions
    _chatRoomsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}