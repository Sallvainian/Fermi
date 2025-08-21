import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/nav_item.dart';
import './logger_service.dart';

/// Service for managing navigation items and favorites
class NavigationService {
  static const String _favoritesKey = 'nav_favorites';
  static const int maxFavorites = 4;

  // All available navigation items
  static const List<NavItem> allItems = [
    // Student items
    NavItem(
      id: 'dashboard',
      title: 'Dashboard',
      route: '/dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      category: 'general',
      roles: ['student', 'teacher'],
    ),
    NavItem(
      id: 'courses',
      title: 'Courses',
      route: '/student/courses',
      icon: Icons.book_outlined,
      activeIcon: Icons.book,
      category: 'academic',
      roles: ['student'],
    ),
    NavItem(
      id: 'assignments',
      title: 'Assignments',
      route: '/student/assignments',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      category: 'academic',
      roles: ['student'],
    ),
    NavItem(
      id: 'grades',
      title: 'Grades',
      route: '/student/grades',
      icon: Icons.grade_outlined,
      activeIcon: Icons.grade,
      category: 'academic',
      roles: ['student'],
    ),
    NavItem(
      id: 'messages',
      title: 'Messages',
      route: '/messages',
      icon: Icons.chat_outlined,
      activeIcon: Icons.chat,
      category: 'communication',
      roles: ['student', 'teacher'],
    ),
    NavItem(
      id: 'calendar',
      title: 'Calendar',
      route: '/calendar',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
      category: 'planning',
      roles: ['student', 'teacher'],
    ),
    NavItem(
      id: 'notifications',
      title: 'Notifications',
      route: '/notifications',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      category: 'communication',
      roles: ['student', 'teacher'],
    ),
    NavItem(
      id: 'discussions',
      title: 'Discussions',
      route: '/discussions',
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum,
      category: 'communication',
      roles: ['student', 'teacher'],
    ),
    NavItem(
      id: 'settings',
      title: 'Settings',
      route: '/settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      category: 'system',
      roles: ['student', 'teacher'],
    ),
    // Teacher items
    NavItem(
      id: 'classes',
      title: 'Classes',
      route: '/teacher/classes',
      icon: Icons.class_outlined,
      activeIcon: Icons.class_,
      category: 'teaching',
      roles: ['teacher'],
    ),
    NavItem(
      id: 'gradebook',
      title: 'Gradebook',
      route: '/teacher/gradebook',
      icon: Icons.grade_outlined,
      activeIcon: Icons.grade,
      category: 'teaching',
      roles: ['teacher'],
    ),
    NavItem(
      id: 'teacher-assignments',
      title: 'Assignments',
      route: '/teacher/assignments',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      category: 'teaching',
      roles: ['teacher'],
    ),
    NavItem(
      id: 'students',
      title: 'Students',
      route: '/teacher/students',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      category: 'teaching',
      roles: ['teacher'],
    ),
    NavItem(
      id: 'analytics',
      title: 'Analytics',
      route: '/teacher/analytics',
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
      category: 'teaching',
      roles: ['teacher'],
    ),
  ];

  /// Get navigation items for a specific role
  static List<NavItem> getItemsForRole(String role) {
    return allItems.where((item) => item.roles.contains(role)).toList();
  }

  /// Get items by category
  static List<NavItem> getItemsByCategory(String category, String role) {
    return allItems
        .where((item) => item.category == category && item.roles.contains(role))
        .toList();
  }

  /// Load favorite item IDs from storage
  static Future<List<String>> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getString(_favoritesKey);
      if (favoritesJson != null) {
        return List<String>.from(json.decode(favoritesJson));
      }
    } catch (e) {
      LoggerService.error('Error loading favorites',
          tag: 'NavigationService', error: e);
    }
    return [];
  }

  /// Save favorite item IDs to storage
  static Future<bool> saveFavorites(List<String> favoriteIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Limit to max favorites
      final limitedFavorites = favoriteIds.take(maxFavorites).toList();
      return await prefs.setString(
          _favoritesKey, json.encode(limitedFavorites));
    } catch (e) {
      LoggerService.error('Error saving favorites',
          tag: 'NavigationService', error: e);
      return false;
    }
  }

  /// Get default favorites for a role
  static List<String> getDefaultFavorites(String role) {
    if (role == 'student') {
      return ['dashboard', 'courses', 'assignments', 'grades'];
    } else if (role == 'teacher') {
      return ['dashboard', 'classes', 'gradebook', 'messages'];
    }
    return ['dashboard', 'settings'];
  }

  /// Get navigation items from favorite IDs
  static List<NavItem> getFavoriteItems(List<String> favoriteIds) {
    return favoriteIds
        .map((id) => allItems.firstWhere(
              (item) => item.id == id,
              orElse: () => allItems.first,
            ))
        .toList();
  }
}
