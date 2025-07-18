import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/services/webrtc_service.dart';
import '../../domain/models/call.dart';
import 'dart:async';

class CallScreen extends StatefulWidget {
  final String? callId; // For incoming calls
  final String? receiverId; // For outgoing calls
  final String? receiverName;
  final String? receiverPhotoUrl;
  final bool isVideoCall;
  final String? chatRoomId;

  const CallScreen({
    super.key,
    this.callId,
    this.receiverId,
    this.receiverName,
    this.receiverPhotoUrl,
    required this.isVideoCall,
    this.chatRoomId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerOn = false;
  bool _isConnecting = true;
  bool _renderersInitialized = false;
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }
  
  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      setState(() {
        _renderersInitialized = true;
      });
      _initCall();
    } catch (e) {
      debugPrint('Renderer init failed: $e');
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize video renderers')),
        );
      }
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webrtcService.dispose();
    super.dispose();
  }

  Future<void> _initCall() async {
    // Request permissions
    final permissions = [
      Permission.camera,
      Permission.microphone,
    ];
    
    final statuses = await permissions.request();
    
    if (!mounted) return;

    if (statuses[Permission.microphone]!.isDenied ||
        (widget.isVideoCall && statuses[Permission.camera]!.isDenied)) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera and microphone permissions are required for calls'),
        ),
      );
      return;
    }

    // Initialize WebRTC
    await _webrtcService.initialize();
    
    // Set up callbacks
    _webrtcService.onLocalStream = (stream) {
      if (!mounted || !_renderersInitialized) return;
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };
    
    _webrtcService.onRemoteStream = (stream) {
      if (!mounted || !_renderersInitialized) return;
      setState(() {
        _remoteRenderer.srcObject = stream;
        _isConnecting = false;
      });
    };
    
    _webrtcService.onCallStateChanged = (call) {
      if (!mounted) return;
      setState(() {
        if (call.status == CallStatus.accepted && _callTimer == null) {
          _startCallTimer();
        } else if (call.status == CallStatus.ended || 
                   call.status == CallStatus.rejected) {
          _callTimer?.cancel();
          // Navigation is handled in _endCall() method to prevent double pop
        }
      });
    };

    // Start or accept call
    if (widget.callId != null) {
      // Incoming call - accept it
      await _webrtcService.acceptCall(widget.callId!);
    } else if (widget.receiverId != null) {
      // Outgoing call - start it
      await _webrtcService.startCall(
        receiverId: widget.receiverId!,
        receiverName: widget.receiverName!,
        receiverPhotoUrl: widget.receiverPhotoUrl!,
        isVideoCall: widget.isVideoCall,
        chatRoomId: widget.chatRoomId,
      );
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
      });
    });
  }

  void _toggleMute() async {
    await _webrtcService.toggleMute();
    if (!mounted) return;
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleVideo() async {
    await _webrtcService.toggleVideo();
    if (!mounted) return;
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // TODO: Implement speaker toggle
  }

  void _switchCamera() async {
    await _webrtcService.switchCamera();
  }

  void _endCall() async {
    // Cancel timer immediately to prevent further updates
    _callTimer?.cancel();
    
    // End the call and wait for cleanup
    await _webrtcService.endCall();
    
    // Navigate back using GoRouter
    if (!mounted) return;
    context.pop();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.isVideoCall;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video/avatar
          if (isVideoCall)
            Positioned.fill(
              child: _renderersInitialized 
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    placeholderBuilder: (context) => Center(
                      child: _buildUserAvatar(
                        widget.receiverName ?? 'User',
                        widget.receiverPhotoUrl,
                        size: 120,
                      ),
                    ),
                  )
                : Center(
                    child: _buildUserAvatar(
                      widget.receiverName ?? 'User',
                      widget.receiverPhotoUrl,
                      size: 120,
                    ),
                  ),
            )
          else
            Center(
              child: _buildUserAvatar(
                widget.receiverName ?? 'User',
                widget.receiverPhotoUrl,
                size: 120,
              ),
            ),
          
          // Local video (PiP)
          if (isVideoCall && _isVideoEnabled)
            Positioned(
              top: 80,
              right: 20,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _renderersInitialized
                  ? RTCVideoView(
                      _localRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      mirror: true,
                    )
                  : Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
              ),
            ),
          
          // Top bar with call info
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(179),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        widget.receiverName ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isConnecting
                            ? 'Connecting...'
                            : _formatDuration(_callDuration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withAlpha(179),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Speaker button (voice calls only)
                      if (!isVideoCall)
                        _buildControlButton(
                          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                          onPressed: _toggleSpeaker,
                          backgroundColor: _isSpeakerOn ? Colors.white : Colors.white24,
                          iconColor: _isSpeakerOn ? Colors.black : Colors.white,
                        ),
                      
                      // Video toggle (video calls only)
                      if (isVideoCall)
                        _buildControlButton(
                          icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                          onPressed: _toggleVideo,
                          backgroundColor: _isVideoEnabled ? Colors.white24 : Colors.white,
                          iconColor: _isVideoEnabled ? Colors.white : Colors.black,
                        ),
                      
                      // Mute button
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        onPressed: _toggleMute,
                        backgroundColor: _isMuted ? Colors.white : Colors.white24,
                        iconColor: _isMuted ? Colors.black : Colors.white,
                      ),
                      
                      // End call button
                      _buildControlButton(
                        icon: Icons.call_end,
                        onPressed: _endCall,
                        backgroundColor: Colors.red,
                        iconColor: Colors.white,
                        size: 72,
                      ),
                      
                      // Switch camera (video calls only)
                      if (isVideoCall)
                        _buildControlButton(
                          icon: Icons.cameraswitch,
                          onPressed: _switchCamera,
                          backgroundColor: Colors.white24,
                          iconColor: Colors.white,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String name, String? photoUrl, {double size = 48}) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).primaryColor,
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? CachedNetworkImageProvider(photoUrl)
          : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: size / 2,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: IconButton(
        icon: Icon(icon),
        color: iconColor,
        iconSize: size * 0.5,
        onPressed: onPressed,
      ),
    );
  }
}