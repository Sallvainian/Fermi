import 'package:flutter/material.dart';

class PreviewButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isCompact;
  final String? label;

  const PreviewButton({
    super.key,
    required this.onPressed,
    this.isCompact = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isCompact) {
      return IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.preview_outlined),
        iconSize: 20,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        tooltip: 'Preview',
        color: theme.colorScheme.primary,
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.preview_outlined, size: 18),
      label: Text(label ?? 'Preview'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        side: BorderSide(color: theme.colorScheme.primary, width: 1),
      ),
    );
  }
}
