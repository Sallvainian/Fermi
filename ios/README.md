# Fermi iOS Build Setup

This document provides comprehensive instructions for building and deploying the Fermi Flutter app on iOS.

## Prerequisites

- **macOS**: Required for iOS development
- **Xcode 16.0+**: Download from Mac App Store
- **Flutter 3.24+**: Install from [flutter.dev](https://flutter.dev)
- **CocoaPods**: Install with `sudo gem install cocoapods`
- **Apple Developer Account**: Required for device deployment

## Quick Start

We've provided several scripts to simplify iOS development:

### 1. Build Scripts

```bash
# Build for simulator (recommended for development)
./scripts/ios_build.sh

# Build for physical device
./scripts/ios_build.sh --device

# Clean build (resolves most issues)
./scripts/ios_build.sh --clean

# Build release version
./scripts/ios_build.sh --release
```

### 2. Development Helper

Interactive menu for common tasks:

```bash
./scripts/ios_dev.sh
```

Options include:
- Quick build for simulator
- Build for device
- Run on simulator/device
- Clean build
- Update dependencies
- Fix common issues
- Open in Xcode
- Check build settings

### 3. Troubleshooting

Diagnose and fix issues:

```bash
./scripts/ios_troubleshoot.sh
```

### 4. Code Signing Setup

Configure signing for your Apple Developer account:

```bash
./scripts/ios_setup_signing.sh
```

## Manual Setup

### Step 1: Install Dependencies

```bash
cd /Users/sallvain/Projects/Fermi
flutter pub get
cd ios
pod install
```

### Step 2: Configure Code Signing

1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select the Runner project in the navigator
3. Go to "Signing & Capabilities" tab
4. Select your team from the dropdown
5. Ensure "Automatically manage signing" is checked

### Step 3: Build and Run

```bash
# For simulator
flutter run -d ios

# For specific simulator
flutter run -d "iPhone 16"

# For physical device
flutter run -d <device-id>

# List available devices
flutter devices
```

## Firebase Configuration

The app uses Firebase for backend services. The `GoogleService-Info.plist` file is already configured.

Current Firebase Bundle ID: `com.academic-tools.fermi`

If you need to use a different Firebase project:
1. Download `GoogleService-Info.plist` from Firebase Console
2. Replace the file in `ios/Runner/`
3. Ensure bundle IDs match

## Common Issues and Solutions

### Issue: CocoaPods Installation Fails

```bash
# Clean and reinstall
cd ios
rm -rf Pods Podfile.lock
pod install
```

### Issue: Swift Compatibility Errors

The build scripts automatically apply patches for Swift 6 compatibility. If you still encounter issues:

```bash
./scripts/ios_build.sh --clean
```

### Issue: Code Signing Errors

1. Ensure you're signed into Xcode with your Apple ID
2. Run the signing setup script:
   ```bash
   ./scripts/ios_setup_signing.sh
   ```
3. Or manually configure in Xcode

### Issue: Build Takes Too Long

First builds can take 10-15 minutes. Subsequent builds are faster. To speed up:

```bash
# Build for simulator (faster than device)
flutter build ios --simulator --debug

# Use hot reload during development
flutter run -d ios
```

### Issue: Derived Data Corruption

```bash
# Clear Xcode caches
rm -rf ~/Library/Developer/Xcode/DerivedData/*
./scripts/ios_build.sh --clean
```

## Deployment

### TestFlight Deployment

1. Build release version:
   ```bash
   flutter build ios --release
   ```

2. Open in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

3. Archive and upload:
   - Product → Archive
   - Distribute App → App Store Connect
   - Upload

### App Store Submission

1. Ensure all app metadata is complete in App Store Connect
2. Build and archive as above
3. Submit for review through App Store Connect

## Build Configurations

### Debug (Development)
- Enables hot reload
- Shows debug banner
- Verbose logging
- No code obfuscation

### Release (Production)
- Optimized for performance
- No debug information
- Code obfuscation enabled
- Smaller app size

### Profile
- Performance profiling enabled
- Some optimizations
- Used with Flutter DevTools

## Project Structure

```
ios/
├── Runner/                 # Main iOS app
│   ├── Info.plist         # App configuration
│   ├── Runner.entitlements # App capabilities
│   └── GoogleService-Info.plist # Firebase config
├── Runner.xcodeproj/      # Xcode project
├── Runner.xcworkspace/    # Xcode workspace (use this)
├── Podfile               # CocoaPods dependencies
└── Podfile.lock          # Locked pod versions
```

## Requirements

### Minimum iOS Version
- iOS 15.0+ (configured in Podfile)

### Supported Devices
- iPhone 6s and later
- iPad (5th generation) and later
- iPod touch (7th generation)

### Permissions Required
- Camera (for profile pictures)
- Photo Library (for image uploads)
- Notifications (for push notifications)
- Microphone (for voice messages)

## Tips for Development

1. **Use Simulator for Development**: Faster build times and easier debugging
2. **Enable Hot Reload**: Press 'r' in terminal while `flutter run` is active
3. **Check Console Logs**: View in Xcode's debug console or `flutter logs`
4. **Profile Performance**: Use `flutter run --profile` with Flutter DevTools
5. **Test on Real Devices**: Always test on physical devices before release

## Support

For issues specific to the iOS build:
1. Run the troubleshooting script: `./scripts/ios_troubleshoot.sh`
2. Check Flutter doctor: `flutter doctor -v`
3. Review Xcode build logs
4. Check Firebase Console for backend issues

## Version Information

- Flutter: 3.35.1
- Dart: 3.9.0
- CocoaPods: 1.16.2
- Firebase SDK: 12.0.0
- iOS Deployment Target: 15.0

Last updated: August 30, 2025