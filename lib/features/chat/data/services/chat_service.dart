/// Chat service for managing real-time messaging in the education platform.
///
/// This service provides comprehensive chat functionality including
/// direct messages, group chats, and class-wide communication channels.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/message.dart';
import '../../domain/models/chat_room.dart';

/// Core service for managing chat rooms and messages in Firestore.
///
/// This service handles:
/// - Direct messaging between users
/// - Group chat creation and management
/// - Real-time message streaming
/// - Read receipts and unread counts
/// - Message search functionality
/// - Chat room lifecycle management
///
/// All operations require authentication and enforce
/// user-specific access controls.
class ChatService {
  /// Firestore instance for database operations.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Firebase Auth instance for user authentication.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Gets the current authenticated user's ID.
  ///
  /// Returns null if no user is signed in.
  ///
  /// @return Current user's UID or null
  String? get currentUserId => _auth.currentUser?.uid;

  /// Creates or retrieves a direct chat room between two users.
  ///
  /// For direct chats, generates a consistent room ID by sorting
  /// user IDs alphabetically. This ensures the same room is used
  /// regardless of who initiates the chat.
  ///
  /// If the room doesn't exist, creates it with both participants'
  /// information. The current user's role is hardcoded as 'teacher'
  /// (TODO: fetch from user profile).
  ///
  /// @param otherUserId ID of the other participant
  /// @param otherUserName Display name of the other participant
  /// @return ChatRoom instance for the direct chat
  /// @throws Exception if user is not authenticated
  Future<ChatRoom> createOrGetDirectChat(
      String otherUserId, String otherUserName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    // Sort user IDs to ensure consistent chat room ID
    final List<String> userIds = [currentUser.uid, otherUserId]..sort();
    final chatRoomId = '${userIds[0]}_${userIds[1]}';

    // Check if chat room already exists
    final chatRoomDoc =
        await _firestore.collection('chat_rooms').doc(chatRoomId).get();

    if (chatRoomDoc.exists) {
      return ChatRoom.fromFirestore(chatRoomDoc);
    }

    // Create new chat room
    final newChatRoom = {
      'name': otherUserName,
      'type': 'direct',
      'participantIds': userIds,
      'participants': [
        {
          'id': currentUser.uid,
          'name': currentUser.displayName ?? 'Unknown',
          'role': 'teacher', // TODO: fetch from user profile
          'photoUrl': currentUser.photoURL,
        },
        {
          'id': otherUserId,
          'name': otherUserName,
          'role': 'student', // TODO: fetch from user profile
          'photoUrl': null, // TODO: fetch from user profile
        },
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageTime': null,
      'lastMessageSenderId': null,
      'unreadCount': 0,
    };

    await _firestore.collection('chat_rooms').doc(chatRoomId).set(newChatRoom);
    final newDoc =
        await _firestore.collection('chat_rooms').doc(chatRoomId).get();
    return ChatRoom.fromFirestore(newDoc);
  }

  /// Creates a new group or class chat room.
  ///
  /// Supports creating chat rooms for:
  /// - Groups of users (custom participant lists)
  /// - Class-wide communication (linked to a class ID)
  ///
  /// The creator must be authenticated and will automatically
  /// be included in the participant list.
  ///
  /// @param name Display name for the chat room
  /// @param type Chat type ('group' or 'class')
  /// @param participantIds List of user IDs who can access the chat
  /// @param participants List of participant info objects
  /// @param classId Optional class ID for class-specific chats
  /// @return Created ChatRoom instance
  /// @throws Exception if user is not authenticated
  Future<ChatRoom> createGroupChat({
    required String name,
    required String type,
    required List<String> participantIds,
    required List<ParticipantInfo> participants,
    String? classId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final chatRoomRef = _firestore.collection('chat_rooms').doc();

    final chatRoomData = {
      'name': name,
      'type': type,
      'participantIds': participantIds,
      'participants': participants.map((p) => p.toMap()).toList(),
      'classId': classId,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageTime': null,
      'lastMessageSenderId': null,
      'unreadCount': 0,
    };

    await chatRoomRef.set(chatRoomData);
    final newDoc = await chatRoomRef.get();
    return ChatRoom.fromFirestore(newDoc);
  }

  /// Streams all chat rooms for the current user.
  ///
  /// Returns a real-time stream of chat rooms where the
  /// current user is a participant. Rooms are ordered by
  /// last message time (most recent first).
  ///
  /// Returns empty stream if user is not authenticated.
  ///
  /// @return Stream of ChatRoom lists, updated in real-time
  Stream<List<ChatRoom>> getUserChatRooms() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('chat_rooms')
        .where('participantIds', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList());
  }

  /// Streams messages for a specific chat room.
  ///
  /// Returns a real-time stream of messages ordered by
  /// timestamp (newest first). This stream updates automatically
  /// when new messages are added or existing messages change.
  ///
  /// @param chatRoomId ID of the chat room to get messages from
  /// @return Stream of Message lists, updated in real-time
  Stream<List<Message>> getChatMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }

  /// Sends a new message to a chat room.
  ///
  /// Creates a message with the current user as sender and
  /// adds it to the chat room's messages subcollection.
  /// Also updates the chat room's last message metadata.
  ///
  /// The sender's role is hardcoded as 'teacher'
  /// (TODO: fetch from user profile).
  ///
  /// @param chatRoomId Target chat room ID
  /// @param content Text content of the message
  /// @param attachmentUrl Optional URL for file attachments
  /// @param attachmentType Optional attachment MIME type
  /// @throws Exception if user is not authenticated
  Future<void> sendMessage({
    required String chatRoomId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final messageData = {
      'senderId': currentUser.uid,
      'senderName': currentUser.displayName ?? 'Unknown',
      'senderRole': 'teacher', // This should be fetched from user profile
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
    };

    // Add message to subcollection
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    // Update chat room with last message info
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'lastMessage': content,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUser.uid,
    });
  }

  /// Marks all unread messages in a chat room as read.
  ///
  /// Updates all messages that:
  /// - Are marked as unread
  /// - Were not sent by the current user
  ///
  /// Also resets the unread count for the chat room.
  /// Uses batch operations for efficiency.
  ///
  /// @param chatRoomId Chat room to mark messages in
  Future<void> markMessagesAsRead(String chatRoomId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final batch = _firestore.batch();

    // Get all unread messages and filter in memory to avoid complex index
    final allUnreadMessages = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    // Filter out current user's messages
    final unreadMessages = allUnreadMessages.docs
        .where((doc) => doc.data()['senderId'] != currentUser.uid)
        .toList();

    for (final doc in unreadMessages) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Reset unread count for current user
    batch.update(
      _firestore.collection('chat_rooms').doc(chatRoomId),
      {'unreadCount': 0},
    );

    await batch.commit();
  }

  /// Deletes a specific message from a chat room.
  ///
  /// Permanently removes the message from Firestore.
  /// This operation cannot be undone.
  ///
  /// @param chatRoomId Chat room containing the message
  /// @param messageId ID of the message to delete
  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  /// Removes the current user from a chat room.
  ///
  /// For group chats only - removes the user from both
  /// the participantIds array and the participants list.
  /// The user's role is hardcoded as 'teacher'
  /// (TODO: fetch from user profile).
  ///
  /// Direct chats should not use this method.
  ///
  /// @param chatRoomId ID of the chat room to leave
  Future<void> leaveChatRoom(String chatRoomId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'participantIds': FieldValue.arrayRemove([currentUser.uid]),
      'participants': FieldValue.arrayRemove([
        {
          'id': currentUser.uid,
          'name': currentUser.displayName ?? 'Unknown',
          'role': 'teacher', // This should be fetched from user profile
          'photoUrl': currentUser.photoURL,
        }
      ]),
    });
  }

  /// Searches for messages within a chat room.
  ///
  /// Performs a case-insensitive search on:
  /// - Message content
  /// - Sender names
  ///
  /// Results are sorted by timestamp (newest first).
  /// Note: This implementation loads all messages into memory,
  /// which may not scale well for large chat histories.
  ///
  /// @param chatRoomId Chat room to search in
  /// @param query Search term to match
  /// @return List of matching messages
  Future<List<Message>> searchMessages(String chatRoomId, String query) async {
    final querySnapshot = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .get();

    final messages = querySnapshot.docs
        .map((doc) => Message.fromFirestore(doc))
        .where((message) =>
            message.content.toLowerCase().contains(query.toLowerCase()) ||
            message.senderName.toLowerCase().contains(query.toLowerCase()))
        .toList();

    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return messages;
  }
}
