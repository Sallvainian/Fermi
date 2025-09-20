import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/services/logger_service.dart';

/// Simplified chat provider using direct Firestore access
class SimpleChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _chatRooms = [];
  List<Map<String, dynamic>> _currentMessages = [];
  Map<String, dynamic>? _currentChatRoom;
  bool _isLoading = false;
  String? _error;

  StreamSubscription<QuerySnapshot>? _chatRoomsSubscription;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  // Getters
  List<Map<String, dynamic>> get chatRooms => _chatRooms;
  List<Map<String, dynamic>> get currentMessages => _currentMessages;
  Map<String, dynamic>? get currentChatRoom => _currentChatRoom;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize chat rooms for current user
  void initializeChatRooms() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _chatRoomsSubscription?.cancel();
    _chatRoomsSubscription = _firestore
        .collection('chatRooms')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _chatRooms = snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            LoggerService.error('Failed to load chat rooms', error: error);
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  /// Load messages for a specific chat room
  void loadChatMessages(String chatRoomId) {
    _messagesSubscription?.cancel();
    _messagesSubscription = _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            _currentMessages = snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            LoggerService.error('Failed to load messages', error: error);
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  /// Create or get direct chat with another user
  Future<String> createOrGetDirectChat(
    String otherUserId,
    String otherUserName,
  ) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not authenticated');

    _isLoading = true;
    notifyListeners();

    try {
      // Check for existing direct chat
      final existingChats = await _firestore
          .collection('chatRooms')
          .where('type', isEqualTo: 'direct')
          .where('participantIds', arrayContains: currentUserId)
          .get();

      for (final doc in existingChats.docs) {
        final participants = List<String>.from(doc['participantIds']);
        if (participants.contains(otherUserId) && participants.length == 2) {
          _currentChatRoom = doc.data();
          _currentChatRoom!['id'] = doc.id;
          loadChatMessages(doc.id);
          return doc.id;
        }
      }

      // Create new direct chat
      final chatData = {
        'name': otherUserName,
        'type': 'direct',
        'participantIds': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'mutedUsers': [],
      };

      final docRef = await _firestore.collection('chatRooms').add(chatData);
      _currentChatRoom = chatData;
      _currentChatRoom!['id'] = docRef.id;
      loadChatMessages(docRef.id);
      return docRef.id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send a message to current chat room
  Future<void> sendMessage({
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    if (_currentChatRoom == null) return;

    final userId = _auth.currentUser?.uid;
    final userEmail = _auth.currentUser?.email;
    if (userId == null) return;

    try {
      final messageData = {
        'text': content,
        'content': content,
        'senderId': userId,
        'senderName': userEmail?.split('@')[0] ?? 'User',
        'senderRole': 'user',
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': attachmentUrl,
        'attachmentUrl': attachmentUrl,
        'attachmentType': attachmentType,
        'isRead': false,
      };

      await _firestore
          .collection('chatRooms')
          .doc(_currentChatRoom!['id'])
          .collection('messages')
          .add(messageData);

      // Update last message in chat room
      await _firestore
          .collection('chatRooms')
          .doc(_currentChatRoom!['id'])
          .update({
            'lastMessage': content,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSenderId': userId,
          });
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId) async {
    // Simple implementation - could be enhanced with read receipts
    try {
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastReadTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggerService.error('Failed to mark as read', error: e);
    }
  }

  /// Set the current chat room
  void setCurrentChatRoom(Map<String, dynamic> chatRoom) {
    _currentChatRoom = chatRoom;
    loadChatMessages(chatRoom['id']);
    notifyListeners();
  }

  /// Get a specific chat room by ID
  Future<Map<String, dynamic>?> getChatRoom(String chatRoomId) async {
    try {
      final doc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      LoggerService.error('Failed to get chat room', error: e);
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Leave a chat room (for group chats)
  Future<void> leaveChatRoom(String chatRoomId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'participantIds': FieldValue.arrayRemove([userId]),
      });

      // Clear current room if it's the one being left
      if (_currentChatRoom?['id'] == chatRoomId) {
        _currentChatRoom = null;
        _currentMessages = [];
        notifyListeners();
      }
    } catch (e) {
      LoggerService.error('Failed to leave chat room', error: e);
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a chat room completely
  Future<void> deleteChatRoom(String chatRoomId) async {
    try {
      // Delete all messages in the chat first (subcollection)
      final messagesSnapshot = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .get();

      // Batch delete messages for better performance
      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Now delete the chat room document itself
      await _firestore.collection('chatRooms').doc(chatRoomId).delete();

      // Remove from local state immediately
      _chatRooms.removeWhere((chat) => chat['id'] == chatRoomId);

      // Clear current room if it's the one being deleted
      if (_currentChatRoom?['id'] == chatRoomId) {
        _currentChatRoom = null;
        _currentMessages = [];
      }

      notifyListeners();
      LoggerService.info('Chat room $chatRoomId deleted successfully');
    } catch (e) {
      LoggerService.error('Failed to delete chat room', error: e);
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Create a group chat
  Future<Map<String, dynamic>> createGroupChat({
    required String name,
    required String type,
    required List<String> participantIds,
    required List<Map<String, dynamic>> participants,
    String? classId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not authenticated');

    try {
      final chatData = {
        'name': name,
        'type': type,
        'participantIds': participantIds,
        'participants': participants,
        'classId': classId,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUserId,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'mutedUsers': [],
        'unreadCount': 0,
        'unreadCounts': {},
      };

      final docRef = await _firestore.collection('chatRooms').add(chatData);
      chatData['id'] = docRef.id;

      // Set as current chat room
      _currentChatRoom = chatData;
      loadChatMessages(docRef.id);

      return chatData;
    } catch (e) {
      LoggerService.error('Failed to create group chat', error: e);
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Set auth provider (compatibility method)
  void setAuthProvider(dynamic authProvider) {
    // This is a compatibility method that doesn't need to do anything
    // since we're using FirebaseAuth directly
  }

  @override
  void dispose() {
    _chatRoomsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
