import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
// Temporarily disabled WebRTC imports - will re-enable when implementing video calling
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../data/services/webrtc_service.dart';
import 'dart:async';

/// Placeholder for call screen - WebRTC implementation pending
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
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerOn = false;
  bool _isConnecting = true;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    // Simulate connection after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
        // Show coming soon message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video calling feature coming soon!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar or video placeholder
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[800],
                    ),
                    child:
                        widget.receiverPhotoUrl != null &&
                            widget.receiverPhotoUrl!.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.receiverPhotoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.white54,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.white54,
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.receiverName ?? 'Unknown User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isConnecting
                        ? 'Connecting...'
                        : 'Video calling coming soon',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  if (_isConnecting)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                ],
              ),
            ),
            // Call controls
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                      });
                    },
                    backgroundColor: _isMuted ? Colors.white24 : Colors.white12,
                  ),
                  // End call button
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: () {
                      context.pop();
                    },
                    backgroundColor: Colors.red,
                    iconColor: Colors.white,
                    size: 64,
                  ),
                  // Video toggle button (for video calls)
                  if (widget.isVideoCall)
                    _buildControlButton(
                      icon: _isVideoEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                      onPressed: () {
                        setState(() {
                          _isVideoEnabled = !_isVideoEnabled;
                        });
                      },
                      backgroundColor: _isVideoEnabled
                          ? Colors.white12
                          : Colors.white24,
                    )
                  else
                    // Speaker button (for voice calls)
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      onPressed: () {
                        setState(() {
                          _isSpeakerOn = !_isSpeakerOn;
                        });
                      },
                      backgroundColor: _isSpeakerOn
                          ? Colors.white24
                          : Colors.white12,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color backgroundColor = Colors.white12,
    Color iconColor = Colors.white,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: backgroundColor),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }
}
