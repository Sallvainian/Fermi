class AppSpacing {
  // Base spacing unit (8px)
  static const double _baseUnit = 8.0;

  // Spacing scale based on 8px grid
  static const double xs = _baseUnit * 0.5;  // 4px
  static const double sm = _baseUnit;        // 8px
  static const double md = _baseUnit * 2;    // 16px
  static const double lg = _baseUnit * 3;    // 24px
  static const double xl = _baseUnit * 4;    // 32px
  static const double xxl = _baseUnit * 6;   // 48px
  static const double xxxl = _baseUnit * 8;  // 64px

  // Semantic spacing
  static const double tiny = xs;
  static const double small = sm;
  static const double medium = md;
  static const double large = lg;
  static const double extraLarge = xl;
  static const double huge = xxl;
  static const double massive = xxxl;

  // Component-specific spacing
  static const double cardPadding = md;
  static const double cardMargin = sm;
  static const double listItemPadding = md;
  static const double buttonPadding = md;
  static const double screenPadding = md;
  static const double sectionSpacing = lg;
  
  // Layout spacing
  static const double drawerWidth = 280.0;
  static const double railWidth = 72.0;
  static const double extendedRailWidth = 256.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 80.0;
  
  // Form spacing
  static const double formFieldSpacing = md;
  static const double formSectionSpacing = lg;
  static const double formButtonSpacing = xl;
  
  // Grid spacing
  static const double gridSpacing = md;
  static const double gridRunSpacing = md;
  
  // Icon sizes
  static const double iconXs = 12.0;
  static const double iconSm = 16.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  static const double iconXxl = 64.0;
  
  // Avatar sizes
  static const double avatarSm = 24.0;
  static const double avatarMd = 40.0;
  static const double avatarLg = 56.0;
  static const double avatarXl = 72.0;
  
  // Button heights
  static const double buttonHeightSm = 32.0;
  static const double buttonHeightMd = 40.0;
  static const double buttonHeightLg = 48.0;
  static const double buttonHeightXl = 56.0;
  
  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusRound = 999.0;
  
  // Elevation levels
  static const double elevation0 = 0.0;
  static const double elevation1 = 1.0;
  static const double elevation2 = 2.0;
  static const double elevation3 = 3.0;
  static const double elevation4 = 4.0;
  static const double elevation6 = 6.0;
  static const double elevation8 = 8.0;
  static const double elevation12 = 12.0;
  static const double elevation16 = 16.0;
  static const double elevation24 = 24.0;
  
  // Responsive breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 768.0;
  static const double desktopBreakpoint = 1024.0;
  static const double largeDesktopBreakpoint = 1440.0;
  
  // Content max widths
  static const double maxContentWidth = 1200.0;
  static const double maxFormWidth = 400.0;
  static const double maxCardWidth = 600.0;
  
  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // Helper method to get responsive spacing
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
  
  // Helper method to get responsive padding
  static double getScreenPadding(double screenWidth) {
    return responsive(md, lg, xl, screenWidth);
  }
  
  // Helper method to get responsive grid columns
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
  
  // Helper method to get responsive card width
  static double getCardWidth(double screenWidth) {
    if (screenWidth >= desktopBreakpoint) {
      return (screenWidth - (getScreenPadding(screenWidth) * 2) - (gridSpacing * 2)) / 3;
    } else if (screenWidth >= tabletBreakpoint) {
      return (screenWidth - (getScreenPadding(screenWidth) * 2) - gridSpacing) / 2;
    } else {
      return screenWidth - (getScreenPadding(screenWidth) * 2);
    }
  }
}