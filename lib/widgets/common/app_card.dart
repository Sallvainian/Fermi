import 'package:flutter/material.dart';

/// Base card component that follows the app's dark theme styling
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool hasBorder;
  final double? elevation;
  final BorderRadius? borderRadius;

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
    final theme = Theme.of(context);
    final cardTheme = theme.cardTheme;
    
    return Card(
      color: backgroundColor ?? cardTheme.color,
      elevation: elevation ?? cardTheme.elevation,
      surfaceTintColor: cardTheme.surfaceTintColor,
      shadowColor: cardTheme.shadowColor,
      margin: cardTheme.margin,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        side: hasBorder 
            ? const BorderSide(color: Color(0xFF2A2A2A), width: 0.5)
            : BorderSide.none,
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: borderRadius ?? BorderRadius.circular(12),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
    );
  }
}