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
  }) async {
    if (_currentChatRoom == null) return;

    final userId = _auth.currentUser?.uid;
    final userEmail = _auth.currentUser?.email;
    if (userId == null) return;

    try {
      final messageData = {
        'text': content,
        'senderId': userId,
        'senderName': userEmail?.split('@')[0] ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': attachmentUrl,
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
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .update({
        'lastReadTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggerService.error('Failed to mark as read', error: e);
    }
  }

  @override
  void dispose() {
    _chatRoomsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}