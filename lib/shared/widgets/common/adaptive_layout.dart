/// Adaptive layout system for responsive navigation and content presentation.
///
/// This module provides platform-aware layout components that automatically
/// adapt between mobile and desktop/tablet layouts, handling navigation
/// patterns, spacing, and UI structure for optimal user experience across
/// different screen sizes and educational platform contexts.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../navigation/app_drawer.dart';
import '../navigation/favorites_nav_bar.dart';
import 'responsive_layout.dart';
import '../../theme/app_spacing.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';

/// Adaptive layout wrapper that switches between mobile and desktop layouts.
///
/// This widget provides automatic layout adaptation based on screen size:
/// - **Mobile Layout**: Standard Scaffold with drawer, bottom navigation, and mobile spacing
/// - **Desktop/Tablet Layout**: Permanent side navigation with expanded content area
///
/// Key Features:
/// - Automatic responsive breakpoint detection
/// - Conditional navigation drawer display (slide-out mobile, permanent desktop)
/// - Bottom navigation bar for mobile, hidden for desktop
/// - Responsive padding that scales with screen size
/// - Consistent app bar behavior across layouts
/// - Support for floating action buttons and custom app bar actions
/// - Back button handling with custom callbacks
/// - Optional navigation components for different screen contexts
///
/// Layout Behavior:
/// - Mobile (< 768px): Drawer slides from left, bottom nav visible, compact spacing
/// - Tablet/Desktop (≥ 768px): Permanent drawer sidebar, no bottom nav, generous spacing
/// - Maintains consistent theme integration and accessibility
///
/// Usage:
/// ```dart
/// AdaptiveLayout(
///   title: 'Dashboard',
///   body: DashboardContent(),
///   actions: [IconButton(icon: Icon(Icons.settings), onPressed: () {})],
///   showBackButton: true,
///   onBackPressed: () => context.go('/'),
/// )
/// ```
class AdaptiveLayout extends StatelessWidget {
  /// Main content widget to display in the layout body.
  final Widget body;

  /// Title text displayed in the app bar across all screen sizes.
  final String title;

  /// Optional action widgets for the app bar (typically IconButtons).
  ///
  /// Displayed in the trailing section of the app bar.
  /// Common actions include settings, search, or context menus.
  final List<Widget>? actions;

  /// Whether to show the navigation drawer/sidebar.
  ///
  /// When true, displays slide-out drawer on mobile and permanent
  /// sidebar on desktop/tablet. Defaults to true.
  final bool showNavigationDrawer;

  /// Whether to show bottom navigation bar on mobile layouts.
  ///
  /// Defaults to true. Bottom navigation is always hidden on
  /// desktop/tablet layouts regardless of this setting.
  final bool showBottomNavigation;

  /// Optional floating action button to display.
  ///
  /// Positioned consistently across both mobile and desktop layouts
  /// following Material Design guidelines.
  final Widget? floatingActionButton;

  /// Optional bottom widget for the app bar (typically TabBar).
  ///
  /// Extends the app bar downward and maintains consistent
  /// behavior across responsive layouts.
  final PreferredSizeWidget? bottom;

  /// Whether to show back button instead of menu/drawer toggle.
  ///
  /// When true, replaces the drawer toggle with a back arrow.
  /// Useful for detail views and nested navigation screens.
  final bool showBackButton;

  /// Custom callback for back button press handling.
  ///
  /// If not provided, defaults to Navigator.pop() behavior.
  /// Use for custom navigation logic or route management.
  final VoidCallback? onBackPressed;

  /// Creates an adaptive layout with responsive navigation.
  ///
  /// @param body Main content widget (required)
  /// @param title App bar title text (required)
  /// @param actions Optional app bar action widgets
  /// @param showNavigationDrawer Whether to show drawer/sidebar (default: true)
  /// @param showBottomNavigation Whether to show bottom nav on mobile (default: true)
  /// @param floatingActionButton Optional floating action button
  /// @param bottom Optional app bar bottom widget (e.g., TabBar)
  /// @param showBackButton Whether to show back button (default: false)
  /// @param onBackPressed Custom back button callback (optional)
  const AdaptiveLayout({
    super.key,
    required this.body,
    required this.title,
    this.actions,
    this.showNavigationDrawer = true,
    this.showBottomNavigation = true,
    this.floatingActionButton,
    this.bottom,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Get providers
    final authProvider = context.watch<AuthProvider>();

    // Schedule role update after build completes
    if (authProvider.userModel != null) {
      final role = authProvider.userModel!.role
          .toString()
          .split('.')
          .last
          .toLowerCase();
      // Use a microtask to ensure this happens after the current build
      Future.microtask(() {
        if (context.mounted) {
          context.read<NavigationProvider>().setRole(role);
        }
      });
    }

    return ResponsiveLayoutBuilder(
      builder: (context, screenSize) {
        if (screenSize == ScreenSize.mobile) {
          // Mobile layout with drawer and bottom navigation
          return Scaffold(
            appBar: AppBar(
              // Show back button or default drawer toggle
              leading: showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed:
                          onBackPressed ??
                          () {
                            // Use GoRouter instead of Navigator for better navigation control
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              // If we can't pop, go to the dashboard
                              context.go('/dashboard');
                            }
                          },
                    )
                  : null,
              title: Text(title),
              actions: actions,
              bottom: bottom,
            ),
            // Conditional drawer display (hidden when showing back button)
            drawer: showNavigationDrawer && !showBackButton
                ? const AppDrawer()
                : null,
            // Content area with mobile-optimized padding and safe area handling
            body: SafeArea(
              child: ResponsivePadding(
                mobile: const EdgeInsets.all(AppSpacing.md),
                child: body,
              ),
            ),
            // Bottom navigation for mobile-first navigation pattern
            bottomNavigationBar: showBottomNavigation
                ? const FavoritesNavBar()
                : null,
            floatingActionButton: floatingActionButton,
          );
        } else {
          // Desktop/Tablet layout with permanent navigation drawer
          return Scaffold(
            body: Row(
              children: [
                // Permanent navigation sidebar for larger screens
                if (showNavigationDrawer)
                  const SizedBox(
                    width: AppSpacing.drawerWidth,
                    child: AppDrawer(),
                  ),
                // Main content area with app bar and content
                Expanded(
                  child: Scaffold(
                    appBar: AppBar(
                      // Back button handling for desktop layout
                      leading: showBackButton
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed:
                                  onBackPressed ??
                                  () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/dashboard');
                                    }
                                  },
                            )
                          : null,
                      title: Text(title),
                      actions: actions,
                      automaticallyImplyLeading:
                          false, // Disable default drawer toggle
                      bottom: bottom,
                    ),
                    body: SafeArea(
                      child: ResponsivePadding(
                        tablet: const EdgeInsets.all(AppSpacing.lg),
                        desktop: const EdgeInsets.all(AppSpacing.xl),
                        child: body,
                      ),
                    ),
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
