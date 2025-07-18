import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../shared/services/logger_service.dart';
import '../../domain/models/call.dart';
import '../../../notifications/data/services/notification_service.dart';

/// Service for handling WebRTC signaling through Firebase Realtime Database
class WebRTCSignalingService {
  static const String _tag = 'WebRTCSignalingService';
  
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  
  // Signaling paths in Firebase
  static const String _callsPath = 'calls';
  static const String _incomingCallsPath = 'incoming_calls';
  
  // Stream subscriptions
  final Map<String, StreamSubscription> _subscriptions = {};
  
  // Callbacks
  Function(Call call)? onIncomingCall;
  Function(String callId, RTCSessionDescription offer)? onOffer;
  Function(String callId, RTCSessionDescription answer)? onAnswer;
  Function(String callId, RTCIceCandidate candidate)? onIceCandidate;
  Function(String callId)? onCallEnded;
  
  /// Initialize signaling service
  Future<void> initialize() async {
    await _notificationService.initialize();
    _listenForIncomingCalls();
  }
  
  /// Clean up resources
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
  
  /// Listen for incoming calls
  void _listenForIncomingCalls() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    // Cancel existing subscription if any
    _subscriptions['incoming_calls']?.cancel();
    
    // Listen for calls where we are the callee
    _subscriptions['incoming_calls'] = _database
        .ref('$_incomingCallsPath/$userId')
        .onChildAdded
        .listen((DatabaseEvent event) async {
      try {
        final data = event.snapshot.value as Map?;
        if (data == null) return;
        
        final callId = event.snapshot.key;
        if (callId == null) return;
        
        // Create Call object from data
        final call = Call(
          id: callId,
          callerId: data['callerId'] as String,
          callerName: data['callerName'] as String? ?? 'Unknown Caller',
          callerPhotoUrl: data['callerPhotoUrl'] as String? ?? '',
          receiverId: userId,
          receiverName: data['calleeName'] as String? ?? 'You',
          receiverPhotoUrl: data['calleePhotoUrl'] as String? ?? '',
          type: (data['isVideo'] as bool? ?? false) ? CallType.video : CallType.voice,
          status: CallStatus.ringing,
          startedAt: DateTime.fromMillisecondsSinceEpoch(
              data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
          chatRoomId: data['chatRoomId'] as String?,
        );
        
        // Show notification
        await _notificationService.showIncomingCall(call);
        
        // Notify listeners
        onIncomingCall?.call(call);
        
        // Listen for this specific call's signaling data
        _listenToCallSignaling(callId);
        
        // Remove from incoming calls queue
        await event.snapshot.ref.remove();
        
      } catch (e) {
        LoggerService.error('Error processing incoming call', error: e, tag: _tag);
      }
    });
  }
  
  /// Initiate a call
  Future<String> initiateCall({
    required String calleeId,
    required bool isVideo,
    String? calleeName,
  }) async {
    final userId = _auth.currentUser?.uid;
    final userDisplayName = _auth.currentUser?.displayName;
    final userPhotoUrl = _auth.currentUser?.photoURL;
    
    if (userId == null) throw Exception('User not authenticated');
    
    // Generate unique call ID
    final callId = _database.ref().child(_callsPath).push().key;
    if (callId == null) throw Exception('Failed to generate call ID');
    
    // Create call data
    final callData = {
      'callId': callId,
      'callerId': userId,
      'callerName': userDisplayName,
      'callerPhotoUrl': userPhotoUrl,
      'calleeId': calleeId,
      'calleeName': calleeName,
      'isVideo': isVideo,
      'isGroupCall': false,
      'participants': [userId, calleeId],
      'timestamp': ServerValue.timestamp,
      'status': 'initiating',
    };
    
    // Save call data
    await _database.ref('$_callsPath/$callId').set(callData);
    
    // Notify callee
    await _database.ref('$_incomingCallsPath/$calleeId/$callId').set({
      ...callData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Listen for signaling on this call
    _listenToCallSignaling(callId);
    
    return callId;
  }
  
  /// Send offer
  Future<void> sendOffer(String callId, RTCSessionDescription offer) async {
    await _database.ref('$_callsPath/$callId/offer').set({
      'sdp': offer.sdp,
      'type': offer.type,
      'timestamp': ServerValue.timestamp,
    });
  }
  
  /// Send answer
  Future<void> sendAnswer(String callId, RTCSessionDescription answer) async {
    await _database.ref('$_callsPath/$callId/answer').set({
      'sdp': answer.sdp,
      'type': answer.type,
      'timestamp': ServerValue.timestamp,
    });
  }
  
  /// Send ICE candidate
  Future<void> sendIceCandidate(String callId, RTCIceCandidate candidate) async {
    final candidateData = {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
      'timestamp': ServerValue.timestamp,
    };
    
    await _database
        .ref('$_callsPath/$callId/iceCandidates')
        .push()
        .set(candidateData);
  }
  
  /// End call
  Future<void> endCall(String callId) async {
    // Update call status
    await _database.ref('$_callsPath/$callId/status').set('ended');
    await _database.ref('$_callsPath/$callId/endTime').set(ServerValue.timestamp);
    
    // Clean up notifications
    await _notificationService.endCall(callId);
    
    // Cancel subscriptions for this call
    _cancelCallSubscriptions(callId);
    
    // Notify listeners
    onCallEnded?.call(callId);
  }
  
  /// Listen to signaling data for a specific call
  void _listenToCallSignaling(String callId) {
    final callRef = _database.ref('$_callsPath/$callId');
    
    // Listen for offer
    _subscriptions['offer_$callId'] = callRef
        .child('offer')
        .onValue
        .listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null && data['sdp'] != null) {
        final offer = RTCSessionDescription(
          data['sdp'] as String,
          data['type'] as String?,
        );
        onOffer?.call(callId, offer);
      }
    });
    
    // Listen for answer
    _subscriptions['answer_$callId'] = callRef
        .child('answer')
        .onValue
        .listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null && data['sdp'] != null) {
        final answer = RTCSessionDescription(
          data['sdp'] as String,
          data['type'] as String?,
        );
        onAnswer?.call(callId, answer);
      }
    });
    
    // Listen for ICE candidates
    _subscriptions['ice_$callId'] = callRef
        .child('iceCandidates')
        .onChildAdded
        .listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null && data['candidate'] != null) {
        final candidate = RTCIceCandidate(
          data['candidate'] as String,
          data['sdpMid'] as String?,
          data['sdpMLineIndex'] as int?,
        );
        onIceCandidate?.call(callId, candidate);
      }
    });
    
    // Listen for call end
    _subscriptions['status_$callId'] = callRef
        .child('status')
        .onValue
        .listen((DatabaseEvent event) {
      final status = event.snapshot.value as String?;
      if (status == 'ended') {
        onCallEnded?.call(callId);
        _cancelCallSubscriptions(callId);
      }
    });
  }
  
  /// Cancel subscriptions for a specific call
  void _cancelCallSubscriptions(String callId) {
    _subscriptions['offer_$callId']?.cancel();
    _subscriptions['answer_$callId']?.cancel();
    _subscriptions['ice_$callId']?.cancel();
    _subscriptions['status_$callId']?.cancel();
    
    _subscriptions.remove('offer_$callId');
    _subscriptions.remove('answer_$callId');
    _subscriptions.remove('ice_$callId');
    _subscriptions.remove('status_$callId');
  }
  
  /// Accept incoming call
  Future<void> acceptCall(String callId) async {
    await _database.ref('$_callsPath/$callId/status').set('accepted');
  }
  
  /// Decline incoming call
  Future<void> declineCall(String callId) async {
    await _database.ref('$_callsPath/$callId/status').set('declined');
    await _notificationService.endCall(callId);
    _cancelCallSubscriptions(callId);
  }
  
  /// Get call data
  Future<Map<String, dynamic>?> getCallData(String callId) async {
    final snapshot = await _database.ref('$_callsPath/$callId').get();
    return snapshot.value as Map<String, dynamic>?;
  }
  
  /// Update call status
  Future<void> updateCallStatus(String callId, String status) async {
    await _database.ref('$_callsPath/$callId/status').set(status);
  }
}