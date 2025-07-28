import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/models/call.dart';
import '../../../../shared/services/logger_service.dart';

// WebRTC Error Types for better error handling
enum WebRTCErrorType {
  deviceNotFound,
  deviceInUse,
  permissionDenied,
  callTimeout,
  unknown,
}

// Custom WebRTC Exception class
class WebRTCException implements Exception {
  final String message;
  final WebRTCErrorType type;
  
  const WebRTCException(this.message, this.type);
  
  @override
  String toString() => 'WebRTCException: $message';
  
  // User-friendly error messages
  String get userFriendlyMessage {
    switch (type) {
      case WebRTCErrorType.deviceNotFound:
        return message;
      case WebRTCErrorType.deviceInUse:
        return message;
      case WebRTCErrorType.permissionDenied:
        return message;
      case WebRTCErrorType.callTimeout:
        return 'Call timeout. The recipient did not answer.';
      case WebRTCErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

class WebRTCService {
  static const String _tag = 'WebRTCService';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // WebRTC configuration with Unified Plan semantics
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      // STUN servers for discovering public IP
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      // Custom TURN server for production - replace with your server details
      {
        'urls': [
          'turn:your-turn-server-domain:3478?transport=udp',
          'turn:your-turn-server-domain:3478?transport=tcp',
          'turns:your-turn-server-domain:5349?transport=tcp',
        ],
        'username': 'your-username',
        'credential': 'your-credential',
      },
    ],
    'sdpSemantics': 'unified-plan', // Use modern Unified Plan semantics
    'iceCandidatePoolSize': 10, // Pre-gather candidates for faster connection
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
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  
  // Getters for backward compatibility
  RTCVideoRenderer get localRenderer => _localRenderer ??= RTCVideoRenderer();
  RTCVideoRenderer get remoteRenderer => _remoteRenderer ??= RTCVideoRenderer();
  
  // Call state
  String? _currentCallId;
  Call? _currentCall;
  bool _isCaller = false;
  bool _isEndingCall = false;
  Timer? _callTimeoutTimer;
  
  // Call timeout duration (30 seconds)
  static const Duration _callTimeoutDuration = Duration(seconds: 30);
  
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
    // Don't initialize renderers here - will do it conditionally based on call type
    LoggerService.debug('WebRTC service initialized', tag: _tag);
    
    // Clean up any stale calls on startup
    await _cleanupStaleCalls();
  }
  
  // Clean up stale calls that were never ended properly
  Future<void> _cleanupStaleCalls() async {
    try {
      // Find all calls where the current user is involved and still ringing
      final staleCalls = await _firestore
          .collection('calls')
          .where('status', isEqualTo: CallStatus.ringing.name)
          .get();
      
      for (final doc in staleCalls.docs) {
        final callData = doc.data();
        final callId = doc.id;
        
        // Check if this call involves the current user
        if (callData['callerId'] == currentUserId || callData['receiverId'] == currentUserId) {
          // Check if call is stale (older than 60 seconds)
          final startedAt = (callData['startedAt'] as Timestamp?)?.toDate();
          if (startedAt != null) {
            final callAge = DateTime.now().difference(startedAt).inSeconds;
            if (callAge > 60) {
              // Mark as missed/ended
              await doc.reference.update({
                'status': CallStatus.ended.name,
                'endedAt': FieldValue.serverTimestamp(),
                'endReason': 'stale_cleanup',
              });
              LoggerService.info('Cleaned up stale call: $callId (${callAge}s old)', tag: _tag);
            }
          }
        }
      }
    } catch (e) {
      LoggerService.error('Failed to cleanup stale calls', tag: _tag, error: e);
    }
  }
  
  Future<void> _initializeRenderersForVideo() async {
    if (_localRenderer == null) {
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
    }
    if (_remoteRenderer == null) {
      _remoteRenderer = RTCVideoRenderer();
      await _remoteRenderer!.initialize();
    }
    LoggerService.debug('Video renderers initialized', tag: _tag);
  }

  Future<void> dispose() async {
    await _cleanUp();
    await _disposeRenderers();
    await _callStateController.close();
    LoggerService.debug('WebRTC service disposed', tag: _tag);
  }
  
  Future<void> _disposeRenderers() async {
    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
      await _localRenderer!.dispose();
      _localRenderer = null;
    }
    if (_remoteRenderer != null) {
      _remoteRenderer!.srcObject = null;
      await _remoteRenderer!.dispose();
      _remoteRenderer = null;
    }
    LoggerService.debug('Video renderers disposed', tag: _tag);
  }

  Future<MediaStream> _getUserMedia(bool isVideoCall) async {
    // Request permissions before accessing media
    final permissions = await _requestMediaPermissions(isVideoCall);
    if (!permissions) {
      throw WebRTCException('Media permissions denied', WebRTCErrorType.permissionDenied);
    }
    
    // Optimize audio constraints for voice calls
    final Map<String, dynamic> audioConstraints = {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
      'sampleRate': 48000,
      'channelCount': 1, // Mono audio for bandwidth efficiency
    };
    
    final Map<String, dynamic> mediaConstraints = {
      'audio': isVideoCall ? true : audioConstraints, // Use optimized settings for voice-only
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
      
      // Parse specific error types for better user experience
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('could not start video source') || 
          errorString.contains('no video capture device found') ||
          errorString.contains('requested device not found')) {
        throw WebRTCException(
          isVideoCall 
            ? 'No webcam detected. Please connect a camera or switch to voice call.'
            : 'No microphone detected. Please connect a microphone.',
          WebRTCErrorType.deviceNotFound
        );
      } else if (errorString.contains('device in use') || 
                 errorString.contains('could not start audio source')) {
        throw WebRTCException(
          isVideoCall
            ? 'Camera is being used by another application. Please close other apps using the camera and try again.'
            : 'Microphone is being used by another application. Please close other apps using the microphone and try again.',
          WebRTCErrorType.deviceInUse
        );
      } else if (errorString.contains('permission denied') || 
                 errorString.contains('not allowed')) {
        throw WebRTCException(
          'Camera and microphone access denied. Please allow access in your browser settings.',
          WebRTCErrorType.permissionDenied
        );
      } else {
        throw WebRTCException(
          'Failed to access camera/microphone: ${e.toString()}',
          WebRTCErrorType.unknown
        );
      }
    }
  }
  
  Future<bool> _requestMediaPermissions(bool isVideoCall) async {
    try {
      // Request microphone permission (always needed)
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          LoggerService.error('Microphone permission denied', tag: _tag);
          return false;
        }
      }
      
      // Request camera permission if video call
      if (isVideoCall) {
        var cameraStatus = await Permission.camera.status;
        if (!cameraStatus.isGranted) {
          cameraStatus = await Permission.camera.request();
          if (!cameraStatus.isGranted) {
            LoggerService.error('Camera permission denied', tag: _tag);
            return false;
          }
        }
      }
      
      LoggerService.info('Media permissions granted for ${isVideoCall ? "video" : "voice"} call', tag: _tag);
      return true;
    } catch (e) {
      LoggerService.error('Failed to request media permissions', error: e, tag: _tag);
      return false;
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      // Create configuration optimized for call type
      final config = Map<String, dynamic>.from(_configuration);
      
      // For voice-only calls, optimize bandwidth and CPU usage
      if (_currentCall?.type == CallType.voice) {
        config['bundlePolicy'] = 'max-bundle'; // Bundle all media in a single transport
        config['rtcpMuxPolicy'] = 'require'; // Reduce port usage
      }
      
      _peerConnection = await createPeerConnection(config);
      
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

      // Use modern onTrack instead of deprecated onAddStream
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          if (event.streams.isNotEmpty) {
            _remoteStream = event.streams[0];
            // Only set srcObject if this is a video call and renderer is initialized
            if (_currentCall?.type == CallType.video && _remoteRenderer != null) {
              _remoteRenderer!.srcObject = _remoteStream;
            }
            onRemoteStream?.call(_remoteStream!);
          }
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        LoggerService.debug('Connection state: $state', tag: _tag);
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          endCall();
        }
      };

      LoggerService.debug('Peer connection created', tag: _tag);
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
      
      // Initialize renderers if video call
      if (isVideoCall) {
        await _initializeRenderersForVideo();
      }
      
      // Get user media
      _localStream = await _getUserMedia(isVideoCall);
      if (isVideoCall && _localRenderer != null) {
        _localRenderer!.srcObject = _localStream;
      }
      onLocalStream?.call(_localStream!);
      
      // Create peer connection
      await _createPeerConnection();
      
      // Add tracks individually (modern approach for Unified Plan)
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
      
      // Create call document
      final callRef = _firestore.collection('calls').doc();
      _currentCallId = callRef.id;
      
      final now = DateTime.now();
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
        startedAt: now,
        chatRoomId: chatRoomId,
        expireAt: now.add(const Duration(hours: 1)), // TTL: auto-cleanup after 1 hour
      );
      
      await callRef.set(call.toMap());
      _currentCall = call;
      if (!_callStateController.isClosed) {
        _callStateController.add(call);
      }
      onCallStateChanged?.call(call);
      
      // Create offer
      final offer = await _peerConnection!.createOffer(_offerSdpConstraints);
      
      // For voice calls, prefer Opus codec for better quality
      if (!isVideoCall) {
        offer.sdp = _preferOpusCodec(offer.sdp!);
      }
      
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
              if (!_callStateController.isClosed) {
                _callStateController.add(_currentCall);
              }
              onCallStateChanged?.call(_currentCall!);
              
              if (status == CallStatus.rejected || status == CallStatus.ended) {
                _cancelCallTimeoutTimer(); // Cancel timeout when call ends
                await endCall();
              }
            }
          }
        }
      });
      
      // Listen for ICE candidates
      _listenForRemoteCandidates();
      
      // Start call timeout timer
      _startCallTimeoutTimer();
      
      LoggerService.debug('Call started: $_currentCallId', tag: _tag);
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
      
      // Initialize renderers if video call
      final isVideoCall = _currentCall!.type == CallType.video;
      if (isVideoCall) {
        await _initializeRenderersForVideo();
      }
      
      // Get user media
      _localStream = await _getUserMedia(isVideoCall);
      if (isVideoCall && _localRenderer != null) {
        _localRenderer!.srcObject = _localStream;
      }
      onLocalStream?.call(_localStream!);
      
      // Create peer connection
      await _createPeerConnection();
      
      // Add tracks individually (modern approach for Unified Plan)
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
      
      // Set remote description from offer
      final offer = RTCSessionDescription(
        callDoc.data()!['offer']['sdp'],
        callDoc.data()!['offer']['type'],
      );
      await _peerConnection!.setRemoteDescription(offer);
      
      // Create answer
      final answer = await _peerConnection!.createAnswer();
      
      // For voice calls, prefer Opus codec for better quality
      if (!isVideoCall) {
        answer.sdp = _preferOpusCodec(answer.sdp!);
      }
      
      await _peerConnection!.setLocalDescription(answer);
      
      // Update call document
      await _firestore.collection('calls').doc(callId).update({
        'answer': answer.toMap(),
        'status': CallStatus.accepted.name,
      });
      
      _currentCall = _currentCall!.copyWith(status: CallStatus.accepted);
      if (!_callStateController.isClosed) {
        _callStateController.add(_currentCall);
      }
      onCallStateChanged?.call(_currentCall!);
      
      // Listen for ICE candidates
      _listenForRemoteCandidates();
      
      // Cancel timeout timer since call was accepted
      _cancelCallTimeoutTimer();
      
      LoggerService.debug('Call accepted: $callId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to accept call', tag: _tag, error: e);
      await _cleanUp();
      rethrow;
    }
  }

  Future<void> rejectCall(String callId) async {
    try {
      // Cancel timeout timer since call is being rejected
      _cancelCallTimeoutTimer();
      
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.rejected.name,
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': 'rejected',
        'expireAt': FieldValue.serverTimestamp(), // Immediate cleanup for rejected calls
      });
      
      await _cleanUp();
      LoggerService.debug('Call rejected: $callId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to reject call', tag: _tag, error: e);
    }
  }

  Future<void> endCall() async {
    // Prevent duplicate executions
    if (_isEndingCall) {
      return;
    }
    _isEndingCall = true;
    
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
          'endReason': 'user_ended',
          'expireAt': FieldValue.serverTimestamp(), // Immediate cleanup for ended calls
        });
      }
      
      await _cleanUp();
      LoggerService.debug('Call ended', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to end call', tag: _tag, error: e);
    } finally {
      _isEndingCall = false;
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

  // Start call timeout timer
  void _startCallTimeoutTimer() {
    _cancelCallTimeoutTimer(); // Cancel any existing timer
    
    _callTimeoutTimer = Timer(_callTimeoutDuration, () async {
      if (_currentCall?.status == CallStatus.ringing) {
        LoggerService.info('Call timeout reached, ending call', tag: _tag);
        
        // Update call status to timeout
        if (_currentCallId != null) {
          await _firestore.collection('calls').doc(_currentCallId).update({
            'status': CallStatus.ended.name,
            'endedAt': FieldValue.serverTimestamp(),
            'endReason': 'timeout',
            'expireAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Update local call state
        if (_currentCall != null) {
          _currentCall = _currentCall!.copyWith(status: CallStatus.ended);
          if (!_callStateController.isClosed) {
            _callStateController.add(_currentCall);
          }
          onCallStateChanged?.call(_currentCall!);
        }
        
        await _cleanUp();
      }
    });
  }
  
  // Cancel call timeout timer
  void _cancelCallTimeoutTimer() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
  }

  Future<void> _cleanUp() async {
    try {
      // Cancel timeout timer
      _cancelCallTimeoutTimer();
      
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
      
      // Dispose renderers after call ends
      await _disposeRenderers();
      
      _currentCallId = null;
      _currentCall = null;
      _isCaller = false;
      _isEndingCall = false;
      
      // Only emit event if controller is not closed
      if (!_callStateController.isClosed) {
        _callStateController.add(null);
      }
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
            .where((call) {
              // Filter out stale calls (older than 60 seconds)
              final callAge = DateTime.now().difference(call.startedAt).inSeconds;
              if (callAge > 60) {
                LoggerService.debug('Filtering out stale call: ${call.id} (${callAge}s old)', tag: _tag);
                // Mark stale call as missed
                _markCallAsMissed(call.id);
                return false;
              }
              return true;
            })
            .toList())
        .expand((calls) => calls);
  }
  
  // Mark stale call as missed
  Future<void> _markCallAsMissed(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': 'missed',
        'expireAt': FieldValue.serverTimestamp(), // Immediate cleanup for missed calls
      });
      LoggerService.debug('Marked stale call as missed: $callId', tag: _tag);
    } catch (e) {
      LoggerService.error('Failed to mark call as missed', tag: _tag, error: e);
    }
  }
  
  // Prefer Opus codec for better voice quality
  String _preferOpusCodec(String sdp) {
    // Extract Opus codec line
    final lines = sdp.split('\r\n');
    int opusPayload = -1;
    
    // Find Opus codec payload type
    for (final line in lines) {
      if (line.contains('opus/48000')) {
        final match = RegExp(r'a=rtpmap:(\d+)').firstMatch(line);
        if (match != null) {
          opusPayload = int.parse(match.group(1)!);
          break;
        }
      }
    }
    
    if (opusPayload == -1) return sdp; // Opus not found
    
    // Reorder m=audio line to prefer Opus
    final newLines = <String>[];
    for (final line in lines) {
      if (line.startsWith('m=audio')) {
        final parts = line.split(' ');
        final payloads = parts.sublist(3);
        
        // Move Opus to front
        payloads.remove(opusPayload.toString());
        payloads.insert(0, opusPayload.toString());
        
        newLines.add('${parts[0]} ${parts[1]} ${parts[2]} ${payloads.join(' ')}');
      } else {
        newLines.add(line);
      }
    }
    
    return newLines.join('\r\n');
  }
}