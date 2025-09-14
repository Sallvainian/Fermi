import 'package:flutter/material.dart';

/// Available color themes for the application
class AppColors {
  static const Map<String, ColorThemeData> availableThemes = {
    'indigo': ColorThemeData(
      name: 'Indigo',
      primary: Color(0xFF3F51B5),
      secondary: Color(0xFF009688),
      icon: Icons.water_drop,
    ),
    'blue': ColorThemeData(
      name: 'Blue',
      primary: Color(0xFF2196F3),
      secondary: Color(0xFF00BCD4),
      icon: Icons.water,
    ),
    'purple': ColorThemeData(
      name: 'Purple',
      primary: Color(0xFF9C27B0),
      secondary: Color(0xFFE91E63),
      icon: Icons.favorite,
    ),
    'deepPurple': ColorThemeData(
      name: 'Deep Purple',
      primary: Color(0xFF673AB7),
      secondary: Color(0xFF7C4DFF),
      icon: Icons.gradient,
    ),
    'green': ColorThemeData(
      name: 'Green',
      primary: Color(0xFF4CAF50),
      secondary: Color(0xFF8BC34A),
      icon: Icons.eco,
    ),
    'teal': ColorThemeData(
      name: 'Teal',
      primary: Color(0xFF009688),
      secondary: Color(0xFF00BCD4),
      icon: Icons.waves,
    ),
    'orange': ColorThemeData(
      name: 'Orange',
      primary: Color(0xFFFF9800),
      secondary: Color(0xFFFF5722),
      icon: Icons.wb_sunny,
    ),
    'red': ColorThemeData(
      name: 'Red',
      primary: Color(0xFFF44336),
      secondary: Color(0xFFE91E63),
      icon: Icons.favorite_border,
    ),
    'pink': ColorThemeData(
      name: 'Pink',
      primary: Color(0xFFE91E63),
      secondary: Color(0xFFF06292),
      icon: Icons.favorite,
    ),
    'amber': ColorThemeData(
      name: 'Amber',
      primary: Color(0xFFFFC107),
      secondary: Color(0xFFFF9800),
      icon: Icons.brightness_7,
    ),
    'cyan': ColorThemeData(
      name: 'Cyan',
      primary: Color(0xFF00BCD4),
      secondary: Color(0xFF0097A7),
      icon: Icons.pool,
    ),
    'brown': ColorThemeData(
      name: 'Brown',
      primary: Color(0xFF795548),
      secondary: Color(0xFF6D4C41),
      icon: Icons.coffee,
    ),
  };

  static ColorThemeData getTheme(String? themeId) {
    final theme = availableThemes[themeId] ?? availableThemes['indigo']!;
    return theme;
  }
}

/// Data class for color theme information
class ColorThemeData {
  final String name;
  final Color primary;
  final Color secondary;
  final IconData icon;

  const ColorThemeData({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.icon,
  });
}
