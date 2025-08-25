# Fermi - macOS Development Guide

## Overview
This guide covers building, testing, and distributing the Fermi app for macOS.

## Prerequisites

### Required Software
- macOS 10.15 (Catalina) or later
- Xcode 13.0 or later
- Flutter 3.24+ with macOS desktop support
- CocoaPods (`sudo gem install cocoapods`)

### Optional (for distribution)
- Apple Developer Account (for code signing and notarization)
- create-dmg (`brew install create-dmg`) for professional DMG creation

## Building the App

### Development Build
```bash
# Run in debug mode
flutter run -d macos

# Hot reload is available in debug mode (press 'r' in terminal)
```

### Release Build
```bash
# Build optimized release version
flutter build macos --release

# The app will be at: build/macos/Build/Products/Release/teacher_dashboard_flutter.app
```

## Creating a DMG Installer

We provide two scripts for creating DMG installers:

### Basic DMG (Quick & Simple)
```bash
cd macos
./create_dmg.sh
```
This creates a simple DMG with the app and Applications folder shortcut.

### Advanced DMG (Professional)
```bash
cd macos
./create_dmg_advanced.sh
```
This creates a professional DMG with:
- Custom window layout
- Version numbering
- Code signing (if certificates available)
- DMG verification

## Firebase Configuration

Firebase is already configured for macOS. The app uses:
- Firebase Auth (with OAuth2 for Google Sign-In)
- Cloud Firestore
- Firebase Storage
- Firebase Messaging
- Cloud Functions

### OAuth2 Authentication
The app supports Google Sign-In on macOS using OAuth2 flow through the system browser.

## Troubleshooting

### Common Issues

#### 1. App won't open ("damaged" or "unidentified developer")
**Solution**: Right-click the app and select "Open" or go to System Settings > Privacy & Security and click "Open Anyway"

#### 2. Firebase connection issues
**Solution**: Ensure network client entitlement is enabled in `Runner/DebugProfile.entitlements`

#### 3. Build failures
**Solution**: 
```bash
# Clean and rebuild
flutter clean
flutter pub get
cd macos && pod install
flutter build macos --release
```

#### 4. OAuth Sign-In not working
**Solution**: Check that:
- Network entitlements are properly configured
- OAuth2 redirect URLs are set correctly in Google Cloud Console
- The app has permission to open URLs

## Distribution

### Local Distribution
1. Build the release version
2. Create DMG using one of the provided scripts
3. Share the DMG file directly

### App Store Distribution (requires Apple Developer Account)
1. Sign the app with Developer ID certificate
2. Notarize the app with Apple
3. Submit to Mac App Store or distribute outside

### Notarization (for distribution outside App Store)
```bash
# Sign the app
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" "build/macos/Build/Products/Release/teacher_dashboard_flutter.app"

# Create DMG and sign it
./create_dmg_advanced.sh
codesign --sign "Developer ID Application: Your Name" "build/macos/Fermi-*.dmg"

# Notarize
xcrun notarytool submit "build/macos/Fermi-*.dmg" --apple-id your@email.com --team-id TEAMID --wait

# Staple the notarization
xcrun stapler staple "build/macos/Fermi-*.dmg"
```

## Features Working on macOS

✅ **Authentication**
- Email/Password login
- Google Sign-In (OAuth2)
- Role selection (Teacher/Student)
- Email verification

✅ **Core Features**
- Dashboard (Teacher & Student views)
- Chat/Messaging system
- Discussion boards
- Assignments
- Classes management
- Grades
- Calendar
- Notifications
- Student management

✅ **Games**
- Jeopardy educational game

## Known Limitations

1. **Apple Sign-In**: Currently uses iOS implementation, may need adjustment for macOS
2. **Push Notifications**: Requires additional configuration for macOS
3. **File Picker**: Some features may behave differently than on mobile

## Development Tips

1. **Use Activity Monitor** to check memory usage during development
2. **Enable macOS desktop support** in VS Code/Android Studio Flutter settings
3. **Test on multiple macOS versions** if possible (Catalina, Big Sur, Monterey, Ventura, Sonoma, Sequoia)
4. **Use Console.app** to view system logs for debugging

## Resources

- [Flutter Desktop Documentation](https://docs.flutter.dev/desktop)
- [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)
- [macOS App Distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Code Signing Guide](https://developer.apple.com/support/code-signing/)

## Support

For issues specific to macOS, please include:
- macOS version
- Flutter doctor output
- Console.app logs
- Steps to reproduce