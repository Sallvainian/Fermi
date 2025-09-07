import 'package:flutter/material.dart';
import '../../../../shared/widgets/common/app_card.dart';

class QuickActionsGrid extends StatelessWidget {
  final VoidCallback onCreateStudent;
  final VoidCallback onCreateTeacher;
  final VoidCallback onViewReports;
  final VoidCallback onSystemSettings;

  const QuickActionsGrid({
    super.key,
    required this.onCreateStudent,
    required this.onCreateTeacher,
    required this.onViewReports,
    required this.onSystemSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _QuickActionButton(
                icon: Icons.person_add,
                label: 'Create Student',
                color: Colors.green,
                onTap: onCreateStudent,
              ),
              _QuickActionButton(
                icon: Icons.school,
                label: 'Create Teacher',
                color: Colors.orange,
                onTap: onCreateTeacher,
              ),
              _QuickActionButton(
                icon: Icons.analytics,
                label: 'View Reports',
                color: Colors.blue,
                onTap: onViewReports,
              ),
              _QuickActionButton(
                icon: Icons.settings,
                label: 'System Settings',
                color: Colors.purple,
                onTap: onSystemSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}