import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/behavior_points_screen.dart';
import '../providers/behavior_point_provider.dart';
import 'custom_behavior_dialog.dart';

/// Modal bottom sheet popup for assigning behavior points to students.
///
/// Features:
/// - Toggle between "Positive" and "Needs Work" tabs
/// - Grid of behavior options with icons and point values
/// - Shows selected student name and current points
/// - Awards points when behavior is selected
/// - Animated transitions and visual feedback
/// - Responsive design for different screen sizes
class BehaviorAssignmentPopup extends StatefulWidget {
  /// Student to assign behavior points to
  final StudentPointData student;

  /// Callback when points are awarded (points, behavior type)
  final Function(int points, String behaviorType) onPointsAwarded;

  /// Creates a behavior assignment popup
  const BehaviorAssignmentPopup({
    super.key,
    required this.student,
    required this.onPointsAwarded,
  });

  @override
  State<BehaviorAssignmentPopup> createState() =>
      _BehaviorAssignmentPopupState();
}

class _BehaviorAssignmentPopupState extends State<BehaviorAssignmentPopup>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Edit mode state for managing behaviors
  bool _isEditMode = false;
  bool _isProcessingAward = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Get positive behaviors from provider
  List<BehaviorOption> get _positiveBehaviors {
    final provider = context.watch<BehaviorPointProvider>();
    return provider.positiveBehaviors
        .map(
          (behavior) => BehaviorOption(
            id: behavior.id,
            name: behavior.name,
            points: behavior.points,
            icon: behavior.iconData,
            description: behavior.description,
            isCustom: behavior.isCustom,
          ),
        )
        .toList();
  }

  /// Get negative behaviors from provider
  List<BehaviorOption> get _needsWorkBehaviors {
    final provider = context.watch<BehaviorPointProvider>();
    return provider.negativeBehaviors
        .map(
          (behavior) => BehaviorOption(
            id: behavior.id,
            name: behavior.name,
            points: behavior.points,
            icon: behavior.iconData,
            description: behavior.description,
            isCustom: behavior.isCustom,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 77,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with student info
              _buildHeader(theme),

              // Tab bar
              _buildTabBar(theme),

              // Content area
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBehaviorGrid(
                      _positiveBehaviors,
                      scrollController,
                      theme,
                    ),
                    _buildBehaviorGrid(
                      _needsWorkBehaviors,
                      scrollController,
                      theme,
                    ),
                  ],
                ),
              ),

              // Close button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the header section with student information
  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Student Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.student.avatarColor.withValues(alpha: 51),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.student.avatarColor.withValues(alpha: 128),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                widget.student.initials,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.student.avatarColor,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Student Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: widget.student.pointsColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.student.totalPoints} points',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: widget.student.pointsColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Edit/Done Button
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
              });
            },
            icon: Icon(_isEditMode ? Icons.check : Icons.edit, size: 18),
            label: Text(_isEditMode ? 'Done' : 'Edit'),
            style: TextButton.styleFrom(
              foregroundColor: _isEditMode
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the tab bar for switching between positive and needs work
  Widget _buildTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.thumb_up, size: 18),
                SizedBox(width: 8),
                Text('Positive'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.build, size: 18),
                SizedBox(width: 8),
                Text('Needs Work'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the behavior options grid
  Widget _buildBehaviorGrid(
    List<BehaviorOption> behaviors,
    ScrollController scrollController,
    ThemeData theme,
  ) {
    // Add 1 to item count for the "+" button
    final totalItems = behaviors.length + 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        controller: scrollController,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(context),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85, // Adjusted to prevent text overflow
        ),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // Last item is the "+" button for adding custom behaviors
          if (index == behaviors.length) {
            return _buildAddCustomBehaviorCard(theme);
          }

          final behavior = behaviors[index];
          return _buildBehaviorCard(behavior, theme);
        },
      ),
    );
  }

  /// Builds individual behavior option cards
  Widget _buildBehaviorCard(BehaviorOption behavior, ThemeData theme) {
    final isPositive = behavior.points > 0;
    final cardColor = isPositive ? Colors.green : Colors.orange;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          elevation: 2,
          color: theme.colorScheme.surface.withValues(alpha: 235),
          shadowColor: cardColor.withValues(alpha: 102),
          child: InkWell(
            onTap: (_isEditMode || _isProcessingAward)
                ? null
                : () => _awardBehaviorPoints(behavior),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cardColor.withValues(alpha: 140),
                  width: 1,
                ),
              ),
              child: SizedBox(
                height: 124,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 80),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(behavior.icon, color: cardColor, size: 24),
                    ),

                    // Behavior name with flexible height
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Center(
                          child: Text(
                            behavior.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Points
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${behavior.points > 0 ? '+' : ''}${behavior.points}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Delete button (shown in edit mode for any behavior)
        if (_isEditMode)
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: () => _confirmDeleteBehavior(behavior),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the "+" button card for adding custom behaviors
  Widget _buildAddCustomBehaviorCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 51),
      child: InkWell(
        onTap: _showAddCustomBehaviorDialog,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8), // Reduced padding for consistency
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 77),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: SizedBox(
            height: 120, // Fixed height matching regular cards
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Plus icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),

                // Add custom text with flexible height
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: Text(
                        'Add Custom\nBehavior',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),

                // Empty container to match the height of points badge in regular cards
                Container(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Determines grid column count based on screen size
  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) return 4; // Tablet
    return 3; // Mobile
  }

  /// Show confirmation dialog before deleting a behavior
  Future<void> _confirmDeleteBehavior(BehaviorOption behavior) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Behavior?'),
        content: Text(
          'Are you sure you want to delete "${behavior.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteBehavior(behavior);
    }
  }

  /// Delete a behavior
  void _deleteBehavior(BehaviorOption behavior) async {
    try {
      final provider = context.read<BehaviorPointProvider>();
      await provider.deleteBehavior(behavior.id);

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${behavior.name}"'),
          backgroundColor: Colors.red,
        ),
      );

      // Exit edit mode after deletion
      setState(() {
        _isEditMode = false;
      });
    } catch (e) {
      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete behavior: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Awards behavior points and provides feedback
  void _awardBehaviorPoints(BehaviorOption behavior) async {
    // Prevent duplicate operations
    if (_isProcessingAward) {
      debugPrint('Award already in progress, ignoring duplicate click');
      return;
    }

    setState(() {
      _isProcessingAward = true;
    });

    try {
      // Award the points
      await widget.onPointsAwarded(behavior.points, behavior.name);

      // Show visual feedback
      _showPointsAnimation(behavior);

      // Close popup after brief delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAward = false;
        });
      }
    }
  }

  /// Shows animated feedback when points are awarded
  void _showPointsAnimation(BehaviorOption behavior) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;

    if (renderBox == null) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final overlayEntry = OverlayEntry(
      builder: (context) => _PointsAnimationWidget(
        points: behavior.points,
        position: Offset(
          position.dx + size.width / 2,
          position.dy + size.height / 2,
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove after animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      overlayEntry.remove();
    });
  }

  /// Shows the add custom behavior dialog
  void _showAddCustomBehaviorDialog() {
    showDialog(
      context: context,
      builder: (context) => CustomBehaviorDialog(
        onBehaviorCreated: () {
          // Optionally refresh behaviors here
          // The provider's real-time listeners should handle this automatically
        },
      ),
    );
  }
}

/// Data model for behavior options
class BehaviorOption {
  final String id;
  final String name;
  final int points;
  final IconData icon;
  final String description;
  final bool? isCustom;

  BehaviorOption({
    String? id,
    required this.name,
    required this.points,
    required this.icon,
    required this.description,
    this.isCustom,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();
}

/// Animated widget for showing points feedback
class _PointsAnimationWidget extends StatefulWidget {
  final int points;
  final Offset position;

  const _PointsAnimationWidget({required this.points, required this.position});

  @override
  State<_PointsAnimationWidget> createState() => _PointsAnimationWidgetState();
}

class _PointsAnimationWidgetState extends State<_PointsAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0)),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -2),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.points > 0;
    final color = isPositive ? Colors.green : Colors.orange;

    return Positioned(
      left: widget.position.dx - 50,
      top: widget.position.dy - 25,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 230),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 77),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${widget.points > 0 ? '+' : ''}${widget.points}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
