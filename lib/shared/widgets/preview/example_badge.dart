/// ExampleBadge component with accessibility support.
///
/// This widget provides a clear visual indicator that content is example/preview
/// data with proper accessibility labels and interaction handling.
library;

import 'package:flutter/material.dart';

/// A badge widget that clearly indicates example/preview content.
///
/// Features:
/// - Clear visual design with example text and icon
/// - Accessibility support with semantic labels
/// - Optional tap interaction for more information
/// - Material Design 3 styling
/// - Customizable appearance
class ExampleBadge extends StatelessWidget {
  /// Callback when the badge is tapped
  final VoidCallback? onTap;

  /// Custom text for the badge (defaults to "Example")
  final String? text;

  /// Custom icon for the badge
  final IconData? icon;

  /// Size variant of the badge
  final ExampleBadgeSize size;

  /// Whether the badge should be interactive
  final bool interactive;

  /// Custom background color
  final Color? backgroundColor;

  /// Custom text/icon color
  final Color? foregroundColor;

  const ExampleBadge({
    super.key,
    this.onTap,
    this.text,
    this.icon,
    this.size = ExampleBadgeSize.medium,
    this.interactive = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Create a compact badge variant
  const ExampleBadge.compact({
    super.key,
    this.onTap,
    this.text,
    this.icon,
    this.interactive = true,
    this.backgroundColor,
    this.foregroundColor,
  }) : size = ExampleBadgeSize.compact;

  /// Create a large badge variant
  const ExampleBadge.large({
    super.key,
    this.onTap,
    this.text,
    this.icon,
    this.interactive = true,
    this.backgroundColor,
    this.foregroundColor,
  }) : size = ExampleBadgeSize.large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine colors
    final bgColor =
        backgroundColor ?? colorScheme.tertiary.withValues(alpha: 230);
    final fgColor = foregroundColor ?? colorScheme.onTertiary;

    // Get size-specific properties
    final sizeProps = _getSizeProperties();

    final badgeContent = Container(
      padding: sizeProps.padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(sizeProps.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.visibility_outlined,
            size: sizeProps.iconSize,
            color: fgColor,
          ),
          if (size != ExampleBadgeSize.compact) ...[
            SizedBox(width: sizeProps.spacing),
            Text(
              text ?? 'Example',
              style: theme.textTheme.labelSmall?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w600,
                fontSize: sizeProps.fontSize,
              ),
            ),
          ],
        ],
      ),
    );

    if (!interactive || onTap == null) {
      return Semantics(
        label: 'Example content badge - indicates preview data',
        hint: 'This content is for demonstration purposes',
        child: badgeContent,
      );
    }

    return Semantics(
      label: 'Example content badge - tap for more information',
      hint: 'Double tap to learn about example content',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(sizeProps.borderRadius),
          child: badgeContent,
        ),
      ),
    );
  }

  _BadgeSizeProperties _getSizeProperties() {
    switch (size) {
      case ExampleBadgeSize.compact:
        return const _BadgeSizeProperties(
          padding: EdgeInsets.all(6),
          iconSize: 14,
          fontSize: 10,
          spacing: 4,
          borderRadius: 8,
        );
      case ExampleBadgeSize.medium:
        return const _BadgeSizeProperties(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          iconSize: 16,
          fontSize: 12,
          spacing: 6,
          borderRadius: 10,
        );
      case ExampleBadgeSize.large:
        return const _BadgeSizeProperties(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          iconSize: 18,
          fontSize: 14,
          spacing: 8,
          borderRadius: 12,
        );
    }
  }
}

/// Size variants for the ExampleBadge
enum ExampleBadgeSize {
  /// Compact size - icon only
  compact,

  /// Medium size - icon and text (default)
  medium,

  /// Large size - larger icon and text
  large,
}

/// Internal class to hold size-specific properties
class _BadgeSizeProperties {
  final EdgeInsets padding;
  final double iconSize;
  final double fontSize;
  final double spacing;
  final double borderRadius;

  const _BadgeSizeProperties({
    required this.padding,
    required this.iconSize,
    required this.fontSize,
    required this.spacing,
    required this.borderRadius,
  });
}

/// Utility widget for showing example info dialogs
class ExampleInfoDialog extends StatelessWidget {
  /// Title for the dialog
  final String title;

  /// Message content for the dialog
  final String message;

  /// Optional action button text
  final String? actionText;

  /// Optional action callback
  final VoidCallback? onAction;

  const ExampleInfoDialog({
    super.key,
    this.title = 'Example Content',
    this.message =
        'This is preview content to show you how the app works. Create your own content to replace these examples.',
    this.actionText,
    this.onAction,
  });

  /// Show the example info dialog
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ExampleInfoDialog(
        title: title ?? 'Example Content',
        message:
            message ??
            'This is preview content to show you how the app works. Create your own content to replace these examples.',
        actionText: actionText,
        onAction: onAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.info_outline,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        if (actionText != null && onAction != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction!();
            },
            child: Text(actionText!),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
