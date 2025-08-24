import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../../shared/models/user_model.dart';

class SimpleChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String chatTitle;

  const SimpleChatScreen({
    super.key,
    required this.chatRoomId,
    required this.chatTitle,
  });

  @override
  State<SimpleChatScreen> createState() => _SimpleChatScreenState();
}

class _SimpleChatScreenState extends State<SimpleChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Smart navigation: check if we can pop, otherwise go to dashboard
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // Use go_router to navigate to dashboard
              GoRouter.of(context).go('/dashboard');
            }
          },
        ),
        title: Text(widget.chatTitle),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chatRooms')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start chatting!'),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    return _buildMessage(messageData);
                  },
                );
              },
            ),
          ),

          // Upload progress indicator
          if (_isUploading) LinearProgressIndicator(value: _uploadProgress),

          // Input area
          Container(
            padding: const EdgeInsets.all(8),
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
                // Attachment button
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _showAttachmentOptions,
                ),

                // Text field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendTextMessage(),
                  ),
                ),

                // Send button
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendTextMessage,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> messageData) {
    final isMe = messageData['senderId'] == _auth.currentUser?.uid;
    final hasImage = messageData['imageUrl'] != null;
    final hasVideo = messageData['videoUrl'] != null;
    final messageText = messageData['text'] ?? '';
    // Handle server timestamp that hasn't been set yet
    final timestamp = messageData['timestamp'] != null
        ? (messageData['timestamp'] as Timestamp).toDate()
        : DateTime.now(); // Use current time for pending messages

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image display
            if (hasImage) ...[
              _buildImageWidget(messageData['imageUrl']),
              const SizedBox(height: 8),
            ],

            // Video thumbnail
            if (hasVideo) ...[
              _buildVideoThumbnail(messageData['videoUrl']),
              const SizedBox(height: 8),
            ],

            // Text message
            if (messageText.isNotEmpty)
              Text(
                messageText,
                style: TextStyle(
                  color: isMe
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),

            // Timestamp
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(timestamp),
              style: TextStyle(
                fontSize: 11,
                color: isMe
                    ? Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.7)
                    : Theme.of(context)
                        .colorScheme
                        .onSecondaryContainer
                        .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    // For web, use a simple approach that works
    if (kIsWeb) {
      return Container(
        constraints: const BoxConstraints(
          maxHeight: 200,
          maxWidth: 200,
        ),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 200,
              width: 200,
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
            // Fallback: Just show the URL as text for debugging
            return Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[300],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 40),
                  const Text('Image failed to load'),
                  Text(
                    imageUrl,
                    style: const TextStyle(fontSize: 8),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // For mobile platforms
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      height: 200,
      width: 200,
    );
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    return Container(
      height: 200,
      width: 200,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.play_circle_filled,
            color: Colors.white,
            size: 60,
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.black54,
              child: const Text(
                'Video',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Send Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Send Video'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await _firestore
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': _auth.currentUser?.uid,
        'senderName': UserModel(
          uid: _auth.currentUser?.uid ?? '',
          email: _auth.currentUser?.email,
          displayName: _auth.currentUser?.displayName,
        ).displayNameOrFallback,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': null,
        'videoUrl': null,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      // Upload to Firebase Storage
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      debugPrint(
          'DEBUG: Uploading to path: chat_images/${widget.chatRoomId}/$fileName');
      final Reference ref = _storage
          .ref()
          .child('chat_images')
          .child(widget.chatRoomId)
          .child(fileName);

      UploadTask uploadTask;

      if (kIsWeb) {
        // For web, read as bytes
        final Uint8List imageData = await image.readAsBytes();
        uploadTask = ref.putData(imageData);
      } else {
        // For mobile, use file
        final File imageFile = File(image.path);
        uploadTask = ref.putFile(imageFile);
      }

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Send message with image URL
      await _firestore
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .add({
        'text': '',
        'senderId': _auth.currentUser?.uid,
        'senderName': UserModel(
          uid: _auth.currentUser?.uid ?? '',
          email: _auth.currentUser?.email,
          displayName: _auth.currentUser?.displayName,
        ).displayNameOrFallback,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': downloadUrl,
        'videoUrl': null,
      });

      setState(() {
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      // Upload to Firebase Storage
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${video.name}';
      final Reference ref = _storage
          .ref()
          .child('chat_videos')
          .child(widget.chatRoomId)
          .child(fileName);

      UploadTask uploadTask;

      if (kIsWeb) {
        // For web, read as bytes
        final Uint8List videoData = await video.readAsBytes();
        uploadTask = ref.putData(videoData);
      } else {
        // For mobile, use file
        final File videoFile = File(video.path);
        uploadTask = ref.putFile(videoFile);
      }

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Send message with video URL
      await _firestore
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .add({
        'text': '',
        'senderId': _auth.currentUser?.uid,
        'senderName': UserModel(
          uid: _auth.currentUser?.uid ?? '',
          email: _auth.currentUser?.email,
          displayName: _auth.currentUser?.displayName,
        ).displayNameOrFallback,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': null,
        'videoUrl': downloadUrl,
      });

      setState(() {
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload video: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
