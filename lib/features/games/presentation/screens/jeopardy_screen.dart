import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/jeopardy_game.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';

class JeopardyScreen extends StatefulWidget {
  const JeopardyScreen({super.key});

  @override
  State<JeopardyScreen> createState() => _JeopardyScreenState();
}

class _JeopardyScreenState extends State<JeopardyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Mock data for demonstration
  final List<JeopardyGame> _myGames = [
    JeopardyGame(
      id: 'game1',
      title: 'American History Jeopardy',
      teacherId: 'teacher1',
      categories: [
        JeopardyCategory(
          name: 'Presidents',
          questions: [
            JeopardyQuestion(question: 'First president of the United States', answer: 'Who is George Washington?', points: 100),
            JeopardyQuestion(question: 'President during the Civil War', answer: 'Who is Abraham Lincoln?', points: 200),
            JeopardyQuestion(question: 'President who served 4 terms', answer: 'Who is Franklin D. Roosevelt?', points: 300),
            JeopardyQuestion(question: 'Youngest elected president', answer: 'Who is John F. Kennedy?', points: 400),
            JeopardyQuestion(question: 'First president to resign', answer: 'Who is Richard Nixon?', points: 500),
          ],
        ),
        JeopardyCategory(
          name: 'Wars',
          questions: [
            JeopardyQuestion(question: 'War fought from 1861-1865', answer: 'What is the Civil War?', points: 100),
            JeopardyQuestion(question: 'War that began with Pearl Harbor', answer: 'What is World War II?', points: 200),
            JeopardyQuestion(question: 'War for American independence', answer: 'What is the Revolutionary War?', points: 300),
            JeopardyQuestion(question: 'Cold War opponent of the USA', answer: 'What is the Soviet Union?', points: 400),
            JeopardyQuestion(question: 'War sparked by 9/11 attacks', answer: 'What is the War on Terror?', points: 500),
          ],
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      isPublic: true,
    ),
    JeopardyGame(
      id: 'game2',
      title: 'Math Concepts Review',
      teacherId: 'teacher1',
      categories: [
        JeopardyCategory(
          name: 'Algebra',
          questions: [
            JeopardyQuestion(question: 'Value of x in: 2x + 4 = 10', answer: 'What is 3?', points: 100),
            JeopardyQuestion(question: 'Slope of y = 3x + 2', answer: 'What is 3?', points: 200),
            JeopardyQuestion(question: 'Quadratic formula', answer: 'What is x = (-b ± √(b²-4ac))/2a?', points: 300),
            JeopardyQuestion(question: 'Factor: x² - 4', answer: 'What is (x+2)(x-2)?', points: 400),
            JeopardyQuestion(question: 'Solution to |x| = 5', answer: 'What is x = 5 or x = -5?', points: 500),
          ],
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      updatedAt: DateTime.now().subtract(const Duration(days: 14)),
      isPublic: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
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
    if (_myGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
      itemCount: _myGames.length,
      itemBuilder: (context, index) => _buildGameCard(_myGames[index]),
    );
  }

  Widget _buildPublicGamesTab() {
    // Show public games that other teachers have shared
    final publicGames = _myGames.where((game) => game.isPublic).toList();
    
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
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                  const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
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
        // TODO: Implement duplicate
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duplicate feature coming soon')),
        );
        break;
      case 'share':
        // TODO: Toggle public/private
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(game.isPublic ? 'Made private' : 'Made public'),
          ),
        );
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
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Delete game
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${game.title}"')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}