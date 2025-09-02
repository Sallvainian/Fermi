import 'package:flutter/material.dart';

/// A reusable confirmation dialog widget that follows Material 3 design principles.
///
/// Used throughout the app for consistent confirmation dialogs.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? confirmText;
  final String? cancelText;
  final Color? confirmColor;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText,
    this.cancelText,
    this.confirmColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirmButtonColor = confirmColor ??
        (isDestructive ? theme.colorScheme.error : theme.colorScheme.primary);

    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: confirmButtonColor,
            foregroundColor: isDestructive
                ? theme.colorScheme.onError
                : theme.colorScheme.onPrimary,
          ),
          child: Text(confirmText ?? 'Confirm'),
        ),
      ],
    );
  }
}
