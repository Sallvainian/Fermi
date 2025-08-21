import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/models/jeopardy_game.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../providers/jeopardy_provider.dart';

class JeopardyScreen extends StatefulWidget {
  const JeopardyScreen({super.key});

  @override
  State<JeopardyScreen> createState() => _JeopardyScreenState();
}

class _JeopardyScreenState extends State<JeopardyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);

    // Initialize the Jeopardy provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JeopardyProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Jeopardy Games',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewGame,
        icon: const Icon(Icons.add),
        label: const Text('Create Game'),
      ),
      body: Column(
        children: [
          // TabBar
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: 'My Games'),
                Tab(text: 'Public Games'),
                Tab(text: 'Active Games'),
              ],
            ),
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyGamesTab(),
                _buildPublicGamesTab(),
                _buildActiveGamesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyGamesTab() {
    return Consumer<JeopardyProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${provider.error}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => provider.initialize(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final myGames = provider.teacherGames;

        if (myGames.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.grid_view_rounded,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No games created yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first Jeopardy game',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _createNewGame,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Game'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myGames.length,
          itemBuilder: (context, index) => _buildGameCard(myGames[index]),
        );
      },
    );
  }

  Widget _buildPublicGamesTab() {
    return Consumer<JeopardyProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final publicGames = provider.publicGames;

        if (publicGames.isEmpty) {
          return const Center(
            child: Text('No public games available'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: publicGames.length,
          itemBuilder: (context, index) => _buildGameCard(publicGames[index]),
        );
      },
    );
  }

  Widget _buildActiveGamesTab() {
    return const Center(
      child: Text('No active games in progress'),
    );
  }

  Widget _buildGameCard(JeopardyGame game) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openGame(game),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Game icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${game.categories.length} categories',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Updated ${_formatDate(game.updatedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleGameAction(game, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'play', child: Text('Play')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                      value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(
                    value: 'share',
                    child: Text(game.isPublic ? 'Make Private' : 'Make Public'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _createNewGame() {
    context.go('/teacher/games/jeopardy/create');
  }

  void _openGame(JeopardyGame game) {
    context.go('/teacher/games/jeopardy/${game.id}/play');
  }

  void _handleGameAction(JeopardyGame game, String action) {
    switch (action) {
      case 'play':
        _openGame(game);
        break;
      case 'edit':
        context.go('/teacher/games/jeopardy/${game.id}/edit');
        break;
      case 'duplicate':
        _duplicateGame(game);
        break;
      case 'share':
        _togglePublicStatus(game);
        break;
      case 'delete':
        _showDeleteConfirmation(game);
        break;
    }
  }

  void _showDeleteConfirmation(JeopardyGame game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game?'),
        content: Text('Are you sure you want to delete "${game.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              // Capture context-dependent values before async operations
              final navigator = Navigator.of(context);
              final provider = context.read<JeopardyProvider>();
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              navigator.pop();
              final success = await provider.deleteGame(game.id);
              if (!mounted) return;

              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(success
                      ? 'Deleted "${game.title}"'
                      : 'Failed to delete game'),
                  backgroundColor: success ? null : Colors.red,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _togglePublicStatus(JeopardyGame game) async {
    final provider = context.read<JeopardyProvider>();
    final success = await provider.togglePublicStatus(game.id, !game.isPublic);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? (game.isPublic ? 'Made private' : 'Made public')
              : 'Failed to update game visibility'),
          backgroundColor: success ? null : Colors.red,
        ),
      );
    }
  }

  void _duplicateGame(JeopardyGame game) async {
    final provider = context.read<JeopardyProvider>();

    // Create a copy with a new title
    final duplicatedGame = JeopardyGame(
      id: '',
      title: 'Copy of ${game.title}',
      teacherId: game.teacherId,
      categories: game.categories,
      finalJeopardy: game.finalJeopardy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPublic: false,
    );

    final gameId = await provider.createGame(duplicatedGame);

    if (mounted) {
      if (gameId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game duplicated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to duplicate game'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
