import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';

class StudentNotificationsScreen extends StatefulWidget {
  const StudentNotificationsScreen({super.key});

  @override
  State<StudentNotificationsScreen> createState() => _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState extends State<StudentNotificationsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    // Initialize notifications provider for student context
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
          icon: const Icon(Icons.mark_email_read),
          onPressed: _markAllAsRead,
          tooltip: 'Mark All as Read',
        ),
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
          Tab(text: 'Classes'),
          Tab(text: 'Grades'),
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
                      context.read<NotificationProvider>().updateSearchQuery(value);
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
                        context.read<NotificationProvider>().updateFilter(value);
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'All', child: Text('All Types')),
                      const PopupMenuItem(value: 'Grades', child: Text('Grades')),
                      const PopupMenuItem(value: 'Assignments', child: Text('Assignments')),
                      const PopupMenuItem(value: 'Announcements', child: Text('Announcements')),
                      const PopupMenuItem(value: 'Messages', child: Text('Messages from Teachers')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                _buildClassNotifications(),
                _buildGradeNotifications(),
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
          return _buildEmptyState(
            icon: Icons.notifications_none,
            title: 'No notifications',
            subtitle: 'You\'ll see updates from your classes here',
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
          return _buildEmptyState(
            icon: Icons.mark_email_read,
            title: 'All caught up!',
            subtitle: 'No unread notifications',
          );
        }
        
        return _buildNotificationsList(notifications);
      },
    );
  }

  Widget _buildClassNotifications() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Filter for class-related notifications
        final notifications = provider.getNotificationsByTab('all').where((notif) {
          return notif.type == NotificationType.announcement ||
                 notif.type == NotificationType.calendar ||
                 notif.type == NotificationType.discussion;
        }).toList();
        
        if (notifications.isEmpty) {
          return _buildEmptyState(
            icon: Icons.class_outlined,
            title: 'No class updates',
            subtitle: 'Class announcements will appear here',
          );
        }
        
        return _buildNotificationsList(notifications);
      },
    );
  }

  Widget _buildGradeNotifications() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Filter for grade-related notifications
        final notifications = provider.getNotificationsByTab('all').where((notif) {
          return notif.type == NotificationType.grade ||
                 notif.type == NotificationType.submission;
        }).toList();
        
        if (notifications.isEmpty) {
          return _buildEmptyState(
            icon: Icons.grade_outlined,
            title: 'No grade updates',
            subtitle: 'New grades will appear here',
          );
        }
        
        return _buildNotificationsList(notifications);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
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
      case NotificationType.announcement:
        typeColor = Colors.red;
        typeIcon = Icons.campaign;
        break;
      case NotificationType.submission:
        typeColor = Colors.deepOrange;
        typeIcon = Icons.upload_file;
        break;
      case NotificationType.calendar:
        typeColor = Colors.indigo;
        typeIcon = Icons.calendar_month;
        break;
      case NotificationType.discussion:
        typeColor = Colors.teal;
        typeIcon = Icons.forum;
        break;
      case NotificationType.system:
        typeColor = Colors.purple;
        typeIcon = Icons.info;
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
                ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Type Icon with unread indicator
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
                  if (isUnread)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
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
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatNotificationTime(notification.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
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
                        fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Course Tag if available
                    if (notification.actionData?['courseName'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          notification.actionData!['courseName'],
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
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
                          isUnread ? Icons.mark_email_read : Icons.mark_email_unread,
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
                onSelected: (value) => _handleNotificationAction(value, notification),
              ),
            ],
          ),
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

    // Handle different notification types for students
    switch (notification.type) {
      case NotificationType.grade:
        // Navigate to grades/progress screen
        context.go('/student/grades');
        break;
      case NotificationType.assignment:
        // Navigate to assignments screen with specific assignment
        if (notification.actionData?['assignmentId'] != null) {
          context.go('/student/assignments/${notification.actionData!['assignmentId']}');
        } else {
          context.go('/student/assignments');
        }
        break;
      case NotificationType.message:
        // Navigate to messages/chat
        if (notification.actionData?['conversationId'] != null) {
          context.go('/student/messages/${notification.actionData!['conversationId']}');
        } else {
          context.go('/student/messages');
        }
        break;
      case NotificationType.announcement:
        // Show announcement details
        _showAnnouncementDetails(notification);
        break;
      case NotificationType.submission:
        // Navigate to specific submission
        if (notification.actionData?['assignmentId'] != null) {
          context.go('/student/assignments/${notification.actionData!['assignmentId']}');
        }
        break;
      case NotificationType.calendar:
        // Navigate to calendar/schedule
        context.go('/student/schedule');
        break;
      case NotificationType.discussion:
        // Navigate to class discussions
        if (notification.actionData?['discussionId'] != null) {
          context.go('/student/discussions/${notification.actionData!['discussionId']}');
        } else {
          context.go('/student/discussions');
        }
        break;
      case NotificationType.system:
        _showSystemNotificationDetails(notification);
        break;
    }
  }

  void _showAnnouncementDetails(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notification.actionData?['courseName'] != null) ...[
                Text(
                  notification.actionData!['courseName'],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(notification.message),
              if (notification.actionData?['details'] != null) ...[
                const SizedBox(height: 16),
                Text(notification.actionData!['details']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (notification.actionData?['classId'] != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/student/classes/${notification.actionData!['classId']}');
              },
              child: const Text('View Class'),
            ),
        ],
      ),
    );
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

  void _handleNotificationAction(String action, NotificationModel notification) {
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
              notification.isRead 
                  ? 'Marked as unread' 
                  : 'Marked as read',
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
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<NotificationProvider>().deleteNotification(notification.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification deleted'),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _markAllAsRead() {
    final provider = context.read<NotificationProvider>();
    provider.markAllAsRead();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const StudentNotificationSettingsSheet(),
    );
  }
}

// Student-specific Notification Settings Sheet
class StudentNotificationSettingsSheet extends StatefulWidget {
  const StudentNotificationSettingsSheet({super.key});

  @override
  State<StudentNotificationSettingsSheet> createState() => 
      _StudentNotificationSettingsSheetState();
}

class _StudentNotificationSettingsSheetState 
    extends State<StudentNotificationSettingsSheet> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _gradeNotifications = true;
  bool _assignmentNotifications = true;
  bool _announcementNotifications = true;
  bool _messageNotifications = true;
  bool _discussionNotifications = true;
  String _assignmentReminder = '24 hours';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                    subtitle: const Text('Get instant updates on your device'),
                    value: _pushNotifications,
                    onChanged: (value) {
                      setState(() {
                        _pushNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Email Notifications'),
                    subtitle: const Text('Receive important updates via email'),
                    value: _emailNotifications,
                    onChanged: (value) {
                      setState(() {
                        _emailNotifications = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Academic Notifications
                  Text(
                    'Academic Updates',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('New Grades'),
                    subtitle: const Text('When teachers post new grades'),
                    value: _gradeNotifications,
                    onChanged: (value) {
                      setState(() {
                        _gradeNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Assignment Updates'),
                    subtitle: const Text('New assignments and due date reminders'),
                    value: _assignmentNotifications,
                    onChanged: (value) {
                      setState(() {
                        _assignmentNotifications = value;
                      });
                    },
                  ),
                  
                  // Assignment Reminder Timing
                  ListTile(
                    title: const Text('Assignment Reminders'),
                    subtitle: Text('Remind me $_assignmentReminder before due'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showReminderOptions(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Communication Notifications
                  Text(
                    'Communications',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Class Announcements'),
                    subtitle: const Text('Important updates from teachers'),
                    value: _announcementNotifications,
                    onChanged: (value) {
                      setState(() {
                        _announcementNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Direct Messages'),
                    subtitle: const Text('Messages from teachers'),
                    value: _messageNotifications,
                    onChanged: (value) {
                      setState(() {
                        _messageNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Discussion Updates'),
                    subtitle: const Text('New posts in class discussions'),
                    value: _discussionNotifications,
                    onChanged: (value) {
                      setState(() {
                        _discussionNotifications = value;
                      });
                    },
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

  void _showReminderOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('1 hour before'),
              onTap: () {
                setState(() {
                  _assignmentReminder = '1 hour';
                });
                Navigator.pop(context);
              },
              trailing: _assignmentReminder == '1 hour' 
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
            ListTile(
              title: const Text('6 hours before'),
              onTap: () {
                setState(() {
                  _assignmentReminder = '6 hours';
                });
                Navigator.pop(context);
              },
              trailing: _assignmentReminder == '6 hours' 
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
            ListTile(
              title: const Text('24 hours before'),
              onTap: () {
                setState(() {
                  _assignmentReminder = '24 hours';
                });
                Navigator.pop(context);
              },
              trailing: _assignmentReminder == '24 hours' 
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
            ListTile(
              title: const Text('2 days before'),
              onTap: () {
                setState(() {
                  _assignmentReminder = '2 days';
                });
                Navigator.pop(context);
              },
              trailing: _assignmentReminder == '2 days' 
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
            ListTile(
              title: const Text('1 week before'),
              onTap: () {
                setState(() {
                  _assignmentReminder = '1 week';
                });
                Navigator.pop(context);
              },
              trailing: _assignmentReminder == '1 week' 
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}