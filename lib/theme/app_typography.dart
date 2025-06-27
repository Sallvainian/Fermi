import 'package:flutter/material.dart';

class AppTypography {
  // Base font family
  static const String fontFamily = 'Inter';

  // Font weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  // Text styles based on Material 3 typography scale
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 57,
    fontWeight: regular,
    height: 1.12,
    letterSpacing: -0.25,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 45,
    fontWeight: regular,
    height: 1.16,
    letterSpacing: 0,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: regular,
    height: 1.22,
    letterSpacing: 0,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: regular,
    height: 1.25,
    letterSpacing: 0,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: regular,
    height: 1.29,
    letterSpacing: 0,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: regular,
    height: 1.33,
    letterSpacing: 0,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: regular,
    height: 1.27,
    letterSpacing: 0,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: medium,
    height: 1.50,
    letterSpacing: 0.15,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: medium,
    height: 1.43,
    letterSpacing: 0.1,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: medium,
    height: 1.43,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: medium,
    height: 1.33,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: medium,
    height: 1.45,
    letterSpacing: 0.5,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: regular,
    height: 1.50,
    letterSpacing: 0.15,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: regular,
    height: 1.43,
    letterSpacing: 0.25,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: regular,
    height: 1.33,
    letterSpacing: 0.4,
  );

  // Custom text styles for educational context
  static const TextStyle gradeDisplay = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: bold,
    height: 1.0,
  );

  static const TextStyle subjectTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: semiBold,
    height: 1.22,
  );

  static const TextStyle assignmentTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: medium,
    height: 1.25,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: semiBold,
    height: 1.2,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: regular,
    height: 1.43,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: medium,
    height: 1.43,
    letterSpacing: 0.1,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: regular,
    height: 1.33,
    letterSpacing: 0.4,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: medium,
    height: 1.6,
    letterSpacing: 1.5,
  );

  // Create text theme for Material 3
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

  // Responsive text scaling based on screen size
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

  // Get responsive text style
  static TextStyle responsive(BuildContext context, TextStyle baseStyle) {
    final scaleFactor = getScaleFactor(context);
    return baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 14) * scaleFactor,
    );
  }

  // Text styles with semantic colors
  static TextStyle success(BuildContext context) {
    return bodyMedium.copyWith(
      color: const Color(0xFF4CAF50),
      fontWeight: medium,
    );
  }

  static TextStyle warning(BuildContext context) {
    return bodyMedium.copyWith(
      color: const Color(0xFFFF9800),
      fontWeight: medium,
    );
  }

  static TextStyle error(BuildContext context) {
    return bodyMedium.copyWith(
      color: Theme.of(context).colorScheme.error,
      fontWeight: medium,
    );
  }

  static TextStyle info(BuildContext context) {
    return bodyMedium.copyWith(
      color: const Color(0xFF2196F3),
      fontWeight: medium,
    );
  }

  // Educational-specific text styles
  static TextStyle gradeA(BuildContext context) {
    return gradeDisplay.copyWith(color: const Color(0xFF4CAF50));
  }

  static TextStyle gradeB(BuildContext context) {
    return gradeDisplay.copyWith(color: const Color(0xFF8BC34A));
  }

  static TextStyle gradeC(BuildContext context) {
    return gradeDisplay.copyWith(color: const Color(0xFFFFEB3B));
  }

  static TextStyle gradeD(BuildContext context) {
    return gradeDisplay.copyWith(color: const Color(0xFFFF9800));
  }

  static TextStyle gradeF(BuildContext context) {
    return gradeDisplay.copyWith(color: const Color(0xFFE53935));
  }

  // Get grade text style based on grade value
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

  // Priority text styles
  static TextStyle priorityHigh(BuildContext context) {
    return labelMedium.copyWith(
      color: const Color(0xFFE53935),
      fontWeight: bold,
    );
  }

  static TextStyle priorityMedium(BuildContext context) {
    return labelMedium.copyWith(
      color: const Color(0xFFFF9800),
      fontWeight: medium,
    );
  }

  static TextStyle priorityLow(BuildContext context) {
    return labelMedium.copyWith(
      color: const Color(0xFF4CAF50),
      fontWeight: regular,
    );
  }

  // Get priority text style
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