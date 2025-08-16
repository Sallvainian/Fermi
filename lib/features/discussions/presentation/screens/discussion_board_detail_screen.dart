import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../providers/discussion_provider.dart';
import '../widgets/create_thread_dialog.dart';
import 'thread_detail_screen.dart';
import '../../domain/models/discussion_board.dart';

class DiscussionBoardDetailScreen extends StatefulWidget {
  final String boardId;
  final String boardTitle;

  const DiscussionBoardDetailScreen({
    super.key,
    required this.boardId,
    required this.boardTitle,
  });

  @override
  State<DiscussionBoardDetailScreen> createState() =>
      _DiscussionBoardDetailScreenState();
}

class _DiscussionBoardDetailScreenState extends State<DiscussionBoardDetailScreen> {
  String _sortType = 'recent';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscussionProvider>().loadBoardThreads(widget.boardId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      title: widget.boardTitle,
      showBackButton: true,
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              _sortType = value;
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'recent',
              child: Text('Most Recent'),
            ),
            const PopupMenuItem(
              value: 'popular',
              child: Text('Most Popular'),
            ),
            const PopupMenuItem(
              value: 'active',
              child: Text('Most Active'),
            ),
          ],
          icon: const Icon(Icons.sort),
        ),
      ],
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateThreadDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Start New Thread'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildThreadsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadsList() {
    return Consumer<DiscussionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final threads = provider.getBoardThreads(widget.boardId);
        if (threads.isEmpty) {
          return const Center(child: Text('No threads yet. Start one!'));
        }

        List<DiscussionThread> sortedThreads = List.from(threads);
        switch (_sortType) {
          case 'recent':
            sortedThreads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case 'popular':
            sortedThreads.sort((a, b) => b.likeCount.compareTo(a.likeCount));
            break;
          case 'active':
            sortedThreads.sort((a, b) => b.replyCount.compareTo(a.replyCount));
            break;
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sortedThreads.length,
          itemBuilder: (context, index) {
            final thread = sortedThreads[index];
            return _buildThreadCard(
              title: thread.title,
              author: thread.authorName,
              authorRole: thread.authorRole,
              content: thread.content,
              createdAt: thread.createdAt,
              replyCount: thread.replyCount,
              likeCount: thread.likeCount,
              isPinned: thread.isPinned,
              tags: thread.tags,
            );
          },
        );
      },
    );
  }

  Widget _buildThreadCard({
    required String title,
    required String author,
    required String authorRole,
    required String content,
    required DateTime createdAt,
    required int replyCount,
    required int likeCount,
    bool isPinned = false,
    List<String> tags = const [],
  }) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ThreadDetailScreen(
                threadId: 'temp-id',
                boardId: widget.boardId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: authorRole == 'teacher'
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                    child: Text(
                      author[0].toUpperCase(),
                      style: TextStyle(
                        color: authorRole == 'teacher'
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: authorRole == 'teacher'
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                authorRole,
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatTime(createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPinned)
                    Icon(
                      Icons.push_pin,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Content preview
              Text(
                content,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: tags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      labelStyle: theme.textTheme.labelSmall,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              // Stats
              Row(
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$replyCount replies',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.thumb_up_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$likeCount likes',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  void _showCreateThreadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateThreadDialog(boardId: widget.boardId),
    );
  }
}