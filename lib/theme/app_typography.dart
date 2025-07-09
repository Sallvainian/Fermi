/// Typography system for consistent text styling.
/// 
/// This module provides a comprehensive typography system based on Material 3
/// design principles, including base text styles, educational-specific styling,
/// semantic color variations, and responsive text scaling utilities.
library;

import 'package:flutter/material.dart';

/// Central typography system for consistent text styling.
/// 
/// This class provides a complete typography design system with:
/// - Material 3 compliant text style hierarchy
/// - Custom educational-specific text styles
/// - Semantic color variations (success, warning, error, info)
/// - Grade-specific styling with color coding
/// - Priority and status text styling
/// - Responsive text scaling for different screen sizes
/// - Context-aware text theme generation
/// 
/// All styles use the Inter font family and follow Material 3
/// typography scale specifications.
class AppTypography {
  /// Primary font family for the application.
  /// 
  /// Inter is chosen for its excellent readability and
  /// comprehensive character set.
  static const String fontFamily = 'Inter';

  /// Light font weight for delicate text.
  static const FontWeight light = FontWeight.w300;
  
  /// Regular font weight for standard body text.
  static const FontWeight regular = FontWeight.w400;
  
  /// Medium font weight for emphasis and labels.
  static const FontWeight medium = FontWeight.w500;
  
  /// Semi-bold font weight for headings and titles.
  static const FontWeight semiBold = FontWeight.w600;
  
  /// Bold font weight for strong emphasis.
  static const FontWeight bold = FontWeight.w700;
  
  /// Extra bold font weight for hero text.
  static const FontWeight extraBold = FontWeight.w800;

  /// Large display text style for hero headings (57px).
  /// 
  /// Used for the largest text in the application,
  /// typically for landing pages or splash screens.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 57,
    fontWeight: regular,
    height: 1.12,
    letterSpacing: -0.25,
  );

  /// Medium display text style for section headers (45px).
  /// 
  /// Used for prominent headings and feature titles.
  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 45,
    fontWeight: regular,
    height: 1.16,
    letterSpacing: 0,
  );

  /// Small display text style for page titles (36px).
  /// 
  /// Used for main page headings and important announcements.
  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: regular,
    height: 1.22,
    letterSpacing: 0,
  );

  /// Large headline text style for content headers (32px).
  /// 
  /// Used for major content section headers.
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: regular,
    height: 1.25,
    letterSpacing: 0,
  );

  /// Medium headline text style for subsection headers (28px).
  /// 
  /// Used for subsection headings and card titles.
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: regular,
    height: 1.29,
    letterSpacing: 0,
  );

  /// Small headline text style for component headers (24px).
  /// 
  /// Used for component-level headings and dialog titles.
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: regular,
    height: 1.33,
    letterSpacing: 0,
  );

  /// Large title text style for prominent titles (22px).
  /// 
  /// Used for AppBar titles and major content titles.
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: regular,
    height: 1.27,
    letterSpacing: 0,
  );

  /// Medium title text style for standard titles (16px).
  /// 
  /// Used for list headers and card subtitles.
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: medium,
    height: 1.50,
    letterSpacing: 0.15,
  );

  /// Small title text style for minor titles (14px).
  /// 
  /// Used for small component titles and form labels.
  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: medium,
    height: 1.43,
    letterSpacing: 0.1,
  );

  /// Large label text style for prominent labels (14px).
  /// 
  /// Used for button text and important labels.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: medium,
    height: 1.43,
    letterSpacing: 0.1,
  );

  /// Medium label text style for standard labels (12px).
  /// 
  /// Used for form field labels and navigation items.
  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: medium,
    height: 1.33,
    letterSpacing: 0.5,
  );

  /// Small label text style for compact labels (11px).
  /// 
  /// Used for dense UI elements and status indicators.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: medium,
    height: 1.45,
    letterSpacing: 0.5,
  );

  /// Large body text style for prominent content (16px).
  /// 
  /// Used for main content text and descriptions.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: regular,
    height: 1.50,
    letterSpacing: 0.15,
  );

  /// Medium body text style for standard content (14px).
  /// 
  /// Used for regular body text and content.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: regular,
    height: 1.43,
    letterSpacing: 0.25,
  );

  /// Small body text style for compact content (12px).
  /// 
  /// Used for supporting text and captions.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: regular,
    height: 1.33,
    letterSpacing: 0.4,
  );

  /// Grade display text style for prominent grade values.
  /// 
  /// Used for displaying letter grades and scores prominently.
  static const TextStyle gradeDisplay = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: bold,
    height: 1.0,
  );

  /// Subject title text style for course names.
  /// 
  /// Used for subject and course titles in lists and headers.
  static const TextStyle subjectTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: semiBold,
    height: 1.22,
  );

  /// Assignment title text style for assignment names.
  /// 
  /// Used for assignment titles in lists and detail views.
  static const TextStyle assignmentTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: medium,
    height: 1.25,
  );

  /// Card title text style for card component headers.
  /// 
  /// Used for titles within card components.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: semiBold,
    height: 1.2,
  );

  /// Card subtitle text style for card supporting text.
  /// 
  /// Used for subtitles and descriptions within cards.
  static const TextStyle cardSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: regular,
    height: 1.43,
  );


  /// Creates a Material 3 text theme with semantic colors.
  /// 
  /// Generates a complete text theme using the provided color scheme,
  /// applying appropriate semantic colors to each text style.
  /// 
  /// @param colorScheme The color scheme to apply to text styles
  /// @return Configured text theme for Material 3
  static TextTheme createTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: colorScheme.onSurface),
      displayMedium: displayMedium.copyWith(color: colorScheme.onSurface),
      displaySmall: displaySmall.copyWith(color: colorScheme.onSurface),
      headlineLarge: headlineLarge.copyWith(color: colorScheme.onSurface),
      headlineMedium: headlineMedium.copyWith(color: colorScheme.onSurface),
      headlineSmall: headlineSmall.copyWith(color: colorScheme.onSurface),
      titleLarge: titleLarge.copyWith(color: colorScheme.onSurface),
      titleMedium: titleMedium.copyWith(color: colorScheme.onSurface),
      titleSmall: titleSmall.copyWith(color: colorScheme.onSurfaceVariant),
      labelLarge: labelLarge.copyWith(color: colorScheme.primary),
      labelMedium: labelMedium.copyWith(color: colorScheme.onSurfaceVariant),
      labelSmall: labelSmall.copyWith(color: colorScheme.onSurfaceVariant),
      bodyLarge: bodyLarge.copyWith(color: colorScheme.onSurface),
      bodyMedium: bodyMedium.copyWith(color: colorScheme.onSurfaceVariant),
      bodySmall: bodySmall.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }

  /// Gets responsive text scale factor based on screen size.
  /// 
  /// Adjusts text size for better readability across devices:
  /// - Desktop (≥1200px): 1.1x scale (slightly larger)
  /// - Tablet (≥768px): 1.0x scale (normal)
  /// - Mobile (<768px): 0.95x scale (slightly smaller)
  /// 
  /// @param context Build context for accessing screen dimensions
  /// @return Scale factor for responsive text sizing
  static double getScaleFactor(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth >= 1200) {
      return 1.1; // Desktop - slightly larger
    } else if (screenWidth >= 768) {
      return 1.0; // Tablet - normal
    } else {
      return 0.95; // Mobile - slightly smaller
    }
  }

  /// Creates responsive text style with device-appropriate scaling.
  /// 
  /// Applies responsive scale factor to the base text style
  /// while preserving all other style properties.
  /// 
  /// @param context Build context for screen size detection
  /// @param baseStyle Base text style to make responsive
  /// @return Scaled text style for current device
  static TextStyle responsive(BuildContext context, TextStyle baseStyle) {
    final scaleFactor = getScaleFactor(context);
    return baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 14) * scaleFactor,
    );
  }

  /// Success text style with green semantic color.
  /// 
  /// Used for positive feedback and successful operations.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style with success color
  static TextStyle success(BuildContext context) {
    return bodyMedium.copyWith(
      color: const Color(0xFF4CAF50),
      fontWeight: medium,
    );
  }

  /// Warning text style with orange semantic color.
  /// 
  /// Used for caution messages and important notices.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style with warning color
  static TextStyle warning(BuildContext context) {
    return bodyMedium.copyWith(
      color: const Color(0xFFFF9800),
      fontWeight: medium,
    );
  }

  /// Error text style with theme-based error color.
  /// 
  /// Used for error messages and validation feedback.
  /// 
  /// @param context Build context for accessing theme colors
  /// @return Text style with error color
  static TextStyle error(BuildContext context) {
    return bodyMedium.copyWith(
      color: Theme.of(context).colorScheme.error,
      fontWeight: medium,
    );
  }

  /// Info text style with blue semantic color.
  /// 
  /// Used for informational messages and tips.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style with info color
  static TextStyle info(BuildContext context) {
    return bodyMedium.copyWith(
      color: const Color(0xFF2196F3),
      fontWeight: medium,
    );
  }

  /// Grade A text style with green color for excellent performance.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style for A grades
  static TextStyle gradeA(BuildContext context) {
    return gradeDisplay.copyWith(color: const Color(0xFF4CAF50));
  }

  /// Grade B text style with light green color for good performance.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style for B grades
  static TextStyle gradeB(BuildContext context) {
    return gradeDisplay.copyWith(color: const Color(0xFF8BC34A));
  }

  /// Grade C text style with yellow color for average performance.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style for C grades
  static TextStyle gradeC(BuildContext context) {
    return gradeDisplay.copyWith(color: const Color(0xFFFFEB3B));
  }

  /// Grade D text style with orange color for below average performance.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style for D grades
  static TextStyle gradeD(BuildContext context) {
    return gradeDisplay.copyWith(color: const Color(0xFFFF9800));
  }

  /// Grade F text style with red color for failing performance.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style for F grades
  static TextStyle gradeF(BuildContext context) {
    return gradeDisplay.copyWith(color: const Color(0xFFE53935));
  }

  /// Returns appropriate grade text style based on letter grade.
  /// 
  /// Automatically selects color-coded style based on grade letter:
  /// - A grades: Green (excellent)
  /// - B grades: Light green (good)
  /// - C grades: Yellow (average)
  /// - D grades: Orange (below average)
  /// - F grades: Red (failing)
  /// - Other: Default theme color
  /// 
  /// @param context Build context for accessing theme
  /// @param grade Letter grade string (A, B, C, D, F with optional +/-)
  /// @return Appropriate text style for the grade
  static TextStyle getGradeStyle(BuildContext context, String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
      case 'A+':
      case 'A-':
        return gradeA(context);
      case 'B':
      case 'B+':
      case 'B-':
        return gradeB(context);
      case 'C':
      case 'C+':
      case 'C-':
        return gradeC(context);
      case 'D':
      case 'D+':
      case 'D-':
        return gradeD(context);
      case 'F':
        return gradeF(context);
      default:
        return gradeDisplay.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    }
  }

  /// High priority text style with red color and bold weight.
  /// 
  /// Used for urgent tasks and high-priority items.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style for high priority items
  static TextStyle priorityHigh(BuildContext context) {
    return labelMedium.copyWith(
      color: const Color(0xFFE53935),
      fontWeight: bold,
    );
  }

  /// Medium priority text style with orange color.
  /// 
  /// Used for standard priority tasks and items.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style for medium priority items
  static TextStyle priorityMedium(BuildContext context) {
    return labelMedium.copyWith(
      color: const Color(0xFFFF9800),
      fontWeight: medium,
    );
  }

  /// Low priority text style with green color.
  /// 
  /// Used for low-priority and optional tasks.
  /// 
  /// @param context Build context (required for API consistency)
  /// @return Text style for low priority items
  static TextStyle priorityLow(BuildContext context) {
    return labelMedium.copyWith(
      color: const Color(0xFF4CAF50),
      fontWeight: regular,
    );
  }

  /// Returns appropriate priority text style based on priority level.
  /// 
  /// Automatically selects color-coded style based on priority:
  /// - "high": Red with bold weight (urgent)
  /// - "medium": Orange with medium weight (standard)
  /// - "low": Green with regular weight (optional)
  /// - Other: Default theme color
  /// 
  /// @param context Build context for accessing theme
  /// @param priority Priority level string (case-insensitive)
  /// @return Appropriate text style for the priority level
  static TextStyle getPriorityStyle(BuildContext context, String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return priorityHigh(context);
      case 'medium':
        return priorityMedium(context);
      case 'low':
        return priorityLow(context);
      default:
        return labelMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    }
  }
}