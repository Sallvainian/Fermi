import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/services/webrtc_service.dart';
import '../../domain/models/call.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../notifications/data/services/firebase_messaging_service.dart';

class CallProvider extends ChangeNotifier {
  static const String _tag = 'CallProvider';
  
  final WebRTCService _webrtcService = WebRTCService();
  
  Call? _currentCall;
  Call? _incomingCall;
  StreamSubscription? _incomingCallSubscription;
  bool _isNavigationInProgress = false;
  
  Call? get currentCall => _currentCall;
  Call? get incomingCall => _incomingCall;
  bool get hasIncomingCall => _incomingCall != null;
  bool get isNavigationInProgress => _isNavigationInProgress;

  CallProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _webrtcService.initialize();
      _listenForIncomingCalls();
      _setupNotificationHandlers();
      _setupFirebaseMessagingHandlers();
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
    } on WebRTCException catch (e) {
      LoggerService.error('WebRTC error starting call: ${e.userFriendlyMessage}', tag: _tag, error: e);
      rethrow;
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
      _isNavigationInProgress = false;
      notifyListeners();
    } on WebRTCException catch (e) {
      LoggerService.error('WebRTC error accepting call: ${e.userFriendlyMessage}', tag: _tag, error: e);
      rethrow;
    } catch (e) {
      LoggerService.error('Failed to accept call', tag: _tag, error: e);
      rethrow;
    }
  }

  Future<void> rejectCall(String callId) async {
    try {
      await _webrtcService.rejectCall(callId);
      _incomingCall = null;
      _isNavigationInProgress = false;
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
    _isNavigationInProgress = false;
    notifyListeners();
  }

  void setNavigationInProgress(bool inProgress) {
    _isNavigationInProgress = inProgress;
    notifyListeners();
  }

  WebRTCService get webrtcService => _webrtcService;

  void _setupNotificationHandlers() {
    final notificationService = NotificationService();
    
    // Handle call accepted from notification
    notificationService.onCallAccepted = (callId) {
      LoggerService.info('Call accepted from notification: $callId', tag: _tag);
      acceptCall(callId);
    };
    
    // Handle call declined from notification
    notificationService.onCallDeclined = (callId) {
      LoggerService.info('Call declined from notification: $callId', tag: _tag);
      rejectCall(callId);
    };
  }
  
  void _setupFirebaseMessagingHandlers() {
    final messagingService = FirebaseMessagingService();
    
    // Handle incoming VoIP call from FCM
    messagingService.onIncomingCall = (call) {
      LoggerService.info('Incoming VoIP call from FCM: ${call.callerName}', tag: _tag);
      _incomingCall = call;
      notifyListeners();
      
      // Show notification
      final notificationService = NotificationService();
      notificationService.showIncomingCall(call);
    };
  }
  
  Future<String> startCallWithNotification({
    required String receiverId,
    required String receiverName,
    required String receiverPhotoUrl,
    required bool isVideoCall,
    String? chatRoomId,
  }) async {
    try {
      // Start the call
      final callId = await startCall(
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPhotoUrl: receiverPhotoUrl,
        isVideoCall: isVideoCall,
        chatRoomId: chatRoomId,
      );
      
      // Send push notification to receiver
      final messagingService = FirebaseMessagingService();
      await messagingService.sendCallNotification(
        receiverId: receiverId,
        callId: callId,
        callerName: _webrtcService.currentUserName,
        isVideo: isVideoCall,
        callerPhotoUrl: _webrtcService.currentUserPhoto,
        chatRoomId: chatRoomId,
      );
      
      return callId;
    } catch (e) {
      LoggerService.error('Failed to start call with notification', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _webrtcService.dispose();
    super.dispose();
  }
}