import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/call.dart';
import '../../../../shared/services/logger_service.dart';

class WebRTCService {
  static const String _tag = 'WebRTCService';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // WebRTC configuration
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  final Map<String, dynamic> _offerSdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  
  // Call state
  String? _currentCallId;
  Call? _currentCall;
  bool _isCaller = false;
  
  // Callbacks
  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function(Call call)? onCallStateChanged;
  
  // Stream controllers
  final BehaviorSubject<Call?> _callStateController = BehaviorSubject<Call?>();
  Stream<Call?> get callStateStream => _callStateController.stream;
  Call? get currentCallState => _callStateController.value;

  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserName => _auth.currentUser?.displayName ?? 'Unknown';
  String get currentUserPhoto => _auth.currentUser?.photoURL ?? '';

  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    LoggerService.info('WebRTC service initialized', tag: _tag);
  }

  Future<void> dispose() async {
    await _cleanUp();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _callStateController.close();
    LoggerService.info('WebRTC service disposed', tag: _tag);
  }

  Future<MediaStream> _getUserMedia(bool isVideoCall) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideoCall
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };

    try {
      final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      return stream;
    } catch (e) {
      LoggerService.error('Failed to get user media', tag: _tag, error: e);
      rethrow;
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(_configuration);
      
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (_currentCallId != null) {
          _firestore
              .collection('calls')
              .doc(_currentCallId)
              .collection('candidates')
              .doc(_isCaller ? 'caller' : 'receiver')
              .collection('candidates')
              .add(candidate.toMap());
        }
      };

      _peerConnection!.onAddStream = (MediaStream stream) {
        _remoteStream = stream;
        remoteRenderer.srcObject = stream;
        onRemoteStream?.call(stream);
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        LoggerService.info('Connection state: $state', tag: _tag);
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          endCall();
        }
      };

      LoggerService.info('Peer connection created', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to create peer connection', tag: _tag, error: e);
      rethrow;
    }
  }

  Future<String> startCall({
    required String receiverId,
    required String receiverName,
    required String receiverPhotoUrl,
    required bool isVideoCall,
    String? chatRoomId,
  }) async {
    try {
      _isCaller = true;
      
      // Get user media
      _localStream = await _getUserMedia(isVideoCall);
      localRenderer.srcObject = _localStream;
      onLocalStream?.call(_localStream!);
      
      // Create peer connection
      await _createPeerConnection();
      _peerConnection!.addStream(_localStream!);
      
      // Create call document
      final callRef = _firestore.collection('calls').doc();
      _currentCallId = callRef.id;
      
      final call = Call(
        id: _currentCallId!,
        callerId: currentUserId,
        callerName: currentUserName,
        callerPhotoUrl: currentUserPhoto,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPhotoUrl: receiverPhotoUrl,
        type: isVideoCall ? CallType.video : CallType.voice,
        status: CallStatus.ringing,
        startedAt: DateTime.now(),
        chatRoomId: chatRoomId,
      );
      
      await callRef.set(call.toMap());
      _currentCall = call;
      _callStateController.add(call);
      onCallStateChanged?.call(call);
      
      // Create offer
      final offer = await _peerConnection!.createOffer(_offerSdpConstraints);
      await _peerConnection!.setLocalDescription(offer);
      
      await callRef.update({
        'offer': offer.toMap(),
      });
      
      // Listen for answer
      callRef.snapshots().listen((snapshot) async {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          
          if (data['answer'] != null && _peerConnection != null) {
            final answer = RTCSessionDescription(
              data['answer']['sdp'],
              data['answer']['type'],
            );
            await _peerConnection!.setRemoteDescription(answer);
          }
          
          if (data['status'] != null) {
            final status = CallStatus.values.firstWhere(
              (e) => e.name == data['status'],
              orElse: () => CallStatus.ended,
            );
            
            if (_currentCall != null) {
              _currentCall = _currentCall!.copyWith(status: status);
              _callStateController.add(_currentCall);
              onCallStateChanged?.call(_currentCall!);
              
              if (status == CallStatus.rejected || status == CallStatus.ended) {
                await endCall();
              }
            }
          }
        }
      });
      
      // Listen for ICE candidates
      _listenForRemoteCandidates();
      
      LoggerService.info('Call started: $_currentCallId', tag: _tag);
      return _currentCallId!;
    } catch (e) {
      LoggerService.error('Failed to start call', tag: _tag, error: e);
      await _cleanUp();
      rethrow;
    }
  }

  Future<void> acceptCall(String callId) async {
    try {
      _isCaller = false;
      _currentCallId = callId;
      
      // Get call document
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (!callDoc.exists) {
        throw Exception('Call not found');
      }
      
      _currentCall = Call.fromMap(callDoc.data()!, callId);
      
      // Get user media
      _localStream = await _getUserMedia(_currentCall!.type == CallType.video);
      localRenderer.srcObject = _localStream;
      onLocalStream?.call(_localStream!);
      
      // Create peer connection
      await _createPeerConnection();
      _peerConnection!.addStream(_localStream!);
      
      // Set remote description from offer
      final offer = RTCSessionDescription(
        callDoc.data()!['offer']['sdp'],
        callDoc.data()!['offer']['type'],
      );
      await _peerConnection!.setRemoteDescription(offer);
      
      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      // Update call document
      await _firestore.collection('calls').doc(callId).update({
        'answer': answer.toMap(),
        'status': CallStatus.accepted.name,
      });
      
      _currentCall = _currentCall!.copyWith(status: CallStatus.accepted);
      _callStateController.add(_currentCall);
      onCallStateChanged?.call(_currentCall!);
      
      // Listen for ICE candidates
      _listenForRemoteCandidates();
      
      LoggerService.info('Call accepted: $callId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to accept call', tag: _tag, error: e);
      await _cleanUp();
      rethrow;
    }
  }

  Future<void> rejectCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.rejected.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      
      await _cleanUp();
      LoggerService.info('Call rejected: $callId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to reject call', tag: _tag, error: e);
    }
  }

  Future<void> endCall() async {
    try {
      if (_currentCallId != null) {
        final endTime = DateTime.now();
        final duration = _currentCall?.startedAt != null
            ? endTime.difference(_currentCall!.startedAt).inSeconds
            : 0;
        
        await _firestore.collection('calls').doc(_currentCallId).update({
          'status': CallStatus.ended.name,
          'endedAt': FieldValue.serverTimestamp(),
          'duration': duration,
        });
      }
      
      await _cleanUp();
      LoggerService.info('Call ended', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to end call', tag: _tag, error: e);
    }
  }

  Future<void> toggleMute() async {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = !track.enabled;
      }
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        track.enabled = !track.enabled;
      }
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        // This method is platform-specific
        Helper.switchCamera(track);
      }
    }
  }

  void _listenForRemoteCandidates() {
    if (_currentCallId == null) return;
    
    final candidatesCollection = _firestore
        .collection('calls')
        .doc(_currentCallId)
        .collection('candidates')
        .doc(_isCaller ? 'receiver' : 'caller')
        .collection('candidates');
    
    candidatesCollection.snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          _peerConnection?.addCandidate(candidate);
        }
      }
    });
  }

  Future<void> _cleanUp() async {
    try {
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localStream?.dispose();
      _localStream = null;
      
      _remoteStream?.getTracks().forEach((track) {
        track.stop();
      });
      _remoteStream?.dispose();
      _remoteStream = null;
      
      await _peerConnection?.close();
      _peerConnection = null;
      
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      
      _currentCallId = null;
      _currentCall = null;
      _isCaller = false;
      
      _callStateController.add(null);
    } catch (e) {
      LoggerService.error('Error during cleanup', tag: _tag, error: e);
    }
  }

  // Check for incoming calls
  Stream<Call> getIncomingCalls() {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Call.fromMap(doc.data(), doc.id))
            .toList())
        .expand((calls) => calls);
  }
}