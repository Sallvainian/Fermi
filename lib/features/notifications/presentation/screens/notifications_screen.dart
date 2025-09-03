import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../shared/widgets/common/responsive_layout.dart';
import '../providers/notification_provider.dart';
import '../../domain/models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    // Initialize notifications provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Notifications',
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _showNotificationSettings(context),
          tooltip: 'Notification Settings',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Unread'),
          Tab(text: 'Academic'),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Search Field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search notifications...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      context.read<NotificationProvider>().updateSearchQuery(
                        value,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Filter Button
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: PopupMenuButton<String>(
                    initialValue: _selectedFilter,
                    onSelected: (value) {
                      setState(() {
                        _selectedFilter = value;
                        context.read<NotificationProvider>().updateFilter(
                          value,
                        );
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'All',
                        child: Text('All Types'),
                      ),
                      const PopupMenuItem(
                        value: 'Grades',
                        child: Text('Grades'),
                      ),
                      const PopupMenuItem(
                        value: 'Assignments',
                        child: Text('Assignments'),
                      ),
                      const PopupMenuItem(
                        value: 'Messages',
                        child: Text('Messages'),
                      ),
                      const PopupMenuItem(
                        value: 'System',
                        child: Text('System'),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list, size: 20),
                          const SizedBox(width: 8),
                          Text(_selectedFilter),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Notifications List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllNotifications(),
                _buildUnreadNotifications(),
                _buildAcademicNotifications(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllNotifications() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(provider.error),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => provider.initialize(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final notifications = provider.getNotificationsByTab('all');
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return _buildNotificationsList(notifications);
      },
    );
  }

  Widget _buildUnreadNotifications() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = provider.getNotificationsByTab('unread');
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_email_read,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'All caught up!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No unread notifications',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return _buildNotificationsList(notifications);
      },
    );
  }

  Widget _buildAcademicNotifications() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = provider.getNotificationsByTab('academic');
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No academic notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return _buildNotificationsList(notifications);
      },
    );
  }

  Widget _buildNotificationsList(List<NotificationModel> notifications) {
    return ResponsiveContainer(
      child: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    Color typeColor;
    IconData typeIcon;
    switch (notification.type) {
      case NotificationType.grade:
        typeColor = Colors.green;
        typeIcon = Icons.grade;
        break;
      case NotificationType.assignment:
        typeColor = Colors.blue;
        typeIcon = Icons.assignment;
        break;
      case NotificationType.message:
        typeColor = Colors.orange;
        typeIcon = Icons.message;
        break;
      case NotificationType.system:
        typeColor = Colors.purple;
        typeIcon = Icons.info;
        break;
      case NotificationType.calendar:
        typeColor = Colors.indigo;
        typeIcon = Icons.calendar_month;
        break;
      case NotificationType.announcement:
        typeColor = Colors.red;
        typeIcon = Icons.campaign;
        break;
      case NotificationType.discussion:
        typeColor = Colors.teal;
        typeIcon = Icons.forum;
        break;
      case NotificationType.submission:
        typeColor = Colors.deepOrange;
        typeIcon = Icons.upload_file;
        break;
    }

    Color priorityColor;
    switch (notification.priority) {
      case NotificationPriority.urgent:
        priorityColor = Colors.red[700]!;
        break;
      case NotificationPriority.high:
        priorityColor = Colors.red;
        break;
      case NotificationPriority.medium:
        priorityColor = Colors.orange;
        break;
      case NotificationPriority.low:
        priorityColor = Colors.green;
        break;
      case NotificationPriority.normal:
        priorityColor = Colors.grey;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isUnread ? 2 : 1,
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isUnread
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Type Icon with priority indicator
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUnread
                          ? typeColor.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      typeIcon,
                      color: isUnread ? typeColor : Colors.grey,
                      size: 20,
                    ),
                  ),
                  if (notification.priority == NotificationPriority.high ||
                      notification.priority == NotificationPriority.urgent)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.priority_high,
                          color: Colors.white,
                          size: 8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Notification Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatNotificationTime(notification.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Message
                    Text(
                      notification.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: isUnread
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Type and Priority Tags
                    Row(
                      children: [
                        _buildNotificationTag(
                          notification.type.name.toUpperCase(),
                          typeColor,
                        ),
                        if (notification.priority !=
                            NotificationPriority.normal) ...[
                          const SizedBox(width: 8),
                          _buildNotificationTag(
                            notification.priority.name.toUpperCase(),
                            priorityColor,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Actions
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'mark_read',
                    child: Row(
                      children: [
                        Icon(
                          isUnread
                              ? Icons.mark_email_read
                              : Icons.mark_email_unread,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(isUnread ? 'Mark as Read' : 'Mark as Unread'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) =>
                    _handleNotificationAction(value, notification),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  String _formatNotificationTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    final provider = context.read<NotificationProvider>();

    // Mark as read if unread
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }

    // Handle different notification types
    switch (notification.type) {
      case NotificationType.grade:
        _navigateToGrades(notification.actionData);
        break;
      case NotificationType.assignment:
        _navigateToAssignments(notification.actionData);
        break;
      case NotificationType.message:
        _navigateToMessages(notification.actionData);
        break;
      case NotificationType.system:
        _showSystemNotificationDetails(notification);
        break;
      case NotificationType.calendar:
        context.go('/calendar');
        break;
      case NotificationType.announcement:
        // Navigate to discussions board where announcements are typically posted
        if (notification.actionData != null &&
            notification.actionData!['boardId'] != null) {
          context.go('/discussions/${notification.actionData!['boardId']}');
        } else {
          context.go('/discussions');
        }
        break;
      case NotificationType.discussion:
        context.go('/discussions');
        break;
      case NotificationType.submission:
        _navigateToAssignments(notification.actionData);
        break;
    }
  }

  void _navigateToGrades(Map<String, dynamic>? actionData) {
    // Check if user is a teacher or student and navigate accordingly
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isTeacher = authProvider.userModel?.role == UserRole.teacher;

    if (actionData != null && actionData['assignmentId'] != null) {
      // Navigate to specific assignment's grades
      if (isTeacher) {
        context.go(
          '/teacher/gradebook?assignmentId=${actionData['assignmentId']}',
        );
      } else {
        // For students, just go to their grades page
        context.go('/student/grades');
      }
    } else if (actionData != null && actionData['classId'] != null) {
      // Navigate to specific class grades
      if (isTeacher) {
        context.go('/teacher/gradebook?classId=${actionData['classId']}');
      } else {
        context.go('/student/grades');
      }
    } else {
      // Navigate to general grades page
      context.go(isTeacher ? '/teacher/gradebook' : '/student/grades');
    }
  }

  void _navigateToAssignments(Map<String, dynamic>? actionData) {
    // Check if user is a teacher or student and navigate accordingly
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isTeacher = authProvider.userModel?.role == UserRole.teacher;

    if (actionData != null && actionData['assignmentId'] != null) {
      // Navigate to specific assignment
      if (isTeacher) {
        context.go('/teacher/assignments/${actionData['assignmentId']}');
      } else {
        // For students, go to submission page
        context.go('/student/assignments/${actionData['assignmentId']}/submit');
      }
    } else {
      // Navigate to general assignments page
      context.go(isTeacher ? '/teacher/assignments' : '/student/assignments');
    }
  }

  void _navigateToMessages(Map<String, dynamic>? actionData) {
    if (actionData != null && actionData['chatRoomId'] != null) {
      // Navigate to specific chat room
      context.go('/messages/${actionData['chatRoomId']}');
    } else if (actionData != null && actionData['userId'] != null) {
      // Navigate to create new chat with specific user
      context.go('/messages', extra: {'userId': actionData['userId']});
    } else {
      // Navigate to general messages page
      context.go('/messages');
    }
  }

  void _showSystemNotificationDetails(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Text(notification.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationAction(
    String action,
    NotificationModel notification,
  ) {
    final provider = context.read<NotificationProvider>();

    switch (action) {
      case 'mark_read':
        if (notification.isRead) {
          provider.markAsUnread(notification.id);
        } else {
          provider.markAsRead(notification.id);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              notification.isRead ? 'Marked as unread' : 'Marked as read',
            ),
          ),
        );
        break;
      case 'delete':
        _showDeleteConfirmation(notification);
        break;
    }
  }

  void _showDeleteConfirmation(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text(
          'Are you sure you want to delete this notification?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<NotificationProvider>().deleteNotification(
                notification.id,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationSettingsSheet(),
    );
  }
}

// Notification Settings Sheet
class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key});

  @override
  State<NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _gradeNotifications = true;
  bool _assignmentNotifications = true;
  bool _messageNotifications = true;
  bool _systemNotifications = true;
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '08:00';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notification Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Settings Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // General Settings
                  Text(
                    'General',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Push Notifications'),
                    subtitle: const Text(
                      'Receive notifications on this device',
                    ),
                    value: _pushNotifications,
                    onChanged: (value) {
                      setState(() {
                        _pushNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Email Notifications'),
                    subtitle: const Text('Receive notifications via email'),
                    value: _emailNotifications,
                    onChanged: (value) {
                      setState(() {
                        _emailNotifications = value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // Notification Types
                  Text(
                    'Notification Types',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Grade Notifications'),
                    subtitle: const Text('New grades and grade updates'),
                    value: _gradeNotifications,
                    onChanged: (value) {
                      setState(() {
                        _gradeNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Assignment Notifications'),
                    subtitle: const Text('Assignment reminders and updates'),
                    value: _assignmentNotifications,
                    onChanged: (value) {
                      setState(() {
                        _assignmentNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Message Notifications'),
                    subtitle: const Text(
                      'New messages from teachers and staff',
                    ),
                    value: _messageNotifications,
                    onChanged: (value) {
                      setState(() {
                        _messageNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('System Notifications'),
                    subtitle: const Text('System updates and announcements'),
                    value: _systemNotifications,
                    onChanged: (value) {
                      setState(() {
                        _systemNotifications = value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // Quiet Hours
                  Text(
                    'Quiet Hours',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications will be sent during quiet hours',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Start Time'),
                          subtitle: Text(_quietHoursStart),
                          trailing: const Icon(Icons.access_time),
                          onTap: () => _selectTime(context, true),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('End Time'),
                          subtitle: Text(_quietHoursEnd),
                          trailing: const Icon(Icons.access_time),
                          onTap: () => _selectTime(context, false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Save Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification settings saved'),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Settings'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final currentTime = isStart ? _quietHoursStart : _quietHoursEnd;
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _quietHoursStart = formattedTime;
        } else {
          _quietHoursEnd = formattedTime;
        }
      });
    }
  }
}
