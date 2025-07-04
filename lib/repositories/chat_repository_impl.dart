import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../models/chat_room.dart';
import '../services/firestore_service.dart';
import '../services/logger_service.dart';
import 'chat_repository.dart';
import 'firestore_repository.dart';

class ChatRepositoryImpl extends FirestoreRepository<ChatRoom> implements ChatRepository {
  static const String _tag = 'ChatRepository';
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatRepositoryImpl(this._firestore, this._auth)
      : super(
          firestore: _firestore,
          collectionPath: 'chat_rooms',
          fromFirestore: (doc) => ChatRoom.fromFirestore(doc),
          toFirestore: (chatRoom) => chatRoom.toFirestore(),
          logTag: _tag,
        );

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  @override
  Future<String> createChatRoom(ChatRoom chatRoom) async {
    try {
      final chatRoomToCreate = chatRoom.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return await create(chatRoomToCreate);
    } catch (e) {
      LoggerService.error('Failed to create chat room', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<ChatRoom?> getChatRoom(String id) => read(id);

  @override
  Future<void> updateChatRoom(String id, ChatRoom chatRoom) async {
    try {
      final chatRoomToUpdate = chatRoom.copyWith(
        updatedAt: DateTime.now(),
      );
      await update(id, chatRoomToUpdate);
    } catch (e) {
      LoggerService.error('Failed to update chat room', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteChatRoom(String id) => delete(id);

  @override
  Future<ChatRoom> createOrGetDirectChat(
    String otherUserId,
    String otherUserName,
    String otherUserRole,
  ) async {
    try {
      // Check if direct chat already exists
      final existing = await findDirectChat(_currentUserId, otherUserId);
      if (existing != null) {
        return existing;
      }

      // Create new direct chat
      final participants = [
        ParticipantInfo(
          id: _currentUserId,
          name: _auth.currentUser?.displayName ?? 'User',
          role: 'user', // This should be fetched from user profile
        ),
        ParticipantInfo(
          id: otherUserId,
          name: otherUserName,
          role: otherUserRole,
        ),
      ];

      final chatRoom = ChatRoom(
        id: '',
        name: otherUserName,
        type: 'direct',
        participantIds: [_currentUserId, otherUserId],
        participants: participants,
        createdBy: _currentUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await createChatRoom(chatRoom);
      return chatRoom.copyWith(id: id);
    } catch (e) {
      LoggerService.error('Failed to create or get direct chat', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<ChatRoom> createGroupChat({
    required String name,
    required String type,
    required List<String> participantIds,
    required List<ParticipantInfo> participants,
    String? classId,
  }) async {
    try {
      final chatRoom = ChatRoom(
        id: '',
        name: name,
        type: type,
        participantIds: participantIds,
        participants: participants,
        classId: classId,
        createdBy: _currentUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await createChatRoom(chatRoom);
      return chatRoom.copyWith(id: id);
    } catch (e) {
      LoggerService.error('Failed to create group chat', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<String> sendMessage({
    required String chatRoomId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    try {
      final message = Message(
        id: '',
        senderId: _currentUserId,
        senderName: _auth.currentUser?.displayName ?? 'User',
        senderRole: _auth.currentUser?.email?.endsWith('@teacher.edu') == true ? 'teacher' : 'student',
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        timestamp: DateTime.now(),
      );

      // Add message to subcollection
      final ref = _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc();
      
      final messageWithId = message.copyWith(id: ref.id);
      await ref.set(messageWithId.toFirestore());

      // Update last message in chat room
      await updateLastMessage(chatRoomId, messageWithId);

      LoggerService.info('Message sent to chat room $chatRoomId', tag: _tag);
      return ref.id;
    } catch (e) {
      LoggerService.error('Failed to send message', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .delete();
      
      LoggerService.info('Message $messageId deleted from chat room $chatRoomId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to delete message', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> editMessage(String chatRoomId, String messageId, String newContent) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
            'content': newContent,
            'isEdited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });
      
      LoggerService.info('Message $messageId edited in chat room $chatRoomId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to edit message', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Stream<List<ChatRoom>> getUserChatRooms() {
    return stream(
      conditions: [
        QueryCondition(field: 'participantIds', arrayContains: _currentUserId),
      ],
      orderBy: [OrderBy(field: 'updatedAt', descending: true)],
    );
  }

  @override
  Stream<List<Message>> getChatMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> addParticipant(String chatRoomId, String userId, ParticipantInfo participantInfo) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'participantIds': FieldValue.arrayUnion([userId]),
        'participants': FieldValue.arrayUnion([participantInfo.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('Participant $userId added to chat room $chatRoomId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to add participant', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> removeParticipant(String chatRoomId, String userId) async {
    try {
      // Get chat room to find participant info
      final chatRoom = await getChatRoom(chatRoomId);
      if (chatRoom == null) return;

      final participant = chatRoom.participants.firstWhere(
        (p) => p.id == userId,
        orElse: () => ParticipantInfo(id: userId, name: '', role: ''),
      );

      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'participantIds': FieldValue.arrayRemove([userId]),
        'participants': FieldValue.arrayRemove([participant.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('Participant $userId removed from chat room $chatRoomId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to remove participant', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> leaveChatRoom(String chatRoomId) async {
    try {
      await removeParticipant(chatRoomId, _currentUserId);
    } catch (e) {
      LoggerService.error('Failed to leave chat room', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> updateLastMessage(String chatRoomId, Message message) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': message.content,
        'lastMessageTime': message.timestamp,
        'lastMessageSenderId': message.senderId,
        'lastMessageSenderName': message.senderName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggerService.error('Failed to update last message', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> markMessagesAsRead(String chatRoomId) async {
    try {
      // Get unread messages
      final unreadMessages = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('status', isEqualTo: MessageStatus.delivered.name)
          .where('senderId', isNotEqualTo: _currentUserId)
          .get();

      // Batch update to read status
      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'status': MessageStatus.read.name,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      // Update unread count in chat room
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'unreadCounts.$_currentUserId': 0,
      });
      
      LoggerService.info('Marked ${unreadMessages.size} messages as read', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to mark messages as read', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> markMessageAsDelivered(String chatRoomId, String messageId) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
            'status': MessageStatus.delivered.name,
            'deliveredAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      LoggerService.error('Failed to mark message as delivered', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<List<Message>> searchMessages(String chatRoomId, String query) async {
    try {
      // Note: This is a simple implementation. For better search,
      // consider using a search service like Algolia
      final messages = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .get();
      
      final lowercaseQuery = query.toLowerCase();
      return messages.docs
          .map((doc) => Message.fromFirestore(doc))
          .where((message) => message.content.toLowerCase().contains(lowercaseQuery))
          .toList();
    } catch (e) {
      LoggerService.error('Failed to search messages', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<List<ChatRoom>> searchChatRooms(String query) async {
    try {
      final chatRooms = await list(
        conditions: [
          QueryCondition(field: 'participantIds', arrayContains: _currentUserId),
        ],
      );
      
      final lowercaseQuery = query.toLowerCase();
      return chatRooms.where((room) => 
        room.name.toLowerCase().contains(lowercaseQuery)
      ).toList();
    } catch (e) {
      LoggerService.error('Failed to search chat rooms', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<ChatRoom?> findDirectChat(String userId1, String userId2) async {
    try {
      final chatRooms = await list(
        conditions: [
          QueryCondition(field: 'type', isEqualTo: 'direct'),
          QueryCondition(field: 'participantIds', arrayContains: userId1),
        ],
      );
      
      return chatRooms.firstWhere(
        (room) => room.participantIds.contains(userId2) && room.participantIds.length == 2,
        orElse: () => null as dynamic,
      );
    } catch (e) {
      LoggerService.error('Failed to find direct chat', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> setTypingStatus(String chatRoomId, bool isTyping) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'typingUsers.$_currentUserId': isTyping,
      });
    } catch (e) {
      LoggerService.error('Failed to set typing status', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Stream<Map<String, bool>> getTypingStatuses(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data != null && data['typingUsers'] != null) {
            return Map<String, bool>.from(data['typingUsers'] as Map);
          }
          return {};
        });
  }

  @override
  Future<int> getUnreadCount(String chatRoomId) async {
    try {
      final chatRoom = await getChatRoom(chatRoomId);
      if (chatRoom?.unreadCounts != null) {
        return chatRoom!.unreadCounts![_currentUserId] ?? 0;
      }
      return 0;
    } catch (e) {
      LoggerService.error('Failed to get unread count', tag: _tag, error: e);
      return 0;
    }
  }

  @override
  Future<Map<String, int>> getAllUnreadCounts() async {
    try {
      final chatRooms = await list(
        conditions: [
          QueryCondition(field: 'participantIds', arrayContains: _currentUserId),
        ],
      );
      
      final unreadCounts = <String, int>{};
      for (final room in chatRooms) {
        if (room.unreadCounts != null && room.unreadCounts![_currentUserId] != null) {
          unreadCounts[room.id] = room.unreadCounts![_currentUserId]!;
        }
      }
      
      return unreadCounts;
    } catch (e) {
      LoggerService.error('Failed to get all unread counts', tag: _tag, error: e);
      return {};
    }
  }

  @override
  Future<void> batchDeleteMessages(String chatRoomId, List<String> messageIds) async {
    try {
      final batch = _firestore.batch();
      
      for (final messageId in messageIds) {
        final ref = _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .doc(messageId);
        batch.delete(ref);
      }
      
      await batch.commit();
      LoggerService.info('Batch deleted ${messageIds.length} messages', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to batch delete messages', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> batchUpdateMessageStatus(String chatRoomId, List<String> messageIds, MessageStatus status) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (final messageId in messageIds) {
        final ref = _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .doc(messageId);
        
        final updates = <String, dynamic>{
          'status': status.name,
        };
        
        if (status == MessageStatus.delivered) {
          updates['deliveredAt'] = now;
        } else if (status == MessageStatus.read) {
          updates['readAt'] = now;
        }
        
        batch.update(ref, updates);
      }
      
      await batch.commit();
      LoggerService.info('Batch updated ${messageIds.length} messages to status ${status.name}', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to batch update message status', tag: _tag, error: e);
      rethrow;
    }
  }
}