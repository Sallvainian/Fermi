/// Service for managing scheduled messages in the education platform.
/// 
/// This service enables users to schedule messages for future delivery,
/// manage scheduled messages, and track scheduled message status within
/// the chat system.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/message.dart';
import '../../../../shared/services/logger_service.dart';

/// Core service for scheduling and managing future message delivery.
/// 
/// This service provides:
/// - Message scheduling for future timestamps
/// - Scheduled message retrieval and monitoring
/// - Cancellation and update capabilities
/// - User-specific scheduled message management
/// - Integration with the chat messaging system
/// 
/// Scheduled messages are stored separately from regular messages
/// until their scheduled time, when they should be processed by
/// a background job or cloud function.
class ScheduledMessagesService {
  /// Logging tag for this service.
  static const String _tag = 'ScheduledMessagesService';
  
  /// Firestore instance for database operations.
  final FirebaseFirestore _firestore;
  
  /// Firebase Auth instance for user authentication.
  final FirebaseAuth _auth;

  /// Creates a ScheduledMessagesService instance.
  /// 
  /// Accepts optional dependencies for testing:
  /// @param firestore Optional Firestore instance
  /// @param auth Optional Firebase Auth instance
  ScheduledMessagesService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Gets the current authenticated user's ID.
  /// 
  /// Returns empty string if no user is authenticated.
  String get _currentUserId => _auth.currentUser?.uid ?? '';

  /// Schedules a message for future delivery.
  /// 
  /// Creates a scheduled message entry that will be processed
  /// at the specified future time. The message is stored in
  /// a separate collection until its scheduled delivery time.
  /// 
  /// @param chatRoomId Target chat room for the message
  /// @param content Message text content
  /// @param scheduledFor Future timestamp for delivery
  /// @param attachmentUrl Optional file attachment URL
  /// @param attachmentType Optional attachment MIME type
  /// @return Document ID of the scheduled message
  /// @throws Exception if scheduled time is in the past
  Future<String> scheduleMessage({
    required String chatRoomId,
    required String content,
    required DateTime scheduledFor,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    try {
      if (scheduledFor.isBefore(DateTime.now())) {
        throw Exception('Scheduled time must be in the future');
      }

      final message = Message(
        id: '',
        senderId: _currentUserId,
        senderName: _auth.currentUser?.displayName ?? 'User',
        senderRole: _auth.currentUser?.email?.endsWith('@teacher.edu') == true 
            ? 'teacher' 
            : 'student',
        content: content,
        timestamp: DateTime.now(),
        scheduledFor: scheduledFor,
        isScheduled: true,
        status: MessageStatus.sent,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );

      // Store in scheduled_messages collection
      final ref = _firestore.collection('scheduled_messages').doc();
      
      await ref.set({
        'chatRoomId': chatRoomId,
        'message': message.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      LoggerService.info(
        'Message scheduled for ${scheduledFor.toIso8601String()}',
        tag: _tag,
      );
      
      return ref.id;
    } catch (e) {
      LoggerService.error('Failed to schedule message', tag: _tag, error: e);
      rethrow;
    }
  }

  /// Streams scheduled messages for a specific chat room.
  /// 
  /// Returns a real-time stream of scheduled messages that:
  /// - Belong to the specified chat room
  /// - Were created by the current user
  /// - Have future scheduled delivery times
  /// - Are sorted by scheduled time (earliest first)
  /// 
  /// Past scheduled messages are automatically filtered out.
  /// 
  /// @param chatRoomId Chat room to get scheduled messages for
  /// @return Stream of scheduled messages list
  Stream<List<ScheduledMessage>> getScheduledMessages(String chatRoomId) {
    return _firestore
        .collection('scheduled_messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .where('message.senderId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          return snapshot.docs
              .map((doc) => ScheduledMessage.fromFirestore(doc))
              .where((msg) => msg.message.scheduledFor?.isAfter(now) ?? false)
              .toList()
            ..sort((a, b) => a.message.scheduledFor!.compareTo(b.message.scheduledFor!));
        });
  }

  /// Cancels a scheduled message before delivery.
  /// 
  /// Permanently deletes the scheduled message from the queue.
  /// This operation cannot be undone and the message will not
  /// be delivered at its scheduled time.
  /// 
  /// @param scheduledMessageId ID of the scheduled message to cancel
  /// @throws Exception if cancellation fails
  Future<void> cancelScheduledMessage(String scheduledMessageId) async {
    try {
      await _firestore
          .collection('scheduled_messages')
          .doc(scheduledMessageId)
          .delete();
      
      LoggerService.info(
        'Scheduled message $scheduledMessageId cancelled',
        tag: _tag,
      );
    } catch (e) {
      LoggerService.error('Failed to cancel scheduled message', tag: _tag, error: e);
      rethrow;
    }
  }

  /// Updates an existing scheduled message.
  /// 
  /// Allows modification of message content and/or scheduled
  /// delivery time. Only future messages can be updated.
  /// 
  /// @param scheduledMessageId ID of the message to update
  /// @param content New message content (optional)
  /// @param scheduledFor New scheduled time (optional)
  /// @throws Exception if new scheduled time is in the past
  Future<void> updateScheduledMessage({
    required String scheduledMessageId,
    String? content,
    DateTime? scheduledFor,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (content != null) {
        updates['message.content'] = content;
      }
      
      if (scheduledFor != null) {
        if (scheduledFor.isBefore(DateTime.now())) {
          throw Exception('Scheduled time must be in the future');
        }
        updates['message.scheduledFor'] = Timestamp.fromDate(scheduledFor);
      }
      
      await _firestore
          .collection('scheduled_messages')
          .doc(scheduledMessageId)
          .update(updates);
      
      LoggerService.info(
        'Scheduled message $scheduledMessageId updated',
        tag: _tag,
      );
    } catch (e) {
      LoggerService.error('Failed to update scheduled message', tag: _tag, error: e);
      rethrow;
    }
  }

  /// Streams all scheduled messages for the current user.
  /// 
  /// Returns a real-time stream of all scheduled messages
  /// created by the current user across all chat rooms.
  /// Messages are:
  /// - Filtered to show only future deliveries
  /// - Sorted by scheduled time (earliest first)
  /// 
  /// Useful for displaying a user's scheduled message overview.
  /// 
  /// @return Stream of all user's scheduled messages
  Stream<List<ScheduledMessage>> getAllScheduledMessages() {
    return _firestore
        .collection('scheduled_messages')
        .where('message.senderId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          return snapshot.docs
              .map((doc) => ScheduledMessage.fromFirestore(doc))
              .where((msg) => msg.message.scheduledFor?.isAfter(now) ?? false)
              .toList()
            ..sort((a, b) => a.message.scheduledFor!.compareTo(b.message.scheduledFor!));
        });
  }
}

/// Model representing a scheduled message in the system.
/// 
/// Wraps a regular Message with scheduling metadata including
/// the target chat room and creation timestamp. Used for
/// managing messages scheduled for future delivery.
class ScheduledMessage {
  /// Unique identifier for the scheduled message.
  final String id;
  
  /// ID of the chat room where message will be delivered.
  final String chatRoomId;
  
  /// The actual message content and metadata.
  final Message message;
  
  /// Timestamp when the scheduled message was created.
  final DateTime createdAt;

  /// Creates a ScheduledMessage instance.
  /// 
  /// @param id Unique identifier
  /// @param chatRoomId Target chat room ID
  /// @param message Message to be delivered
  /// @param createdAt Creation timestamp
  ScheduledMessage({
    required this.id,
    required this.chatRoomId,
    required this.message,
    required this.createdAt,
  });

  /// Factory constructor to create ScheduledMessage from Firestore.
  /// 
  /// Parses the Firestore document structure including:
  /// - Chat room reference
  /// - Embedded message data
  /// - Creation timestamp with null safety
  /// 
  /// @param doc Firestore document containing scheduled message
  /// @return Parsed ScheduledMessage instance
  factory ScheduledMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final messageData = data['message'] as Map<String, dynamic>;
    return ScheduledMessage(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      message: Message.fromMap(doc.id, messageData),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}