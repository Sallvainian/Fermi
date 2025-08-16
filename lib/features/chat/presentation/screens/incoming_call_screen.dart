import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/models/call.dart';
import '../../data/services/webrtc_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final Call call;

  const IncomingCallScreen({
    super.key,
    required this.call,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final WebRTCService _webrtcService = WebRTCService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _acceptCall() {
    context.pushReplacement(
      '/call',
      extra: {
        'callId': widget.call.id,
        'isVideoCall': widget.call.type == CallType.video,
        'receiverName': widget.call.callerName,
        'receiverPhotoUrl': widget.call.callerPhotoUrl,
        'chatRoomId': widget.call.chatRoomId,
      },
    );
  }

  void _rejectCall() async {
    // Placeholder - actual implementation pending
    await _webrtcService.endCall();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.call.type == CallType.video;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withAlpha(204),
              Theme.of(context).primaryColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Call type
              Column(
                children: [
                  Icon(
                    isVideoCall ? Icons.videocam : Icons.phone,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Incoming ${isVideoCall ? 'Video' : 'Voice'} Call',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              
              // Caller info
              Column(
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.white24,
                      backgroundImage: widget.call.callerPhotoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(widget.call.callerPhotoUrl)
                          : null,
                      child: widget.call.callerPhotoUrl.isEmpty
                          ? Text(
                              widget.call.callerName.isNotEmpty
                                  ? widget.call.callerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 48,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.call.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject button
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.call_end),
                      color: Colors.white,
                      iconSize: 40,
                      onPressed: _rejectCall,
                    ),
                  ),
                  
                  // Accept button
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.call),
                      color: Colors.white,
                      iconSize: 40,
                      onPressed: _acceptCall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}