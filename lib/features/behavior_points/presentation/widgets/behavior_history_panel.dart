import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../data/models/behavior_history_entry.dart';
import '../../../students/data/models/student_enhanced.dart';
import '../../../../shared/services/logger_service.dart';

/// Panel position options
enum PanelPosition { right, bottom }

/// Filter options for behavior history
class BehaviorHistoryFilters {
  String? studentName;
  Gender? gender;
  DateTime? startDate;
  DateTime? endDate;
  String? behaviorType;

  BehaviorHistoryFilters({
    this.studentName,
    this.gender,
    this.startDate,
    this.endDate,
    this.behaviorType,
  });

  Map<String, dynamic> toMap() {
    return {
      if (studentName != null && studentName!.isNotEmpty)
        'studentName': studentName,
      if (gender != null && gender != Gender.notSpecified)
        'gender': gender!.name,
      if (startDate != null)
        'startDate': startDate!.toIso8601String(),
      if (endDate != null)
        'endDate': endDate!.toIso8601String(),
      if (behaviorType != null && behaviorType != 'all')
        'behaviorType': behaviorType,
    };
  }
}

/// Comprehensive behavior history panel with filters
class BehaviorHistoryPanel extends StatefulWidget {
  final String classId;
  final PanelPosition position;
  final double? width;
  final double? height;
  final VoidCallback? onClose;

  const BehaviorHistoryPanel({
    super.key,
    required this.classId,
    this.position = PanelPosition.right,
    this.width,
    this.height,
    this.onClose,
  });

  @override
  State<BehaviorHistoryPanel> createState() => _BehaviorHistoryPanelState();
}

class _BehaviorHistoryPanelState extends State<BehaviorHistoryPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final List<BehaviorHistoryEntry> _historyEntries = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  BehaviorHistoryFilters _filters = BehaviorHistoryFilters();
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();

    _loadHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreHistory();
    }
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _offset = 0;
        _historyEntries.clear();
        _hasMore = true;
      }
    });

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-east4');
      final callable = functions.httpsCallable('getBehaviorHistory');

      final filters = _filters.toMap();
      filters['classId'] = widget.classId;
      filters['limit'] = _limit;
      filters['offset'] = _offset;

      final result = await callable.call(filters);
      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final historyData = data['history'] as List;
        final entries = historyData.map((item) {
          return BehaviorHistoryEntry.fromMap(item as Map<String, dynamic>);
        }).toList();

        setState(() {
          _historyEntries.addAll(entries);
          _offset += entries.length;
          _hasMore = data['hasMore'] ?? false;
        });
      }
    } catch (e) {
      LoggerService.error('Failed to load behavior history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreHistory() async {
    if (!_hasMore || _isLoading) return;
    _loadHistory();
  }

  void _applyFilters() {
    _loadHistory(refresh: true);
  }

  void _clearFilters() {
    setState(() {
      _filters = BehaviorHistoryFilters();
      _searchController.clear();
    });
    _loadHistory(refresh: true);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        filters: _filters,
        onApply: (filters) {
          setState(() {
            _filters = filters;
          });
          _applyFilters();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    final panelWidth = widget.width ??
        (widget.position == PanelPosition.right ? 400.0 : size.width);
    final panelHeight = widget.height ??
        (widget.position == PanelPosition.bottom ? 300.0 : size.height);

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Positioned(
          right: widget.position == PanelPosition.right
              ? (_slideAnimation.value - 1) * panelWidth
              : 0,
          bottom: widget.position == PanelPosition.bottom
              ? (_slideAnimation.value - 1) * panelHeight
              : 0,
          width: widget.position == PanelPosition.right ? panelWidth : size.width,
          height: widget.position == PanelPosition.bottom ? panelHeight : size.height,
          child: Material(
            elevation: 0,
            color: theme.colorScheme.surface,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: widget.position == PanelPosition.right
                        ? const Offset(-2, 0)
                        : const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(theme),
                  _buildSearchBar(theme),
                  _buildFilterChips(theme),
                  Expanded(
                    child: _buildHistoryList(theme),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.timeline_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Behavior History',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track student progress and behaviors',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showFilterDialog,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _animationController.reverse().then((_) {
                          widget.onClose?.call();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_historyEntries.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildStatChip(
                      Icons.trending_up_rounded,
                      '${_historyEntries.where((e) => e.type == "positive").length}',
                      'Positive',
                      Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      Icons.trending_down_rounded,
                      '${_historyEntries.where((e) => e.type == "negative").length}',
                      'Negative',
                      Colors.red,
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      Icons.people_rounded,
                      '${_historyEntries.map((e) => e.studentId).toSet().length}',
                      'Students',
                      Colors.blue,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search students...',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.primary,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _filters.studentName = null;
                      });
                      _applyFilters();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          onSubmitted: (value) {
            setState(() {
              _filters.studentName = value.isEmpty ? null : value;
            });
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    final chips = <Widget>[];

    if (_filters.gender != null && _filters.gender != Gender.notSpecified) {
      chips.add(
        Chip(
          label: Text(_filters.gender!.displayName),
          deleteIcon: const Icon(Icons.close, size: 18),
          onDeleted: () {
            setState(() {
              _filters.gender = null;
            });
            _applyFilters();
          },
        ),
      );
    }

    if (_filters.behaviorType != null && _filters.behaviorType != 'all') {
      chips.add(
        Chip(
          label: Text(_filters.behaviorType == 'positive' ? 'Positive' : 'Negative'),
          deleteIcon: const Icon(Icons.close, size: 18),
          onDeleted: () {
            setState(() {
              _filters.behaviorType = null;
            });
            _applyFilters();
          },
        ),
      );
    }

    if (_filters.startDate != null || _filters.endDate != null) {
      final dateFormat = DateFormat('MMM d');
      String dateText = '';
      if (_filters.startDate != null && _filters.endDate != null) {
        dateText = '${dateFormat.format(_filters.startDate!)} - ${dateFormat.format(_filters.endDate!)}';
      } else if (_filters.startDate != null) {
        dateText = 'From ${dateFormat.format(_filters.startDate!)}';
      } else {
        dateText = 'Until ${dateFormat.format(_filters.endDate!)}';
      }

      chips.add(
        Chip(
          label: Text(dateText),
          deleteIcon: const Icon(Icons.close, size: 18),
          onDeleted: () {
            setState(() {
              _filters.startDate = null;
              _filters.endDate = null;
            });
            _applyFilters();
          },
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          ...chips,
          if (chips.isNotEmpty)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear all'),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    if (_isLoading && _historyEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading history...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_historyEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.timeline_rounded,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No behavior history yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Behavior points will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadHistory(refresh: true),
      color: theme.colorScheme.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _historyEntries.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _historyEntries.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            );
          }

          final entry = _historyEntries[index];
          return _buildHistoryItem(entry, theme);
        },
      ),
    );
  }

  Widget _buildHistoryItem(BehaviorHistoryEntry entry, ThemeData theme) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final fullDateFormat = DateFormat('EEEE, MMMM d');
    final isToday = entry.timestamp.day == DateTime.now().day &&
        entry.timestamp.month == DateTime.now().month &&
        entry.timestamp.year == DateTime.now().year;
    final isYesterday = entry.timestamp.day == DateTime.now().subtract(const Duration(days: 1)).day &&
        entry.timestamp.month == DateTime.now().subtract(const Duration(days: 1)).month &&
        entry.timestamp.year == DateTime.now().subtract(const Duration(days: 1)).year;

    String timeText;
    String dateText;
    if (isToday) {
      timeText = timeFormat.format(entry.timestamp);
      dateText = 'Today';
    } else if (isYesterday) {
      timeText = timeFormat.format(entry.timestamp);
      dateText = 'Yesterday';
    } else {
      timeText = timeFormat.format(entry.timestamp);
      dateText = dateFormat.format(entry.timestamp);
    }

    final isPositive = entry.type == 'positive';
    final pointColor = isPositive ? Colors.green : Colors.red;
    final pointIcon = isPositive ? Icons.add_circle_rounded : Icons.remove_circle_rounded;
    final pointBackgroundColor = isPositive
        ? Colors.green.withValues(alpha: 0.1)
        : Colors.red.withValues(alpha: 0.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Show details or allow undo
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Points Badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: pointBackgroundColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        pointIcon,
                        color: pointColor,
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.points > 0 ? "+" : ""}${entry.points}',
                        style: TextStyle(
                          color: pointColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Student name and gender
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.studentName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (entry.gender != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: entry.gender == 'male'
                                    ? Colors.blue.withValues(alpha: 0.1)
                                    : Colors.pink.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                entry.gender == 'male'
                                    ? Icons.male_rounded
                                    : Icons.female_rounded,
                                size: 14,
                                color: entry.gender == 'male'
                                    ? Colors.blue
                                    : Colors.pink,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Behavior name
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.behaviorName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Note if present
                      if (entry.note != null && entry.note!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.note_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  entry.note!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Time and date
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$dateText • $timeText',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (entry.teacherName != null)
                            Text(
                              'by ${entry.teacherName}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter dialog for behavior history
class _FilterDialog extends StatefulWidget {
  final BehaviorHistoryFilters filters;
  final Function(BehaviorHistoryFilters) onApply;

  const _FilterDialog({
    required this.filters,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late BehaviorHistoryFilters _tempFilters;

  @override
  void initState() {
    super.initState();
    _tempFilters = BehaviorHistoryFilters(
      studentName: widget.filters.studentName,
      gender: widget.filters.gender,
      startDate: widget.filters.startDate,
      endDate: widget.filters.endDate,
      behaviorType: widget.filters.behaviorType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Filter History'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gender filter
            Text(
              'Gender',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<Gender?>(
              segments: const [
                ButtonSegment(
                  value: null,
                  label: Text('All'),
                ),
                ButtonSegment(
                  value: Gender.male,
                  label: Text('Male'),
                ),
                ButtonSegment(
                  value: Gender.female,
                  label: Text('Female'),
                ),
              ],
              selected: {_tempFilters.gender},
              onSelectionChanged: (Set<Gender?> selection) {
                setState(() {
                  _tempFilters.gender = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Behavior type filter
            Text(
              'Behavior Type',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String?>(
              segments: const [
                ButtonSegment(
                  value: null,
                  label: Text('All'),
                ),
                ButtonSegment(
                  value: 'positive',
                  label: Text('Positive'),
                ),
                ButtonSegment(
                  value: 'negative',
                  label: Text('Negative'),
                ),
              ],
              selected: {_tempFilters.behaviorType},
              onSelectionChanged: (Set<String?> selection) {
                setState(() {
                  _tempFilters.behaviorType = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Date range filter
            Text(
              'Date Range',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _tempFilters.startDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _tempFilters.startDate = date;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _tempFilters.startDate != null
                          ? DateFormat('MMM d').format(_tempFilters.startDate!)
                          : 'Start Date',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _tempFilters.endDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _tempFilters.endDate = date;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _tempFilters.endDate != null
                          ? DateFormat('MMM d').format(_tempFilters.endDate!)
                          : 'End Date',
                    ),
                  ),
                ),
              ],
            ),
            if (_tempFilters.startDate != null || _tempFilters.endDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _tempFilters.startDate = null;
                    _tempFilters.endDate = null;
                  });
                },
                child: const Text('Clear dates'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onApply(_tempFilters);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}