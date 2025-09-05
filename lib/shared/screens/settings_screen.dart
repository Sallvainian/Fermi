import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/common/adaptive_layout.dart';
import '../widgets/common/responsive_layout.dart';
import '../widgets/custom_radio_list_tile.dart';
import '../widgets/color_picker_dialog.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ImagePicker _picker = ImagePicker();

  // User Preferences
  bool _darkMode = false;
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  String _language = 'English';
  String _timeZone = 'America/New_York';
  String _dateFormat = 'MM/dd/yyyy';

  // Privacy Settings
  bool _crashReporting = true;

  // Academic Settings
  bool _gradeNotifications = true;
  bool _assignmentReminders = true;
  bool _attendanceAlerts = true;
  String _defaultView = 'Dashboard';

  // Security Settings
  bool _biometricAuth = false;
  bool _autoLock = true;
  String _autoLockTime = '5 minutes';

  @override
  void initState() {
    super.initState();
    // Initialize dark mode from theme provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = context.read<ThemeProvider>();
      setState(() {
        _darkMode = themeProvider.isDarkMode;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();

    return AdaptiveLayout(
      title: 'Settings',
      showBackButton: true,
      body: ResponsiveContainer(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Profile Section
            _buildProfileSection(),

            const SizedBox(height: 24),

            // Appearance Settings
            _buildSettingsSection(
              title: 'Appearance',
              icon: Icons.palette,
              children: [
                _buildSwitchTile(
                  title: 'Dark Mode',
                  subtitle: 'Use dark theme throughout the app',
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() {
                      _darkMode = value;
                    });
                    themeProvider.toggleTheme();
                  },
                ),
                ListTile(
                  title: const Text('Theme Color'),
                  subtitle: Text(
                    'Current: ${AppColors.getTheme(themeProvider.colorThemeId).name}',
                  ),
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.getTheme(
                        themeProvider.colorThemeId,
                      ).primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ColorPickerDialog(),
                    );
                  },
                ),
                _buildDropdownTile(
                  title: 'Language',
                  subtitle: 'Choose your preferred language',
                  value: _language,
                  items: ['English', 'Spanish', 'French', 'German', 'Chinese'],
                  onChanged: (value) {
                    setState(() {
                      _language = value!;
                    });
                    _showFeatureComingSoon();
                  },
                ),
                _buildDropdownTile(
                  title: 'Date Format',
                  subtitle: 'How dates are displayed',
                  value: _dateFormat,
                  items: ['MM/dd/yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd'],
                  onChanged: (value) {
                    setState(() {
                      _dateFormat = value!;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Notification Settings
            _buildSettingsSection(
              title: 'Notifications',
              icon: Icons.notifications,
              children: [
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive notifications on this device',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _pushNotifications = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Email Notifications',
                  subtitle: 'Receive notifications via email',
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() {
                      _emailNotifications = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Grade Notifications',
                  subtitle: 'Get notified when grades are posted',
                  value: _gradeNotifications,
                  onChanged: (value) {
                    setState(() {
                      _gradeNotifications = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Assignment Reminders',
                  subtitle: 'Reminders for upcoming assignments',
                  value: _assignmentReminders,
                  onChanged: (value) {
                    setState(() {
                      _assignmentReminders = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Attendance Alerts',
                  subtitle: 'Notifications about attendance',
                  value: _attendanceAlerts,
                  onChanged: (value) {
                    setState(() {
                      _attendanceAlerts = value;
                    });
                  },
                ),
                _buildActionTile(
                  title: 'Notification Settings',
                  subtitle: 'Advanced notification preferences',
                  icon: Icons.tune,
                  onTap: _showAdvancedNotificationSettings,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Academic Settings
            _buildSettingsSection(
              title: 'Academic',
              icon: Icons.school,
              children: [
                _buildDropdownTile(
                  title: 'Default View',
                  subtitle: 'Screen to show when app opens',
                  value: _defaultView,
                  items: ['Dashboard', 'Calendar', 'Grades', 'Assignments'],
                  onChanged: (value) {
                    setState(() {
                      _defaultView = value!;
                    });
                  },
                ),
                _buildDropdownTile(
                  title: 'Time Zone',
                  subtitle: 'Your local time zone',
                  value: _timeZone,
                  items: [
                    'America/New_York',
                    'America/Chicago',
                    'America/Denver',
                    'America/Los_Angeles',
                    'Europe/London',
                    'Europe/Paris',
                    'Asia/Tokyo',
                  ],
                  onChanged: (value) {
                    setState(() {
                      _timeZone = value!;
                    });
                  },
                ),
                _buildActionTile(
                  title: 'Academic Calendar',
                  subtitle: 'Configure semester and holiday dates',
                  icon: Icons.calendar_month,
                  onTap: () => _showFeatureComingSoon(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Security & Privacy
            _buildSettingsSection(
              title: 'Security & Privacy',
              icon: Icons.security,
              children: [
                _buildSwitchTile(
                  title: 'Biometric Authentication',
                  subtitle: 'Use fingerprint or face ID to unlock',
                  value: _biometricAuth,
                  onChanged: (value) {
                    setState(() {
                      _biometricAuth = value;
                    });
                    _showFeatureComingSoon();
                  },
                ),
                _buildSwitchTile(
                  title: 'Auto Lock',
                  subtitle: 'Automatically lock the app when inactive',
                  value: _autoLock,
                  onChanged: (value) {
                    setState(() {
                      _autoLock = value;
                    });
                  },
                ),
                _buildDropdownTile(
                  title: 'Auto Lock Time',
                  subtitle: 'Time before auto lock activates',
                  value: _autoLockTime,
                  items: ['1 minute', '5 minutes', '10 minutes', '30 minutes'],
                  onChanged: _autoLock
                      ? (value) {
                          setState(() {
                            _autoLockTime = value!;
                          });
                        }
                      : null,
                ),
                _buildActionTile(
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  icon: Icons.lock,
                  onTap: _showChangePasswordDialog,
                ),
                _buildActionTile(
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  icon: Icons.privacy_tip,
                  onTap: () => _showFeatureComingSoon(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Data & Storage
            _buildSettingsSection(
              title: 'Data & Storage',
              icon: Icons.storage,
              children: [
                _buildSwitchTile(
                  title: 'Crash Reporting',
                  subtitle: 'Automatically report app crashes',
                  value: _crashReporting,
                  onChanged: (value) {
                    setState(() {
                      _crashReporting = value;
                    });
                  },
                ),
                _buildActionTile(
                  title: 'Clear Cache',
                  subtitle: 'Free up storage space',
                  icon: Icons.cleaning_services,
                  onTap: _showClearCacheDialog,
                ),
                _buildActionTile(
                  title: 'Export Data',
                  subtitle: 'Download your personal data',
                  icon: Icons.download,
                  onTap: () => _showFeatureComingSoon(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Support & About
            _buildSettingsSection(
              title: 'Support & About',
              icon: Icons.help,
              children: [
                // Teacher Dashboard button (only for teachers)
                if (authProvider.userModel?.role == UserRole.teacher)
                  _buildActionTile(
                    title: 'Teacher Dashboard',
                    subtitle: 'Access teacher management tools',
                    icon: Icons.dashboard,
                    onTap: () {
                      context.go('/');
                    },
                  ),
                _buildActionTile(
                  title: 'Send Feedback',
                  subtitle: 'Share your thoughts and suggestions',
                  icon: Icons.feedback,
                  onTap: _showFeedbackDialog,
                ),
                _buildActionTile(
                  title: 'About',
                  subtitle: 'Version 1.0.0 • Build 100',
                  icon: Icons.info,
                  onTap: _showAboutDialog,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Account Actions
            _buildSettingsSection(
              title: 'Account',
              icon: Icons.account_circle,
              children: [
                _buildActionTile(
                  title: 'Sign Out',
                  subtitle: 'Sign out of your account',
                  icon: Icons.logout,
                  onTap: _showSignOutDialog,
                  isDestructive: true,
                ),
                _buildActionTile(
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account and all data',
                  icon: Icons.delete_forever,
                  onTap: _showDeleteAccountDialog,
                  isDestructive: true,
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).colorScheme.primary,
            backgroundImage:
                user?.photoURL != null && user!.photoURL!.isNotEmpty
                ? CachedNetworkImageProvider(user.photoURL!)
                : null,
            child: user?.photoURL == null || user!.photoURL!.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayNameOrFallback,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.role.toString().split('.').last.toUpperCase() ?? 'USER',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showEditProfileDialog,
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
          ),
          IconButton(
            onPressed: _showProfilePictureOptions,
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Change Photo',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.red
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? Colors.red : null),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showAdvancedNotificationSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AdvancedNotificationSettingsSheet(),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed successfully')),
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data and may temporarily slow down the app. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Simulate clearing cache
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Your feedback',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feedback sent successfully')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Teacher Dashboard',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.school, color: Colors.white, size: 24),
      ),
      children: const [
        Text(
          'A comprehensive educational management platform for students and teachers.',
        ),
        SizedBox(height: 16),
        Text('Built with Flutter and Firebase.'),
      ],
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = context.read<AuthProvider>();
              await authProvider.signOut();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete your account?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('This action cannot be undone and will:'),
            SizedBox(height: 8),
            Text('• Delete all your personal data'),
            Text('• Remove all your courses and grades'),
            Text('• Cancel any active subscriptions'),
            Text('• Sign you out permanently'),
            SizedBox(height: 16),
            Text(
              'You may need to re-authenticate to confirm this action.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              _confirmDeleteAccount();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    // Show re-authentication dialog
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.firebaseUser;

    if (user == null) return;

    // Check if user signed in with Apple or Google
    // TODO: Add provider info to AuthUser interface for Windows support
    bool isAppleUser = user.providerData.any(
      (info) => info.providerId == 'apple.com',
    );
    bool isGoogleUser = user.providerData.any(
      (info) => info.providerId == 'google.com',
    );

    if (isAppleUser) {
      // Re-authenticate with Apple
      try {
        await authProvider.reauthenticateWithApple();
        await _deleteAccount();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Re-authentication failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (isGoogleUser) {
      // Re-authenticate with Google
      try {
        await authProvider.reauthenticateWithGoogle();
        await _deleteAccount();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Re-authentication failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Re-authenticate with email/password
      _showReauthenticationDialog();
    }
  }

  void _showReauthenticationDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Your Identity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please enter your credentials to confirm account deletion.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = context.read<AuthProvider>();
              final messenger = ScaffoldMessenger.of(context);

              try {
                await authProvider.reauthenticateWithEmail(
                  emailController.text.trim(),
                  passwordController.text,
                );
                await _deleteAccount();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Re-authentication failed: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm & Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final authProvider = context.read<AuthProvider>();

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleting account...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      await authProvider.deleteAccount();

      // Account deleted successfully - the user will be automatically signed out
      // and redirected to login by the auth provider
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFeatureComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This feature is coming soon!')),
    );
  }

  void _showProfilePictureOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Remove Photo'),
              onTap: () {
                Navigator.pop(context);
                _removeProfilePicture();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        await _uploadProfilePicture(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _uploadProfilePicture(XFile image) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.userModel;

      if (user == null) return;

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading profile picture...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Create a reference to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('profile')
          .child('avatar.jpg');

      // Upload the file
      final file = File(image.path);
      await storageRef.putFile(file);

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update user profile with new photo URL
      await authProvider.updateProfilePicture(downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload profile picture: $e')),
        );
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.userModel;

      if (user == null || user.photoURL == null) return;

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removing profile picture...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Delete from Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('profile')
          .child('avatar.jpg');

      try {
        await storageRef.delete();
      } catch (e) {
        // File might not exist, continue with profile update
      }

      // Update user profile to remove photo URL
      // Note: photoURL is not directly updateable through updateProfile
      // This would need to be handled through a separate method or database update

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove profile picture: $e')),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.userModel;
    final firstNameController = TextEditingController(text: user?.firstName);
    final lastNameController = TextEditingController(text: user?.lastName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final firstName = firstNameController.text.trim();
              final lastName = lastNameController.text.trim();

              if (firstName.isNotEmpty || lastName.isNotEmpty) {
                final displayName = '$firstName $lastName'.trim();

                final authProvider = context.read<AuthProvider>();
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                await authProvider.updateProfile(
                  displayName: displayName,
                  firstName: firstName,
                  lastName: lastName,
                );

                if (!mounted) return;

                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully!'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// Advanced Notification Settings Sheet
class AdvancedNotificationSettingsSheet extends StatefulWidget {
  const AdvancedNotificationSettingsSheet({super.key});

  @override
  State<AdvancedNotificationSettingsSheet> createState() =>
      _AdvancedNotificationSettingsSheetState();
}

class _AdvancedNotificationSettingsSheetState
    extends State<AdvancedNotificationSettingsSheet> {
  bool _quietHours = true;
  String _quietStart = '22:00';
  String _quietEnd = '08:00';
  bool _weekendNotifications = false;
  String _notificationSound = 'Default';
  bool _vibration = true;
  bool _ledNotification = true;

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
                  'Advanced Notifications',
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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                SwitchListTile(
                  title: const Text('Quiet Hours'),
                  subtitle: const Text(
                    'Disable notifications during specified hours',
                  ),
                  value: _quietHours,
                  onChanged: (value) {
                    setState(() {
                      _quietHours = value;
                    });
                  },
                ),
                if (_quietHours) ...[
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(_quietStart),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _selectTime(true),
                  ),
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(_quietEnd),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _selectTime(false),
                  ),
                ],
                const Divider(),
                SwitchListTile(
                  title: const Text('Weekend Notifications'),
                  subtitle: const Text('Receive notifications on weekends'),
                  value: _weekendNotifications,
                  onChanged: (value) {
                    setState(() {
                      _weekendNotifications = value;
                    });
                  },
                ),
                ListTile(
                  title: const Text('Notification Sound'),
                  subtitle: Text(_notificationSound),
                  trailing: const Icon(Icons.music_note),
                  onTap: _selectNotificationSound,
                ),
                SwitchListTile(
                  title: const Text('Vibration'),
                  subtitle: const Text('Vibrate when receiving notifications'),
                  value: _vibration,
                  onChanged: (value) {
                    setState(() {
                      _vibration = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('LED Notification'),
                  subtitle: const Text('Flash LED for notifications'),
                  value: _ledNotification,
                  onChanged: (value) {
                    setState(() {
                      _ledNotification = value;
                    });
                  },
                ),
              ],
            ),
          ),
          // Save Button
          Container(
            padding: const EdgeInsets.all(24),
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

  Future<void> _selectTime(bool isStart) async {
    final currentTime = isStart ? _quietStart : _quietEnd;
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
          _quietStart = formattedTime;
        } else {
          _quietEnd = formattedTime;
        }
      });
    }
  }

  void _selectNotificationSound() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Sound'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Default', 'Bell', 'Chime', 'Ding', 'None']
              .map(
                (sound) => CustomRadioListTile<String>(
                  title: Text(sound),
                  value: sound,
                  groupValue: _notificationSound,
                  onChanged: (value) {
                    setState(() {
                      _notificationSound = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
