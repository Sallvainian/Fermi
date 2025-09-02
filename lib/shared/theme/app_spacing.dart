/// Design system spacing constants and utilities.
///
/// This module provides a comprehensive spacing system based on an 8-pixel
/// grid, ensuring visual consistency across the application. Includes
/// semantic spacing values, component-specific dimensions, responsive
/// breakpoints, and utility methods for adaptive layouts.
library;

/// Central spacing system for consistent layout and design.
///
/// This class provides a complete design system with:
/// - 8-pixel grid-based spacing scale for visual rhythm
/// - Semantic spacing aliases for intuitive usage
/// - Component-specific dimensions for UI elements
/// - Responsive breakpoints and adaptive utilities
/// - Layout constants for navigation and content areas
/// - Form, grid, and content spacing guidelines
/// - Animation timing constants
///
/// All spacing values are based on a base unit of 8 pixels,
/// following Material Design spacing principles.
class AppSpacing {
  /// Base spacing unit (8px) for the design system.
  ///
  /// All spacing values are multiples of this base unit
  /// to maintain consistent visual rhythm.
  static const double _baseUnit = 8.0;

  /// Extra small spacing (4px) - minimal gaps.
  static const double xs = _baseUnit * 0.5; // 4px

  /// Small spacing (8px) - base unit for tight layouts.
  static const double sm = _baseUnit; // 8px

  /// Medium spacing (16px) - standard component spacing.
  static const double md = _baseUnit * 2; // 16px

  /// Large spacing (24px) - section separators.
  static const double lg = _baseUnit * 3; // 24px

  /// Extra large spacing (32px) - major layout gaps.
  static const double xl = _baseUnit * 4; // 32px

  /// Double extra large spacing (48px) - large separations.
  static const double xxl = _baseUnit * 6; // 48px

  /// Triple extra large spacing (64px) - maximum gaps.
  static const double xxxl = _baseUnit * 8; // 64px

  /// Tiny spacing alias for minimal gaps.
  static const double tiny = xs;

  /// Small spacing alias for compact layouts.
  static const double small = sm;

  /// Medium spacing alias for standard spacing.
  static const double medium = md;

  /// Large spacing alias for generous spacing.
  static const double large = lg;

  /// Extra large spacing alias for major separations.
  static const double extraLarge = xl;

  /// Huge spacing alias for large layout gaps.
  static const double huge = xxl;

  /// Massive spacing alias for maximum separations.
  static const double massive = xxxl;

  /// Standard padding for card components.
  static const double cardPadding = md;

  /// Standard margin between cards.
  static const double cardMargin = sm;

  /// Padding for list item components.
  static const double listItemPadding = md;

  /// Internal padding for button components.
  static const double buttonPadding = md;

  /// Default screen edge padding.
  static const double screenPadding = md;

  /// Spacing between major screen sections.
  static const double sectionSpacing = lg;

  /// Width of navigation drawer in pixels.
  static const double drawerWidth = 280.0;

  /// Width of compact navigation rail.
  static const double railWidth = 72.0;

  /// Width of extended navigation rail with labels.
  static const double extendedRailWidth = 256.0;

  /// Standard application bar height.
  static const double appBarHeight = 56.0;

  /// Height of bottom navigation bar.
  static const double bottomNavHeight = 80.0;

  /// Spacing between form fields.
  static const double formFieldSpacing = md;

  /// Spacing between form sections.
  static const double formSectionSpacing = lg;

  /// Spacing above form action buttons.
  static const double formButtonSpacing = xl;

  /// Horizontal spacing between grid items.
  static const double gridSpacing = md;

  /// Vertical spacing between grid rows.
  static const double gridRunSpacing = md;

  /// Extra small icon size for inline text icons.
  static const double iconXs = 12.0;

  /// Small icon size for compact UI elements.
  static const double iconSm = 16.0;

  /// Medium icon size for standard buttons and lists.
  static const double iconMd = 24.0;

  /// Large icon size for prominent actions.
  static const double iconLg = 32.0;

  /// Extra large icon size for hero elements.
  static const double iconXl = 48.0;

  /// Double extra large icon size for feature graphics.
  static const double iconXxl = 64.0;

  /// Small avatar size for compact lists.
  static const double avatarSm = 24.0;

  /// Medium avatar size for standard profiles.
  static const double avatarMd = 40.0;

  /// Large avatar size for detailed views.
  static const double avatarLg = 56.0;

  /// Extra large avatar size for profile headers.
  static const double avatarXl = 72.0;

  /// Small button height for compact interfaces.
  static const double buttonHeightSm = 32.0;

  /// Medium button height for standard actions.
  static const double buttonHeightMd = 40.0;

  /// Large button height for prominent actions.
  static const double buttonHeightLg = 48.0;

  /// Extra large button height for hero CTAs.
  static const double buttonHeightXl = 56.0;

  /// Extra small border radius for subtle rounding.
  static const double radiusXs = 4.0;

  /// Small border radius for buttons and cards.
  static const double radiusSm = 8.0;

  /// Medium border radius for containers.
  static const double radiusMd = 12.0;

  /// Large border radius for prominent elements.
  static const double radiusLg = 16.0;

  /// Extra large border radius for special elements.
  static const double radiusXl = 24.0;

  /// Fully rounded border radius for circular elements.
  static const double radiusRound = 999.0;

  /// No elevation for flat surfaces.
  static const double elevation0 = 0.0;

  /// Minimal elevation for subtle depth.
  static const double elevation1 = 1.0;

  /// Low elevation for cards and buttons.
  static const double elevation2 = 2.0;

  /// Medium-low elevation for interactive elements.
  static const double elevation3 = 3.0;

  /// Medium elevation for floating elements.
  static const double elevation4 = 4.0;

  /// Medium-high elevation for prominent cards.
  static const double elevation6 = 6.0;

  /// High elevation for navigation elements.
  static const double elevation8 = 8.0;

  /// Very high elevation for modal elements.
  static const double elevation12 = 12.0;

  /// Maximum standard elevation for dialogs.
  static const double elevation16 = 16.0;

  /// Extreme elevation for special overlays.
  static const double elevation24 = 24.0;

  /// Screen width threshold for mobile devices.
  static const double mobileBreakpoint = 600.0;

  /// Screen width threshold for tablet devices.
  static const double tabletBreakpoint = 768.0;

  /// Screen width threshold for desktop devices.
  static const double desktopBreakpoint = 1024.0;

  /// Screen width threshold for large desktop displays.
  static const double largeDesktopBreakpoint = 1440.0;

  /// Maximum width for main content areas.
  static const double maxContentWidth = 1200.0;

  /// Maximum width for form containers.
  static const double maxFormWidth = 400.0;

  /// Maximum width for card components.
  static const double maxCardWidth = 600.0;

  /// Fast animation duration for micro-interactions.
  static const Duration animationFast = Duration(milliseconds: 150);

  /// Medium animation duration for standard transitions.
  static const Duration animationMedium = Duration(milliseconds: 300);

  /// Slow animation duration for complex transitions.
  static const Duration animationSlow = Duration(milliseconds: 500);

  /// Returns responsive spacing based on screen width.
  ///
  /// Selects spacing value based on device breakpoints:
  /// - Desktop: >= 1024px
  /// - Tablet: >= 768px
  /// - Mobile: < 768px
  ///
  /// @param mobile Spacing for mobile devices
  /// @param tablet Spacing for tablet devices
  /// @param desktop Spacing for desktop devices
  /// @param screenWidth Current screen width in pixels
  /// @return Appropriate spacing value for screen size
  static double responsive(
    double mobile,
    double tablet,
    double desktop,
    double screenWidth,
  ) {
    if (screenWidth >= desktopBreakpoint) {
      return desktop;
    } else if (screenWidth >= tabletBreakpoint) {
      return tablet;
    } else {
      return mobile;
    }
  }

  /// Returns responsive screen padding based on device size.
  ///
  /// Provides appropriate edge padding:
  /// - Mobile: medium (16px)
  /// - Tablet: large (24px)
  /// - Desktop: extra large (32px)
  ///
  /// @param screenWidth Current screen width in pixels
  /// @return Responsive padding value
  static double getScreenPadding(double screenWidth) {
    return responsive(md, lg, xl, screenWidth);
  }

  /// Returns responsive grid column count based on screen size.
  ///
  /// Grid layout adaptation:
  /// - Large Desktop (≥1440px): 4 columns
  /// - Desktop (≥1024px): 3 columns
  /// - Tablet (≥768px): 2 columns
  /// - Mobile (<768px): 1 column
  ///
  /// @param screenWidth Current screen width in pixels
  /// @return Number of grid columns for screen size
  static int getGridColumns(double screenWidth) {
    if (screenWidth >= largeDesktopBreakpoint) {
      return 4;
    } else if (screenWidth >= desktopBreakpoint) {
      return 3;
    } else if (screenWidth >= tabletBreakpoint) {
      return 2;
    } else {
      return 1;
    }
  }

  /// Calculates responsive card width based on grid layout.
  ///
  /// Automatically calculates card width considering:
  /// - Screen padding on both sides
  /// - Grid spacing between cards
  /// - Number of columns for screen size
  ///
  /// Desktop: (screen - padding - 2*spacing) / 3 columns
  /// Tablet: (screen - padding - spacing) / 2 columns
  /// Mobile: screen - padding (full width)
  ///
  /// @param screenWidth Current screen width in pixels
  /// @return Calculated card width for responsive grid
  static double getCardWidth(double screenWidth) {
    if (screenWidth >= desktopBreakpoint) {
      return (screenWidth -
              (getScreenPadding(screenWidth) * 2) -
              (gridSpacing * 2)) /
          3;
    } else if (screenWidth >= tabletBreakpoint) {
      return (screenWidth - (getScreenPadding(screenWidth) * 2) - gridSpacing) /
          2;
    } else {
      return screenWidth - (getScreenPadding(screenWidth) * 2);
    }
  }
}
