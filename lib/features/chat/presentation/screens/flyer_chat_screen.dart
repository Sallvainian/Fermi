import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/controllers/firestore_chat_controller.dart';

class FlyerChatScreen extends StatefulWidget {
  final String conversationId;
  final String conversationTitle;

  const FlyerChatScreen({
    super.key,
    required this.conversationId,
    required this.conversationTitle,
  });

  @override
  State<FlyerChatScreen> createState() => _FlyerChatScreenState();
}

class _FlyerChatScreenState extends State<FlyerChatScreen> {
  late FirestoreChatController _controller;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final _uuid = const Uuid();
  bool _isLoading = true;
  final Map<String, User> _userCache = {};

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    _controller = FirestoreChatController(conversationId: widget.conversationId);
    await _controller.initialize();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSendPressed(String text) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final textMessage = TextMessage(
      id: _uuid.v4(),
      authorId: currentUser.uid,
      createdAt: DateTime.now(),
      text: text,
    );

    _controller.sendMessage(textMessage);
    _controller.updateTypingStatus(false); // Stop typing when sending
  }


  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(top: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Color(0xFF8B5CF6)),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _controller.uploadImage(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF8B5CF6)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _controller.uploadImage(source: ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFF8B5CF6)),
              title: const Text('Upload Document'),
              onTap: () {
                Navigator.pop(context);
                _controller.uploadFile();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }



  Future<User> _resolveUser(UserID id) async {
    // Check cache first
    if (_userCache.containsKey(id)) {
      return _userCache[id]!;
    }

    // TODO: Fetch user data from Firestore
    // For now, return a basic user
    final user = User(
      id: id,
      name: 'User $id',
    );
    _userCache[id] = user;
    return user;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    // Get theme colors
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDarkMode = brightness == Brightness.dark;

    // Create Fermi Plus themed chat UI
    final chatTheme = isDarkMode
        ? ChatTheme.dark().copyWith(
            colors: ChatTheme.dark().colors.copyWith(
              primary: const Color(0xFF8B5CF6),
              onPrimary: Colors.white,
            ),
          )
        : ChatTheme.light().copyWith(
            colors: ChatTheme.light().colors.copyWith(
              primary: const Color(0xFF8B5CF6),
              onPrimary: Colors.white,
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversationTitle),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, child) {
                final typingUsers = _controller.getTypingUsers();
                if (typingUsers.isEmpty) {
                  return const SizedBox.shrink();
                }
                final typingText = typingUsers.length == 1
                    ? '${typingUsers.first} is typing...'
                    : '${typingUsers.length} people are typing...';
                return Text(
                  typingText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.normal,
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Chat(
              chatController: _controller,
              currentUserId: currentUser.uid,
              onMessageSend: _handleSendPressed,
              onAttachmentTap: _handleAttachmentPressed,
              resolveUser: _resolveUser,
              theme: chatTheme,
              builders: Builders(
                textMessageBuilder: (context, message, index, {required bool isSentByMe, MessageGroupStatus? groupStatus}) {
                  // Custom text message with read receipts
                  final textMessage = message;

                  // Build status icon
                  Widget? statusIcon;
                  if (isSentByMe) {
                    if (textMessage.failedAt != null) {
                      statusIcon = const Icon(Icons.error, size: 12, color: Colors.red);
                    } else if (textMessage.seenAt != null) {
                      statusIcon = const Icon(Icons.done_all, size: 12, color: Colors.blue);
                    } else if (textMessage.sentAt != null) {
                      statusIcon = const Icon(Icons.done, size: 12, color: Colors.grey);
                    } else {
                      statusIcon = const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      );
                    }
                  }

                  return Container(
                    margin: EdgeInsets.only(
                      left: isSentByMe ? 48 : 0,
                      right: isSentByMe ? 0 : 48,
                      top: 4,
                      bottom: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSentByMe
                                  ? const Color(0xFF8B5CF6)
                                  : isDarkMode
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  textMessage.text,
                                  style: TextStyle(
                                    color: isSentByMe
                                        ? Colors.white
                                        : isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                  ),
                                ),
                                if (statusIcon != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: statusIcon,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}