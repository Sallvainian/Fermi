/// Custom list tile widgets for educational data display.
///
/// This module provides specialized list tile components optimized for
/// the education platform with theme-aware styling, role-specific layouts,
/// and consistent Material Design patterns for student and class listings.
library;

import 'package:flutter/material.dart';

/// Customizable list tile with educational platform theming.
///
/// This widget provides a themed alternative to the standard ListTile with:
/// - Dark theme optimization and consistent border styling
/// - Selection state visualization with primary container colors
/// - Configurable padding, background colors, and border options
/// - Smooth tap interactions with proper accessibility support
/// - Consistent spacing and visual hierarchy
///
/// Features:
/// - Automatic theme integration with Material 3 colors
/// - Optional border display for enhanced definition
/// - Selection state with subtle background highlighting
/// - Custom padding and background color overrides
/// - Tap handling with visual feedback
///
/// Usage:
/// ```dart
/// CustomListTile(
///   leading: Icon(Icons.person),
///   title: Text('Student Name'),
///   subtitle: Text('student@school.edu'),
///   trailing: Icon(Icons.chevron_right),
///   isSelected: true,
///   onTap: () => navigateToDetail(),
/// )
/// ```
class CustomListTile extends StatelessWidget {
  /// Widget to display before the title (typically an icon or avatar).
  final Widget? leading;

  /// Primary content widget, usually displaying the main text or name.
  final Widget? title;

  /// Secondary content widget, typically showing additional details.
  final Widget? subtitle;

  /// Widget to display after the content (typically an action icon).
  final Widget? trailing;

  /// Callback function executed when the list tile is tapped.
  ///
  /// If null, the list tile will not be interactive.
  final VoidCallback? onTap;

  /// Whether to display a subtle border around the list tile.
  ///
  /// Defaults to false. When enabled, adds visual definition
  /// particularly useful in dark themes.
  final bool showBorder;

  /// Custom padding override for the list tile content.
  ///
  /// If not provided, uses the theme's default list tile padding.
  final EdgeInsets? padding;

  /// Custom background color override.
  ///
  /// If not provided, uses selection state color for selected items
  /// or transparent background for unselected items.
  final Color? backgroundColor;

  /// Whether this list tile is currently selected.
  ///
  /// When true, applies a subtle background highlight using
  /// the theme's primary container color with transparency.
  final bool isSelected;

  /// Creates a custom themed list tile.
  ///
  /// @param leading Widget to display before title (optional)
  /// @param title Primary content widget (optional)
  /// @param subtitle Secondary content widget (optional)
  /// @param trailing Widget to display after content (optional)
  /// @param onTap Tap callback for interactivity (optional)
  /// @param showBorder Whether to show border (default: false)
  /// @param padding Custom padding override (optional)
  /// @param backgroundColor Custom background color (optional)
  /// @param isSelected Whether tile is selected (default: false)
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
    // Access theme configuration for consistent styling
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final listTileTheme = theme.listTileTheme;

    return Container(
      // Add subtle vertical spacing between list items
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        // Apply background color with selection state handling
        color:
            backgroundColor ??
            (isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.1)
                : null),
        borderRadius: BorderRadius.circular(8),
        // Conditional border for enhanced definition
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

/// Specialized list tile for displaying student information.
///
/// This widget provides a standardized layout for student listings with:
/// - Automatic avatar generation from student name initials
/// - Grade display with appropriate formatting and colors
/// - Optional email display with theme-aware styling
/// - Status indicators for enrollment, attendance, or performance
/// - Consistent spacing and typography following Material Design
///
/// Features:
/// - Automatic fallback avatar with name initials
/// - Themed grade display with bold formatting
/// - Conditional email display for different contexts
/// - Status widget support for enrollment indicators
/// - Consistent chevron indicator for navigation
/// - Optimized for educational platform color schemes
///
/// Usage:
/// ```dart
/// StudentListTile(
///   name: 'John Smith',
///   email: 'john.smith@school.edu',
///   grade: 'A',
///   status: Icon(Icons.check_circle, color: Colors.green),
///   onTap: () => viewStudentProfile(),
/// )
/// ```
class StudentListTile extends StatelessWidget {
  /// Student's full name (required for display and avatar generation).
  final String name;

  /// Current grade or score to display (optional).
  ///
  /// Typically shows letter grades (A, B, C) or percentage scores.
  /// Displayed with bold formatting in the trailing section.
  final String? grade;

  /// Student's email address (optional).
  ///
  /// Shown in subtitle when showEmail is true and email is provided.
  /// Uses theme's onSurfaceVariant color for secondary appearance.
  final String? email;

  /// Custom avatar widget override (optional).
  ///
  /// If not provided, generates a circular avatar with the student's
  /// initials using the theme's primary container colors.
  final Widget? avatar;

  /// Status indicator widget (optional).
  ///
  /// Typically displays enrollment status, attendance indicators,
  /// or performance badges. Positioned before the chevron icon.
  final Widget? status;

  /// Callback function executed when the student tile is tapped.
  ///
  /// Usually navigates to student detail view or profile screen.
  final VoidCallback? onTap;

  /// Whether to display the student's email in the subtitle.
  ///
  /// Defaults to true. Set to false for compact views or when
  /// email display is not needed in the current context.
  final bool showEmail;

  /// Creates a student list tile with educational platform theming.
  ///
  /// @param name Student's full name (required)
  /// @param grade Current grade or score (optional)
  /// @param email Student's email address (optional)
  /// @param avatar Custom avatar widget (optional)
  /// @param status Status indicator widget (optional)
  /// @param onTap Tap callback for navigation (optional)
  /// @param showEmail Whether to show email in subtitle (default: true)
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
    // Access theme configuration for educational platform styling
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return CustomListTile(
      // Generate avatar with initials or use custom avatar
      leading:
          avatar ??
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      // Display student name with medium weight
      title: Text(
        name,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      // Conditionally show email in subtitle
      subtitle: showEmail && email != null
          ? Text(
              email!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      // Arrange grade, status, and navigation elements
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display grade with bold formatting
          if (grade != null) ...[
            Text(
              grade!,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Display status indicator
          if (status != null) ...[status!, const SizedBox(width: 8)],
          // Standard navigation chevron
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Specialized list tile for displaying class information.
///
/// This widget provides a standardized layout for class listings with:
/// - Class icon with secondary container theming
/// - Class name display with appropriate typography
/// - Subject, student count, and schedule information
/// - Status indicators for class state or enrollment status
/// - Consistent layout matching educational platform design
///
/// Features:
/// - Themed class icon with secondary container colors
/// - Subject and schedule display in subtitle column
/// - Student count with primary color emphasis
/// - Status widget support for enrollment or activity indicators
/// - Consistent chevron indicator for navigation
/// - Optimized spacing and typography for class information
///
/// Usage:
/// ```dart
/// ClassListTile(
///   className: 'Advanced Mathematics',
///   subject: 'Mathematics',
///   studentCount: 28,
///   schedule: 'Mon, Wed, Fri 10:00 AM',
///   status: Icon(Icons.schedule, color: Colors.blue),
///   onTap: () => viewClassDetails(),
/// )
/// ```
class ClassListTile extends StatelessWidget {
  /// Class name or title (required for display).
  final String className;

  /// Subject area or discipline (optional).
  ///
  /// Displayed in subtitle to provide additional context
  /// about the class content and academic area.
  final String? subject;

  /// Number of enrolled students (required).
  ///
  /// Displayed with primary color emphasis to highlight
  /// enrollment metrics for teachers and administrators.
  final int studentCount;

  /// Class schedule information (optional).
  ///
  /// Typically shows meeting times, days, or frequency.
  /// Displayed in subtitle with secondary text styling.
  final String? schedule;

  /// Status indicator widget (optional).
  ///
  /// Shows class state, enrollment status, or activity indicators.
  /// Positioned before the chevron icon in the trailing section.
  final Widget? status;

  /// Callback function executed when the class tile is tapped.
  ///
  /// Usually navigates to class detail view, roster, or gradebook.
  final VoidCallback? onTap;

  /// Creates a class list tile with educational platform theming.
  ///
  /// @param className Class name or title (required)
  /// @param subject Subject area or discipline (optional)
  /// @param studentCount Number of enrolled students (required)
  /// @param schedule Class schedule information (optional)
  /// @param status Status indicator widget (optional)
  /// @param onTap Tap callback for navigation (optional)
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
    // Access theme configuration for educational platform styling
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return CustomListTile(
      // Class icon with secondary container theming
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        child: Icon(Icons.class_, color: colorScheme.onSecondaryContainer),
      ),
      // Display class name with medium weight
      title: Text(
        className,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      // Organize class details in column layout
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display subject if provided
          if (subject != null)
            Text(
              subject!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          // Student count with primary color emphasis
          Text(
            '$studentCount students',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
          ),
          // Display schedule if provided
          if (schedule != null)
            Text(
              schedule!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      // Arrange status and navigation elements
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display status indicator
          if (status != null) ...[status!, const SizedBox(width: 8)],
          // Standard navigation chevron
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
