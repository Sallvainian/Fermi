/// Chat room model for managing messaging channels in the education platform.
/// 
/// This module contains data models for chat rooms and participant information,
/// supporting various communication types between teachers, students, and groups.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Core chat room model representing a messaging channel.
/// 
/// This model supports different types of chat rooms:
/// - Direct messages between two users
/// - Group chats with multiple participants
/// - Class-based channels for educational discussions
/// 
/// Features include:
/// - Participant management with role information
/// - Unread message tracking (global and per-user)
/// - Last message preview for list displays
/// - Class association for academic context
class ChatRoom {
  /// Unique identifier for the chat room
  final String id;
  
  /// Display name of the chat room
  final String name;
  
  /// Type of chat room: 'direct', 'group', or 'class'
  final String type; // 'direct', 'group', 'class'
  
  /// List of user IDs participating in this chat
  final List<String> participantIds;
  
  /// Detailed participant information including names and roles
  final List<ParticipantInfo> participants;
  
  /// Preview text of the most recent message
  final String? lastMessage;
  
  /// Timestamp of the most recent message
  final DateTime? lastMessageTime;
  
  /// User ID of the last message sender
  final String? lastMessageSenderId;
  
  /// Total unread message count (deprecated, use unreadCounts)
  final int unreadCount;
  
  /// Per-user unread message counts (userId -> count)
  final Map<String, int>? unreadCounts; // Per-user unread counts
  
  /// Associated class ID for class-based chat rooms
  final String? classId; // For class-based chats
  
  /// Timestamp when the chat room was created
  final DateTime createdAt;
  
  /// Timestamp of last modification
  final DateTime? updatedAt;
  
  /// User ID who created the chat room
  final String? createdBy;

  /// List of user IDs who have muted this chat
  final List<String> mutedUsers;

  ChatRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.participantIds,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.unreadCounts,
    this.classId,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.mutedUsers = const [],
  });

  /// Factory constructor to create ChatRoom from Firestore document.
  /// 
  /// Handles complex data parsing including:
  /// - Nested participant information objects
  /// - Timestamp conversions for dates
  /// - Map casting for unread counts
  /// - Null safety with appropriate defaults
  /// 
  /// @param doc Firestore document snapshot containing chat room data
  /// @return Parsed ChatRoom instance
  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? 'direct',
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participants: (data['participants'] as List<dynamic>?)
          ?.map((p) => ParticipantInfo.fromMap(p))
          .toList() ?? [],
      lastMessage: data['lastMessage'],
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: data['unreadCount'] ?? 0,
      unreadCounts: data['unreadCounts'] != null
          ? Map<String, int>.from(data['unreadCounts'])
          : null,
      classId: data['classId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      createdBy: data['createdBy'],
      mutedUsers: List<String>.from(data['mutedUsers'] ?? []),
    );
  }

  /// Converts the ChatRoom instance to a Map for Firestore storage.
  /// 
  /// Serializes all chat room data including:
  /// - Converting participant objects to maps
  /// - DateTime fields to Firestore Timestamps
  /// - Preserving null values for optional fields
  /// 
  /// @return Map containing all chat room data for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'participantIds': participantIds,
      'participants': participants.map((p) => p.toMap()).toList(),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'unreadCounts': unreadCounts,
      'classId': classId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null 
          ? Timestamp.fromDate(updatedAt!)
          : null,
      'createdBy': createdBy,
      'mutedUsers': mutedUsers,
    };
  }

  /// Gets the display name for this chat room from the perspective of a specific user.
  /// 
  /// For direct chats, this returns the name of the OTHER participant.
  /// For group and class chats, this returns the chat room's name.
  /// 
  /// @param currentUserId The ID of the user viewing the chat
  /// @return The display name for the chat room
  String getDisplayName(String currentUserId) {
    if (type == 'direct' && participants.length >= 2) {
      // For direct chats, show the other participant's name
      final otherParticipant = participants.firstWhere(
        (p) => p.id != currentUserId,
        orElse: () => participants.first,
      );
      return otherParticipant.name;
    }
    
    // For group and class chats, use the chat room name
    return name;
  }

  /// Gets the display photo URL for this chat room from the perspective of a specific user.
  /// 
  /// For direct chats, this returns the photo URL of the OTHER participant.
  /// For group and class chats, this returns null (groups don't have photos).
  /// 
  /// @param currentUserId The ID of the user viewing the chat
  /// @return The photo URL for the chat room, or null
  String? getDisplayPhotoUrl(String currentUserId) {
    if (type == 'direct' && participants.length >= 2) {
      // For direct chats, show the other participant's photo
      final otherParticipant = participants.firstWhere(
        (p) => p.id != currentUserId,
        orElse: () => participants.first,
      );
      return otherParticipant.photoUrl;
    }
    
    // Group and class chats don't have individual photos
    return null;
  }

  /// Creates a copy of the ChatRoom with updated fields.
  /// 
  /// Follows immutable data pattern for state management.
  /// Useful for:
  /// - Updating last message information
  /// - Managing participant lists
  /// - Tracking unread counts
  /// - Modifying room metadata
  /// 
  /// All parameters are optional - only provided fields will be updated.
  /// 
  /// @return New ChatRoom instance with updated fields
  ChatRoom copyWith({
    String? id,
    String? name,
    String? type,
    List<String>? participantIds,
    List<ParticipantInfo>? participants,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    int? unreadCount,
    Map<String, int>? unreadCounts,
    String? classId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    List<String>? mutedUsers,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      participantIds: participantIds ?? this.participantIds,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      classId: classId ?? this.classId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      mutedUsers: mutedUsers ?? this.mutedUsers,
    );
  }
}

/// Information about a chat room participant.
/// 
/// This model stores detailed information about each participant
/// in a chat room, including their identity and role. This allows
/// for rich participant displays without requiring additional
/// database lookups.
class ParticipantInfo {
  /// User ID of the participant
  final String id;
  
  /// Display name of the participant
  final String name;
  
  /// Role of the participant (e.g., 'teacher', 'student')
  final String role;
  
  /// Optional URL to participant's profile photo
  final String? photoUrl;

  ParticipantInfo({
    required this.id,
    required this.name,
    required this.role,
    this.photoUrl,
  });

  /// Factory constructor to create ParticipantInfo from a Map.
  /// 
  /// Used when deserializing participant data from Firestore
  /// documents. Provides safe defaults for all required fields.
  /// 
  /// @param map Map containing participant data
  /// @return Parsed ParticipantInfo instance
  factory ParticipantInfo.fromMap(Map<String, dynamic> map) {
    return ParticipantInfo(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      photoUrl: map['photoUrl'],
    );
  }

  /// Converts the ParticipantInfo instance to a Map.
  /// 
  /// Used for serializing participant data when storing
  /// chat rooms in Firestore.
  /// 
  /// @return Map containing all participant information
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'photoUrl': photoUrl,
    };
  }
}