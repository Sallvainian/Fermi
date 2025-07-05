/// Responsive layout system for adaptive UI design.
/// 
/// This module provides a comprehensive responsive design framework with
/// standardized breakpoints, adaptive widgets, and utility classes for
/// creating layouts that work across mobile, tablet, and desktop devices.
/// Follows Material Design responsive guidelines.
library;

import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// Screen size breakpoints for responsive design.
/// 
/// Defines the four standard device categories used throughout
/// the application for responsive layout decisions.
enum ScreenSize {
  /// Mobile devices (< 768px) - phones in portrait/landscape.
  mobile,
  
  /// Tablet devices (768px - 1023px) - tablets and small laptops.
  tablet,
  
  /// Desktop devices (1024px - 1439px) - standard desktop displays.
  desktop,
  
  /// Large desktop devices (≥ 1440px) - wide monitors and displays.
  largeDesktop,
}

/// Responsive layout builder that provides screen size context.
/// 
/// Core responsive widget that determines the current screen size
/// based on available width and provides this context to child widgets
/// through a builder function. Used as the foundation for all other
/// responsive widgets in the system.
/// 
/// Usage:
/// ```dart
/// ResponsiveLayoutBuilder(
///   builder: (context, screenSize) {
///     if (screenSize == ScreenSize.mobile) {
///       return MobileLayout();
///     }
///     return DesktopLayout();
///   },
/// )
/// ```
class ResponsiveLayoutBuilder extends StatelessWidget {
  /// Builder function that receives screen size context.
  /// 
  /// Called whenever the layout constraints change, providing
  /// the appropriate screen size for responsive decisions.
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  /// Creates a responsive layout builder.
  /// 
  /// @param builder Function to build widget based on screen size
  const ResponsiveLayoutBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = _getScreenSize(constraints.maxWidth);
        return builder(context, screenSize);
      },
    );
  }

  /// Determines screen size category from available width.
  /// 
  /// Maps pixel width to semantic screen size categories
  /// using predefined breakpoints from AppSpacing.
  /// 
  /// @param width Available width in pixels
  /// @return Appropriate screen size category
  ScreenSize _getScreenSize(double width) {
    if (width >= AppSpacing.largeDesktopBreakpoint) {
      return ScreenSize.largeDesktop;
    } else if (width >= AppSpacing.desktopBreakpoint) {
      return ScreenSize.desktop;
    } else if (width >= AppSpacing.tabletBreakpoint) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.mobile;
    }
  }
}

/// Responsive widget that shows different widgets based on screen size.
/// 
/// Simplifies responsive design by allowing developers to specify
/// different widgets for each screen size. Falls back gracefully:
/// mobile is required, larger sizes fall back to smaller ones if not provided.
/// 
/// Usage:
/// ```dart
/// ResponsiveWidget(
///   mobile: Text('Mobile'),
///   tablet: Text('Tablet'),
///   desktop: Text('Desktop'),
/// )
/// ```
class ResponsiveWidget extends StatelessWidget {
  /// Widget to display on mobile devices (required).
  final Widget mobile;
  
  /// Widget to display on tablet devices (optional, falls back to mobile).
  final Widget? tablet;
  
  /// Widget to display on desktop devices (optional, falls back to tablet/mobile).
  final Widget? desktop;
  
  /// Widget to display on large desktop devices (optional, falls back to desktop/tablet/mobile).
  final Widget? largeDesktop;

  /// Creates a responsive widget with screen-specific layouts.
  /// 
  /// @param mobile Widget for mobile devices (required)
  /// @param tablet Widget for tablet devices (optional)
  /// @param desktop Widget for desktop devices (optional)
  /// @param largeDesktop Widget for large desktop devices (optional)
  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, screenSize) {
        switch (screenSize) {
          case ScreenSize.largeDesktop:
            return largeDesktop ?? desktop ?? tablet ?? mobile;
          case ScreenSize.desktop:
            return desktop ?? tablet ?? mobile;
          case ScreenSize.tablet:
            return tablet ?? mobile;
          case ScreenSize.mobile:
            return mobile;
        }
      },
    );
  }
}

/// Responsive padding that adapts to screen size.
/// 
/// Provides different padding values for each screen size with
/// intelligent fallbacks. Defaults to standard spacing values
/// from AppSpacing if no custom padding is specified.
/// 
/// Usage:
/// ```dart
/// ResponsivePadding(
///   mobile: EdgeInsets.all(16),
///   desktop: EdgeInsets.all(32),
///   child: MyWidget(),
/// )
/// ```
class ResponsivePadding extends StatelessWidget {
  /// Child widget to wrap with responsive padding.
  final Widget child;
  
  /// Padding for mobile devices (falls back to AppSpacing.md).
  final EdgeInsets? mobile;
  
  /// Padding for tablet devices (falls back to mobile or AppSpacing.md).
  final EdgeInsets? tablet;
  
  /// Padding for desktop devices (falls back to tablet/mobile or AppSpacing.lg).
  final EdgeInsets? desktop;
  
  /// Padding for large desktop devices (falls back to desktop/tablet/mobile or AppSpacing.xl).
  final EdgeInsets? largeDesktop;

  /// Creates responsive padding wrapper.
  /// 
  /// @param child Widget to wrap with padding
  /// @param mobile Mobile device padding (optional)
  /// @param tablet Tablet device padding (optional)
  /// @param desktop Desktop device padding (optional)
  /// @param largeDesktop Large desktop padding (optional)
  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, screenSize) {
        EdgeInsets padding;
        
        switch (screenSize) {
          case ScreenSize.largeDesktop:
            padding = largeDesktop ?? 
                      desktop ?? 
                      tablet ?? 
                      mobile ?? 
                      const EdgeInsets.all(AppSpacing.xl);
            break;
          case ScreenSize.desktop:
            padding = desktop ?? 
                      tablet ?? 
                      mobile ?? 
                      const EdgeInsets.all(AppSpacing.lg);
            break;
          case ScreenSize.tablet:
            padding = tablet ?? 
                      mobile ?? 
                      const EdgeInsets.all(AppSpacing.md);
            break;
          case ScreenSize.mobile:
            padding = mobile ?? 
                      const EdgeInsets.all(AppSpacing.md);
            break;
        }
        
        return Padding(
          padding: padding,
          child: child,
        );
      },
    );
  }
}

/// Responsive grid that adapts column count to screen size.
/// 
/// Creates a grid layout that automatically adjusts the number of columns
/// based on screen size. Defaults to sensible column counts (1 mobile,
/// 2 tablet, 3 desktop, 4 large desktop) if not specified.
/// 
/// Usage:
/// ```dart
/// ResponsiveGrid(
///   mobileColumns: 1,
///   tabletColumns: 2,
///   desktopColumns: 3,
///   children: [Widget1(), Widget2(), Widget3()],
/// )
/// ```
class ResponsiveGrid extends StatelessWidget {
  /// List of child widgets to display in the grid.
  final List<Widget> children;
  
  /// Number of columns on mobile devices (default: 1).
  final int? mobileColumns;
  
  /// Number of columns on tablet devices (default: 2).
  final int? tabletColumns;
  
  /// Number of columns on desktop devices (default: 3).
  final int? desktopColumns;
  
  /// Number of columns on large desktop devices (default: 4).
  final int? largeDesktopColumns;
  
  /// Horizontal spacing between grid items.
  final double spacing;
  
  /// Vertical spacing between grid rows.
  final double runSpacing;
  
  /// Aspect ratio of grid children (width/height).
  final double? childAspectRatio;
  
  /// Whether grid should shrink-wrap its content.
  final bool shrinkWrap;
  
  /// Scroll physics for the grid view.
  final ScrollPhysics? physics;

  /// Creates a responsive grid layout.
  /// 
  /// @param children Widgets to display in grid
  /// @param mobileColumns Columns for mobile (default: 1)
  /// @param tabletColumns Columns for tablet (default: 2)
  /// @param desktopColumns Columns for desktop (default: 3)
  /// @param largeDesktopColumns Columns for large desktop (default: 4)
  /// @param spacing Horizontal spacing between items
  /// @param runSpacing Vertical spacing between rows
  /// @param childAspectRatio Aspect ratio of grid children
  /// @param shrinkWrap Whether to shrink-wrap content
  /// @param physics Scroll physics for grid
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.largeDesktopColumns,
    this.spacing = AppSpacing.md,
    this.runSpacing = AppSpacing.md,
    this.childAspectRatio,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, screenSize) {
        int columns;
        
        switch (screenSize) {
          case ScreenSize.largeDesktop:
            columns = largeDesktopColumns ?? desktopColumns ?? tabletColumns ?? mobileColumns ?? 4;
            break;
          case ScreenSize.desktop:
            columns = desktopColumns ?? tabletColumns ?? mobileColumns ?? 3;
            break;
          case ScreenSize.tablet:
            columns = tabletColumns ?? mobileColumns ?? 2;
            break;
          case ScreenSize.mobile:
            columns = mobileColumns ?? 1;
            break;
        }
        
        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: runSpacing,
            childAspectRatio: childAspectRatio ?? 1.0,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Responsive container with max width constraints.
/// 
/// Constrains content to a maximum width for better readability
/// on large screens. Optionally centers the content and applies
/// padding. Uses AppSpacing.maxContentWidth as default max width.
/// 
/// Usage:
/// ```dart
/// ResponsiveContainer(
///   maxWidth: 800,
///   child: MyContent(),
/// )
/// ```
class ResponsiveContainer extends StatelessWidget {
  /// Child widget to constrain and optionally center.
  final Widget child;
  
  /// Maximum width constraint (default: AppSpacing.maxContentWidth).
  final double? maxWidth;
  
  /// Whether to center the constrained content.
  final bool center;
  
  /// Optional padding to apply inside the container.
  final EdgeInsets? padding;

  /// Creates a responsive container with width constraints.
  /// 
  /// @param child Widget to constrain
  /// @param maxWidth Maximum width (default: AppSpacing.maxContentWidth)
  /// @param center Whether to center content (default: true)
  /// @param padding Optional internal padding
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.center = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget container = Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? AppSpacing.maxContentWidth,
      ),
      padding: padding,
      child: child,
    );

    if (center) {
      container = Center(child: container);
    }

    return container;
  }
}

/// Responsive columns that stack on mobile.
/// 
/// Displays children as a horizontal row on larger screens
/// and stacks them vertically on mobile devices. Automatically
/// applies appropriate spacing between children.
/// 
/// Usage:
/// ```dart
/// ResponsiveColumns(
///   children: [Widget1(), Widget2(), Widget3()],
///   spacing: 16,
/// )
/// ```
class ResponsiveColumns extends StatelessWidget {
  /// List of child widgets to display as columns/stack.
  final List<Widget> children;
  
  /// Main axis alignment for row layout (larger screens).
  final MainAxisAlignment mainAxisAlignment;
  
  /// Cross axis alignment for both row and column layouts.
  final CrossAxisAlignment crossAxisAlignment;
  
  /// Spacing between children (horizontal for row, vertical for column).
  final double spacing;

  /// Creates responsive columns that adapt to screen size.
  /// 
  /// @param children Widgets to display
  /// @param mainAxisAlignment Main axis alignment for row layout
  /// @param crossAxisAlignment Cross axis alignment for both layouts
  /// @param spacing Spacing between children
  const ResponsiveColumns({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.spacing = AppSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, screenSize) {
        if (screenSize == ScreenSize.mobile) {
          // Stack vertically on mobile
          return Column(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            children: children
                .expand((child) => [child, SizedBox(height: spacing)])
                .take(children.length * 2 - 1)
                .toList(),
          );
        } else {
          // Display as row on larger screens
          return Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            children: children
                .expand((child) => [Expanded(child: child), SizedBox(width: spacing)])
                .take(children.length * 2 - 1)
                .toList(),
          );
        }
      },
    );
  }
}

/// Adaptive card that adjusts size based on screen.
/// 
/// Creates a Material Design card that adapts its padding and
/// margins based on screen size. Optionally constrains width
/// on larger screens for better visual hierarchy.
/// 
/// Usage:
/// ```dart
/// ResponsiveCard(
///   fullWidth: false,
///   child: CardContent(),
/// )
/// ```
class ResponsiveCard extends StatelessWidget {
  /// Child widget to display inside the card.
  final Widget child;
  
  /// Custom padding override (uses responsive defaults if not provided).
  final EdgeInsets? padding;
  
  /// Custom margin override (uses responsive defaults if not provided).
  final EdgeInsets? margin;
  
  /// Card elevation override.
  final double? elevation;
  
  /// Card background color override.
  final Color? color;
  
  /// Whether card should take full width on all screen sizes.
  final bool fullWidth;

  /// Creates an adaptive card with responsive sizing.
  /// 
  /// @param child Content to display in card
  /// @param padding Custom padding (optional)
  /// @param margin Custom margin (optional)
  /// @param elevation Card elevation (optional)
  /// @param color Card background color (optional)
  /// @param fullWidth Whether to take full width (default: false)
  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, screenSize) {
        EdgeInsets cardPadding;
        EdgeInsets cardMargin;
        
        switch (screenSize) {
          case ScreenSize.largeDesktop:
          case ScreenSize.desktop:
            cardPadding = padding ?? const EdgeInsets.all(AppSpacing.lg);
            cardMargin = margin ?? const EdgeInsets.all(AppSpacing.sm);
            break;
          case ScreenSize.tablet:
            cardPadding = padding ?? const EdgeInsets.all(AppSpacing.md);
            cardMargin = margin ?? const EdgeInsets.all(AppSpacing.sm);
            break;
          case ScreenSize.mobile:
            cardPadding = padding ?? const EdgeInsets.all(AppSpacing.md);
            cardMargin = margin ?? const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            );
            break;
        }

        Widget card = Card(
          elevation: elevation,
          color: color,
          margin: cardMargin,
          child: Padding(
            padding: cardPadding,
            child: child,
          ),
        );

        if (!fullWidth && screenSize != ScreenSize.mobile) {
          card = ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxCardWidth,
            ),
            child: card,
          );
        }

        return card;
      },
    );
  }
}

/// Helper class for responsive values.
/// 
/// Generic container for screen-size-specific values with intelligent
/// fallback behavior. Useful for defining responsive properties that
/// aren't covered by the standard responsive widgets.
/// 
/// Usage:
/// ```dart
/// final fontSize = ResponsiveValue<double>(
///   mobile: 14,
///   tablet: 16,
///   desktop: 18,
/// );
/// final size = fontSize.getValue(context.screenSize);
/// ```
class ResponsiveValue<T> {
  /// Value for mobile devices (required).
  final T mobile;
  
  /// Value for tablet devices (falls back to mobile if not provided).
  final T? tablet;
  
  /// Value for desktop devices (falls back to tablet/mobile if not provided).
  final T? desktop;
  
  /// Value for large desktop devices (falls back to desktop/tablet/mobile if not provided).
  final T? largeDesktop;

  /// Creates a responsive value container.
  /// 
  /// @param mobile Value for mobile devices (required)
  /// @param tablet Value for tablet devices (optional)
  /// @param desktop Value for desktop devices (optional)
  /// @param largeDesktop Value for large desktop devices (optional)
  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  /// Gets the appropriate value for the given screen size.
  /// 
  /// Implements fallback logic: if a value isn't defined for the
  /// current screen size, falls back to the next smaller size.
  /// 
  /// @param screenSize Current screen size category
  /// @return Appropriate value for the screen size
  T getValue(ScreenSize screenSize) {
    switch (screenSize) {
      case ScreenSize.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile;
      case ScreenSize.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.mobile:
        return mobile;
    }
  }
}

/// Extension to get screen size from BuildContext.
/// 
/// Provides convenient access to screen size information directly
/// from any BuildContext. Includes both the semantic screen size
/// and boolean helpers for common responsive checks.
/// 
/// Usage:
/// ```dart
/// if (context.isMobile) {
///   return MobileLayout();
/// }
/// ```
extension ScreenSizeExtension on BuildContext {
  /// Gets the current screen size category.
  /// 
  /// Determines screen size based on MediaQuery width and
  /// standard breakpoints defined in AppSpacing.
  ScreenSize get screenSize {
    final width = MediaQuery.of(this).size.width;
    
    if (width >= AppSpacing.largeDesktopBreakpoint) {
      return ScreenSize.largeDesktop;
    } else if (width >= AppSpacing.desktopBreakpoint) {
      return ScreenSize.desktop;
    } else if (width >= AppSpacing.tabletBreakpoint) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.mobile;
    }
  }

  /// Whether the current screen is mobile size.
  bool get isMobile => screenSize == ScreenSize.mobile;
  
  /// Whether the current screen is tablet size.
  bool get isTablet => screenSize == ScreenSize.tablet;
  
  /// Whether the current screen is desktop or larger.
  bool get isDesktop => screenSize == ScreenSize.desktop || screenSize == ScreenSize.largeDesktop;
  
  /// Whether the current screen is large desktop size.
  bool get isLargeDesktop => screenSize == ScreenSize.largeDesktop;
}