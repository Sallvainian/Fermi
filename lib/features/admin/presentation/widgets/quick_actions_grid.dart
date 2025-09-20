import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/widgets/common/app_card.dart';

class QuickActionsGrid extends StatelessWidget {
  final VoidCallback onCreateStudent;
  final VoidCallback onCreateTeacher;
  final VoidCallback onViewReports;
  final VoidCallback onSystemSettings;
  final VoidCallback onBulkImport;
  final VoidCallback onManageUsers;
  final VoidCallback? onDeveloperTools;

  const QuickActionsGrid({
    super.key,
    required this.onCreateStudent,
    required this.onCreateTeacher,
    required this.onViewReports,
    required this.onSystemSettings,
    required this.onBulkImport,
    required this.onManageUsers,
    this.onDeveloperTools,
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
            crossAxisCount: kDebugMode && onDeveloperTools != null ? 4 : 3,
            childAspectRatio: 0.9, // Reduced from 1.1 to give more height
            mainAxisSpacing: 8,   // Reduced from 12
            crossAxisSpacing: 8,   // Reduced from 12
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
                icon: Icons.upload_file,
                label: 'Bulk Import',
                color: Colors.teal,
                onTap: onBulkImport,
              ),
              _QuickActionButton(
                icon: Icons.people,
                label: 'Manage Users',
                color: Colors.indigo,
                onTap: onManageUsers,
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
              if (kDebugMode && onDeveloperTools != null)
                _QuickActionButton(
                  icon: Icons.code,
                  label: 'Developer Tools',
                  color: Colors.deepOrange,
                  onTap: onDeveloperTools!,
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
          padding: const EdgeInsets.all(8), // Reduced from 16
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
              Flexible(
                child: Icon(
                  icon,
                  size: 28, // Reduced from 32
                  color: color,
                ),
              ),
              const SizedBox(height: 4), // Reduced from 8
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith( // Changed from bodyMedium
                    fontWeight: FontWeight.w500,
                    color: color,
                    fontSize: 11, // Explicit smaller font size
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}