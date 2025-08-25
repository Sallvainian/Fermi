import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/discussion_provider_simple.dart';

class CreateBoardDialog extends StatefulWidget {
  const CreateBoardDialog({super.key});

  @override
  State<CreateBoardDialog> createState() => _CreateBoardDialogState();
}

class _CreateBoardDialogState extends State<CreateBoardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _selectedTags = [];
  bool _isPinned = false;

  final List<String> _availableTags = [
    'General',
    'Assignments',
    'Projects',
    'Resources',
    'Announcements',
    'Questions',
    'Study Group',
    'Events',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Discussion Board'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Board Title',
                  hintText: 'e.g., General Discussion',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of the board purpose',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Tags',
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
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Pin this board'),
                subtitle: const Text('Pinned boards appear at the top'),
                value: _isPinned,
                onChanged: (value) {
                  setState(() {
                    _isPinned = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _createBoard,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _createBoard() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<SimpleDiscussionProvider>();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await provider.createBoard(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        tags: _selectedTags,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pop(context); // Close create dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Discussion board created successfully'),
          ),
        );
      }
    }
  }
}
