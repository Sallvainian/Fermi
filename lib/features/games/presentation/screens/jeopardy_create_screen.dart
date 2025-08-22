import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/models/jeopardy_game.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../providers/jeopardy_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class JeopardyCreateScreen extends StatefulWidget {
  final String? gameId;

  const JeopardyCreateScreen({
    super.key,
    this.gameId,
  });

  @override
  State<JeopardyCreateScreen> createState() => _JeopardyCreateScreenState();
}

class _JeopardyCreateScreenState extends State<JeopardyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  JeopardyGame? _game;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _enableDailyDoubles = true;  // Whether to use Daily Doubles

  @override
  void initState() {
    super.initState();
    _isEditing = widget.gameId != null;
    // Use post frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrCreateGame();
    });
  }

  void _loadOrCreateGame() async {
    final authProvider = context.read<AuthProvider>();
    final jeopardyProvider = context.read<JeopardyProvider>();
    final currentUserId = authProvider.userModel?.uid ?? '';

    if (_isEditing) {
      // Load existing game from Firebase without notifying listeners during build
      final loadedGame = await jeopardyProvider.loadGameWithoutNotify(widget.gameId!);
      if (loadedGame != null && mounted) {
        setState(() {
          _game = loadedGame;
          _titleController.text = _game!.title;
          _isLoading = false;
        });
      } else {
        // Handle error - game not found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Game not found')),
          );
          // Use go instead of pop to avoid navigation errors
          context.go('/teacher/games/jeopardy');
        }
      }
    } else {
      // Create new game with default structure
      setState(() {
        _game = JeopardyGame(
          id: '',
          title: '',
          teacherId: currentUserId,
          categories: [
            JeopardyCategory(
              name: 'Category 1',
              questions: List.generate(
                  5,
                  (index) => JeopardyQuestion(
                        question: '',
                        answer: '',
                        points: (index + 1) * 100,
                      )),
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show loading spinner while game is being loaded/created
    if (_isLoading || _game == null) {
      return AdaptiveLayout(
        title: 'Loading...',
        showBackButton: true,
        onBackPressed: () => context.go('/teacher/games/jeopardy'),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AdaptiveLayout(
      title: _isEditing ? 'Edit Jeopardy Game' : 'Create Jeopardy Game',
      showBackButton: true,
      onBackPressed: () => context.go('/teacher/games/jeopardy'),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _saveGame,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Game Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Game Title',
                hintText: 'Enter a title for your Jeopardy game',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a game title';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Categories
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categories',
                  style: theme.textTheme.titleLarge,
                ),
                FilledButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Category'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category List
            ..._game!.categories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              return _buildCategorySection(index, category);
            }),
            const SizedBox(height: 24),
            
            // Daily Doubles toggle
            SwitchListTile(
              title: const Text('Enable Daily Doubles'),
              subtitle: const Text('Add 3 hidden Daily Double questions with wagering'),
              value: _enableDailyDoubles,
              onChanged: (value) {
                setState(() {
                  _enableDailyDoubles = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(int categoryIndex, JeopardyCategory category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: category.name,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: _game!.categories.length > 1
                            ? () => _removeCategory(categoryIndex)
                            : null,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _game!.categories[categoryIndex] = JeopardyCategory(
                          name: value,
                          questions: category.questions,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Questions
            ...category.questions.asMap().entries.map((entry) {
              final questionIndex = entry.key;
              final question = entry.value;
              return _buildQuestionRow(categoryIndex, questionIndex, question);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionRow(
      int categoryIndex, int questionIndex, JeopardyQuestion question) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '\$${question.points}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Question field
          TextFormField(
            initialValue: question.question,
            decoration: const InputDecoration(
              labelText: 'Question/Clue',
              hintText: 'Enter the question or clue',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (value) => _updateQuestion(
              categoryIndex,
              questionIndex,
              question.copyWith(question: value),
            ),
          ),
          const SizedBox(height: 8),

          // Answer field
          TextFormField(
            initialValue: question.answer,
            decoration: const InputDecoration(
              labelText: 'Answer',
              hintText: 'Enter the answer (in Jeopardy format)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _updateQuestion(
              categoryIndex,
              questionIndex,
              question.copyWith(answer: value),
            ),
          ),
        ],
      ),
    );
  }

  void _updateQuestion(
      int categoryIndex, int questionIndex, JeopardyQuestion newQuestion) {
    setState(() {
      final category = _game!.categories[categoryIndex];
      final updatedQuestions = List<JeopardyQuestion>.from(category.questions);
      updatedQuestions[questionIndex] = newQuestion;

      _game!.categories[categoryIndex] = JeopardyCategory(
        name: category.name,
        questions: updatedQuestions,
      );
    });
  }

  void _addCategory() {
    if (_game!.categories.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 categories allowed')),
      );
      return;
    }

    setState(() {
      _game!.categories.add(
        JeopardyCategory(
          name: 'Category ${_game!.categories.length + 1}',
          questions: List.generate(
              5,
              (index) => JeopardyQuestion(
                    question: '',
                    answer: '',
                    points: (index + 1) * 100,
                  )),
        ),
      );
    });
  }

  void _removeCategory(int index) {
    setState(() {
      _game!.categories.removeAt(index);
    });
  }

  void _saveGame() async {
    if (_formKey.currentState!.validate()) {
      // Validate all questions have content
      bool hasEmptyQuestions = false;
      for (final category in _game!.categories) {
        if (category.name.isEmpty) {
          hasEmptyQuestions = true;
          break;
        }
        for (final question in category.questions) {
          if (question.question.isEmpty || question.answer.isEmpty) {
            hasEmptyQuestions = true;
            break;
          }
        }
      }

      if (hasEmptyQuestions) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Please fill in all categories, questions, and answers'),
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final jeopardyProvider = context.read<JeopardyProvider>();

      // Prepare game data with Daily Doubles
      List<DailyDouble> dailyDoubles = [];
      if (_enableDailyDoubles && _game!.categories.isNotEmpty) {
        // Add 3 Daily Doubles in regular Jeopardy (not in first row)
        // Standard Jeopardy has 1 in round 1 and 2 in round 2, but since we don't have
        // Double Jeopardy UI yet, we'll put all 3 in the regular round
        dailyDoubles.addAll(_generateDailyDoubles(_game!.categories, 3));
        
        // Note: Currently all 3 Daily Doubles are in regular Jeopardy.
        // Standard game format: 1 in Jeopardy, 2 in Double Jeopardy.
      }
      
      _game = JeopardyGame(
        id: _game!.id,
        title: _titleController.text,
        teacherId: _game!.teacherId,
        categories: _game!.categories,
        doubleJeopardyCategories: _game!.doubleJeopardyCategories,
        createdAt: _game!.createdAt,
        updatedAt: DateTime.now(),
        isPublic: _game!.isPublic,
        dailyDoubles: dailyDoubles,
        randomDailyDoubles: _enableDailyDoubles,
      );

      // Save to Firebase
      bool success = false;
      if (_isEditing) {
        success = await jeopardyProvider.updateGame(_game!.id, _game!);
      } else {
        final gameId = await jeopardyProvider.createGame(_game!);
        success = gameId != null;
      }

      setState(() {
        _isLoading = false;
      });

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? 'Game updated!' : 'Game created!'),
            ),
          );
          context.go('/teacher/games/jeopardy');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save game. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  // Generate random Daily Double positions
  List<DailyDouble> _generateDailyDoubles(List<JeopardyCategory> categories, int count, {String round = 'jeopardy'}) {
    final dailyDoubles = <DailyDouble>[];
    final random = Random();
    final usedPositions = <String>{};
    
    while (dailyDoubles.length < count && categories.isNotEmpty) {
      final categoryIndex = random.nextInt(categories.length);
      // Never place Daily Doubles in the first row (lowest value questions)
      final questionIndex = random.nextInt(4) + 1;  // Indices 1-4 (skip index 0)
      
      final positionKey = '$categoryIndex-$questionIndex';
      if (!usedPositions.contains(positionKey)) {
        usedPositions.add(positionKey);
        dailyDoubles.add(DailyDouble(
          round: round,
          categoryIndex: categoryIndex,
          questionIndex: questionIndex,
        ));
      }
    }
    
    return dailyDoubles;
  }
}
