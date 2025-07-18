import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/services/webrtc_service.dart';
import '../../data/services/webrtc_signaling_service.dart';
import '../../domain/models/call.dart';
import '../../../../shared/services/logger_service.dart';

/// Manages WebRTC calls with Firebase signaling
class WebRTCCallManager extends ChangeNotifier {
  static const String _tag = 'WebRTCCallManager';
  
  final WebRTCService _webrtcService = WebRTCService();
  final WebRTCSignalingService _signalingService = WebRTCSignalingService();
  
  // WebRTC configuration
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Add TURN servers for better connectivity
      // {
      //   'urls': 'turn:your-turn-server.com:3478',
      //   'username': 'username',
      //   'credential': 'password',
      // },
    ],
    'sdpSemantics': 'unified-plan',
  };
  
  // Peer connections map
  final Map<String, RTCPeerConnection> _peerConnections = {};
  
  // Media streams
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  
  // Renderers
  final localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> remoteRenderers = {};
  
  // Call state
  Call? _currentCall;
  bool _isCaller = false;
  
  // Getters
  Call? get currentCall => _currentCall;
  bool get isCaller => _isCaller;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  
  /// Initialize the call manager
  Future<void> initialize() async {
    await localRenderer.initialize();
    await _signalingService.initialize();
    
    // Set up signaling callbacks
    _signalingService.onIncomingCall = _handleIncomingCall;
    _signalingService.onOffer = _handleOffer;
    _signalingService.onAnswer = _handleAnswer;
    _signalingService.onIceCandidate = _handleIceCandidate;
    _signalingService.onCallEnded = _handleCallEnded;
  }
  
  /// Start a call
  Future<void> startCall({
    required String calleeId,
    required bool isVideo,
    String? calleeName,
  }) async {
    try {
      _isCaller = true;
      
      // Initialize local stream
      await _initializeLocalStream(isVideo);
      
      // Initiate call through signaling
      final callId = await _signalingService.initiateCall(
        calleeId: calleeId,
        isVideo: isVideo,
        calleeName: calleeName,
      );
      
      // Create peer connection
      final pc = await _createPeerConnection(callId);
      
      // Add local stream tracks
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          pc.addTrack(track, _localStream!);
        });
      }
      
      // Create offer
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      
      // Send offer through signaling
      await _signalingService.sendOffer(callId, offer);
      
      // Update current call
      _currentCall = Call(
        id: callId,
        callerId: _webrtcService.currentUserId,
        callerName: _webrtcService.currentUserName,
        callerPhotoUrl: _webrtcService.currentUserPhoto,
        receiverId: calleeId,
        receiverName: calleeName ?? 'Unknown',
        receiverPhotoUrl: '', // TODO: Get receiver photo URL
        type: isVideo ? CallType.video : CallType.voice,
        status: CallStatus.ringing,
        startedAt: DateTime.now(),
        chatRoomId: null, // TODO: Add chatRoomId if available
      );
      
      notifyListeners();
      
    } catch (e) {
      LoggerService.error('Failed to start call', error: e, tag: _tag);
      await endCall();
      rethrow;
    }
  }
  
  /// Accept incoming call
  Future<void> acceptCall(Call call) async {
    try {
      _currentCall = call;
      _isCaller = false;
      
      // Initialize local stream
      await _initializeLocalStream(call.isVideo);
      
      // Accept call through signaling
      await _signalingService.acceptCall(call.id);
      
      // Create peer connection
      final pc = await _createPeerConnection(call.id);
      
      // Add local stream tracks
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          pc.addTrack(track, _localStream!);
        });
      }
      
      notifyListeners();
      
    } catch (e) {
      LoggerService.error('Failed to accept call', error: e, tag: _tag);
      await endCall();
      rethrow;
    }
  }
  
  /// Decline incoming call
  Future<void> declineCall(String callId) async {
    await _signalingService.declineCall(callId);
    _cleanup();
  }
  
  /// End current call
  Future<void> endCall() async {
    if (_currentCall != null) {
      await _signalingService.endCall(_currentCall!.id);
    }
    _cleanup();
  }
  
  /// Toggle camera
  Future<void> toggleCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        videoTrack.enabled = !videoTrack.enabled;
        notifyListeners();
      }
    }
  }
  
  /// Toggle microphone
  Future<void> toggleMicrophone() async {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().firstOrNull;
      if (audioTrack != null) {
        audioTrack.enabled = !audioTrack.enabled;
        notifyListeners();
      }
    }
  }
  
  /// Switch camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    }
  }
  
  // Private methods
  
  Future<void> _initializeLocalStream(bool isVideo) async {
    // Request permissions before accessing media
    final permissions = await _requestMediaPermissions(isVideo);
    if (!permissions) {
      throw Exception('Media permissions denied');
    }
    
    final mediaConstraints = {
      'audio': true,
      'video': isVideo ? {
        'facingMode': 'user',
        'width': {'min': 640, 'ideal': 1280, 'max': 1920},
        'height': {'min': 480, 'ideal': 720, 'max': 1080},
      } : false,
    };
    
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
    } catch (e) {
      LoggerService.error('Failed to get user media', error: e, tag: _tag);
      throw Exception('Failed to access camera/microphone: ${e.toString()}');
    }
  }
  
  Future<bool> _requestMediaPermissions(bool isVideo) async {
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
      if (isVideo) {
        var cameraStatus = await Permission.camera.status;
        if (!cameraStatus.isGranted) {
          cameraStatus = await Permission.camera.request();
          if (!cameraStatus.isGranted) {
            LoggerService.error('Camera permission denied', tag: _tag);
            return false;
          }
        }
      }
      
      LoggerService.info('Media permissions granted', tag: _tag);
      return true;
    } catch (e) {
      LoggerService.error('Failed to request media permissions', error: e, tag: _tag);
      return false;
    }
  }
  
  Future<RTCPeerConnection> _createPeerConnection(String callId) async {
    final pc = await createPeerConnection(_configuration);
    _peerConnections[callId] = pc;
    
    // Set up event handlers
    pc.onIceCandidate = (candidate) {
      _signalingService.sendIceCandidate(callId, candidate);
    };
    
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        _remoteStreams[callId] = stream;
        
        // Initialize renderer if needed
        if (!remoteRenderers.containsKey(callId)) {
          final renderer = RTCVideoRenderer();
          renderer.initialize().then((_) {
            renderer.srcObject = stream;
            remoteRenderers[callId] = renderer;
            notifyListeners();
          });
        } else {
          remoteRenderers[callId]!.srcObject = stream;
          notifyListeners();
        }
      }
    };
    
    pc.onConnectionState = (state) {
      LoggerService.info('Connection state: $state', tag: _tag);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // Handle connection failure
        endCall();
      }
    };
    
    return pc;
  }
  
  void _handleIncomingCall(Call call) {
    // This is handled by the CallProvider
    // You can emit an event or update state here if needed
  }
  
  void _handleOffer(String callId, RTCSessionDescription offer) async {
    try {
      final pc = _peerConnections[callId];
      if (pc == null) return;
      
      // Set remote description
      await pc.setRemoteDescription(offer);
      
      // Create answer
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      
      // Send answer through signaling
      await _signalingService.sendAnswer(callId, answer);
      
    } catch (e) {
      LoggerService.error('Failed to handle offer', error: e, tag: _tag);
    }
  }
  
  void _handleAnswer(String callId, RTCSessionDescription answer) async {
    try {
      final pc = _peerConnections[callId];
      if (pc == null) return;
      
      await pc.setRemoteDescription(answer);
      
    } catch (e) {
      LoggerService.error('Failed to handle answer', error: e, tag: _tag);
    }
  }
  
  void _handleIceCandidate(String callId, RTCIceCandidate candidate) async {
    try {
      final pc = _peerConnections[callId];
      if (pc == null) return;
      
      await pc.addCandidate(candidate);
      
    } catch (e) {
      LoggerService.error('Failed to add ICE candidate', error: e, tag: _tag);
    }
  }
  
  void _handleCallEnded(String callId) {
    if (_currentCall?.id == callId) {
      _cleanup();
    }
  }
  
  void _cleanup() {
    // Close peer connections
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();
    
    // Dispose local stream
    _localStream?.dispose();
    _localStream = null;
    
    // Clear remote streams
    _remoteStreams.clear();
    
    // Dispose renderers
    for (final renderer in remoteRenderers.values) {
      renderer.dispose();
    }
    remoteRenderers.clear();
    
    // Reset state
    _currentCall = null;
    _isCaller = false;
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    _cleanup();
    localRenderer.dispose();
    _signalingService.dispose();
    super.dispose();
  }
}