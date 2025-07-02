import 'package:flutter/material.dart';

/// Custom list tile that follows the app's dark theme styling
class CustomListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showBorder;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final bool isSelected;

  const CustomListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showBorder = false,
    this.padding,
    this.backgroundColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final listTileTheme = theme.listTileTheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? 
               (isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.1) : null),
        borderRadius: BorderRadius.circular(8),
        border: showBorder 
            ? Border.all(color: const Color(0xFF2A2A2A), width: 0.5)
            : null,
      ),
      child: ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        shape: listTileTheme.shape,
        contentPadding: padding ?? listTileTheme.contentPadding,
        selected: isSelected,
        selectedTileColor: Colors.transparent, // We handle this with container
      ),
    );
  }
}

/// Specialized list tile for students
class StudentListTile extends StatelessWidget {
  final String name;
  final String? grade;
  final String? email;
  final Widget? avatar;
  final Widget? status;
  final VoidCallback? onTap;
  final bool showEmail;

  const StudentListTile({
    super.key,
    required this.name,
    this.grade,
    this.email,
    this.avatar,
    this.status,
    this.onTap,
    this.showEmail = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return CustomListTile(
      leading: avatar ?? CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: showEmail && email != null ? Text(
        email!,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (grade != null) ...[
            Text(
              grade!,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (status != null) ...[
            status!,
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Specialized list tile for classes
class ClassListTile extends StatelessWidget {
  final String className;
  final String? subject;
  final int studentCount;
  final String? schedule;
  final Widget? status;
  final VoidCallback? onTap;

  const ClassListTile({
    super.key,
    required this.className,
    this.subject,
    required this.studentCount,
    this.schedule,
    this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return CustomListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        child: Icon(
          Icons.class_,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        className,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subject != null)
            Text(
              subject!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          Text(
            '$studentCount students',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
            ),
          ),
          if (schedule != null)
            Text(
              schedule!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != null) ...[
            status!,
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}