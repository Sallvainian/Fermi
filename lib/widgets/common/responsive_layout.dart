import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// Screen size breakpoints for responsive design
enum ScreenSize {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

/// Responsive layout builder that provides screen size context
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

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

/// Responsive widget that shows different widgets based on screen size
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? largeDesktop;

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

/// Responsive padding that adapts to screen size
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? mobile;
  final EdgeInsets? tablet;
  final EdgeInsets? desktop;
  final EdgeInsets? largeDesktop;

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

/// Responsive grid that adapts column count to screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final int? largeDesktopColumns;
  final double spacing;
  final double runSpacing;
  final double? childAspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

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

/// Responsive container with max width constraints
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool center;
  final EdgeInsets? padding;

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

/// Responsive columns that stack on mobile
class ResponsiveColumns extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

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

/// Adaptive card that adjusts size based on screen
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? elevation;
  final Color? color;
  final bool fullWidth;

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

/// Helper class for responsive values
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;
  final T? largeDesktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

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

/// Extension to get screen size from BuildContext
extension ScreenSizeExtension on BuildContext {
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

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop || screenSize == ScreenSize.largeDesktop;
  bool get isLargeDesktop => screenSize == ScreenSize.largeDesktop;
}