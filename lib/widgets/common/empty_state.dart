import 'package:flutter/material.dart';

/// Component for displaying empty states with optional action
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customIcon;
  final bool isLoading;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.customIcon,
    this.isLoading = false,
  });

  /// Empty state for when no classes are available
  const EmptyState.noClasses({
    super.key,
    this.actionLabel = 'Create Class',
    this.onAction,
    this.isLoading = false,
  }) : icon = Icons.class_,
       title = 'No Classes Yet',
       message = 'Create your first class to start managing students and assignments.',
       customIcon = null;

  /// Empty state for when no students are available
  const EmptyState.noStudents({
    super.key,
    this.actionLabel = 'Add Student',
    this.onAction,
    this.isLoading = false,
  }) : icon = Icons.person_add,
       title = 'No Students Yet',
       message = 'Add students to this class to start tracking their progress.',
       customIcon = null;

  /// Empty state for when no assignments are available
  const EmptyState.noAssignments({
    super.key,
    this.actionLabel = 'Create Assignment',
    this.onAction,
    this.isLoading = false,
  }) : icon = Icons.assignment,
       title = 'No Assignments Yet',
       message = 'Create assignments to track student progress and grades.',
       customIcon = null;

  /// Empty state for when no grades are available
  const EmptyState.noGrades({
    super.key,
    this.actionLabel,
    this.onAction,
    this.isLoading = false,
  }) : icon = Icons.grade,
       title = 'No Grades Yet',
       message = 'Grades will appear here once assignments are submitted and graded.',
       customIcon = null;

  /// Empty state for when no messages are available
  const EmptyState.noMessages({
    super.key,
    this.actionLabel = 'Start Conversation',
    this.onAction,
    this.isLoading = false,
  }) : icon = Icons.message,
       title = 'No Messages',
       message = 'Start a conversation with students or parents.',
       customIcon = null;

  /// Empty state for search results
  const EmptyState.noSearchResults({
    super.key,
    required String searchTerm,
    this.actionLabel,
    this.onAction,
    this.isLoading = false,
  }) : icon = Icons.search_off,
       title = 'No Results Found',
       message = 'No results found for "$searchTerm". Try a different search term.',
       customIcon = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            customIcon ?? Icon(
              icon,
              size: 80,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(_getActionIcon()),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon() {
    switch (actionLabel?.toLowerCase()) {
      case 'create class':
        return Icons.add;
      case 'add student':
        return Icons.person_add;
      case 'create assignment':
        return Icons.add;
      case 'start conversation':
        return Icons.send;
      default:
        return Icons.add;
    }
  }
}