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

  // Convert to/from JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'route': route,
    'icon': icon.codePoint,
    'activeIcon': activeIcon.codePoint,
    'category': category,
    'roles': roles,
  };

  factory NavItem.fromJson(Map<String, dynamic> json) => NavItem(
    id: json['id'],
    title: json['title'],
    route: json['route'],
    icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
    activeIcon: IconData(json['activeIcon'], fontFamily: 'MaterialIcons'),
    category: json['category'],
    roles: List<String>.from(json['roles']),
  );
}