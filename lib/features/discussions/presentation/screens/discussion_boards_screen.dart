import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/discussion_provider_simple.dart';
import '../widgets/create_board_dialog.dart';

class DiscussionBoardsScreen extends StatefulWidget {
  const DiscussionBoardsScreen({super.key});

  @override
  State<DiscussionBoardsScreen> createState() => _DiscussionBoardsScreenState();
}

class _DiscussionBoardsScreenState extends State<DiscussionBoardsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize boards when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SimpleDiscussionProvider>().initializeBoards();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher =
        context.watch<AuthProvider>().userModel?.role == UserRole.teacher;

    return AdaptiveLayout(
      title: 'Discussion Boards',
      showBackButton: true,
      actions: [
        if (isTeacher)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateBoardDialog(context),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Join discussions, share ideas, and collaborate with your class',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Expanded(child: _buildBoardsList()),
        ],
      ),
    );
  }

  Widget _buildBoardsList() {
    return Consumer<SimpleDiscussionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.boards.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${provider.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.initializeBoards(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.boards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No discussion boards yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create the first board to start discussions',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics:
              const ClampingScrollPhysics(), // Use Android-style physics for iOS compatibility with Dismissible
          padding: const EdgeInsets.all(16),
          itemCount: provider.boards.length,
          itemBuilder: (context, index) {
            final board = provider.boards[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBoardCard(board: board),
            );
          },
        );
      },
    );
  }

  Widget _buildBoardCard({required SimpleDiscussionBoard board}) {
    final theme = Theme.of(context);
    final isTeacher =
        context.read<AuthProvider>().userModel?.role == UserRole.teacher;

    final cardContent = Card(
      child: InkWell(
        onTap: () {
          // Set current board in provider
          context.read<SimpleDiscussionProvider>().selectBoard(board);

          context.go(
            '/discussions/${board.id}?title=${Uri.encodeComponent(board.title)}',
          );
        },
        onLongPress: isTeacher
            ? () {
                _showDeleteBoardDialog(board);
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (board.isPinned) ...[
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      board.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isTeacher)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteBoardDialog(board);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                color: theme.colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Delete Board',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${board.threadCount} threads',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                board.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (board.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: board.tags.take(3).map((tag) {
                    return Chip(
                      label: Text(tag, style: theme.textTheme.labelSmall),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatLastActivity(board.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'by ${board.createdBy}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Wrap with Dismissible for teachers only
    if (isTeacher) {
      return Dismissible(
        key: Key('board_${board.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await _showDeleteBoardDialog(board);
        },
        onDismissed: (direction) {
          // Deletion is handled in confirmDismiss
        },
        child: cardContent,
      );
    }

    return cardContent;
  }

  String _formatLastActivity(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Active just now';
    } else if (difference.inMinutes < 60) {
      return 'Active ${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return 'Active ${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return 'Active ${difference.inDays} days ago';
    } else {
      return 'Active on ${DateFormat('MMM d').format(date)}';
    }
  }

  void _showCreateBoardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateBoardDialog(),
    );
  }

  Future<bool> _showDeleteBoardDialog(SimpleDiscussionBoard board) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Discussion Board?'),
        content: Text(
          'Are you sure you want to delete "${board.title}"? This will also delete all threads and comments within this board. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(true);
              try {
                // Use direct Firestore call like working comments
                await FirebaseFirestore.instance
                    .collection('discussion_boards')
                    .doc(board.id)
                    .delete();

                // Refresh the boards list
                if (!mounted) return;
                context.read<SimpleDiscussionProvider>().initializeBoards();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Board "${board.title}" deleted')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete board: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
