import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/models/jeopardy_game.dart';
import '../providers/jeopardy_provider.dart';

class JeopardyPlayScreen extends StatefulWidget {
  final String gameId;

  const JeopardyPlayScreen({
    super.key,
    required this.gameId,
  });

  @override
  State<JeopardyPlayScreen> createState() => _JeopardyPlayScreenState();
}

class _JeopardyPlayScreenState extends State<JeopardyPlayScreen> {
  JeopardyGame? _game;
  final List<JeopardyPlayer> _players = [];
  JeopardyQuestion? _selectedQuestion;
  JeopardyCategory? _selectedCategory;
  JeopardyPlayer? _currentPlayer;
  bool _showingAnswer = false;
  bool _gameStarted = false;
  bool _isLoading = true;
  final Map<String, int> _finalJeopardyWagers = {};
  final Map<String, String> _finalJeopardyAnswers = {};
  bool _showingDailyDouble = false;
  int _dailyDoubleWager = 0;
  JeopardyPlayer? _dailyDoublePlayer;

  @override
  void initState() {
    super.initState();
    _loadGame();
    _initializePlayers();
  }

  void _loadGame() async {
    final jeopardyProvider = context.read<JeopardyProvider>();
    final loadedGame = await jeopardyProvider.loadGame(widget.gameId);

    if (loadedGame != null) {
      setState(() {
        _game = loadedGame;
        _isLoading = false;
      });
    } else {
      // Handle error - game not found
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game not found')),
        );
        context.pop();
      }
    }
  }

  void _initializePlayers() {
    // Don't auto-add players - let users set them up
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_game == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load game'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _gameStarted ? _buildGameScreen() : _buildSetupScreen(),
    );
  }

  Widget _buildSetupScreen() {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    'Game Setup',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 32),

            // Game title
            Text(
              _game?.title ?? '',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Players setup
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Teams/Players',
                  style: theme.textTheme.titleLarge,
                ),
                FilledButton.icon(
                  onPressed: _addPlayer,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Team'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Player list
            Expanded(
              child: _players.isEmpty
                  ? Center(
                      child: Text(
                        'Add at least 2 teams to start',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _players.length,
                      itemBuilder: (context, index) =>
                          _buildPlayerSetupTile(_players[index]),
                    ),
            ),

            // Start button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _players.length >= 2 ? _startGame : null,
                child: const Text('Start Game'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSetupTile(JeopardyPlayer player) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPlayerColor(player.id),
          child: Text(
            player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
            style: TextStyle(color: Colors.white),
          ),
        ),
        title: TextFormField(
          initialValue: player.name,
          decoration: const InputDecoration(
            hintText: 'Team name',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              player.name = value;
            });
          },
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _removePlayer(player),
        ),
      ),
    );
  }

  Color _getPlayerColor(String playerId) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    final index = _players.indexWhere((p) => p.id == playerId);
    return colors[index % colors.length];
  }

  void _addPlayer() {
    if (_players.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 teams allowed')),
      );
      return;
    }

    setState(() {
      _players.add(JeopardyPlayer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Team ${_players.length + 1}',
      ));
    });
  }

  void _removePlayer(JeopardyPlayer player) {
    setState(() {
      _players.remove(player);
    });
  }

  void _startGame() {
    if (_players.any((p) => p.name.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter names for all teams')),
      );
      return;
    }

    setState(() {
      _gameStarted = true;
      _currentPlayer = _players.first;
    });
  }

  Widget _buildGameScreen() {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Main game board
        Column(
          children: [
            // Header with game title and controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close),
                    ),
                    Expanded(
                      child: Text(
                        _game?.title ?? '',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: _showScoreboard,
                      icon: const Icon(Icons.leaderboard),
                    ),
                  ],
                ),
              ),
            ),

            // Game board
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildGameBoard(),
              ),
            ),

            // Player scores
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _buildPlayerScores(),
            ),
          ],
        ),

        // Question overlay
        if (_selectedQuestion != null) _buildQuestionOverlay(),
      ],
    );
  }

  Widget _buildGameBoard() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Category headers row
        SizedBox(
          height: 80,
          child: Row(
            children: (_game?.categories ?? [])
                .map((category) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              category.name.toUpperCase(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Questions grid
        Expanded(
          child: Row(
            children: (_game?.categories ?? [])
                .map((category) => Expanded(
                      child: Column(
                        children: category.questions
                            .map((question) => Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    child:
                                        _buildQuestionTile(category, question),
                                  ),
                                ))
                            .toList(),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionTile(
      JeopardyCategory category, JeopardyQuestion question) {
    final theme = Theme.of(context);
    final isAnswered = question.isAnswered;

    return Material(
      color: isAnswered
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isAnswered ? null : () => _selectQuestion(category, question),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isAnswered
                  ? theme.colorScheme.outline.withValues(alpha: 0.3)
                  : theme.colorScheme.primary,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              isAnswered ? '' : '\$${question.points}',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: isAnswered
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                    : theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerScores() {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _players.map((player) {
        final isCurrentPlayer = player == _currentPlayer;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentPlayer
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrentPlayer
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  player.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight:
                        isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${player.score}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: player.score < 0 ? theme.colorScheme.error : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuestionOverlay() {
    final theme = Theme.of(context);

    if (_showingDailyDouble && !_showingAnswer) {
      return _buildDailyDoubleOverlay();
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _closeQuestion,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),

              // Points value (or wager for Daily Double)
              Text(
                _selectedQuestion!.isDailyDouble && _dailyDoubleWager > 0
                    ? '\$$_dailyDoubleWager'
                    : '\$${_selectedQuestion!.points}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Question or Answer
              Text(
                _showingAnswer
                    ? _selectedQuestion!.answer
                    : _selectedQuestion!.question,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Action buttons
              if (!_showingAnswer) ...[
                FilledButton.tonal(
                  onPressed: _showAnswer,
                  child: const Text('Show Answer'),
                ),
              ] else ...[
                Text(
                  _selectedQuestion!.isDailyDouble
                      ? 'Did ${_dailyDoublePlayer!.name} get it right?'
                      : 'Who got it right?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedQuestion!.isDailyDouble) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _scoreDailyDouble(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Correct'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.tonal(
                        onPressed: () => _scoreDailyDouble(false),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Incorrect'),
                      ),
                    ],
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._players.map((player) => FilledButton.tonal(
                            onPressed: () => _awardPoints(player),
                            style: FilledButton.styleFrom(
                              backgroundColor: _getPlayerColor(player.id),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(player.name),
                          )),
                      OutlinedButton(
                        onPressed: () => _scoreQuestion(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onPrimary,
                          side: BorderSide(color: theme.colorScheme.onPrimary),
                        ),
                        child: const Text('No one'),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _selectQuestion(JeopardyCategory category, JeopardyQuestion question) {
    setState(() {
      _selectedQuestion = question;
      _selectedCategory = category;
      _showingAnswer = false;

      // Check if it's a Daily Double
      if (question.isDailyDouble && !_showingDailyDouble) {
        _showingDailyDouble = true;
        // The player who selected the Daily Double (current player with control) is the one who wagers
        _dailyDoublePlayer = _currentPlayer;
        _dailyDoubleWager = 0;
      }
    });
  }

  void _showAnswer() {
    setState(() {
      _showingAnswer = true;
    });
  }

  void _closeQuestion() {
    setState(() {
      _selectedQuestion = null;
      _selectedCategory = null;
      _showingAnswer = false;
      _showingDailyDouble = false;
      _dailyDoubleWager = 0;
      _dailyDoublePlayer = null;
    });
  }

  void _awardPoints(JeopardyPlayer player) {
    if (_selectedQuestion == null) return;

    setState(() {
      // Update score
      player.score += _selectedQuestion!.points;

      // Mark question as answered
      final categoryIndex = _game?.categories.indexOf(_selectedCategory!) ?? -1;
      if (categoryIndex != -1 && _game != null) {
        final questionIndex = _game!.categories[categoryIndex].questions
            .indexOf(_selectedQuestion!);
        _game!.categories[categoryIndex].questions[questionIndex] =
            _selectedQuestion!.copyWith(
          isAnswered: true,
          answeredBy: player.id,
        );
      }

      // Set current player for next selection
      _currentPlayer = player;

      // Close question overlay
      _selectedQuestion = null;
      _selectedCategory = null;
      _showingAnswer = false;
    });

    // Check if game is complete
    _checkGameComplete();
  }

  void _scoreQuestion(bool correct) {
    if (_selectedQuestion == null) return;

    setState(() {
      // Mark question as answered with no winner
      final categoryIndex = _game?.categories.indexOf(_selectedCategory!) ?? -1;
      if (categoryIndex != -1 && _game != null) {
        final questionIndex = _game!.categories[categoryIndex].questions
            .indexOf(_selectedQuestion!);
        _game!.categories[categoryIndex].questions[questionIndex] =
            _selectedQuestion!.copyWith(
          isAnswered: true,
          answeredBy: 'none',
        );
      }

      // Close question overlay
      _selectedQuestion = null;
      _selectedCategory = null;
      _showingAnswer = false;
    });

    // Check if game is complete
    _checkGameComplete();
  }

  void _checkGameComplete() {
    final allAnswered = _game?.categories.every(
          (cat) => cat.questions.every((q) => q.isAnswered),
        ) ??
        false;

    if (allAnswered && _game?.finalJeopardy != null) {
      _startFinalJeopardy();
    } else if (allAnswered) {
      _showGameComplete();
    }
  }

  void _showGameComplete() {
    final winner = _players.reduce((a, b) => a.score > b.score ? a : b);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Winner: ${winner.name} with \$${winner.score}!'),
            const SizedBox(height: 16),
            ...(_players..sort((a, b) => b.score.compareTo(a.score)))
                .map((player) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${player.name}: \$${player.score}'),
                    )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text('End Game'),
          ),
        ],
      ),
    );
  }

  void _showScoreboard() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scoreboard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _players
              .map((player) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(player.name),
                        Text(
                          '\$${player.score}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: player.score < 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyDoubleOverlay() {
    final theme = Theme.of(context);
    final maxWager = max(_dailyDoublePlayer!.score, 1000);

    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DAILY DOUBLE!',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '${_dailyDoublePlayer!.name}, place your wager',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Current score: \$${_dailyDoublePlayer!.score}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              Text(
                'Maximum wager: \$$maxWager',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: TextFormField(
                  initialValue: _dailyDoubleWager.toString(),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                  decoration: InputDecoration(
                    labelText: 'Wager',
                    labelStyle: TextStyle(color: theme.colorScheme.onPrimary),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: theme.colorScheme.onPrimary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: theme.colorScheme.onPrimary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    final wager = int.tryParse(value) ?? 0;
                    setState(() {
                      _dailyDoubleWager = min(wager, maxWager);
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed:
                    _dailyDoubleWager > 0 ? _confirmDailyDoubleWager : null,
                child: const Text('Confirm Wager'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDailyDoubleWager() {
    setState(() {
      _showingDailyDouble = false;
    });
  }

  void _scoreDailyDouble(bool correct) {
    if (_selectedQuestion == null || _dailyDoublePlayer == null) return;

    setState(() {
      // Update score
      if (correct) {
        _dailyDoublePlayer!.score += _dailyDoubleWager;
      } else {
        _dailyDoublePlayer!.score -= _dailyDoubleWager;
      }

      // Mark question as answered
      final categoryIndex = _game?.categories.indexOf(_selectedCategory!) ?? -1;
      if (categoryIndex != -1 && _game != null) {
        final questionIndex = _game!.categories[categoryIndex].questions
            .indexOf(_selectedQuestion!);
        _game!.categories[categoryIndex].questions[questionIndex] =
            _selectedQuestion!.copyWith(
          isAnswered: true,
          answeredBy: _dailyDoublePlayer!.id,
        );
      }

      // Set current player for next selection
      _currentPlayer = _dailyDoublePlayer;

      // Close question overlay
      _selectedQuestion = null;
      _selectedCategory = null;
      _showingAnswer = false;
      _showingDailyDouble = false;
      _dailyDoubleWager = 0;
      _dailyDoublePlayer = null;
    });

    // Check if game is complete
    _checkGameComplete();
  }

  void _startFinalJeopardy() {
    _showFinalJeopardyDialog();
  }

  void _showFinalJeopardyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FinalJeopardyDialog(
        game: _game!,
        players: _players,
        onComplete: (wagers, answers) {
          setState(() {
            _finalJeopardyWagers.clear();
            _finalJeopardyWagers.addAll(wagers);
            _finalJeopardyAnswers.clear();
            _finalJeopardyAnswers.addAll(answers);
          });

          _scoreFinalJeopardy();
        },
      ),
    );
  }

  void _scoreFinalJeopardy() {
    // This would typically be done by the teacher/host
    // For now, we'll show a dialog to score each player
    _showFinalJeopardyScoringDialog();
  }

  void _showFinalJeopardyScoringDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Final Jeopardy Scoring'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Question: ${_game?.finalJeopardy?.question ?? ''}'),
            const SizedBox(height: 8),
            Text('Answer: ${_game?.finalJeopardy?.answer ?? ''}'),
            const SizedBox(height: 16),
            ..._players.map((player) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(player.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                                'Answer: ${_finalJeopardyAnswers[player.id] ?? "No answer"}'),
                            Text(
                                'Wager: \$${_finalJeopardyWagers[player.id] ?? 0}'),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () =>
                                _scoreFinalJeopardyPlayer(player, true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () =>
                                _scoreFinalJeopardyPlayer(player, false),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showGameComplete();
            },
            child: const Text('Finish Game'),
          ),
        ],
      ),
    );
  }

  void _scoreFinalJeopardyPlayer(JeopardyPlayer player, bool correct) {
    setState(() {
      final wager = _finalJeopardyWagers[player.id] ?? 0;
      if (correct) {
        player.score += wager;
      } else {
        player.score -= wager;
      }
    });
  }
}

// Final Jeopardy Dialog
class _FinalJeopardyDialog extends StatefulWidget {
  final JeopardyGame game;
  final List<JeopardyPlayer> players;
  final Function(Map<String, int>, Map<String, String>) onComplete;

  const _FinalJeopardyDialog({
    required this.game,
    required this.players,
    required this.onComplete,
  });

  @override
  State<_FinalJeopardyDialog> createState() => _FinalJeopardyDialogState();
}

class _FinalJeopardyDialogState extends State<_FinalJeopardyDialog> {
  final Map<String, int> _wagers = {};
  final Map<String, String> _answers = {};
  int _currentPlayerIndex = 0;
  bool _showingCategory = true;
  bool _showingWagers = false;
  bool _showingQuestion = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_showingCategory) {
      return AlertDialog(
        backgroundColor: theme.colorScheme.primary,
        title: Text(
          'FINAL JEOPARDY',
          style: TextStyle(color: theme.colorScheme.onPrimary),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Text(
              'Category:',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.game.finalJeopardy!.category.toUpperCase(),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _showingCategory = false;
                _showingWagers = true;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('Continue to Wagers'),
          ),
        ],
      );
    }

    if (_showingWagers && _currentPlayerIndex < widget.players.length) {
      final player = widget.players[_currentPlayerIndex];
      final maxWager = max(0, player.score);

      return AlertDialog(
        title: Text('${player.name}\'s Wager'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current score: \$${player.score}'),
            Text('Maximum wager: \$$maxWager'),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _wagers[player.id]?.toString() ?? '0',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Wager',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final wager = int.tryParse(value) ?? 0;
                setState(() {
                  _wagers[player.id] = min(wager, maxWager);
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _currentPlayerIndex++;
                if (_currentPlayerIndex >= widget.players.length) {
                  _showingWagers = false;
                  _showingQuestion = true;
                }
              });
            },
            child: const Text('Next'),
          ),
        ],
      );
    }

    if (_showingQuestion) {
      return AlertDialog(
        title: const Text('Final Jeopardy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.game.finalJeopardy!.question,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ...widget.players.map((player) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: '${player.name}\'s Answer',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _answers[player.id] = value;
                      });
                    },
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onComplete(_wagers, _answers);
            },
            child: const Text('Submit Answers'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
