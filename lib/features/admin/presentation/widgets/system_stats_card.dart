import 'package:flutter/material.dart';
import '../../../../shared/widgets/common/app_card.dart';
import '../../domain/models/system_stats.dart';

class SystemStatsCard extends StatelessWidget {
  final SystemStats? stats;

  const SystemStatsCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (stats == null) {
      return AppCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'No statistics available',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          
          // User Statistics Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildStatCard(
                context,
                'Total Users',
                stats!.totalUsers.toString(),
                Icons.people,
                Colors.blue,
              ),
              _buildStatCard(
                context,
                'Students',
                stats!.studentCount.toString(),
                Icons.school,
                Colors.green,
              ),
              _buildStatCard(
                context,
                'Teachers',
                stats!.teacherCount.toString(),
                Icons.person,
                Colors.orange,
              ),
              _buildStatCard(
                context,
                'Administrators',
                stats!.adminCount.toString(),
                Icons.admin_panel_settings,
                Colors.deepPurple,
              ),
              _buildStatCard(
                context,
                'Active Sessions',
                stats!.activeSessions.toString(),
                Icons.online_prediction,
                Colors.teal,
              ),
              _buildStatCard(
                context,
                'Recent Activity',
                stats!.recentActivityCount.toString(),
                Icons.timeline,
                Colors.indigo,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // User Distribution Bar
          Text(
            'User Distribution',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildDistributionBar(context),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Row(
              children: [
                if (stats!.studentPercentage > 0)
                  Expanded(
                    flex: (stats!.studentPercentage * 100).round(),
                    child: Container(
                      color: Colors.green,
                      child: Center(
                        child: stats!.studentPercentage > 10
                            ? Text(
                                '${stats!.studentPercentage.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                if (stats!.teacherPercentage > 0)
                  Expanded(
                    flex: (stats!.teacherPercentage * 100).round(),
                    child: Container(
                      color: Colors.orange,
                      child: Center(
                        child: stats!.teacherPercentage > 10
                            ? Text(
                                '${stats!.teacherPercentage.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                if (stats!.adminPercentage > 0)
                  Expanded(
                    flex: (stats!.adminPercentage * 100).round(),
                    child: Container(
                      color: Colors.deepPurple,
                      child: Center(
                        child: stats!.adminPercentage > 10
                            ? Text(
                                '${stats!.adminPercentage.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Students', Colors.green),
            const SizedBox(width: 24),
            _buildLegendItem('Teachers', Colors.orange),
            const SizedBox(width: 24),
            _buildLegendItem('Admins', Colors.deepPurple),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}