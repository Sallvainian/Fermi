import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../providers/discussion_provider_simple.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/models/user_model.dart';

class ThreadDetailScreen extends StatefulWidget {
  final String boardId;
  final String threadId;

  const ThreadDetailScreen({
    super.key,
    required this.boardId,
    required this.threadId,
  });

  @override
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
  final _commentController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  SimpleDiscussionThread? _thread;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThreadAndComments();
  }

  Future<void> _loadThreadAndComments() async {
    try {
      // Load thread details
      final threadDoc = await _firestore
          .collection('discussion_boards')
          .doc(widget.boardId)
          .collection('threads')
          .doc(widget.threadId)
          .get();

      if (threadDoc.exists) {
        setState(() {
          _thread = SimpleDiscussionThread.fromFirestore(threadDoc);
        });
      }

      // Load comments
      final commentsSnapshot = await _firestore
          .collection('discussion_boards')
          .doc(widget.boardId)
          .collection('threads')
          .doc(widget.threadId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .get();

      setState(() {
        _comments = commentsSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });

      // Listen for new comments
      _firestore
          .collection('discussion_boards')
          .doc(widget.boardId)
          .collection('threads')
          .doc(widget.threadId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _comments = snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
          });
        }
      });
    } catch (e) {
      LoggerService.error('Error loading thread',
          tag: 'ThreadDetailScreen', error: e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final userModel = authProvider.userModel;

      // Get the user's display name using the standardized extension
      String authorName = userModel.displayNameOrFallback;

      final userId = authProvider.firebaseUser?.uid ?? '';

      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('discussion_boards')
          .doc(widget.boardId)
          .collection('threads')
          .doc(widget.threadId)
          .collection('comments')
          .add({
        'content': text,
        'authorId': userId,
        'authorName': authorName,
        'createdAt': Timestamp.now(),
      });

      // Update reply count
      await _firestore
          .collection('discussion_boards')
          .doc(widget.boardId)
          .collection('threads')
          .doc(widget.threadId)
          .update({
        'replyCount': FieldValue.increment(1),
      });

      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to add comment',
          tag: 'ThreadDetailScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_thread == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thread')),
        body: const Center(
          child: Text('Thread not found'),
        ),
      );
    }

    return AdaptiveLayout(
      title: 'Discussion',
      showBackButton: true,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Thread header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (_thread!.isPinned) ...[
                              Icon(
                                Icons.push_pin,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                _thread!.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _thread!.content,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              child: Text(
                                _thread!.authorName.isNotEmpty
                                    ? _thread!.authorName[0].toUpperCase()
                                    : '?',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _thread!.authorName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateFormat.format(_thread!.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Comments section
                if (_comments.isNotEmpty) ...[
                  Text(
                    'Comments (${_comments.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._comments.map((comment) => _CommentCard(
                        comment: comment,
                        dateFormat: dateFormat,
                        boardId: widget.boardId,
                        threadId: widget.threadId,
                        onDeleted: _loadThreadAndComments,
                      )),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 48,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No comments yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Be the first to comment!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Comment input
          if (!_thread!.isLocked)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addComment,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'This thread is locked. No new comments allowed.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Map<String, dynamic> comment;
  final DateFormat dateFormat;
  final String boardId;
  final String threadId;
  final VoidCallback onDeleted;

  const _CommentCard({
    required this.comment,
    required this.dateFormat,
    required this.boardId,
    required this.threadId,
    required this.onDeleted,
  });
  
  Future<void> _deleteComment(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .doc(threadId)
          .collection('comments')
          .doc(comment['id'])
          .delete();
      
      // Update reply count
      await FirebaseFirestore.instance
          .collection('discussion_boards')
          .doc(boardId)
          .collection('threads')
          .doc(threadId)
          .update({
        'replyCount': FieldValue.increment(-1),
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted'),
          ),
        );
      }
      onDeleted();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<bool> _showDeleteDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Comment?'),
        content: const Text(
          'Are you sure you want to delete this comment? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.firebaseUser?.uid ?? '';
    final isTeacher = authProvider.userModel?.role == UserRole.teacher;
    final canDelete = isTeacher || comment['authorId'] == currentUserId;
    final createdAt =
        (comment['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final cardContent = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                child: Text(
                  comment['authorName']?.isNotEmpty == true
                      ? comment['authorName'][0].toUpperCase()
                      : '?',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                comment['authorName'] ?? 'Unknown',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateFormat.format(createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () async {
                    if (await _showDeleteDialog(context)) {
                      await _deleteComment(context);
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: theme.colorScheme.error,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment['content'] ?? '',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );

    // Wrap with Dismissible if user can delete
    if (canDelete) {
      return Dismissible(
        key: Key('comment_${comment['id']}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
          ),
        ),
        confirmDismiss: (direction) async {
          return await _showDeleteDialog(context);
        },
        onDismissed: (direction) async {
          await _deleteComment(context);
        },
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onLongPress: () async {
              if (await _showDeleteDialog(context)) {
                await _deleteComment(context);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: cardContent,
          ),
        ),
      );
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: cardContent,
    );
  }
}
