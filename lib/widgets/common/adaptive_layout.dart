import 'package:flutter/material.dart';
import 'app_drawer.dart';
import 'bottom_nav_bar.dart';

class AdaptiveLayout extends StatelessWidget {
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final bool showNavigationDrawer;
  final bool showBottomNavigation;
  final Widget? floatingActionButton;

  const AdaptiveLayout({
    super.key,
    required this.body,
    required this.title,
    this.actions,
    this.showNavigationDrawer = true,
    this.showBottomNavigation = true,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 768;

    if (isWideScreen) {
      // Desktop/Tablet layout with permanent navigation drawer
      return Scaffold(
        body: Row(
          children: [
            if (showNavigationDrawer)
              const SizedBox(
                width: 280,
                child: AppDrawer(),
              ),
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    title: Text(title),
                    actions: actions,
                    automaticallyImplyLeading: false,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    } else {
      // Mobile layout with drawer and bottom navigation
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: actions,
        ),
        drawer: showNavigationDrawer ? const AppDrawer() : null,
        body: body,
        bottomNavigationBar: showBottomNavigation ? const BottomNavBar() : null,
        floatingActionButton: floatingActionButton,
      );
    }
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isWideScreen) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 768;
    return builder(context, isWideScreen);
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    int columns;
    if (screenWidth >= 1200) {
      columns = desktopColumns;
    } else if (screenWidth >= 768) {
      columns = tabletColumns;
    } else {
      columns = mobileColumns;
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: 1.0,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}