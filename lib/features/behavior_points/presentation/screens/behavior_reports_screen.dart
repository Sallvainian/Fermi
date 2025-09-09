import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/behavior_point_provider.dart';
import '../../../../shared/widgets/common/app_card.dart';
import '../../../../shared/widgets/common/empty_state.dart';

/// Analytics and reports screen for behavior points system.
///
/// Features:
/// - Class overview with pie chart showing positive vs negative points
/// - Student rankings table with sorting
/// - Recent behavior history list
/// - Time period selector (today, week, month)
/// - Export or share functionality placeholder
/// - Responsive design for different screen sizes
/// - Real-time data updates
class BehaviorReportsScreen extends StatefulWidget {
  const BehaviorReportsScreen({super.key});

  @override
  State<BehaviorReportsScreen> createState() => _BehaviorReportsScreenState();
}

class _BehaviorReportsScreenState extends State<BehaviorReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TimePeriod _selectedPeriod = TimePeriod.week;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Behavior Analytics'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            onPressed: _showExportOptions,
            icon: const Icon(Icons.share),
            tooltip: 'Export Report',
          ),
          IconButton(
            onPressed: () => _refreshData(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart), text: 'Overview'),
            Tab(icon: Icon(Icons.leaderboard), text: 'Rankings'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Time period selector
          _buildTimePeriodSelector(theme),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildRankingsTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the time period selector
  Widget _buildTimePeriodSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Time Period:',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TimePeriod.values.map((period) {
                  final isSelected = period == _selectedPeriod;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(period.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedPeriod = period;
                          });
                        }
                      },
                      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                      checkmarkColor: theme.colorScheme.primary,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the overview tab with pie chart and summary stats
  Widget _buildOverviewTab() {
    return Consumer<BehaviorPointProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = _getAnalyticsData(provider);
        
        if (data.isEmpty) {
          return const EmptyState(
            icon: Icons.analytics,
            title: 'No Data Available',
            message: 'Start awarding behavior points to see analytics',
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary stats cards
              _buildSummaryStats(data),
              const SizedBox(height: 24),
              
              // Pie chart
              _buildPieChart(data),
              const SizedBox(height: 24),
              
              // Behavior breakdown
              _buildBehaviorBreakdown(data, provider),
            ],
          ),
        );
      },
    );
  }

  /// Builds summary statistics cards
  Widget _buildSummaryStats(AnalyticsData data) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Points',
            value: data.totalPoints.toString(),
            icon: Icons.star,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Positive Points',
            value: '+${data.positivePoints}',
            icon: Icons.thumb_up,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Needs Work',
            value: '${data.negativePoints}',
            icon: Icons.build,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  /// Builds individual stat card
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds the pie chart showing positive vs negative points
  Widget _buildPieChart(AnalyticsData data) {
    final theme = Theme.of(context);
    
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Points Distribution',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            height: 250,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: [
                        PieChartSectionData(
                          color: Colors.green,
                          value: data.positivePoints.toDouble(),
                          title: '${data.positivePercentage.toStringAsFixed(1)}%',
                          radius: 80,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: Colors.orange,
                          value: data.negativePoints.abs().toDouble(),
                          title: '${data.negativePercentage.toStringAsFixed(1)}%',
                          radius: 80,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(
                        color: Colors.green,
                        label: 'Positive',
                        value: '+${data.positivePoints}',
                      ),
                      const SizedBox(height: 16),
                      _buildLegendItem(
                        color: Colors.orange,
                        label: 'Needs Work',
                        value: '${data.negativePoints}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds legend item for pie chart
  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds behavior breakdown section
  Widget _buildBehaviorBreakdown(AnalyticsData data, BehaviorPointProvider provider) {
    final theme = Theme.of(context);
    
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Most Common Behaviors',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          ...data.behaviorCounts.entries.take(5).map((entry) {
            final behaviorName = entry.key;
            final count = entry.value;
            final maxCount = data.behaviorCounts.values.fold(0, (a, b) => a > b ? a : b);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          behaviorName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '$count times',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: count / maxCount,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Builds the rankings tab with student leaderboard
  Widget _buildRankingsTab() {
    return Consumer<BehaviorPointProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final rankings = _getStudentRankings(provider);
        
        if (rankings.isEmpty) {
          return const EmptyState(
            icon: Icons.leaderboard,
            title: 'No Rankings Available',
            message: 'Award points to students to see rankings',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rankings.length,
          itemBuilder: (context, index) {
            final ranking = rankings[index];
            return _buildRankingCard(ranking, index + 1);
          },
        );
      },
    );
  }

  /// Builds individual ranking card
  Widget _buildRankingCard(StudentRanking ranking, int position) {
    final theme = Theme.of(context);
    Color rankColor;
    IconData rankIcon;

    switch (position) {
      case 1:
        rankColor = const Color(0xFFFFD700); // Gold
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = const Color(0xFFC0C0C0); // Silver
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = const Color(0xFFCD7F32); // Bronze
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = theme.colorScheme.primary;
        rankIcon = Icons.person;
        break;
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: position <= 3
          ? rankColor.withOpacity(0.1)
          : null,
      child: Row(
        children: [
          // Rank position
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(rankIcon, color: rankColor, size: 20),
                Text(
                  '#$position',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Student info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ranking.studentName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${ranking.totalPoints} points',
                      style: TextStyle(
                        color: ranking.totalPoints >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${ranking.recordCount} behaviors',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Points breakdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (ranking.positivePoints > 0)
                Text(
                  '+${ranking.positivePoints}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              if (ranking.negativePoints < 0)
                Text(
                  '${ranking.negativePoints}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the history tab with recent behavior points
  Widget _buildHistoryTab() {
    return Consumer<BehaviorPointProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = _getFilteredHistory(provider);
        
        if (history.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'No History Available',
            message: 'Behavior point history will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final point = history[index];
            return _buildHistoryItem(point);
          },
        );
      },
    );
  }

  /// Builds individual history item
  Widget _buildHistoryItem(BehaviorPoint point) {
    final theme = Theme.of(context);
    final isPositive = point.points > 0;
    final color = isPositive ? Colors.green : Colors.orange;
    final timeAgo = _formatTimeAgo(point.awardedAt);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.thumb_up : Icons.build,
              color: color,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.behaviorName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Student: ${_getStudentNameFromId(point.studentId)}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'By: ${point.awardedByName} • $timeAgo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${isPositive ? '+' : ''}${point.points}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows export options dialog
  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: const Text('Export functionality will be implemented in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Refreshes the data
  void _refreshData() {
    final provider = context.read<BehaviorPointProvider>();
    if (provider.currentClassId != null) {
      provider.loadBehaviorPointsForClass(provider.currentClassId!);
    }
  }

  /// Gets analytics data for the selected time period
  AnalyticsData _getAnalyticsData(BehaviorPointProvider provider) {
    final points = _getFilteredPoints(provider);
    
    int positivePoints = 0;
    int negativePoints = 0;
    final behaviorCounts = <String, int>{};

    for (final point in points) {
      if (point.points > 0) {
        positivePoints += point.points;
      } else {
        negativePoints += point.points;
      }
      
      behaviorCounts[point.behaviorName] = 
          (behaviorCounts[point.behaviorName] ?? 0) + 1;
    }

    final totalAbsolute = positivePoints + negativePoints.abs();
    final positivePercentage = totalAbsolute > 0 ? (positivePoints / totalAbsolute * 100) : 0.0;
    final negativePercentage = totalAbsolute > 0 ? (negativePoints.abs() / totalAbsolute * 100) : 0.0;

    return AnalyticsData(
      totalPoints: positivePoints + negativePoints,
      positivePoints: positivePoints,
      negativePoints: negativePoints,
      positivePercentage: positivePercentage,
      negativePercentage: negativePercentage,
      behaviorCounts: behaviorCounts,
    );
  }

  /// Gets student rankings
  List<StudentRanking> _getStudentRankings(BehaviorPointProvider provider) {
    final summaries = provider.studentSummaries.values.toList();
    summaries.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    
    return summaries.map((summary) => StudentRanking(
      studentId: summary.studentId,
      studentName: summary.studentName,
      totalPoints: summary.totalPoints,
      positivePoints: summary.positivePoints,
      negativePoints: summary.negativePoints,
      recordCount: summary.recordCount,
    )).toList();
  }

  /// Gets filtered behavior points based on selected time period
  List<BehaviorPoint> _getFilteredPoints(BehaviorPointProvider provider) {
    final now = DateTime.now();
    DateTime cutoffDate;

    switch (_selectedPeriod) {
      case TimePeriod.today:
        cutoffDate = DateTime(now.year, now.month, now.day);
        break;
      case TimePeriod.week:
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case TimePeriod.month:
        cutoffDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case TimePeriod.all:
        cutoffDate = DateTime(2000);
        break;
    }

    return provider.behaviorPoints
        .where((point) => point.awardedAt.isAfter(cutoffDate))
        .toList();
  }

  /// Gets filtered history based on selected time period
  List<BehaviorPoint> _getFilteredHistory(BehaviorPointProvider provider) {
    return _getFilteredPoints(provider);
  }

  /// Gets student name from ID (simplified)
  String _getStudentNameFromId(String studentId) {
    final provider = context.read<BehaviorPointProvider>();
    final summary = provider.studentSummaries[studentId];
    return summary?.studentName ?? 'Unknown Student';
  }

  /// Formats time ago string
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Time period enum for filtering data
enum TimePeriod {
  today('Today'),
  week('This Week'),
  month('This Month'),
  all('All Time');

  const TimePeriod(this.displayName);
  final String displayName;
}

/// Analytics data model
class AnalyticsData {
  final int totalPoints;
  final int positivePoints;
  final int negativePoints;
  final double positivePercentage;
  final double negativePercentage;
  final Map<String, int> behaviorCounts;

  AnalyticsData({
    required this.totalPoints,
    required this.positivePoints,
    required this.negativePoints,
    required this.positivePercentage,
    required this.negativePercentage,
    required this.behaviorCounts,
  });

  bool get isEmpty => totalPoints == 0;
}

/// Student ranking model
class StudentRanking {
  final String studentId;
  final String studentName;
  final int totalPoints;
  final int positivePoints;
  final int negativePoints;
  final int recordCount;

  StudentRanking({
    required this.studentId,
    required this.studentName,
    required this.totalPoints,
    required this.positivePoints,
    required this.negativePoints,
    required this.recordCount,
  });
}