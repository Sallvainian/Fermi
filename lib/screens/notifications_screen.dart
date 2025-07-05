import 'package:flutter/material.dart';
import '../widgets/common/adaptive_layout.dart';
import '../widgets/common/responsive_layout.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                    onChanged: (value) => setState(() {}),
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
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'All', child: Text('All Types')),
                      const PopupMenuItem(value: 'Grades', child: Text('Grades')),
                      const PopupMenuItem(value: 'Assignments', child: Text('Assignments')),
                      const PopupMenuItem(value: 'Messages', child: Text('Messages')),
                      const PopupMenuItem(value: 'System', child: Text('System')),
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
                _buildAcademicNotifications(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllNotifications() {
    final notifications = [
      {
        'id': '1',
        'type': 'grade',
        'title': 'New Grade Posted',
        'message': 'Your grade for Calculus Quiz 3 has been posted: A-',
        'time': DateTime.now().subtract(const Duration(minutes: 30)),
        'isRead': false,
        'priority': 'normal',
        'actionData': {'courseId': '1', 'assignmentId': '1'},
      },
      {
        'id': '2',
        'type': 'assignment',
        'title': 'Assignment Due Tomorrow',
        'message': 'Biology Lab Report is due tomorrow at 11:59 PM',
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'isRead': false,
        'priority': 'high',
        'actionData': {'assignmentId': '2'},
      },
      {
        'id': '3',
        'type': 'message',
        'title': 'New Message from Ms. Johnson',
        'message': 'Regarding your Science project submission...',
        'time': DateTime.now().subtract(const Duration(hours: 4)),
        'isRead': true,
        'priority': 'normal',
        'actionData': {'messageId': '3'},
      },
      {
        'id': '4',
        'type': 'system',
        'title': 'Schedule Update',
        'message': 'Physics class has been moved to Room 205 for tomorrow',
        'time': DateTime.now().subtract(const Duration(hours: 6)),
        'isRead': true,
        'priority': 'normal',
        'actionData': null,
      },
      {
        'id': '5',
        'type': 'grade',
        'title': 'Grade Updated',
        'message': 'Your Creative Writing essay grade has been updated to A',
        'time': DateTime.now().subtract(const Duration(days: 1)),
        'isRead': true,
        'priority': 'normal',
        'actionData': {'courseId': '3', 'assignmentId': '5'},
      },
      {
        'id': '6',
        'type': 'assignment',
        'title': 'Assignment Reminder',
        'message': 'Renaissance Essay due in 3 days - World History',
        'time': DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        'isRead': false,
        'priority': 'medium',
        'actionData': {'assignmentId': '6'},
      },
      {
        'id': '7',
        'type': 'system',
        'title': 'Maintenance Notice',
        'message': 'System maintenance scheduled for this weekend',
        'time': DateTime.now().subtract(const Duration(days: 2)),
        'isRead': true,
        'priority': 'low',
        'actionData': null,
      },
    ];

    return _buildNotificationsList(notifications);
  }

  Widget _buildUnreadNotifications() {
    final notifications = [
      {
        'id': '1',
        'type': 'grade',
        'title': 'New Grade Posted',
        'message': 'Your grade for Calculus Quiz 3 has been posted: A-',
        'time': DateTime.now().subtract(const Duration(minutes: 30)),
        'isRead': false,
        'priority': 'normal',
        'actionData': {'courseId': '1', 'assignmentId': '1'},
      },
      {
        'id': '2',
        'type': 'assignment',
        'title': 'Assignment Due Tomorrow',
        'message': 'Biology Lab Report is due tomorrow at 11:59 PM',
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'isRead': false,
        'priority': 'high',
        'actionData': {'assignmentId': '2'},
      },
      {
        'id': '6',
        'type': 'assignment',
        'title': 'Assignment Reminder',
        'message': 'Renaissance Essay due in 3 days - World History',
        'time': DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        'isRead': false,
        'priority': 'medium',
        'actionData': {'assignmentId': '6'},
      },
    ];

    return _buildNotificationsList(notifications);
  }

  Widget _buildAcademicNotifications() {
    final notifications = [
      {
        'id': '1',
        'type': 'grade',
        'title': 'New Grade Posted',
        'message': 'Your grade for Calculus Quiz 3 has been posted: A-',
        'time': DateTime.now().subtract(const Duration(minutes: 30)),
        'isRead': false,
        'priority': 'normal',
        'actionData': {'courseId': '1', 'assignmentId': '1'},
      },
      {
        'id': '2',
        'type': 'assignment',
        'title': 'Assignment Due Tomorrow',
        'message': 'Biology Lab Report is due tomorrow at 11:59 PM',
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'isRead': false,
        'priority': 'high',
        'actionData': {'assignmentId': '2'},
      },
      {
        'id': '5',
        'type': 'grade',
        'title': 'Grade Updated',
        'message': 'Your Creative Writing essay grade has been updated to A',
        'time': DateTime.now().subtract(const Duration(days: 1)),
        'isRead': true,
        'priority': 'normal',
        'actionData': {'courseId': '3', 'assignmentId': '5'},
      },
      {
        'id': '6',
        'type': 'assignment',
        'title': 'Assignment Reminder',
        'message': 'Renaissance Essay due in 3 days - World History',
        'time': DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        'isRead': false,
        'priority': 'medium',
        'actionData': {'assignmentId': '6'},
      },
    ];

    return _buildNotificationsList(notifications);
  }

  Widget _buildNotificationsList(List<Map<String, dynamic>> notifications) {
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

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final theme = Theme.of(context);
    final isUnread = !(notification['isRead'] as bool);
    
    Color typeColor;
    IconData typeIcon;
    switch (notification['type']) {
      case 'grade':
        typeColor = Colors.green;
        typeIcon = Icons.grade;
        break;
      case 'assignment':
        typeColor = Colors.blue;
        typeIcon = Icons.assignment;
        break;
      case 'message':
        typeColor = Colors.orange;
        typeIcon = Icons.message;
        break;
      case 'system':
        typeColor = Colors.purple;
        typeIcon = Icons.info;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.notifications;
    }

    Color priorityColor;
    switch (notification['priority']) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      case 'low':
        priorityColor = Colors.green;
        break;
      default:
        priorityColor = Colors.grey;
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
                  if (notification['priority'] == 'high')
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
                            notification['title'],
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatNotificationTime(notification['time']),
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
                      notification['message'],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Type and Priority Tags
                    Row(
                      children: [
                        _buildNotificationTag(
                          notification['type'].toString().toUpperCase(),
                          typeColor,
                        ),
                        if (notification['priority'] != 'normal') ...[ 
                          const SizedBox(width: 8),
                          _buildNotificationTag(
                            notification['priority'].toString().toUpperCase(),
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

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Mark as read if unread
    if (!(notification['isRead'] as bool)) {
      setState(() {
        notification['isRead'] = true;
      });
    }

    // Handle different notification types
    switch (notification['type']) {
      case 'grade':
        _navigateToGrades(notification['actionData']);
        break;
      case 'assignment':
        _navigateToAssignments(notification['actionData']);
        break;
      case 'message':
        _navigateToMessages(notification['actionData']);
        break;
      case 'system':
        _showSystemNotificationDetails(notification);
        break;
    }
  }

  void _navigateToGrades(Map<String, dynamic>? actionData) {
    // TODO: Navigate to grades screen with specific course/assignment
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening grades...'),
      ),
    );
  }

  void _navigateToAssignments(Map<String, dynamic>? actionData) {
    // TODO: Navigate to assignments screen with specific assignment
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening assignments...'),
      ),
    );
  }

  void _navigateToMessages(Map<String, dynamic>? actionData) {
    // TODO: Navigate to messages screen with specific message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening messages...'),
      ),
    );
  }

  void _showSystemNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification['title']),
        content: Text(notification['message']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationAction(String action, Map<String, dynamic> notification) {
    switch (action) {
      case 'mark_read':
        setState(() {
          notification['isRead'] = !notification['isRead'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              notification['isRead'] 
                  ? 'Marked as read' 
                  : 'Marked as unread',
            ),
          ),
        );
        break;
      case 'delete':
        _showDeleteConfirmation(notification);
        break;
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> notification) {
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
              // TODO: Remove notification from list
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
  State<NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
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
                    subtitle: const Text('Receive notifications on this device'),
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
                    subtitle: const Text('New messages from teachers and staff'),
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
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
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