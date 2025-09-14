import 'package:flutter/material.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../shared/widgets/common/responsive_layout.dart';

class TeacherMessagesScreen extends StatefulWidget {
  const TeacherMessagesScreen({super.key});

  @override
  State<TeacherMessagesScreen> createState() => _TeacherMessagesScreenState();
}

class _TeacherMessagesScreenState extends State<TeacherMessagesScreen>
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
        label: const Text('Compose'),
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
                        value: 'Students',
                        child: Text('From Students'),
                      ),
                      const PopupMenuItem(
                        value: 'Parents',
                        child: Text('From Parents'),
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
        'sender': 'Sarah Johnson',
        'senderType': 'Student',
        'subject': 'Question about Math homework',
        'preview':
            'Hi Mr. Smith, I\'m having trouble understanding problem 5 from...',
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'isRead': false,
        'isStarred': true,
        'hasAttachment': false,
      },
      {
        'sender': 'Parent - Michael Chen',
        'senderType': 'Parent',
        'subject': 'Michael\'s absence tomorrow',
        'preview':
            'Dear Teacher, Michael will be absent tomorrow due to a doctor\'s appointment...',
        'time': DateTime.now().subtract(const Duration(hours: 5)),
        'isRead': true,
        'isStarred': false,
        'hasAttachment': true,
      },
      {
        'sender': 'Emma Davis',
        'senderType': 'Student',
        'subject': 'Extra credit opportunity',
        'preview':
            'Hello, I was wondering if there are any extra credit opportunities available...',
        'time': DateTime.now().subtract(const Duration(days: 1)),
        'isRead': true,
        'isStarred': false,
        'hasAttachment': false,
      },
      {
        'sender': 'Admin Office',
        'senderType': 'Admin',
        'subject': 'Faculty meeting reminder',
        'preview':
            'This is a reminder about the faculty meeting scheduled for Friday at 3:00 PM...',
        'time': DateTime.now().subtract(const Duration(days: 1)),
        'isRead': false,
        'isStarred': true,
        'hasAttachment': false,
      },
    ];

    return _buildMessagesList(messages);
  }

  Widget _buildSentMessages() {
    final messages = [
      {
        'sender': 'To: James Wilson',
        'senderType': 'Sent',
        'subject': 'Re: Missing assignments',
        'preview':
            'Hi James, I noticed you have several missing assignments. Please submit...',
        'time': DateTime.now().subtract(const Duration(hours: 3)),
        'isRead': true,
        'isStarred': false,
        'hasAttachment': false,
      },
      {
        'sender': 'To: Parent - Sarah Johnson',
        'senderType': 'Sent',
        'subject': 'Sarah\'s progress update',
        'preview':
            'Dear Mr./Mrs. Johnson, I wanted to update you on Sarah\'s excellent progress...',
        'time': DateTime.now().subtract(const Duration(days: 2)),
        'isRead': true,
        'isStarred': false,
        'hasAttachment': true,
      },
    ];

    return _buildMessagesList(messages);
  }

  Widget _buildArchivedMessages() {
    final messages = [
      {
        'sender': 'Previous Student',
        'senderType': 'Student',
        'subject': 'Thank you!',
        'preview':
            'Thank you for all your help this semester. I really appreciated...',
        'time': DateTime.now().subtract(const Duration(days: 30)),
        'isRead': true,
        'isStarred': true,
        'hasAttachment': false,
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

    Color senderTypeColor;
    IconData senderTypeIcon;
    switch (message['senderType']) {
      case 'Student':
        senderTypeColor = Colors.blue;
        senderTypeIcon = Icons.school;
        break;
      case 'Parent':
        senderTypeColor = Colors.green;
        senderTypeIcon = Icons.family_restroom;
        break;
      case 'Admin':
        senderTypeColor = Colors.orange;
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
      builder: (context) => MessageDetailSheet(message: message),
    );
  }

  void _showComposeMessage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ComposeMessageSheet(),
    );
  }
}

// Message Detail Sheet
class MessageDetailSheet extends StatelessWidget {
  final Map<String, dynamic> message;

  const MessageDetailSheet({super.key, required this.message});

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
                      Text('''Hi Mr. Smith,

I'm having trouble understanding problem 5 from the homework assignment. I've tried following the steps we learned in class, but I keep getting a different answer than what's in the answer key.

Could you please help me understand where I might be going wrong? I've attached my work so you can see my process.

Thank you for your time!

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
                                      'homework_problem_5.pdf',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '245 KB',
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
      builder: (context) => ComposeMessageSheet(
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
      builder: (context) =>
          ComposeMessageSheet(subject: 'Fwd: ${originalMessage['subject']}'),
    );
  }
}

// Compose Message Sheet
class ComposeMessageSheet extends StatefulWidget {
  final String? recipient;
  final String? subject;

  const ComposeMessageSheet({super.key, this.recipient, this.subject});

  @override
  State<ComposeMessageSheet> createState() => _ComposeMessageSheetState();
}

class _ComposeMessageSheetState extends State<ComposeMessageSheet> {
  final _recipientController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _recipientType = 'Student';

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
                        value: 'Student',
                        label: Text('Student'),
                        icon: Icon(Icons.school),
                      ),
                      ButtonSegment(
                        value: 'Parent',
                        label: Text('Parent'),
                        icon: Icon(Icons.family_restroom),
                      ),
                      ButtonSegment(
                        value: 'Class',
                        label: Text('Class'),
                        icon: Icon(Icons.groups),
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
                      hintText: _recipientType == 'Class'
                          ? 'Select class...'
                          : 'Enter recipient...',
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
}
