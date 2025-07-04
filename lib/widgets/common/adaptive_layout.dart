import 'package:flutter/material.dart';
import 'app_drawer.dart';
import 'bottom_nav_bar.dart';
import 'responsive_layout.dart';
import '../../theme/app_spacing.dart';

class AdaptiveLayout extends StatelessWidget {
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final bool showNavigationDrawer;
  final bool showBottomNavigation;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  const AdaptiveLayout({
    super.key,
    required this.body,
    required this.title,
    this.actions,
    this.showNavigationDrawer = true,
    this.showBottomNavigation = true,
    this.floatingActionButton,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, screenSize) {
        if (screenSize == ScreenSize.mobile) {
          // Mobile layout with drawer and bottom navigation
          return Scaffold(
            appBar: AppBar(
              title: Text(title),
              actions: actions,
              bottom: bottom,
            ),
            drawer: showNavigationDrawer ? const AppDrawer() : null,
            body: ResponsivePadding(
              mobile: const EdgeInsets.all(AppSpacing.md),
              child: body,
            ),
            bottomNavigationBar: showBottomNavigation ? const BottomNavBar() : null,
            floatingActionButton: floatingActionButton,
          );
        } else {
          // Desktop/Tablet layout with permanent navigation drawer
          return Scaffold(
            body: Row(
              children: [
                if (showNavigationDrawer)
                  const SizedBox(
                    width: AppSpacing.drawerWidth,
                    child: AppDrawer(),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      AppBar(
                        title: Text(title),
                        actions: actions,
                        automaticallyImplyLeading: false,
                        bottom: bottom,
                      ),
                      Expanded(
                        child: ResponsivePadding(
                          tablet: const EdgeInsets.all(AppSpacing.lg),
                          desktop: const EdgeInsets.all(AppSpacing.xl),
                          child: body,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: floatingActionButton,
          );
        }
      },
    );
  }
}

// Legacy responsive builder for backward compatibility
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isWideScreen) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, screenSize) {
        final isWideScreen = screenSize != ScreenSize.mobile;
        return builder(context, isWideScreen);
      },
    );
  }
}