import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../providers/discussion_provider.dart';

class ThreadDetailScreen extends StatefulWidget {
  final String threadId;
  final String threadTitle;
  final String boardId;

  const ThreadDetailScreen({
    super.key,
    required this.threadId,
    required this.threadTitle,
    required this.boardId,
  });

  @override
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isReplying = false;
  String? _replyingTo;

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      title: 'Thread',
      showBackButton: true,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _buildOriginalPost(),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _buildRepliesSection(),
              ],
            ),
          ),
          if (_isReplying) _buildReplyInput(),
        ],
      ),
      floatingActionButton: !_isReplying
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _isReplying = true;
                  _replyingTo = null;
                });
              },
              icon: const Icon(Icons.reply),
              label: const Text('Reply'),
            )
          : null,
    );
  }

  Widget _buildOriginalPost() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thread title
            Text(
              widget.threadTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Author info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    'S',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Sarah Johnson',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'student',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Posted 2 hours ago',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showPostOptions(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Content
            const Text(
              'Hey everyone! I was wondering if anyone has good study strategies for the midterm. I\'ve been reviewing my notes but I feel like I\'m not retaining the information as well as I\'d like. '
              'Does anyone have tips for effective studying, especially for topics like Chapter 5 and 6? I find those particularly challenging.\n\n'
              'Also, would anyone be interested in forming a study group? We could meet in the library or online.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            // Tags
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    'Question',
                    style: theme.textTheme.labelSmall,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Chip(
                  label: Text(
                    'Study Group',
                    style: theme.textTheme.labelSmall,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.thumb_up_outlined),
                  label: const Text('23'),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isReplying = true;
                      _replyingTo = null;
                    });
                  },
                  icon: const Icon(Icons.reply),
                  label: const Text('Reply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepliesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '15 Replies',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _buildReply(
          author: 'Prof. Smith',
          authorRole: 'teacher',
          content:
              'Great question, Sarah! For Chapters 5 and 6, I recommend using the practice problems at the end of each chapter. '
              'Also, try explaining the concepts to someone else - teaching is one of the best ways to learn.',
          time: '1 hour ago',
          likes: 18,
        ),
        _buildReply(
          author: 'Mike Chen',
          authorRole: 'student',
          content:
              'I\'d love to join a study group! I\'m free Tuesday and Thursday afternoons. '
              'For Chapter 5, I found making flashcards really helpful.',
          time: '45 minutes ago',
          likes: 5,
          replyTo: 'Sarah Johnson',
        ),
        _buildReply(
          author: 'Emily Davis',
          authorRole: 'student',
          content:
              'Count me in for the study group! I\'ve been using the Pomodoro technique - 25 minutes of focused study, then a 5-minute break. '
              'It really helps with retention.',
          time: '30 minutes ago',
          likes: 8,
        ),
      ],
    );
  }

  Widget _buildReply({
    required String author,
    required String authorRole,
    required String content,
    required String time,
    required int likes,
    String? replyTo,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: authorRole == 'teacher'
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                  child: Text(
                    author[0].toUpperCase(),
                    style: TextStyle(
                      color: authorRole == 'teacher'
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            author,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: authorRole == 'teacher'
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              authorRole,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        time,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (replyTo != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  'Replying to @$replyTo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(content),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: Text('$likes'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isReplying = true;
                      _replyingTo = author;
                    });
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: const Text('Reply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInput() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    'Replying to @$_replyingTo',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _replyingTo = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _replyController,
            decoration: InputDecoration(
              hintText: 'Write your reply...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isReplying = false;
                    _replyingTo = null;
                    _replyController.clear();
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _postReply,
                child: const Text('Post Reply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _postReply() async {
    if (_replyController.text.trim().isNotEmpty) {
      final discussionProvider = context.read<DiscussionProvider>();
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      try {
        // Create the reply
        final replyId = await discussionProvider.createReply(
          boardId: widget.boardId,
          threadId: widget.threadId,
          content: _replyController.text.trim(),
          replyToId: null, // If replying to a specific reply, this would be set
          replyToAuthor: _replyingTo, // The name of the person being replied to
        );
        
        // Remove loading dialog
        if (mounted) Navigator.pop(context);
        
        if (replyId != null && mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reply posted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Clear the reply UI
          setState(() {
            _isReplying = false;
            _replyingTo = null;
            _replyController.clear();
          });
        } else if (mounted) {
          // Show error if reply creation failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(discussionProvider.error ?? 'Failed to post reply'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Remove loading dialog if still showing
        if (mounted) Navigator.pop(context);
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error posting reply: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('Save Thread'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thread saved')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share Thread'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report Thread'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}