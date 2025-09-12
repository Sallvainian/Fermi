import 'package:flutter/material.dart';
import '../widgets/common/adaptive_layout.dart';
import '../widgets/common/responsive_layout.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      title: 'Help & Support',
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.contact_support),
          onPressed: () => _showContactSupport(context),
          tooltip: 'Contact Support',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'FAQ', icon: Icon(Icons.help_outline)),
          Tab(text: 'Guides', icon: Icon(Icons.menu_book)),
          Tab(text: 'Videos', icon: Icon(Icons.play_circle_outline)),
          Tab(text: 'Feedback', icon: Icon(Icons.feedback_outlined)),
        ],
        isScrollable: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search help topics...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
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
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFAQTab(),
                _buildGuidesTab(),
                _buildVideosTab(),
                _buildFeedbackTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTab() {
    final faqs = [
      {
        'category': 'Getting Started',
        'questions': [
          {
            'question': 'How do I log in to my account?',
            'answer':
                'Use your school-provided email and password to log in. If you forgot your password, click "Forgot Password" on the login screen.',
          },
          {
            'question': 'How do I change my password?',
            'answer':
                'Go to Settings > Security & Privacy > Change Password. You\'ll need to enter your current password and a new password.',
          },
          {
            'question': 'What browsers are supported?',
            'answer':
                'The Teacher Dashboard works best on modern browsers like Chrome, Firefox, Safari, and Edge. Make sure your browser is up to date.',
          },
        ],
      },
      {
        'category': 'Grades & Assignments',
        'questions': [
          {
            'question': 'How do I view my grades?',
            'answer':
                'Navigate to the Grades section from the main dashboard. You can filter by course, assignment type, or search for specific assignments.',
          },
          {
            'question': 'When will new grades appear?',
            'answer':
                'Grades typically appear within 24-48 hours after your teacher enters them. You\'ll receive a notification when new grades are posted.',
          },
          {
            'question': 'How do I submit an assignment?',
            'answer':
                'Go to Assignments, find your assignment, and click "Submit". Follow the prompts to upload files or enter text responses.',
          },
          {
            'question': 'Can I resubmit an assignment?',
            'answer':
                'This depends on your teacher\'s settings. Some assignments allow resubmission before the due date, while others do not.',
          },
        ],
      },
      {
        'category': 'Messages & Communication',
        'questions': [
          {
            'question': 'How do I message my teacher?',
            'answer':
                'Go to Messages and click "Compose". Select your teacher from the recipient list and type your message.',
          },
          {
            'question': 'Can parents see my messages?',
            'answer':
                'No, direct messages between students and teachers are private. However, teachers may contact parents separately about academic matters.',
          },
          {
            'question': 'How do I get notifications?',
            'answer':
                'Enable notifications in Settings > Notifications. You can choose to receive push notifications, emails, or both.',
          },
        ],
      },
      {
        'category': 'Technical Issues',
        'questions': [
          {
            'question': 'The app is running slowly. What can I do?',
            'answer':
                'Try clearing your browser cache, closing other tabs, or restarting your browser. Make sure you have a stable internet connection.',
          },
          {
            'question': 'I can\'t upload files. What\'s wrong?',
            'answer':
                'Check that your file is under the size limit (usually 10MB) and in a supported format. Try using a different browser if the problem persists.',
          },
          {
            'question': 'The page won\'t load. What should I do?',
            'answer':
                'Refresh the page, check your internet connection, and try logging out and back in. If the problem continues, contact support.',
          },
        ],
      },
    ];

    final filteredFAQs = _searchQuery.isEmpty
        ? faqs
        : faqs
              .map((category) {
                final filteredQuestions = category['questions'] as List;
                final matchingQuestions = filteredQuestions.where((q) {
                  final question = q['question'] as String;
                  final answer = q['answer'] as String;
                  return question.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      answer.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                return {
                  'category': category['category'],
                  'questions': matchingQuestions,
                };
              })
              .where((category) => (category['questions'] as List).isNotEmpty)
              .toList();

    return ResponsiveContainer(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredFAQs.length,
        itemBuilder: (context, index) {
          final category = filteredFAQs[index];
          return _buildFAQCategory(category);
        },
      ),
    );
  }

  Widget _buildFAQCategory(Map<String, dynamic> category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            category['category'] as String,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...((category['questions'] as List)
            .map((q) => _buildFAQItem(q))
            .toList()),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFAQItem(Map<String, String> faq) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          faq['question']!,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              faq['answer']!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidesTab() {
    final guides = [
      {
        'title': 'Getting Started Guide',
        'description': 'Learn the basics of using the Teacher Dashboard',
        'icon': Icons.rocket_launch,
        'duration': '5 min read',
        'sections': [
          'Setting up your profile',
          'Navigating the dashboard',
          'Understanding the main features',
          'Customizing your settings',
        ],
      },
      {
        'title': 'Student Guide to Grades',
        'description':
            'Everything you need to know about viewing and understanding your grades',
        'icon': Icons.grade,
        'duration': '8 min read',
        'sections': [
          'Viewing your current grades',
          'Understanding grade calculations',
          'Tracking assignment progress',
          'Grade history and trends',
        ],
      },
      {
        'title': 'Assignment Submission Guide',
        'description': 'Step-by-step instructions for submitting assignments',
        'icon': Icons.assignment,
        'duration': '6 min read',
        'sections': [
          'Finding your assignments',
          'Uploading files and documents',
          'Text-based submissions',
          'Late submission policies',
        ],
      },
      {
        'title': 'Communication Best Practices',
        'description':
            'How to effectively communicate with teachers and classmates',
        'icon': Icons.message,
        'duration': '4 min read',
        'sections': [
          'Writing professional messages',
          'When to message vs. email',
          'Response time expectations',
          'Emergency contact procedures',
        ],
      },
      {
        'title': 'Calendar and Scheduling',
        'description': 'Managing your academic schedule effectively',
        'icon': Icons.calendar_today,
        'duration': '7 min read',
        'sections': [
          'Viewing your class schedule',
          'Important dates and deadlines',
          'Setting up reminders',
          'Syncing with external calendars',
        ],
      },
      {
        'title': 'Mobile App Features',
        'description': 'Getting the most out of the mobile experience',
        'icon': Icons.phone_android,
        'duration': '5 min read',
        'sections': [
          'Installing the mobile app',
          'Offline functionality',
          'Push notifications setup',
          'Mobile-specific features',
        ],
      },
    ];

    return ResponsiveContainer(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: guides.length,
        itemBuilder: (context, index) {
          final guide = guides[index];
          return _buildGuideCard(guide);
        },
      ),
    );
  }

  Widget _buildGuideCard(Map<String, dynamic> guide) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showGuideDetail(guide),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  guide['icon'] as IconData,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guide['title'] as String,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guide['description'] as String,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          guide['duration'] as String,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideosTab() {
    final videos = [
      {
        'title': 'Teacher Dashboard Overview',
        'description':
            'A complete walkthrough of the Teacher Dashboard interface',
        'duration': '12:34',
        'thumbnail': 'overview',
        'category': 'Getting Started',
      },
      {
        'title': 'How to Submit Assignments',
        'description':
            'Step-by-step guide to submitting your homework and projects',
        'duration': '8:45',
        'thumbnail': 'assignments',
        'category': 'Assignments',
      },
      {
        'title': 'Understanding Your Grades',
        'description':
            'Learn how grades are calculated and how to track your progress',
        'duration': '15:20',
        'thumbnail': 'grades',
        'category': 'Grades',
      },
      {
        'title': 'Messaging Your Teachers',
        'description': 'Best practices for communicating with your instructors',
        'duration': '6:12',
        'thumbnail': 'messaging',
        'category': 'Communication',
      },
      {
        'title': 'Mobile App Tutorial',
        'description': 'Get the most out of the Teacher Dashboard mobile app',
        'duration': '10:30',
        'thumbnail': 'mobile',
        'category': 'Mobile',
      },
      {
        'title': 'Troubleshooting Common Issues',
        'description': 'Solutions to frequently encountered problems',
        'duration': '14:18',
        'thumbnail': 'troubleshooting',
        'category': 'Support',
      },
    ];

    return ResponsiveContainer(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return _buildVideoCard(video);
        },
      ),
    );
  }

  Widget _buildVideoCard(Map<String, String> video) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _playVideo(video),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 179),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video['duration']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Video Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      video['category']!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video['title']!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video['description']!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackTab() {
    return ResponsiveContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Feedback Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Your Feedback',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Help us improve the Teacher Dashboard by sharing your thoughts and suggestions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Feedback Type
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Feedback Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'bug',
                          child: Text('Bug Report'),
                        ),
                        DropdownMenuItem(
                          value: 'feature',
                          child: Text('Feature Request'),
                        ),
                        DropdownMenuItem(
                          value: 'improvement',
                          child: Text('Improvement Suggestion'),
                        ),
                        DropdownMenuItem(
                          value: 'general',
                          child: Text('General Feedback'),
                        ),
                      ],
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 16),
                    // Subject
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        hintText: 'Brief description of your feedback',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Message
                    const TextField(
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Details',
                        hintText: 'Please provide detailed feedback...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _submitFeedback(),
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Feedback'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Quick Feedback Options
            Text(
              'Quick Feedback',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildQuickFeedbackCard(
                    'Feature Request',
                    Icons.lightbulb_outline,
                    'Suggest new features',
                    () => _showQuickFeedback('feature'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickFeedbackCard(
                    'Bug Report',
                    Icons.bug_report_outlined,
                    'Report issues',
                    () => _showQuickFeedback('bug'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Contact Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Immediate Help?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Email Support'),
                      subtitle: const Text('support@teacherdashboard.edu'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _contactSupport('email'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('Phone Support'),
                      subtitle: const Text(
                        '1-800-TEACHER (Available 9 AM - 5 PM EST)',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _contactSupport('phone'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.chat),
                      title: const Text('Live Chat'),
                      subtitle: const Text('Chat with our support team'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _contactSupport('chat'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFeedbackCard(
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuideDetail(Map<String, dynamic> guide) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GuideDetailSheet(guide: guide),
    );
  }

  void _playVideo(Map<String, String> video) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(video['title']!),
        content: Text('This would open the video: ${video['description']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement video player
            },
            child: const Text('Watch Video'),
          ),
        ],
      ),
    );
  }

  void _submitFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for your feedback! We\'ll review it soon.'),
      ),
    );
  }

  void _showQuickFeedback(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'feature' ? 'Feature Request' : 'Bug Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: type == 'feature'
                    ? 'Feature Description'
                    : 'Bug Description',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _submitFeedback();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _contactSupport(String method) {
    String message;
    switch (method) {
      case 'email':
        message = 'Opening email client...';
        break;
      case 'phone':
        message = 'Opening phone dialer...';
        break;
      case 'chat':
        message = 'Opening live chat...';
        break;
      default:
        message = 'Contacting support...';
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showContactSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contact Support',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: const Text('support@teacherdashboard.edu'),
              onTap: () {
                Navigator.pop(context);
                _contactSupport('email');
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone'),
              subtitle: const Text('1-800-TEACHER'),
              onTap: () {
                Navigator.pop(context);
                _contactSupport('phone');
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Live Chat'),
              subtitle: const Text('Available 9 AM - 5 PM EST'),
              onTap: () {
                Navigator.pop(context);
                _contactSupport('chat');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Guide Detail Sheet
class GuideDetailSheet extends StatelessWidget {
  final Map<String, dynamic> guide;

  const GuideDetailSheet({super.key, required this.guide});

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
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    guide['icon'] as IconData,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide['title'] as String,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            guide['duration'] as String,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide['description'] as String,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'What You\'ll Learn:',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...((guide['sections'] as List<String>)
                      .map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  section,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList()),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Action Button
          Container(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening full guide...')),
                  );
                },
                icon: const Icon(Icons.menu_book),
                label: const Text('Read Full Guide'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
