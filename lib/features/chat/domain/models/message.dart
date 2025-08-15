/// Message model for real-time chat functionality.
/// 
/// This module contains the data model for messages used in
/// chat rooms and direct messaging within the education platform.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Core message model representing individual chat messages.
/// 
/// Messages support various features for educational communication:
/// - Text content with sender identification
/// - File attachments (images, documents)
/// - Scheduled message delivery
/// - Read receipts and delivery status
/// - Message editing with history tracking
/// - Role-based sender identification
/// 
/// Messages can be sent immediately or scheduled for future delivery,
/// supporting asynchronous teacher-student communication.
class Message {
  /// Unique identifier for the message
  final String id;
  
  /// User ID of the message sender
  final String senderId;
  
  /// Cached name of the sender for display
  final String senderName;
  
  /// Role of the sender ('teacher' or 'student')
  final String senderRole;
  
  /// Text content of the message
  final String content;
  
  /// Timestamp when the message was sent/created
  final DateTime timestamp;
  
  /// Whether the message has been read by recipient
  final bool isRead;
  
  /// Optional URL to attached file
  final String? attachmentUrl;
  
  /// Type of attachment ('image', 'document', 'video', etc.)
  final String? attachmentType;
  
  /// Future timestamp for scheduled messages
  final DateTime? scheduledFor;
  
  /// Whether this is a scheduled message
  final bool isScheduled;
  
  /// Current status of the message
  final MessageStatus status;
  
  /// Whether the message has been edited
  final bool isEdited;
  
  /// Timestamp of last edit (null if never edited)
  final DateTime? editedAt;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.attachmentUrl,
    this.attachmentType,
    this.scheduledFor,
    this.isScheduled = false,
    this.status = MessageStatus.sent,
    this.isEdited = false,
    this.editedAt,
  });

  /// Factory constructor to create Message from Firestore document.
  /// 
  /// Handles data parsing with comprehensive defaults:
  /// - Timestamp conversions for all date fields
  /// - Status enum parsing with fallback to 'sent'
  /// - Null safety for optional fields
  /// - Default values for boolean flags
  /// 
  /// @param doc Firestore document snapshot containing message data
  /// @return Parsed Message instance
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
      attachmentUrl: data['attachmentUrl'],
      attachmentType: data['attachmentType'],
      scheduledFor: data['scheduledFor'] != null 
          ? (data['scheduledFor'] as Timestamp).toDate() 
          : null,
      isScheduled: data['isScheduled'] ?? false,
      status: data['status'] != null 
          ? MessageStatus.values.firstWhere(
              (s) => s.name == data['status'],
              orElse: () => MessageStatus.sent,
            )
          : MessageStatus.sent,
      isEdited: data['isEdited'] ?? false,
      editedAt: data['editedAt'] != null 
          ? (data['editedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  /// Alternative factory constructor to create Message from Map data.
  /// 
  /// Similar to fromFirestore but accepts ID separately, useful for:
  /// - Creating messages from cached data
  /// - Testing with mock data
  /// - Data transformations
  /// 
  /// Includes additional safety with fallback to current timestamp
  /// when timestamp data is missing.
  /// 
  /// @param id Message identifier
  /// @param data Map containing message fields
  /// @return Parsed Message instance
  factory Message.fromMap(String id, Map<String, dynamic> data) {
    return Message(
      id: id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? 'student',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
      attachmentUrl: data['attachmentUrl'],
      attachmentType: data['attachmentType'],
      scheduledFor: data['scheduledFor'] != null 
          ? (data['scheduledFor'] as Timestamp).toDate() 
          : null,
      isScheduled: data['isScheduled'] ?? false,
      status: data['status'] != null
          ? MessageStatus.values.firstWhere(
              (e) => e.name == data['status'],
              orElse: () => MessageStatus.sent,
            )
          : MessageStatus.sent,
      isEdited: data['isEdited'] ?? false,
      editedAt: data['editedAt'] != null 
          ? (data['editedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  /// Converts the Message instance to a Map for Firestore storage.
  /// 
  /// Serializes all message data including:
  /// - DateTime fields to Firestore Timestamps
  /// - Status enum to string using .name property
  /// - Conditional serialization of optional fields
  /// - Attachment metadata preservation
  /// 
  /// @return Map containing all message data for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'scheduledFor': scheduledFor != null 
          ? Timestamp.fromDate(scheduledFor!) 
          : null,
      'isScheduled': isScheduled,
      'status': status.name,
      'isEdited': isEdited,
      'editedAt': editedAt != null 
          ? Timestamp.fromDate(editedAt!) 
          : null,
    };
  }

  /// Creates a copy of the Message with updated fields.
  /// 
  /// Follows immutable data pattern for state management.
  /// Useful for:
  /// - Marking messages as read
  /// - Updating delivery status
  /// - Adding edit timestamps
  /// - Changing scheduled delivery times
  /// 
  /// All parameters are optional - only provided fields will be updated.
  /// 
  /// @return New Message instance with updated fields
  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    String? attachmentUrl,
    String? attachmentType,
    DateTime? scheduledFor,
    bool? isScheduled,
    MessageStatus? status,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      isScheduled: isScheduled ?? this.isScheduled,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}

/// Enumeration representing message delivery states.
/// 
/// Messages progress through these states:
/// - [sent]: Message created and sent to server
/// - [delivered]: Message received by recipient's device
/// - [read]: Message viewed by recipient
/// - [failed]: Message delivery failed
/// 
/// Status tracking enables delivery confirmation and
/// read receipts for better communication awareness.
enum MessageStatus {
  sent,
  delivered,
  read,
  failed,
}