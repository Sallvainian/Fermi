import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/discussion_provider_simple.dart';

class SimpleDiscussionBoardsScreen extends StatefulWidget {
  const SimpleDiscussionBoardsScreen({super.key});

  @override
  State<SimpleDiscussionBoardsScreen> createState() => _SimpleDiscussionBoardsScreenState();
}

class _SimpleDiscussionBoardsScreenState extends State<SimpleDiscussionBoardsScreen> {
  @override
  void initState() {
    super.initState();
    // Load boards when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SimpleDiscussionProvider>().loadBoards();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SimpleDiscussionProvider>();
    final isTeacher = context.watch<AuthProvider>().userModel?.role == UserRole.teacher;

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
          if (provider.error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.boards.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No discussion boards yet',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (isTeacher) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Create the first board to start discussions',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.boards.length,
                        itemBuilder: (context, index) {
                          final board = provider.boards[index];
                          return _BoardCard(board: board);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showCreateBoardDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Discussion Board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Board Title',
                hintText: 'Enter a title for the board',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What is this board about?',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                final provider = context.read<SimpleDiscussionProvider>();
                await provider.createBoard(
                  title: titleController.text,
                  description: descriptionController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
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

class _BoardCard extends StatelessWidget {
  final SimpleDiscussionBoard board;

  const _BoardCard({required this.board});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Select the board in provider
          context.read<SimpleDiscussionProvider>().selectBoard(board);
          
          // Use GoRouter.of to get the router instance
          try {
            GoRouter.of(context).push('/discussions/${board.id}');
          } catch (e) {
            // Fallback to context.go if push fails
            context.go('/discussions/${board.id}');
          }
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
                ],
              ),
              if (board.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  board.description,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${board.threadCount} threads',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(board.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              if (board.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: board.tags.map((tag) => Chip(
                    label: Text(tag),
                    labelStyle: theme.textTheme.labelSmall,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}