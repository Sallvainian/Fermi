import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../widgets/common/adaptive_layout.dart';
import '../theme/app_spacing.dart';
import '../models/user_model.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'bug_report';
  String _selectedPriority = 'medium';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Contact Support',
      showBackButton: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Submit Support Request',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Choose a category below to submit your request',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Category Selection
                  Text(
                    'Issue Type',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'bug_report',
                        child: Text('Bug Report'),
                      ),
                      DropdownMenuItem(
                        value: 'feature_request',
                        child: Text('Feature Request'),
                      ),
                      DropdownMenuItem(
                        value: 'performance_issue',
                        child: Text('Performance Issue'),
                      ),
                      DropdownMenuItem(
                        value: 'ui_ux',
                        child: Text('UI/UX Problem'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Priority Selection
                  Text(
                    'Priority',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'critical',
                        child: Text('Critical - App is unusable'),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: Text('High - Major functionality broken'),
                      ),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('Medium - Minor issue'),
                      ),
                      DropdownMenuItem(
                        value: 'low',
                        child: Text('Low - Cosmetic issue'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPriority = value!;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Subject Field
                  Text(
                    'Subject',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      hintText: 'Brief description of the issue',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a subject';
                      }
                      if (value.trim().length < 5) {
                        return 'Subject must be at least 5 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Description Field
                  Text(
                    'Description',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText:
                          'Please provide detailed information about the issue:\n'
                          '• What were you trying to do?\n'
                          '• What happened instead?\n'
                          '• Steps to reproduce the issue\n'
                          '• Error messages (if any)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(AppSpacing.md),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please provide a description';
                      }
                      if (value.trim().length < 20) {
                        return 'Description must be at least 20 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'The more details you provide, the better we can help!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Device Info (automatically collected)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'System Information',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'We automatically collect device information to help diagnose issues:',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '• App version and platform\n'
                          '• Device type and OS version\n'
                          '• Screen size and orientation',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit Bug Report'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.userModel;

      // Prepare bug report data
      final reportData = {
        'category': _selectedCategory,
        'priority': _selectedPriority,
        'subject': _subjectController.text.trim(),
        'description': _descriptionController.text.trim(),
        'userId': user?.uid ?? 'anonymous',
        'userEmail': user?.email ?? 'unknown',
        'userName': user.displayNameOrFallback,
        'userRole': user?.role.toString().split('.').last ?? 'unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'new',
        'platform': Theme.of(context).platform.name,
        'appVersion':
            '1.0.0', // You might want to get this from package_info_plus
        'deviceInfo': {
          'platform': Theme.of(context).platform.name,
          'screenSize':
              '${MediaQuery.of(context).size.width}x${MediaQuery.of(context).size.height}',
          'pixelRatio': MediaQuery.of(context).devicePixelRatio,
        },
      };

      // Submit to Firestore
      await FirebaseFirestore.instance
          .collection('bug_reports')
          .add(reportData);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Bug report submitted successfully! Thank you for your feedback.'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _subjectController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedCategory = 'bug_report';
        _selectedPriority = 'medium';
      });

      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
