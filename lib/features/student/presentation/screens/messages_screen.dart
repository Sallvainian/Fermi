import 'package:flutter/material.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../shared/widgets/common/responsive_layout.dart';

class StudentMessagesScreen extends StatefulWidget {
  const StudentMessagesScreen({super.key});

  @override
  State<StudentMessagesScreen> createState() => _StudentMessagesScreenState();
}

class _StudentMessagesScreenState extends State<StudentMessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
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
      title: 'Messages',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showComposeMessage(context);
        },
        icon: const Icon(Icons.edit),
        label: const Text('New Message'),
      ),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Inbox'),
          Tab(text: 'Sent'),
          Tab(text: 'Archived'),
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
                      hintText: 'Search messages...',
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
                      const PopupMenuItem(
                        value: 'All',
                        child: Text('All Messages'),
                      ),
                      const PopupMenuItem(
                        value: 'Unread',
                        child: Text('Unread'),
                      ),
                      const PopupMenuItem(
                        value: 'Starred',
                        child: Text('Starred'),
                      ),
                      const PopupMenuItem(
                        value: 'Teachers',
                        child: Text('From Teachers'),
                      ),
                      const PopupMenuItem(
                        value: 'Important',
                        child: Text('Important'),
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
          // Messages List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInboxMessages(),
                _buildSentMessages(),
                _buildArchivedMessages(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxMessages() {
    final messages = [
      {
        'sender': 'Mr. Smith',
        'senderType': 'Teacher',
        'subject': 'Math Assignment Feedback',
        'preview':
            'Great work on your latest assignment! I wanted to provide some additional feedback...',
        'time': DateTime.now().subtract(const Duration(hours: 1)),
        'isRead': false,
        'isStarred': true,
        'hasAttachment': false,
        'priority': 'High',
      },
      {
        'sender': 'Ms. Johnson',
        'senderType': 'Teacher',
        'subject': 'Science Project Reminder',
        'preview':
            'Just a friendly reminder that your science project is due next week...',
        'time': DateTime.now().subtract(const Duration(hours: 4)),
        'isRead': true,
        'isStarred': false,
        'hasAttachment': true,
        'priority': 'Normal',
      },
      {
        'sender': 'Academic Office',
        'senderType': 'Admin',
        'subject': 'Grade Report Available',
        'preview': 'Your quarter grade report is now available for download...',
        'time': DateTime.now().subtract(const Duration(days: 1)),
        'isRead': true,
        'isStarred': false,
        'hasAttachment': true,
        'priority': 'Normal',
      },
      {
        'sender': 'Dr. Wilson',
        'senderType': 'Teacher',
        'subject': 'Class Schedule Change',
        'preview':
            'Please note that tomorrow\'s physics class has been moved to room 205...',
        'time': DateTime.now().subtract(const Duration(days: 2)),
        'isRead': false,
        'isStarred': true,
        'hasAttachment': false,
        'priority': 'High',
      },
    ];

    return _buildMessagesList(messages);
  }

  Widget _buildSentMessages() {
    final messages = [
      {
        'sender': 'To: Mr. Smith',
        'senderType': 'Sent',
        'subject': 'Re: Math homework question',
        'preview':
            'Thank you for the explanation! I understand the concept much better now...',
        'time': DateTime.now().subtract(const Duration(hours: 6)),
        'isRead': true,
        'isStarred': false,
        'hasAttachment': false,
        'priority': 'Normal',
      },
      {
        'sender': 'To: Academic Office',
        'senderType': 'Sent',
        'subject': 'Request for transcript',
        'preview':
            'I would like to request an official transcript for my college applications...',
        'time': DateTime.now().subtract(const Duration(days: 3)),
        'isRead': true,
        'isStarred': false,
        'hasAttachment': false,
        'priority': 'Normal',
      },
    ];

    return _buildMessagesList(messages);
  }

  Widget _buildArchivedMessages() {
    final messages = [
      {
        'sender': 'Previous Teacher',
        'senderType': 'Teacher',
        'subject': 'End of semester message',
        'preview':
            'Thank you for being such a dedicated student this semester...',
        'time': DateTime.now().subtract(const Duration(days: 60)),
        'isRead': true,
        'isStarred': true,
        'hasAttachment': false,
        'priority': 'Normal',
      },
    ];

    return _buildMessagesList(messages);
  }

  Widget _buildMessagesList(List<Map<String, dynamic>> messages) {
    return ResponsiveContainer(
      child: ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return _buildMessageCard(message);
        },
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    final theme = Theme.of(context);
    final isUnread = !(message['isRead'] as bool);
    final isImportant = message['priority'] == 'High';

    Color senderTypeColor;
    IconData senderTypeIcon;
    switch (message['senderType']) {
      case 'Teacher':
        senderTypeColor = Colors.blue;
        senderTypeIcon = Icons.school;
        break;
      case 'Admin':
        senderTypeColor = Colors.purple;
        senderTypeIcon = Icons.admin_panel_settings;
        break;
      case 'Sent':
        senderTypeColor = Colors.grey;
        senderTypeIcon = Icons.send;
        break;
      default:
        senderTypeColor = Colors.grey;
        senderTypeIcon = Icons.person;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showMessageDetail(message),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Sender Avatar
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: isUnread
                        ? senderTypeColor.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.1),
                    child: Icon(
                      senderTypeIcon,
                      color: isUnread ? senderTypeColor : Colors.grey,
                      size: 20,
                    ),
                  ),
                  if (isImportant)
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
              const SizedBox(width: 12),
              // Message Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message['sender'],
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatMessageTime(message['time']),
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
                    // Subject
                    Text(
                      message['subject'],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isUnread
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Preview
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message['preview'],
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (message['hasAttachment']) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.attach_file,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Star Button
              IconButton(
                icon: Icon(
                  message['isStarred'] ? Icons.star : Icons.star_border,
                  color: message['isStarred'] ? Colors.amber : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    message['isStarred'] = !message['isStarred'];
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
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

  void _showMessageDetail(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentMessageDetailSheet(message: message),
    );
  }

  void _showComposeMessage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const StudentComposeMessageSheet(),
    );
  }
}

// Student Message Detail Sheet
class StudentMessageDetailSheet extends StatelessWidget {
  final Map<String, dynamic> message;

  const StudentMessageDetailSheet({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.archive_outlined),
                          tooltip: 'Archive',
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(
                            message['isStarred']
                                ? Icons.star
                                : Icons.star_border,
                            color: message['isStarred'] ? Colors.amber : null,
                          ),
                          tooltip: 'Star',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject
                      Text(
                        message['subject'],
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sender Info
                      Row(
                        children: [
                          CircleAvatar(
                            child: Text(message['sender'][0].toUpperCase()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['sender'],
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'to me',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatFullDate(message['time']),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Message Body
                      Text('''Hi there,

${message['preview']}

I wanted to reach out to discuss your recent progress and provide some feedback on your latest work. Your dedication to learning is really showing in your assignments.

Keep up the excellent work, and please don't hesitate to reach out if you have any questions or need additional help with any concepts.

Best regards,
${message['sender']}''', style: theme.textTheme.bodyLarge),

                      if (message['hasAttachment']) ...[
                        const SizedBox(height: 24),
                        // Attachment
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'grade_report.pdf',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '156 KB',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.download),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Reply Section
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showReplyMessage(context, message);
                        },
                        icon: const Icon(Icons.reply),
                        label: const Text('Reply'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showForwardMessage(context, message);
                        },
                        icon: const Icon(Icons.forward),
                        label: const Text('Forward'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  void _showReplyMessage(
    BuildContext context,
    Map<String, dynamic> originalMessage,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentComposeMessageSheet(
        recipient: originalMessage['sender'],
        subject: 'Re: ${originalMessage['subject']}',
      ),
    );
  }

  void _showForwardMessage(
    BuildContext context,
    Map<String, dynamic> originalMessage,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentComposeMessageSheet(
        subject: 'Fwd: ${originalMessage['subject']}',
      ),
    );
  }
}

// Student Compose Message Sheet
class StudentComposeMessageSheet extends StatefulWidget {
  final String? recipient;
  final String? subject;

  const StudentComposeMessageSheet({super.key, this.recipient, this.subject});

  @override
  State<StudentComposeMessageSheet> createState() =>
      _StudentComposeMessageSheetState();
}

class _StudentComposeMessageSheetState
    extends State<StudentComposeMessageSheet> {
  final _recipientController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _recipientType = 'Teacher';

  @override
  void initState() {
    super.initState();
    if (widget.recipient != null) {
      _recipientController.text = widget.recipient!;
    }
    if (widget.subject != null) {
      _subjectController.text = widget.subject!;
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
                  'New Message',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.attach_file),
                      tooltip: 'Attach file',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipient Type
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'Teacher',
                        label: Text('Teacher'),
                        icon: Icon(Icons.school),
                      ),
                      ButtonSegment(
                        value: 'Admin',
                        label: Text('Admin'),
                        icon: Icon(Icons.admin_panel_settings),
                      ),
                      ButtonSegment(
                        value: 'Support',
                        label: Text('Support'),
                        icon: Icon(Icons.help),
                      ),
                    ],
                    selected: {_recipientType},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _recipientType = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // To Field
                  TextField(
                    controller: _recipientController,
                    decoration: InputDecoration(
                      labelText: 'To',
                      hintText: _recipientType == 'Teacher'
                          ? 'Select teacher...'
                          : _recipientType == 'Admin'
                          ? 'Academic Office'
                          : 'Support Team',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.person_search),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subject Field
                  TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      hintText: 'Enter subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message Field
                  TextField(
                    controller: _messageController,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),

                  // Quick Message Templates
                  const SizedBox(height: 16),
                  Text(
                    'Quick Templates',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTemplateChip('Question about assignment'),
                      _buildTemplateChip('Request for help'),
                      _buildTemplateChip('Schedule clarification'),
                      _buildTemplateChip('Absence notification'),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Action Buttons
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Save as draft
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message saved as draft')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save Draft'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      // Send message
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message sent successfully'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateChip(String template) {
    return ActionChip(
      label: Text(template),
      onPressed: () {
        setState(() {
          if (_subjectController.text.isEmpty) {
            _subjectController.text = template;
          }
          _messageController.text =
              'Hi,\n\nI hope this message finds you well. I wanted to reach out regarding $template.\n\n[Please add your specific details here]\n\nThank you for your time and assistance.\n\nBest regards,\n[Your name]';
        });
      },
    );
  }
}
