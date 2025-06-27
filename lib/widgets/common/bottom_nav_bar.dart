import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    List<BottomNavigationBarItem> items = [];
    List<String> routes = [];

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
        '/dashboard',
        '/teacher/classes',
        '/teacher/gradebook',
        '/messages',
      ];
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
        '/dashboard',
        '/student/courses',
        '/student/assignments',
        '/student/grades',
      ];
    } else {
      // Default for admin or unknown role
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
        '/dashboard',
        '/settings',
      ];
    }

    int currentIndex = routes.indexOf(currentRoute);
    if (currentIndex == -1) currentIndex = 0;

    return BottomNavigationBar(
      items: items,
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index < routes.length) {
          context.go(routes[index]);
        }
      },
    );
  }
}