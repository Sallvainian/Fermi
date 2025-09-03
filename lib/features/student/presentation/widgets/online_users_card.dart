import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/logger_service.dart';
import '../../data/services/presence_service.dart';

class OnlineUsersCard extends StatefulWidget {
  final bool excludeSelf;

  const OnlineUsersCard({super.key, this.excludeSelf = true});

  @override
  State<OnlineUsersCard> createState() => _OnlineUsersCardState();
}

class _OnlineUsersCardState extends State<OnlineUsersCard> {
  late final PresenceService _presenceService;
  Stream<List<OnlineUser>>? _onlineUsersStream;

  @override
  void initState() {
    super.initState();
    _presenceService = PresenceService();
    // Create broadcast stream to allow multiple listeners
    _onlineUsersStream = _presenceService
        .getOnlineUsers(excludeSelf: widget.excludeSelf)
        .asBroadcastStream();
  }

  @override
  void dispose() {
    // Clean up stream subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Online Now',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          StreamBuilder<List<OnlineUser>>(
            stream: _onlineUsersStream,
            builder: (context, snapshot) {
              // Debug output (only in debug builds due to LoggerService level)
              this.logDebug('StreamBuilder rebuild - state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, len: ${snapshot.data?.length ?? 0}');

              if (snapshot.hasError) {
                // Handle error state
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Could not load online users',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final onlineUsers = snapshot.data!;

              if (onlineUsers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No one else online',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: onlineUsers.length,
                itemBuilder: (context, index) {
                  final user = onlineUsers[index];
                  return _buildUserTile(context, user);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, OnlineUser user) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary,
            child: _buildUserAvatar(theme, user),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(user.displayName, style: theme.textTheme.titleSmall),
      subtitle: _buildUserSubtitle(context, user),
      onTap: () {
        // Navigate to messages to start a chat with this user
        context.go('/messages');
        // Direct chat creation pending - userId will be passed as parameter
      },
    );
  }

  Widget _buildUserSubtitle(BuildContext context, OnlineUser user) {
    final theme = Theme.of(context);
    final rawRole = user.role ?? 'user';

    // Clean the role text (remove "user role " prefix if present)
    String cleanRole = rawRole;
    if (rawRole.contains('user role ')) {
      cleanRole = rawRole.replaceFirst('user role ', '');
    }

    final roleText =
        cleanRole.substring(0, 1).toUpperCase() + cleanRole.substring(1);

    // Get activity status
    final activityText = user.isActive ? 'Active now' : user.relativeTime;

    return Row(
      children: [
        _buildRoleChip(context, roleText),
        const SizedBox(width: 8),
        Text(
          '• $activityText',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(BuildContext context, String role) {
    final theme = Theme.of(context);

    // Define role colors
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (role.toLowerCase()) {
      case 'teacher':
        backgroundColor = Colors.red.shade700;
        break;
      case 'student':
        backgroundColor = Colors.blue.shade700;
        break;
      default:
        backgroundColor = theme.colorScheme.primary;
        textColor = theme.colorScheme.onPrimary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role,
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildUserAvatar(ThemeData theme, OnlineUser user) {
    // Helper to build initials avatar
    Widget buildInitialsAvatar() {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            user.displayName.isNotEmpty
                ? user.displayName[0].toUpperCase()
                : 'U',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // If no photo URL, return initials
    if (user.photoURL == null) {
      return buildInitialsAvatar();
    }

    // CORS is now configured, so we can load images on localhost

    // Otherwise, try to load the image
    return ClipOval(
      child: Image.network(
        user.photoURL!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Log error for debugging but don't show it to user
          if (error.toString().contains('CORS')) {
            this.logWarning('CORS error loading profile image. Run apply_cors.sh to fix.');
          }
          return buildInitialsAvatar();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 40,
            height: 40,
            color: theme.colorScheme.primary,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
