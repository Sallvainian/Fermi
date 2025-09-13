import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/common/app_card.dart';
import '../../domain/models/admin_user.dart';

class UserListCard extends StatelessWidget {
  final List<AdminUser> users;
  final Function(AdminUser) onUserTap;
  final VoidCallback onViewAll;

  const UserListCard({
    super.key,
    required this.users,
    required this.onUserTap,
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
                'Recent Users',
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
          
          if (users.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No users yet',
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
              itemCount: users.length > 5 ? 5 : users.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserListTile(
                  user: user,
                  onTap: () => onUserTap(user),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;

  const _UserListTile({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');
    
    Color getRoleColor() {
      switch (user.role) {
        case 'student':
          return Colors.green;
        case 'teacher':
          return Colors.orange;
        case 'admin':
          return Colors.deepPurple;
        default:
          return Colors.grey;
      }
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: getRoleColor().withValues(alpha: 0.2),
        child: Text(
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
          style: TextStyle(
            color: getRoleColor(),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        user.displayName,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.email,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: getRoleColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user.roleDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    color: getRoleColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Joined ${dateFormat.format(user.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user.isOnline) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Online',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            Text(
              'Offline',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}