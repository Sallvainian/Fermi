import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/common/app_card.dart';

class ActivityFeedCard extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final VoidCallback onViewAll;

  const ActivityFeedCard({
    super.key,
    required this.activities,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (activities.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.timeline,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activity',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length > 10 ? 10 : activities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _ActivityItem(activity: activity);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> activity;

  const _ActivityItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Parse activity data
    final type = activity['type'] ?? 'unknown';
    final userName = activity['userName'] ?? 'Unknown User';
    final timestamp = activity['timestamp'];
    final details = activity['details'] ?? {};
    
    // Format timestamp
    String timeString = 'Unknown time';
    if (timestamp != null) {
      try {
        final DateTime time = timestamp is Timestamp 
            ? timestamp.toDate() 
            : DateTime.parse(timestamp.toString());
        final now = DateTime.now();
        final difference = now.difference(time);
        
        if (difference.inMinutes < 1) {
          timeString = 'Just now';
        } else if (difference.inHours < 1) {
          timeString = '${difference.inMinutes}m ago';
        } else if (difference.inDays < 1) {
          timeString = '${difference.inHours}h ago';
        } else if (difference.inDays < 7) {
          timeString = '${difference.inDays}d ago';
        } else {
          timeString = DateFormat('MMM d').format(time);
        }
      } catch (e) {
        // Keep default
      }
    }
    
    // Get icon and color based on activity type
    IconData icon;
    Color color;
    String description;
    
    switch (type) {
      case 'user_login':
        icon = Icons.login;
        color = Colors.green;
        description = '$userName logged in';
        break;
      case 'user_logout':
        icon = Icons.logout;
        color = Colors.orange;
        description = '$userName logged out';
        break;
      case 'user_created':
        icon = Icons.person_add;
        color = Colors.blue;
        description = 'New user created: $userName';
        break;
      case 'assignment_created':
        icon = Icons.assignment;
        color = Colors.purple;
        description = '$userName created an assignment';
        break;
      case 'assignment_submitted':
        icon = Icons.check_circle;
        color = Colors.teal;
        description = '$userName submitted an assignment';
        break;
      case 'class_created':
        icon = Icons.class_;
        color = Colors.indigo;
        description = '$userName created a class';
        break;
      case 'message_sent':
        icon = Icons.message;
        color = Colors.cyan;
        description = '$userName sent a message';
        break;
      case 'grade_posted':
        icon = Icons.grade;
        color = Colors.amber;
        description = '$userName posted grades';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        description = '$userName performed an action';
    }
    
    // Add additional details if available
    if (details['targetName'] != null) {
      description += ' - ${details['targetName']}';
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                timeString,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}