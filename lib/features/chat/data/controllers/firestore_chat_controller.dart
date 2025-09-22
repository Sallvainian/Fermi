import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/utils/firestore_thread_safe.dart';

/// Firestore-backed ChatController for Flyer Chat
class FirestoreChatController extends InMemoryChatController
    with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-east4',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final String conversationId;
  StreamSubscription<QuerySnapshot>? _messageSubscription;
  StreamSubscription<QuerySnapshot>? _typingSubscription;
  final Map<String, Message> _messageCache = {};
  final Map<String, Map<String, dynamic>> _typingUsers = {};
  Timer? _typingTimer;
  bool _isTyping = false;

  FirestoreChatController({required this.conversationId}) : super();

  /// Initialize the controller and start listening to messages
  Future<void> initialize() async {
    LoggerService.info(
      'Initializing chat controller for conversation: $conversationId',
      tag: 'FirestoreChatController',
    );

    // Ensure conversation exists before trying to access messages
    await _ensureConversationExists();

    await _loadInitialMessages();
    _startListening();
    _startTypingListener();
    LoggerService.info(
      'Chat controller initialized successfully',
      tag: 'FirestoreChatController',
    );
  }

  /// Ensure the conversation document exists
  Future<void> _ensureConversationExists() async {
    try {
      final conversationRef = _firestore
          .collection('conversations')
          .doc(conversationId);
      final doc = await conversationRef.get();

      if (!doc.exists) {
        // Create minimal conversation document if it doesn't exist
        // This should have been created by FlyerChatScreen, but adding as safety
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId != null) {
          // Parse conversation ID to get participants (format: userId1_userId2)
          final participants = conversationId.split('_');

          await conversationRef.set({
            'participants': participants,
            'participantIds': participants,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'type': 'direct',
          });

          LoggerService.info(
            'Created missing conversation document: $conversationId',
            tag: 'FirestoreChatController',
          );
        }
      }
    } catch (e) {
      LoggerService.error(
        'Error ensuring conversation exists',
        error: e,
        tag: 'FirestoreChatController',
      );
    }
  }

  /// Load initial messages from Firestore
  Future<void> _loadInitialMessages() async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      final messages = snapshot.docs
          .map((doc) => _convertToFlyerMessage(doc))
          .toList();

      // Add messages to controller
      for (final message in messages.reversed) {
        _messageCache[message.id] = message;
      }

      // Set initial messages
      setMessages(messages);
      LoggerService.debug(
        'Loaded ${messages.length} initial messages',
        tag: 'FirestoreChatController',
      );
    } catch (e) {
      LoggerService.error(
        'Error loading messages',
        error: e,
        tag: 'FirestoreChatController',
      );
    }
  }

  /// Start listening to real-time message updates
  void _startListening() {
    _messageSubscription = FirestoreThreadSafe.listen(
      _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      onData: (snapshot) {
        for (final change in snapshot.docChanges) {
          final message = _convertToFlyerMessage(change.doc);

          switch (change.type) {
            case DocumentChangeType.added:
              // Only add if not already in cache (prevents duplicates)
              if (!_messageCache.containsKey(message.id)) {
                _messageCache[message.id] = message;
                insertMessage(message);
              }
              break;

            case DocumentChangeType.modified:
              // Update existing message
              _messageCache[message.id] = message;
              // Message will update via the messages list
              break;

            case DocumentChangeType.removed:
              // Remove message
              final index = messages.indexWhere((m) => m.id == message.id);
              if (index != -1) {
                _messageCache.remove(message.id);
                removeMessage(message);
              }
              break;
          }
        }
      },
      onError: (error) {
        LoggerService.error(
          'Error listening to messages',
          error: error,
          tag: 'FirestoreChatController',
        );
      },
    );
  }

  /// Convert Firestore document to Flyer Chat message
  Message _convertToFlyerMessage(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Determine message status
    DateTime? sentAt;
    DateTime? seenAt;
    DateTime? failedAt;

    if (data['sentAt'] != null) {
      sentAt = (data['sentAt'] as Timestamp).toDate();
    }

    if (data['seenAt'] != null) {
      seenAt = (data['seenAt'] as Timestamp).toDate();
    }

    if (data['failedAt'] != null) {
      failedAt = (data['failedAt'] as Timestamp).toDate();
    }

    // Handle different message types
    final attachments = data['attachments'] as List<dynamic>? ?? [];

    if (attachments.isNotEmpty && attachments[0]['type'] == 'image') {
      // Image message
      return ImageMessage(
        id: doc.id,
        authorId: data['authorId'] ?? '',
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        source: attachments[0]['url'] ?? '',
        sentAt: sentAt,
        seenAt: seenAt,
        failedAt: failedAt,
        metadata: data['metadata'] ?? {},
      );
    } else if (attachments.isNotEmpty && attachments[0]['type'] == 'file') {
      // File message
      return FileMessage(
        id: doc.id,
        authorId: data['authorId'] ?? '',
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        name: attachments[0]['name'] ?? 'File',
        size: attachments[0]['size'] ?? 0,
        source: attachments[0]['url'] ?? '',
        sentAt: sentAt,
        seenAt: seenAt,
        failedAt: failedAt,
        metadata: data['metadata'] ?? {},
      );
    } else {
      // Text message
      return TextMessage(
        id: doc.id,
        authorId: data['authorId'] ?? '',
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        text: data['text'] ?? '',
        sentAt: sentAt,
        seenAt: seenAt,
        failedAt: failedAt,
        metadata: data['metadata'] ?? {},
      );
    }
  }

  /// Start listening to typing indicators
  void _startTypingListener() {
    _typingSubscription = FirestoreThreadSafe.listen(
      _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('typing')
          .snapshots(),
      onData: (snapshot) {
        final currentUserId = _auth.currentUser?.uid;
        _typingUsers.clear();

        for (final doc in snapshot.docs) {
          if (doc.id != currentUserId) {
            _typingUsers[doc.id] = doc.data() as Map<String, dynamic>;
          }
        }

        // Notify UI about typing status changes using thread-safe wrapper
        FirestoreThreadSafe.safeNotify(() => notifyListeners());
      },
      onError: (error) {
        LoggerService.error(
          'Error listening to typing status',
          error: error,
          tag: 'FirestoreChatController',
        );
      },
    );
  }

  /// Get list of currently typing users
  List<String> getTypingUsers() {
    return _typingUsers.entries
        .where((entry) => entry.value['isTyping'] == true)
        .map((entry) => entry.value['userName'] as String? ?? 'Someone')
        .toList();
  }

  /// Update typing status for current user
  Future<void> updateTypingStatus(bool isTyping) async {
    if (_isTyping == isTyping) return; // Avoid unnecessary calls
    _isTyping = isTyping;

    _typingTimer?.cancel();

    try {
      final callable = _functions.httpsCallable('updateTypingStatus');
      await callable.call({
        'conversationId': conversationId,
        'isTyping': isTyping,
      });

      // Reset typing after 5 seconds of inactivity
      if (isTyping) {
        _typingTimer = Timer(const Duration(seconds: 5), () {
          if (_isTyping) {
            updateTypingStatus(false);
          }
        });
      }
    } catch (e) {
      LoggerService.error(
        'Error updating typing status',
        error: e,
        tag: 'FirestoreChatController',
      );
    }
  }

  /// Send message to Firestore
  Future<void> sendMessage(Message message) async {
    // Add sending indicator
    final sendingMessage = _addSendingMetadata(message);
    insertMessage(sendingMessage);

    try {
      // Call Cloud Function to send message
      final callable = _functions.httpsCallable('sendMessage');
      await callable.call({
        'conversationId': conversationId,
        'text': message is TextMessage ? message.text : '',
        'attachments': _extractAttachments(message),
      });

      LoggerService.debug(
        'Message sent successfully: ${message.id}',
        tag: 'FirestoreChatController',
      );
      // Message will be added via the real-time listener
      // Remove the temporary sending message
      final idx = messages.indexWhere((m) => m.id == message.id);
      if (idx != -1) {
        removeMessage(message);
      }
    } on FirebaseFunctionsException catch (error) {
      LoggerService.error(
        'Error sending message',
        error: error,
        tag: 'FirestoreChatController',
      );
      final failedMessage = _addFailedMetadata(message);
      _messageCache[message.id] = failedMessage;
      notifyListeners();
      throw MessageSendException(
        error.message ?? 'Failed to send message.',
        code: error.code,
      );
    } catch (error) {
      LoggerService.error(
        'Error sending message',
        error: error,
        tag: 'FirestoreChatController',
      );
      final failedMessage = _addFailedMetadata(message);
      _messageCache[message.id] = failedMessage;
      notifyListeners();
      throw MessageSendException('Failed to send message.');
    }
  }

  /// Upload image from camera or gallery
  Future<void> uploadImage({required ImageSource source}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Data = base64Encode(bytes);

      // Call cloud function to upload
      final callable = _functions.httpsCallable('uploadChatFile');
      final result = await callable.call({
        'conversationId': conversationId,
        'fileName': image.name,
        'mimeType': 'image/${image.path.split('.').last}',
        'base64Data': base64Data,
        'fileSize': bytes.length,
      });

      LoggerService.info(
        'Image uploaded successfully: ${result.data['fileName']}',
        tag: 'FirestoreChatController',
      );
      // Send message with image attachment
      final imageUrl = result.data['url'] as String;
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final imageMessage = ImageMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        authorId: currentUser.uid,
        createdAt: DateTime.now(),
        source: imageUrl,
      );

      await sendMessage(imageMessage);
    } catch (e) {
      LoggerService.error(
        'Error uploading image',
        error: e,
        tag: 'FirestoreChatController',
      );
    }
  }

  /// Upload file document
  Future<void> uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'csv'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null && file.path == null) return;

      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        final fileData = await XFile(file.path!).readAsBytes();
        bytes = fileData;
      }

      final base64Data = base64Encode(bytes);

      // Determine MIME type
      String mimeType = 'application/octet-stream';
      final extension = file.extension?.toLowerCase();
      if (extension != null) {
        switch (extension) {
          case 'pdf':
            mimeType = 'application/pdf';
            break;
          case 'doc':
            mimeType = 'application/msword';
            break;
          case 'docx':
            mimeType =
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            break;
          case 'xls':
            mimeType = 'application/vnd.ms-excel';
            break;
          case 'xlsx':
            mimeType =
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            break;
          case 'txt':
            mimeType = 'text/plain';
            break;
          case 'csv':
            mimeType = 'text/csv';
            break;
        }
      }

      // Call cloud function to upload
      final callable = _functions.httpsCallable('uploadChatFile');
      final uploadResult = await callable.call({
        'conversationId': conversationId,
        'fileName': file.name,
        'mimeType': mimeType,
        'base64Data': base64Data,
        'fileSize': bytes.length,
      });

      LoggerService.info(
        'File uploaded successfully: ${uploadResult.data['fileName']}',
        tag: 'FirestoreChatController',
      );
      // Send message with file attachment
      final fileUrl = uploadResult.data['url'] as String;
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final fileMessage = FileMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        authorId: currentUser.uid,
        createdAt: DateTime.now(),
        name: file.name,
        size: file.size,
        source: fileUrl,
      );

      await sendMessage(fileMessage);
    } catch (e) {
      LoggerService.error(
        'Error uploading file',
        error: e,
        tag: 'FirestoreChatController',
      );
    }
  }

  /// Load more messages for pagination
  Future<void> loadMoreMessages() async {
    if (messages.isEmpty) return;

    try {
      final lastMessage = messages.last;
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .startAfter([lastMessage.createdAt])
          .limit(30)
          .get();

      final newMessages = snapshot.docs
          .map((doc) => _convertToFlyerMessage(doc))
          .toList();

      for (final message in newMessages) {
        if (!_messageCache.containsKey(message.id)) {
          _messageCache[message.id] = message;
          insertMessage(message);
        }
      }
    } catch (e) {
      LoggerService.error(
        'Error loading more messages',
        error: e,
        tag: 'FirestoreChatController',
      );
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(List<String> messageIds) async {
    try {
      final callable = _functions.httpsCallable('markMessagesAsRead');
      await callable.call({
        'conversationId': conversationId,
        'messageIds': messageIds,
      });
      LoggerService.debug(
        'Marked ${messageIds.length} messages as read',
        tag: 'FirestoreChatController',
      );
    } catch (e) {
      LoggerService.error(
        'Error marking messages as read',
        error: e,
        tag: 'FirestoreChatController',
      );
    }
  }

  /// Add sending metadata to message
  Message _addSendingMetadata(Message message) {
    final metadata = Map<String, dynamic>.from(message.metadata ?? {});
    metadata['sending'] = true;

    if (message is TextMessage) {
      return message.copyWith(metadata: metadata);
    } else if (message is ImageMessage) {
      return message.copyWith(metadata: metadata);
    } else if (message is FileMessage) {
      return message.copyWith(metadata: metadata);
    }
    return message;
  }

  /// Add failed metadata to message
  Message _addFailedMetadata(Message message) {
    if (message is TextMessage) {
      return message.copyWith(failedAt: DateTime.now());
    } else if (message is ImageMessage) {
      return message.copyWith(failedAt: DateTime.now());
    } else if (message is FileMessage) {
      return message.copyWith(failedAt: DateTime.now());
    }
    return message;
  }

  /// Extract attachments from message
  List<Map<String, dynamic>> _extractAttachments(Message message) {
    if (message is ImageMessage) {
      return [
        {'type': 'image', 'url': message.source},
      ];
    } else if (message is FileMessage) {
      return [
        {
          'type': 'file',
          'url': message.source,
          'name': message.name,
          'size': message.size,
        },
      ];
    }
    return [];
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }
}

class MessageSendException implements Exception {
  MessageSendException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() =>
      'MessageSendException(code: ${code ?? 'unknown'}, message: $message)';
}
