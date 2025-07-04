import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../models/chat_room.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Create or get direct chat room
  Future<ChatRoom> createOrGetDirectChat(String otherUserId, String otherUserName, String otherUserRole) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    // Sort user IDs to ensure consistent chat room ID
    final List<String> userIds = [currentUser.uid, otherUserId]..sort();
    final chatRoomId = '${userIds[0]}_${userIds[1]}';

    // Check if chat room already exists
    final chatRoomDoc = await _firestore.collection('chat_rooms').doc(chatRoomId).get();
    
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
          'role': 'teacher', // This should be fetched from user profile
          'photoUrl': currentUser.photoURL,
        },
        {
          'id': otherUserId,
          'name': otherUserName,
          'role': otherUserRole,
          'photoUrl': null, // This should be fetched from user profile
        },
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageTime': null,
      'lastMessageSenderId': null,
      'unreadCount': 0,
    };

    await _firestore.collection('chat_rooms').doc(chatRoomId).set(newChatRoom);
    final newDoc = await _firestore.collection('chat_rooms').doc(chatRoomId).get();
    return ChatRoom.fromFirestore(newDoc);
  }

  // Create group/class chat room
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

  // Get user's chat rooms
  Stream<List<ChatRoom>> getUserChatRooms() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('chat_rooms')
        .where('participantIds', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatRoom.fromFirestore(doc))
            .toList());
  }

  // Get messages for a chat room
  Stream<List<Message>> getChatMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromFirestore(doc))
            .toList());
  }

  // Send a message
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

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final batch = _firestore.batch();
    
    final unreadMessages = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: currentUser.uid)
        .get();

    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Reset unread count for current user
    batch.update(
      _firestore.collection('chat_rooms').doc(chatRoomId),
      {'unreadCount': 0},
    );

    await batch.commit();
  }

  // Delete a message
  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // Leave a chat room (for group chats)
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

  // Search messages in a chat room
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