import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/services/webrtc_service.dart';
import '../../domain/models/call.dart';
import '../../../../shared/services/logger_service.dart';

class CallProvider extends ChangeNotifier {
  static const String _tag = 'CallProvider';
  
  final WebRTCService _webrtcService = WebRTCService();
  
  Call? _currentCall;
  Call? _incomingCall;
  StreamSubscription? _incomingCallSubscription;
  
  Call? get currentCall => _currentCall;
  Call? get incomingCall => _incomingCall;
  bool get hasIncomingCall => _incomingCall != null;

  CallProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _webrtcService.initialize();
      _listenForIncomingCalls();
    } catch (e) {
      LoggerService.error('Failed to initialize call provider', tag: _tag, error: e);
    }
  }

  void _listenForIncomingCalls() {
    _incomingCallSubscription = _webrtcService.getIncomingCalls().listen(
      (call) {
        LoggerService.info('Incoming call from ${call.callerName}', tag: _tag);
        _incomingCall = call;
        notifyListeners();
      },
      onError: (error) {
        LoggerService.error('Error listening for incoming calls', tag: _tag, error: error);
      },
    );
  }

  Future<String> startCall({
    required String receiverId,
    required String receiverName,
    required String receiverPhotoUrl,
    required bool isVideoCall,
    String? chatRoomId,
  }) async {
    try {
      final callId = await _webrtcService.startCall(
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPhotoUrl: receiverPhotoUrl,
        isVideoCall: isVideoCall,
        chatRoomId: chatRoomId,
      );
      
      _currentCall = _webrtcService.currentCallState;
      notifyListeners();
      
      return callId;
    } catch (e) {
      LoggerService.error('Failed to start call', tag: _tag, error: e);
      rethrow;
    }
  }

  Future<void> acceptCall(String callId) async {
    try {
      await _webrtcService.acceptCall(callId);
      _currentCall = _webrtcService.currentCallState;
      _incomingCall = null;
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to accept call', tag: _tag, error: e);
      rethrow;
    }
  }

  Future<void> rejectCall(String callId) async {
    try {
      await _webrtcService.rejectCall(callId);
      _incomingCall = null;
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to reject call', tag: _tag, error: e);
      rethrow;
    }
  }

  Future<void> endCall() async {
    try {
      await _webrtcService.endCall();
      _currentCall = null;
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to end call', tag: _tag, error: e);
      rethrow;
    }
  }

  void dismissIncomingCall() {
    _incomingCall = null;
    notifyListeners();
  }

  WebRTCService get webrtcService => _webrtcService;

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _webrtcService.dispose();
    super.dispose();
  }
}