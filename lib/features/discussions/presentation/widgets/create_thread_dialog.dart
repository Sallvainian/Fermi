import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/discussion_provider.dart';

class CreateThreadDialog extends StatefulWidget {
  final String boardId;

  const CreateThreadDialog({
    super.key,
    required this.boardId,
  });

  @override
  State<CreateThreadDialog> createState() => _CreateThreadDialogState();
}

class _CreateThreadDialogState extends State<CreateThreadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<String> _selectedTags = [];

  final List<String> _availableTags = [
    'Question',
    'Discussion',
    'Resource',
    'Help Needed',
    'Announcement',
    'Tips',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start New Thread',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Thread Title',
                    hintText: 'Give your thread a descriptive title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    hintText: 'Write your message here...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter content';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Tags (Optional)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _createThread,
                      child: const Text('Post Thread'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _createThread() async {
    if (_formKey.currentState!.validate()) {
      final discussionProvider = context.read<DiscussionProvider>();
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      try {
        // Create the thread with the provided information
        final threadId = await discussionProvider.createThread(
          boardId: widget.boardId,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          tags: _selectedTags,
        );
        
        // Remove loading dialog
        if (mounted) Navigator.pop(context);
        
        if (threadId != null && mounted) {
          // Close the dialog
          Navigator.pop(context);
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thread posted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          // Show error if thread creation failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(discussionProvider.error ?? 'Failed to create thread'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Remove loading dialog if still showing
        if (mounted) Navigator.pop(context);
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating thread: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}