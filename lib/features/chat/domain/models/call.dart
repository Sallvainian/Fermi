import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType { voice, video }

enum CallStatus { ringing, accepted, rejected, ended, missed }

enum CallState {
  idle,
  calling,
  ringing,
  connecting,
  connected,
  reconnecting,
  error,
}

class Call {
  final String id;
  final String callerId;
  final String callerName;
  final String callerPhotoUrl;
  final String receiverId;
  final String receiverName;
  final String receiverPhotoUrl;
  final CallType type;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? duration; // in seconds
  final String? chatRoomId;
  final DateTime? expireAt; // TTL field for automatic cleanup

  Call({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.callerPhotoUrl,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhotoUrl,
    required this.type,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.duration,
    this.chatRoomId,
    this.expireAt,
  });

  factory Call.fromMap(Map<String, dynamic> map, String id) {
    return Call(
      id: id,
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      callerPhotoUrl: map['callerPhotoUrl'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      receiverPhotoUrl: map['receiverPhotoUrl'] ?? '',
      type: CallType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CallType.voice,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CallStatus.ended,
      ),
      startedAt: (map['startedAt'] as Timestamp).toDate(),
      endedAt: map['endedAt'] != null
          ? (map['endedAt'] as Timestamp).toDate()
          : null,
      duration: map['duration'],
      chatRoomId: map['chatRoomId'],
      expireAt: map['expireAt'] != null
          ? (map['expireAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhotoUrl': receiverPhotoUrl,
      'type': type.name,
      'status': status.name,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'duration': duration,
      'chatRoomId': chatRoomId,
      'expireAt': expireAt != null ? Timestamp.fromDate(expireAt!) : null,
    };
  }

  // Convenience getters for compatibility
  bool get isVideo => type == CallType.video;
  String get calleeId => receiverId;
  String? get callerPhotoURL => callerPhotoUrl;

  Call copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerPhotoUrl,
    String? receiverId,
    String? receiverName,
    String? receiverPhotoUrl,
    CallType? type,
    CallStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? duration,
    String? chatRoomId,
    DateTime? expireAt,
  }) {
    return Call(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhotoUrl: callerPhotoUrl ?? this.callerPhotoUrl,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhotoUrl: receiverPhotoUrl ?? this.receiverPhotoUrl,
      type: type ?? this.type,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      expireAt: expireAt ?? this.expireAt,
    );
  }
}
