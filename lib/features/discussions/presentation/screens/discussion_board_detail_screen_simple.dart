import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../providers/discussion_provider_simple.dart';

class SimpleDiscussionBoardDetailScreen extends StatefulWidget {
  final String boardId;

  const SimpleDiscussionBoardDetailScreen({
    super.key,
    required this.boardId,
  });

  @override
  State<SimpleDiscussionBoardDetailScreen> createState() => 
      _SimpleDiscussionBoardDetailScreenState();
}

class _SimpleDiscussionBoardDetailScreenState extends State<SimpleDiscussionBoardDetailScreen> {
  @override
  void initState() {
    super.initState();
    LoggerService.debug('DiscussionBoardDetailScreen - initState for boardId: ${widget.boardId}', tag: 'SimpleDiscussionBoardDetailScreen');
    // Load threads for this board
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoggerService.debug('Loading threads for board: ${widget.boardId}', tag: 'SimpleDiscussionBoardDetailScreen');
      context.read<SimpleDiscussionProvider>().loadThreadsForBoard(widget.boardId);
    });
  }

  @override
  Widget build(BuildContext context) {
    LoggerService.debug('DiscussionBoardDetailScreen - building for boardId: ${widget.boardId}', tag: 'SimpleDiscussionBoardDetailScreen');
    final provider = context.watch<SimpleDiscussionProvider>();
    final board = provider.currentBoard;
    final threads = provider.getThreadsForBoard(widget.boardId);
    LoggerService.debug('Current board: ${board?.title}, Threads count: ${threads.length}', tag: 'SimpleDiscussionBoardDetailScreen');

    return AdaptiveLayout(
      title: board?.title ?? 'Discussion Board',
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showCreateThreadDialog(context),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (board != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Created ${DateFormat.yMMMd().format(board.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: threads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.topic_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No threads yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a discussion by creating the first thread',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: threads.length,
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      return _ThreadCard(thread: thread);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCreateThreadDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New Thread'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Thread Title',
                  hintText: 'What would you like to discuss?',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Share your thoughts...',
                ),
                maxLines: 5,
                minLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty && 
                  contentController.text.isNotEmpty) {
                try {
                  await context.read<SimpleDiscussionProvider>().createThread(
                    boardId: widget.boardId,
                    title: titleController.text,
                    content: contentController.text,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create thread: $e'),
                        backgroundColor: Theme.of(dialogContext).colorScheme.error,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _ThreadCard extends StatefulWidget {
  final SimpleDiscussionThread thread;

  const _ThreadCard({required this.thread});

  @override
  State<_ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends State<_ThreadCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navigate to thread detail screen
          context.push('/discussions/${widget.thread.boardId}/thread/${widget.thread.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.thread.isPinned) ...[
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.thread.isLocked) ...[
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      widget.thread.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.thread.content,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text(
                      widget.thread.authorName.isNotEmpty ? widget.thread.authorName[0].toUpperCase() : '?',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.thread.authorName,
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
                    dateFormat.format(widget.thread.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  if (widget.thread.replyCount > 0) ...[
                    Icon(
                      Icons.comment_outlined,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.thread.replyCount}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  if (widget.thread.likeCount > 0) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.thumb_up_outlined,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.thread.likeCount}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}