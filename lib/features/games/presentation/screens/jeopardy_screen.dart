import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/models/jeopardy_game.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../providers/jeopardy_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../classes/data/services/class_service.dart';
import '../../../classes/domain/models/class_model.dart';

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
                Tab(text: 'Saved Games'),
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
                _buildSavedGamesTab(),
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

  Widget _buildSavedGamesTab() {
    return Consumer<JeopardyProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final savedGames = provider.savedGames;

        if (savedGames.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_outline,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No saved games yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your reusable game templates will appear here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: savedGames.length,
          itemBuilder: (context, index) => _buildSavedGameCard(savedGames[index]),
        );
      },
    );
  }

  Widget _buildActiveGamesTab() {
    return Consumer<JeopardyProvider>(
      builder: (context, provider, child) {
        final activeSessions = provider.activeSessions;

        if (activeSessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_outline,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No active games',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a game from your saved templates',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeSessions.length,
          itemBuilder: (context, index) {
            final session = activeSessions[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.play_arrow, size: 32),
                title: Text('Game Session ${index + 1}'),
                subtitle: Text('Started ${_formatDate(session.startedAt)}'),
                trailing: FilledButton(
                  onPressed: () {
                    // Navigate to active game
                  },
                  child: const Text('Resume'),
                ),
              ),
            );
          },
        );
      },
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
                  const PopupMenuItem(value: 'assign', child: Text('Assign to Classes')),
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

  Widget _buildSavedGameCard(JeopardyGame game) {
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
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bookmark,
                  color: theme.colorScheme.onSecondaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (game.gameMode == GameMode.async)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Async',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${game.categories.length} categories',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (game.doubleJeopardyCategories != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Double Jeopardy: ${game.doubleJeopardyCategories!.length} categories',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    if (game.assignedClassIds.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.class_,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Assigned to ${game.assignedClassIds.length} class${game.assignedClassIds.length == 1 ? '' : 'es'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleGameAction(game, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'play', child: Text('Start Game')),
                  const PopupMenuItem(value: 'assign', child: Text('Assign to Classes')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                      value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(
                    value: 'mode',
                    child: Text(game.gameMode == GameMode.realtime 
                        ? 'Enable Async Mode' 
                        : 'Enable Realtime Mode'),
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
      case 'assign':
        _showAssignToClassesDialog(game);
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
      case 'mode':
        _toggleGameMode(game);
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

  void _showAssignToClassesDialog(JeopardyGame game) {
    showDialog(
      context: context,
      builder: (context) => _ClassAssignmentDialog(game: game),
    );
  }

  void _toggleGameMode(JeopardyGame game) async {
    final provider = context.read<JeopardyProvider>();
    final newMode = game.gameMode == GameMode.realtime 
        ? GameMode.async 
        : GameMode.realtime;
    
    final success = await provider.updateGameMode(game.id, newMode);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Game mode updated to ${newMode.name}'
              : 'Failed to update game mode'),
          backgroundColor: success ? null : Colors.red,
        ),
      );
    }
  }

  void _duplicateGame(JeopardyGame game) async {
    final provider = context.read<JeopardyProvider>();

    // Create a copy with a new title including all data
    final duplicatedGame = JeopardyGame(
      id: '',
      title: 'Copy of ${game.title}',
      teacherId: game.teacherId,
      categories: game.categories,
      doubleJeopardyCategories: game.doubleJeopardyCategories,
      finalJeopardy: game.finalJeopardy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPublic: false,
      gameMode: game.gameMode,
      assignedClassIds: [], // Start with no classes assigned
      dailyDoubles: game.dailyDoubles,
      randomDailyDoubles: game.randomDailyDoubles,
    );

    final gameId = await provider.createGame(duplicatedGame);

    if (mounted) {
      if (gameId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game duplicated successfully')),
        );
        // Navigate to edit the duplicated game
        context.go('/teacher/games/jeopardy/$gameId/edit');
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

// Class Assignment Dialog Widget
class _ClassAssignmentDialog extends StatefulWidget {
  final JeopardyGame game;

  const _ClassAssignmentDialog({required this.game});

  @override
  State<_ClassAssignmentDialog> createState() => _ClassAssignmentDialogState();
}

class _ClassAssignmentDialogState extends State<_ClassAssignmentDialog> {
  final _classService = ClassService();
  List<ClassModel> _availableClasses = [];
  List<String> _selectedClassIds = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedClassIds = List.from(widget.game.assignedClassIds);
    _loadTeacherClasses();
  }

  void _loadTeacherClasses() async {
    final authProvider = context.read<AuthProvider>();
    final teacherId = authProvider.userModel?.uid ?? '';
    
    if (teacherId.isNotEmpty) {
      try {
        final classesStream = _classService.getClassesByTeacher(teacherId);
        classesStream.first.then((classes) {
          if (mounted) {
            setState(() {
              _availableClasses = classes;
              _isLoading = false;
            });
          }
        });
      } catch (e) {
        debugPrint('Error loading classes: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text('Assign "${widget.game.title}" to Classes'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select classes to make this game available to:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_availableClasses.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No classes available'),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: _availableClasses.map((classModel) {
                      final isSelected = _selectedClassIds.contains(classModel.id);
                      return CheckboxListTile(
                        title: Text(classModel.name),
                        subtitle: Text(
                          '${classModel.subject} - ${classModel.studentCount} students',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: isSelected,
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedClassIds.add(classModel.id);
                            } else {
                              _selectedClassIds.remove(classModel.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            if (_selectedClassIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.game.gameMode == GameMode.async
                            ? 'Students can play this game unlimited times for study'
                            : 'Students will play this game together in class',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveAssignments,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Assign (${_selectedClassIds.length})'),
        ),
      ],
    );
  }

  void _saveAssignments() async {
    setState(() {
      _isSaving = true;
    });

    final provider = context.read<JeopardyProvider>();
    final updatedGame = widget.game.copyWith(
      assignedClassIds: _selectedClassIds,
    );

    final success = await provider.updateGame(widget.game.id, updatedGame);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Game assigned to ${_selectedClassIds.length} class${_selectedClassIds.length == 1 ? '' : 'es'}'
              : 'Failed to assign game to classes'),
          backgroundColor: success ? null : Colors.red,
        ),
      );
    }
  }
}
