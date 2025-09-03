/// Themed card component for consistent Material Design styling.
///
/// This module provides a customizable card component that follows the
/// application's design system with dark theme optimization, consistent
/// border styling, and flexible interaction support.
library;

import 'package:flutter/material.dart';

/// Customizable card component with consistent theming.
///
/// This widget provides a standardized card design that:
/// - Follows Material 3 design principles
/// - Integrates with the app's theme system
/// - Supports dark theme optimization
/// - Provides consistent border and elevation styling
/// - Offers optional tap interaction with visual feedback
/// - Allows customization while maintaining design consistency
///
/// Features:
/// - Automatic theme integration
/// - Configurable padding and margins
/// - Optional tap handling with InkWell effect
/// - Customizable background colors and borders
/// - Responsive elevation and shadows
/// - Consistent border radius and styling
///
/// Usage:
/// ```dart
/// AppCard(
///   onTap: () => print('Card tapped'),
///   child: Text('Card content'),
/// )
/// ```
class AppCard extends StatelessWidget {
  /// The widget to display inside the card.
  final Widget child;

  /// Internal padding around the child widget.
  ///
  /// Defaults to EdgeInsets.all(16) if not specified.
  final EdgeInsets? padding;

  /// Callback function executed when the card is tapped.
  ///
  /// When provided, the card becomes interactive with InkWell
  /// ripple effects. If null, the card is non-interactive.
  final VoidCallback? onTap;

  /// Custom background color override.
  ///
  /// If not provided, uses the theme's card color automatically.
  final Color? backgroundColor;

  /// Whether to display the card border.
  ///
  /// Defaults to true. When enabled, shows a subtle border
  /// that enhances card definition in dark themes.
  final bool hasBorder;

  /// Custom elevation override for shadow depth.
  ///
  /// If not provided, uses the theme's card elevation.
  final double? elevation;

  /// Custom border radius override.
  ///
  /// Defaults to BorderRadius.circular(12) if not specified.
  final BorderRadius? borderRadius;

  /// Creates a themed card with customizable properties.
  ///
  /// @param child Content widget to display inside the card
  /// @param padding Internal padding (default: EdgeInsets.all(16))
  /// @param onTap Optional tap callback for interactivity
  /// @param backgroundColor Custom background color override
  /// @param hasBorder Whether to show card border (default: true)
  /// @param elevation Custom elevation override
  /// @param borderRadius Custom border radius override
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.hasBorder = true,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Access theme configuration for consistent styling
    final theme = Theme.of(context);
    final cardTheme = theme.cardTheme;

    return Card(
      // Apply background color with theme fallback
      color: backgroundColor ?? cardTheme.color,

      // Apply elevation with theme fallback
      elevation: elevation ?? cardTheme.elevation,

      // Use theme's surface tint and shadow colors
      surfaceTintColor: cardTheme.surfaceTintColor,
      shadowColor: cardTheme.shadowColor,

      // Apply theme's margin configuration
      margin: cardTheme.margin,

      // Configure card shape with border and radius
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        side: hasBorder
            ? const BorderSide(color: Color(0xFF2A2A2A), width: 0.5)
            : BorderSide.none,
      ),

      // Conditionally wrap with InkWell for tap interaction
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: borderRadius ?? BorderRadius.circular(12),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            )
          : Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
    );
  }
}
