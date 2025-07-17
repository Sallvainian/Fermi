/// Role-based bottom navigation bar for the education platform.
/// 
/// This module provides adaptive navigation that changes based on user role,
/// supporting different navigation structures for teachers, students, and admins
/// with role-specific icons, labels, and routes.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../models/user_model.dart';

/// Adaptive bottom navigation bar that adjusts based on user role.
/// 
/// This widget provides role-specific navigation with:
/// - Teacher navigation: Dashboard, Classes, Gradebook, Messages
/// - Student navigation: Dashboard, Courses, Assignments, Grades
/// - Admin/default navigation: Dashboard, Settings
/// 
/// Features:
/// - Automatic route detection and highlighting
/// - Role-based icon and label customization
/// - Go Router integration for navigation
/// - Fallback handling for unknown routes
/// - Authentication state awareness
/// 
/// The navigation adapts in real-time when user role changes
/// and maintains proper route synchronization.
class BottomNavBar extends StatelessWidget {
  /// Creates an adaptive bottom navigation bar.
  /// 
  /// The navigation items and routes are determined automatically
  /// based on the current user's role from the auth provider.
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch authentication state for real-time role updates
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;
    
    // Get current route for highlighting active navigation item
    final currentRoute = GoRouterState.of(context).matchedLocation;

    // Initialize navigation configuration based on user role
    List<BottomNavigationBarItem> items = [];
    List<String> routes = [];

    // Configure teacher navigation with academic management features
    if (user?.role == UserRole.teacher) {
      items = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.class_outlined),
          activeIcon: Icon(Icons.class_),
          label: 'Classes',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.grade_outlined),
          activeIcon: Icon(Icons.grade),
          label: 'Gradebook',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          activeIcon: Icon(Icons.chat),
          label: 'Messages',
        ),
      ];
      routes = [
        '/dashboard',        // Overview and quick actions
        '/teacher/classes',  // Class management and roster
        '/teacher/gradebook', // Grade entry and analytics
        '/messages',         // Communication hub
      ];
    // Configure student navigation with learning-focused features
    } else if (user?.role == UserRole.student) {
      items = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.book_outlined),
          activeIcon: Icon(Icons.book),
          label: 'Courses',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined),
          activeIcon: Icon(Icons.assignment),
          label: 'Assignments',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.grade_outlined),
          activeIcon: Icon(Icons.grade),
          label: 'Grades',
        ),
      ];
      routes = [
        '/dashboard',           // Student overview and schedule
        '/student/courses',     // Enrolled courses and materials
        '/student/assignments', // Assignment submissions
        '/student/grades',      // Grade tracking and reports
      ];
    // Configure default navigation for admin or unknown roles
    } else {
      // Fallback navigation for admin users or undefined roles
      items = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ];
      routes = [
        '/dashboard', // System overview
        '/settings',  // Administrative settings
      ];
    }

    // Determine active tab index from current route
    int currentIndex = routes.indexOf(currentRoute);
    if (currentIndex == -1) currentIndex = 0; // Default to first tab if route not found

    return BottomNavigationBar(
      items: items,
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed, // Ensure all tabs are always visible
      onTap: (index) {
        // Navigate to selected route with bounds checking
        if (index < routes.length) {
          context.go(routes[index]);
        }
      },
    );
  }
}