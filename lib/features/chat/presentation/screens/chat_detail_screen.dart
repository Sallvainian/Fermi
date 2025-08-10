import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../providers/chat_provider.dart';
import '../../domain/models/message.dart';
import '../../data/services/scheduled_messages_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart' as app_auth;

class ChatDetailScreen extends StatefulWidget {
  final String chatRoomId;

  const ChatDetailScreen({
    super.key,
    required this.chatRoomId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  late final ScheduledMessagesService _scheduledMessagesService;

  @override
  void initState() {
    super.initState();
    _scheduledMessagesService = ScheduledMessagesService();
    // Load chat room and messages when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProvider = context.read<ChatProvider>();
      
      try {
        // Find the chat room from the list
        final chatRoom = chatProvider.chatRooms.firstWhere(
          (room) => room.id == widget.chatRoomId,
        );
        chatProvider.setCurrentChatRoom(chatRoom);
      } catch (e) {
        // Try to fetch the chat room directly if not in the list
        try {
          final chatRoom = await chatProvider.getChatRoom(widget.chatRoomId);
          if (chatRoom != null) {
            chatProvider.setCurrentChatRoom(chatRoom);
          }
        } catch (e2) {
          // Failed to load chat room
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Use GoRouter to ensure proper navigation
            if (context.canPop()) {
              context.pop();
            } else {
              // Navigate to messages list if can't pop
              context.go('/messages');
            }
          },
        ),
        title: Consumer<ChatProvider>(
          builder: (context, chatProvider, child) {
            final chatRoom = chatProvider.currentChatRoom;
            final authProvider = context.read<app_auth.AuthProvider>();
            final currentUserId = authProvider.userModel?.uid ?? '';
            
            final displayName = chatRoom?.getDisplayName(currentUserId) ?? 'Chat';
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName),
                if (chatRoom != null && chatRoom.type != 'direct')
                  Text(
                    '${chatRoom.participantIds.length} participants',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () => _startCall(false),
            tooltip: 'Voice Call',
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () => _startCall(true),
            tooltip: 'Video Call',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showChatInfo(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'search':
                  final chatProvider = context.read<ChatProvider>();
                  showSearch(
                    context: context,
                    delegate: ChatSearchDelegate(messages: chatProvider.currentMessages),
                  );
                  break;
                case 'mute':
                  _toggleMuteNotifications();
                  break;
                case 'leave':
                  _leaveChatRoom(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'search',
                child: Text('Search in chat'),
              ),
              const PopupMenuItem(
                value: 'mute',
                child: Text('Mute notifications'),
              ),
              if (context.read<ChatProvider>().currentChatRoom?.type !=
                  'direct')
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('Leave chat'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final messages = chatProvider.currentMessages;
                final error = chatProvider.error;

                if (error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: $error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            chatProvider.loadChatMessages(widget.chatRoomId);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final previousMessage = index < messages.length - 1
                        ? messages[index + 1]
                        : null;

                    final showDate = previousMessage == null ||
                        !_isSameDay(
                            message.timestamp, previousMessage.timestamp);

                    return Column(
                      children: [
                        if (showDate) _buildDateDivider(message.timestamp),
                        _buildMessageBubble(context, message),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          _buildMessageInput(context),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    String dateText;

    if (difference.inDays == 0) {
      dateText = 'Today';
    } else if (difference.inDays == 1) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('EEEE, MMMM d').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            dateText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMe = message.senderId == currentUserId;
    final theme = Theme.of(context);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.attachmentUrl != null) _buildAttachment(message),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
              child: Text(
                DateFormat('HH:mm').format(message.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment(Message message) {
    if (message.attachmentType == 'image' && message.attachmentUrl != null) {
      return GestureDetector(
        onTap: () => _viewFullScreenImage(message.attachmentUrl!),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: const BoxConstraints(
            maxHeight: 200,
            maxWidth: 200,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              message.attachmentUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 100,
                  width: 100,
                  color: Colors.grey[300],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  width: 100,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error_outline),
                );
              },
            ),
          ),
        ),
      );
    }
    
    if (message.attachmentType == 'video' && message.attachmentUrl != null) {
      return GestureDetector(
        onTap: () => _viewFullScreenVideo(message.attachmentUrl!),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: const BoxConstraints(
            maxHeight: 200,
            maxWidth: 300,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video thumbnail placeholder
              Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Center(
                    child: Icon(
                      Icons.video_library,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 48,
                    ),
                  ),
                ),
              ),
              // Play button
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Fallback for non-image/video attachments
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getAttachmentIcon(message.attachmentType),
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text('Attachment'),
        ],
      ),
    );
  }

  IconData _getAttachmentIcon(String? type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      default:
        return Icons.attach_file;
    }
  }

  Widget _buildMessageInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4,
            color: Colors.black.withValues(alpha: 0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _isUploading ? null : _showAttachmentOptions,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'send') {
                _sendMessage();
              } else if (value == 'schedule') {
                _showScheduleMessageDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'send',
                child: ListTile(
                  leading: Icon(Icons.send),
                  title: Text('Send now'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'schedule',
                child: ListTile(
                  leading: Icon(Icons.schedule_send),
                  title: Text('Schedule send'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();

    try {
      await context.read<ChatProvider>().sendMessage(content: message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _showChatInfo(BuildContext context) {
    final chatRoom = context.read<ChatProvider>().currentChatRoom;
    if (chatRoom == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chatRoom.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Type: ${chatRoom.type}'),
            Text('Participants: ${chatRoom.participantIds.length}'),
            if (chatRoom.classId != null) Text('Class ID: ${chatRoom.classId}'),
            const SizedBox(height: 16),
            const Text(
              'Participants:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...chatRoom.participants.map((participant) => ListTile(
                  leading: CircleAvatar(
                    child: Text(participant.name[0].toUpperCase()),
                  ),
                  title: Text(participant.name),
                  subtitle: Text(participant.role),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _startCall(bool isVideoCall) async {
    final chatProvider = context.read<ChatProvider>();
    final chatRoom = chatProvider.currentChatRoom;
    
    if (chatRoom == null) return;
    
    // For direct chats, find the other participant
    if (chatRoom.type == 'direct') {
      final otherParticipant = chatRoom.participants.firstWhere(
        (p) => p.id != FirebaseAuth.instance.currentUser?.uid,
      );
      
      // Fetch receiver's photo URL from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherParticipant.id).get();
      final receiverPhotoUrl = userDoc.data()?['photoUrl'] ?? '';
      
      // Navigate to call screen
      if (mounted) {
        context.push(
          '/call',
          extra: {
            'receiverId': otherParticipant.id,
            'receiverName': otherParticipant.name,
            'receiverPhotoUrl': receiverPhotoUrl,
            'isVideoCall': isVideoCall,
            'chatRoomId': chatRoom.id,
          },
        );
      }
    } else {
      // For group calls, show participant selection or use a different approach
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group calls are not supported yet'),
          ),
        );
      }
    }
  }

  void _leaveChatRoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Chat'),
        content: const Text('Are you sure you want to leave this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close dialog
              Navigator.pop(context);
              // Navigate back to messages list
              context.go('/messages');
              await context
                  .read<ChatProvider>()
                  .leaveChatRoom(widget.chatRoomId);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMuteNotifications() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    List<String> mutedChats = List<String>.from(userDoc.data()?['mutedChats'] ?? []);

    final isCurrentlyMuted = mutedChats.contains(widget.chatRoomId);

    if (isCurrentlyMuted) {
      mutedChats.remove(widget.chatRoomId);
    } else {
      mutedChats.add(widget.chatRoomId);
    }

    await FirebaseFirestore.instance.collection('users').doc(userId).update({'mutedChats': mutedChats});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCurrentlyMuted ? 'Notifications unmuted' : 'Notifications muted'),
        ),
      );
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Photo from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Video from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadAndSendImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadAndSendImage(File imageFile) async {
    // Validate file size (10MB limit)
    const int maxSizeBytes = 10 * 1024 * 1024;
    if (imageFile.lengthSync() > maxSizeBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image is too large. Maximum size is 10MB')),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Create unique filename
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';

      // Upload to Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child(widget.chatRoomId)
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(imageFile);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      // Wait for upload to complete
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Send message with image attachment
      if (mounted) {
        await context.read<ChatProvider>().sendMessage(
              content: _messageController.text.trim().isEmpty
                  ? 'Sent an image'
                  : _messageController.text.trim(),
              attachmentUrl: downloadUrl,
              attachmentType: 'image',
            );

        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        await _uploadAndSendVideo(File(video.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  Future<void> _uploadAndSendVideo(File videoFile) async {
    // Validate file size (100MB limit)
    const int maxSizeBytes = 100 * 1024 * 1024;
    if (videoFile.lengthSync() > maxSizeBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Video is too large. Maximum size is 100MB')),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Compress video using ffmpeg
      final Directory tempDir = await getTemporaryDirectory();
      final String outputPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      // FFmpeg command for video compression
      final command = '-i ${videoFile.path} -c:v libx264 -crf 28 -preset fast -c:a aac -b:a 128k $outputPath';
      
      await FFmpegKit.execute(command).then((session) async {
        final returnCode = await session.getReturnCode();
        
        if (!ReturnCode.isSuccess(returnCode)) {
          throw Exception('Video compression failed');
        }
      });

      final File compressedFile = File(outputPath);

      // Create unique filename
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${compressedFile.path.split('/').last}';

      // Upload to Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child(widget.chatRoomId)
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(compressedFile);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      // Wait for upload to complete
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Send message with video attachment
      if (mounted) {
        await context.read<ChatProvider>().sendMessage(
              content: _messageController.text.trim().isEmpty
                  ? 'Sent a video'
                  : _messageController.text.trim(),
              attachmentUrl: downloadUrl,
              attachmentType: 'video',
            );

        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload video: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  void _viewFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewFullScreenVideo(String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _VideoPlayerScreen(videoUrl: videoUrl),
      ),
    );
  }

  void _showScheduleMessageDialog() {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type a message first'),
        ),
      );
      return;
    }

    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Schedule Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Message: "$message"',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const Text('Select date and time:'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        DateFormat('MMM d, yyyy').format(selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          setState(() {
                            selectedTime = time;
                            selectedDate = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.access_time),
                      label: Text(selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Will be sent: ${DateFormat('MMM d, yyyy at h:mm a').format(selectedDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _scheduleMessage(selectedDate);
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scheduleMessage(DateTime scheduledFor) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await _scheduledMessagesService.scheduleMessage(
        chatRoomId: widget.chatRoomId,
        content: message,
        scheduledFor: scheduledFor,
      );

      _messageController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message scheduled for ${DateFormat('MMM d, h:mm a').format(scheduledFor)}',
            ),
            action: SnackBarAction(
              label: 'View scheduled',
              onPressed: _showScheduledMessages,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule message: $e')),
        );
      }
    }
  }

  void _showScheduledMessages() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scheduled Messages',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<List<ScheduledMessage>>(
                stream: _scheduledMessagesService.getScheduledMessages(widget.chatRoomId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final scheduledMessages = snapshot.data ?? [];

                  if (scheduledMessages.isEmpty) {
                    return const Center(
                      child: Text('No scheduled messages'),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: scheduledMessages.length,
                    itemBuilder: (context, index) {
                      final scheduled = scheduledMessages[index];
                      final message = scheduled.message;

                      return ListTile(
                        title: Text(message.content),
                        subtitle: Text(
                          'Scheduled for: ${DateFormat('MMM d, h:mm a').format(message.scheduledFor!)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await _scheduledMessagesService.cancelScheduledMessage(
                              scheduled.id,
                            );
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Scheduled message cancelled'),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerScreen({required this.videoUrl});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      setState(() {
        _isInitialized = true;
        _controller.play();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    _VideoControlsOverlay(controller: _controller),
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.all(16),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class _VideoControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;

  const _VideoControlsOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        controller.value.isPlaying ? controller.pause() : controller.play();
      },
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 50),
            reverseDuration: const Duration(milliseconds: 200),
            child: controller.value.isPlaying
                ? const SizedBox.shrink()
                : Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 100.0,
                        semanticLabel: 'Play',
                      ),
                    ),
                  ),
          ),
          Positioned(
            bottom: 50,
            left: 16,
            right: 16,
            child: Row(
              children: [
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, VideoPlayerValue value, child) {
                    return Text(
                      _formatDuration(value.position),
                      style: const TextStyle(color: Colors.white),
                    );
                  },
                ),
                const Spacer(),
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, VideoPlayerValue value, child) {
                    return Text(
                      _formatDuration(value.duration),
                      style: const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class ChatSearchDelegate extends SearchDelegate<Message?> {
  final List<Message> messages;

  ChatSearchDelegate({required this.messages});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = messages.where((message) =>
        message.content.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final message = results[index];
        return ListTile(
          title: Text(message.content),
          subtitle: Text(DateFormat('MMM d, h:mm a').format(message.timestamp)),
          onTap: () {
            close(context, message);
          },
        );
      },
    );
  }
}
