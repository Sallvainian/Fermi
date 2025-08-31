/// Application theme configuration and utilities.
///
/// This module provides comprehensive theme configuration for both light and
/// dark modes, including Material 3 design compliance, educational-specific
/// color schemes, and utility methods for dynamic styling.
library;

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Central theme configuration for the application.
///
/// This class provides complete theme management with:
/// - Material 3 compliant light and dark themes
/// - Educational-specific color schemes and utilities
/// - Semantic color definitions for grades and priorities
/// - Subject-specific color coding for visual organization
/// - Custom component theming for consistency
/// - Utility methods for dynamic color selection
///
/// The theme follows Material 3 design principles while
/// incorporating educational context-specific styling.
class AppTheme {
  /// Primary brand color - Indigo for professional education feel.
  static const Color primaryColor = Color(0xFF3F51B5); // Indigo

  /// Secondary accent color - Teal for complementary contrast.
  static const Color secondaryColor = Color(0xFF009688); // Teal

  /// Error color for validation messages and alerts.
  static const Color errorColor = Color(0xFFE53935);

  /// Warning color for caution messages and notices.
  static const Color warningColor = Color(0xFFFF9800);

  /// Success color for positive feedback and confirmations.
  static const Color successColor = Color(0xFF4CAF50);

  /// Generates Material 3 color scheme from primary color.
  ///
  /// Creates a harmonious color palette following Material 3
  /// design principles using the primary color as seed.
  ///
  /// @param brightness Light or dark theme brightness
  /// @param seedColor Optional custom seed color
  /// @return Generated color scheme
  static ColorScheme _createColorScheme(Brightness brightness, {Color? seedColor}) {
    return ColorScheme.fromSeed(
      seedColor: seedColor ?? primaryColor,
      brightness: brightness,
    );
  }

  /// Creates the light theme configuration.
  ///
  /// Provides a clean, professional light theme suitable for
  /// educational environments with high readability and
  /// accessibility considerations.
  ///
  /// @param colorThemeId Optional color theme ID for custom colors
  /// @return Configured light theme data
  static ThemeData lightTheme({String? colorThemeId}) {
    final colorTheme = AppColors.getTheme(colorThemeId);
    final colorScheme = _createColorScheme(Brightness.light, seedColor: colorTheme.primary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 1,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.2), width: 0.5),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // Navigation Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// Creates the dark theme configuration.
  ///
  /// Provides a sleek black dark theme optimized for low-light
  /// environments with high contrast and modern Material 3
  /// design principles. Features true black surfaces for
  /// OLED displays and reduced eye strain.
  ///
  /// @param colorThemeId Optional color theme ID for custom colors
  /// @return Configured dark theme data
  static ThemeData darkTheme({String? colorThemeId}) {
    // Create a sleek black dark theme
    const surfaceBlack = Color(0xFF000000);
    const cardBlack = Color(0xFF0F0F0F);
    const containerBlack = Color(0xFF1C1C1C);
    const borderGrey = Color(0xFF2A2A2A);

    final colorTheme = AppColors.getTheme(colorThemeId);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colorTheme.primary,
      brightness: Brightness.dark,
    ).copyWith(
      surface: surfaceBlack,
      onSurface: const Color(0xFFE5E5E5),
      surfaceContainerLowest: surfaceBlack,
      surfaceContainerLow: cardBlack,
      surfaceContainer: containerBlack,
      surfaceContainerHigh: const Color(0xFF252525),
      surfaceContainerHighest: const Color(0xFF303030),
      onSurfaceVariant: const Color(0xFFB3B3B3),
      outline: borderGrey,
      outlineVariant: const Color(0xFF1A1A1A),
      primary: const Color(0xFF6366F1), // Modern indigo
      onPrimary: Colors.white,
      secondary: const Color(0xFF10B981), // Modern emerald
      onSecondary: Colors.white,
      tertiary: const Color(0xFFF59E0B), // Modern amber
      onTertiary: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surfaceBlack,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: const Color(0xFF0F0F0F),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // Navigation Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// Custom primary color material palette.
  ///
  /// Full Material Color palette for the primary indigo color
  /// with all standard Material Design color stops from 50-900.
  /// Used for generating color variations and tonal palettes.
  static const MaterialColor customPrimary = MaterialColor(
    0xFF3F51B5,
    <int, Color>{
      50: Color(0xFFE8EAF6),
      100: Color(0xFFC5CAE9),
      200: Color(0xFF9FA8DA),
      300: Color(0xFF7986CB),
      400: Color(0xFF5C6BC0),
      500: Color(0xFF3F51B5),
      600: Color(0xFF3949AB),
      700: Color(0xFF303F9F),
      800: Color(0xFF283593),
      900: Color(0xFF1A237E),
    },
  );

  /// Excellent grade color (A) - Green for outstanding performance.
  static const Color gradeA = Color(0xFF4CAF50); // Green

  /// Good grade color (B) - Light green for above average performance.
  static const Color gradeB = Color(0xFF8BC34A); // Light Green

  /// Average grade color (C) - Yellow for satisfactory performance.
  static const Color gradeC = Color(0xFFFFEB3B); // Yellow

  /// Below average grade color (D) - Orange for needs improvement.
  static const Color gradeD = Color(0xFFFF9800); // Orange

  /// Failing grade color (F) - Red for unsatisfactory performance.
  static const Color gradeF = Color(0xFFE53935); // Red

  /// High priority color - Red for urgent tasks and deadlines.
  static const Color priorityHigh = Color(0xFFE53935);

  /// Medium priority color - Orange for standard priority items.
  static const Color priorityMedium = Color(0xFFFF9800);

  /// Low priority color - Green for optional or future tasks.
  static const Color priorityLow = Color(0xFF4CAF50);

  /// Subject-specific colors for visual organization and categorization.
  ///
  /// Each subject gets a distinct color for easy visual identification
  /// in schedules, assignments, and navigation. Colors are chosen for
  /// accessibility and clear differentiation.
  static const List<Color> subjectColors = [
    Color(0xFF2196F3), // Blue - Mathematics
    Color(0xFF4CAF50), // Green - Science
    Color(0xFFFF9800), // Orange - English
    Color(0xFF9C27B0), // Purple - History
    Color(0xFFF44336), // Red - Physical Education
    Color(0xFF607D8B), // Blue Grey - Arts
    Color(0xFF795548), // Brown - Music
    Color(0xFF009688), // Teal - Foreign Language
  ];

  /// Returns subject color by index with cycling behavior.
  ///
  /// Uses modulo operation to cycle through available colors
  /// when index exceeds the color list length. Ensures every
  /// subject gets a consistent color assignment.
  ///
  /// @param index Subject index or identifier
  /// @return Color for the subject at the given index
  static Color getSubjectColor(int index) {
    return subjectColors[index % subjectColors.length];
  }

  /// Returns appropriate color for letter grade display.
  ///
  /// Maps letter grades to semantic colors for visual feedback:
  /// - A grades (A+, A, A-): Green (excellent)
  /// - B grades (B+, B, B-): Light green (good)
  /// - C grades (C+, C, C-): Yellow (average)
  /// - D grades (D+, D, D-): Orange (below average)
  /// - F grade: Red (failing)
  /// - Other: Grey (ungraded/unknown)
  ///
  /// @param grade Letter grade string (case-insensitive)
  /// @return Semantic color for the grade
  static Color getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
      case 'A+':
      case 'A-':
        return gradeA;
      case 'B':
      case 'B+':
      case 'B-':
        return gradeB;
      case 'C':
      case 'C+':
      case 'C-':
        return gradeC;
      case 'D':
      case 'D+':
      case 'D-':
        return gradeD;
      case 'F':
        return gradeF;
      default:
        return Colors.grey;
    }
  }

  /// Returns appropriate color for priority level display.
  ///
  /// Maps priority levels to semantic colors for visual urgency:
  /// - "high": Red (urgent, immediate attention)
  /// - "medium": Orange (standard priority)
  /// - "low": Green (optional, future consideration)
  /// - Other: Grey (unspecified priority)
  ///
  /// @param priority Priority level string (case-insensitive)
  /// @return Semantic color for the priority level
  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return priorityHigh;
      case 'medium':
        return priorityMedium;
      case 'low':
        return priorityLow;
      default:
        return Colors.grey;
    }
  }
}
