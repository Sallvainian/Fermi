import 'package:flutter/material.dart';

/// Navigation item model for customizable navigation
class NavItem {
  final String id;
  final String title;
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String category;
  final List<String> roles; // Which roles can use this item

  const NavItem({
    required this.id,
    required this.title,
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.category,
    required this.roles,
  });

  // Scalable icon mapping - add new icons here
  static final Map<String, IconData> _iconNameToData = {
    'dashboard': Icons.dashboard,
    'dashboard_outlined': Icons.dashboard_outlined,
    'people': Icons.people,
    'people_outline': Icons.people_outline,
    'class_': Icons.class_,
    'class_outlined': Icons.class_outlined,
    'assignment': Icons.assignment,
    'assignment_outlined': Icons.assignment_outlined,
    'calendar_today': Icons.calendar_today,
    'calendar_today_outlined': Icons.calendar_today_outlined,
    'message': Icons.message,
    'message_outlined': Icons.message_outlined,
    'analytics': Icons.analytics,
    'analytics_outlined': Icons.analytics_outlined,
    'settings': Icons.settings,
    'settings_outlined': Icons.settings_outlined,
    'person': Icons.person,
    'person_outline': Icons.person_outline,
    'help_outline': Icons.help_outline,
    'help': Icons.help,
  };

  // Reverse map for IconData to String conversion
  static final Map<IconData, String> _iconDataToName = {
    for (var entry in _iconNameToData.entries) entry.value: entry.key
  };

  // Convert to/from JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'route': route,
    'icon': _iconToString(icon),
    'activeIcon': _iconToString(activeIcon),
    'category': category,
    'roles': roles,
  };

  factory NavItem.fromJson(Map<String, dynamic> json) => NavItem(
    id: json['id'],
    title: json['title'],
    route: json['route'],
    icon: _iconFromString(json['icon'] ?? 'help_outline'),
    activeIcon: _iconFromString(json['activeIcon'] ?? 'help'),
    category: json['category'],
    roles: List<String>.from(json['roles']),
  );

  // Scalable helper methods using Maps
  static String _iconToString(IconData icon) {
    return _iconDataToName[icon] ?? 'help_outline';
  }

  static IconData _iconFromString(String name) {
    return _iconNameToData[name] ?? Icons.help_outline;
  }
}