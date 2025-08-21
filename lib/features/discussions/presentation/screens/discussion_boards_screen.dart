import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/models/discussion_board.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/discussion_provider.dart';
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
      context.read<DiscussionProvider>().initializeBoards();
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
          Expanded(
            child: _buildBoardsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardsList() {
    return Consumer<DiscussionProvider>(
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

  Widget _buildBoardCard({required DiscussionBoard board}) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: () {
          // Set current board in provider
          context.read<DiscussionProvider>().setCurrentBoard(board);

          context.go(
              '/discussions/${board.id}?title=${Uri.encodeComponent(board.title)}');
        },
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
                      style: theme.textTheme.labelSmall,
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
                      label: Text(
                        tag,
                        style: theme.textTheme.labelSmall,
                      ),
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
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatLastActivity(board.updatedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'by ${board.createdByName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
}
