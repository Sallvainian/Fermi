import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String name;
  final String type; // 'direct', 'group', 'class'
  final List<String> participantIds;
  final List<ParticipantInfo> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final int unreadCount;
  final Map<String, int>? unreadCounts; // Per-user unread counts
  final String? classId; // For class-based chats
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

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
  });

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
    );
  }

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
    };
  }

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
    );
  }
}

class ParticipantInfo {
  final String id;
  final String name;
  final String role;
  final String? photoUrl;

  ParticipantInfo({
    required this.id,
    required this.name,
    required this.role,
    this.photoUrl,
  });

  factory ParticipantInfo.fromMap(Map<String, dynamic> map) {
    return ParticipantInfo(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      photoUrl: map['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'photoUrl': photoUrl,
    };
  }
}