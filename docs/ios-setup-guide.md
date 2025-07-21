# iOS Configuration Guide

## Overview
This guide covers the complete iOS setup for the Teacher Dashboard Flutter app, including deployment target, permissions, capabilities, and CI/CD configuration.

## iOS Deployment Target
- **Minimum iOS Version**: 16.0
- **Target Devices**: iPhone, iPad
- **Device Coverage**: ~90% of active iOS devices

## Permissions (Info.plist)

### Essential Permissions
1. **Camera** - For video calls
2. **Microphone** - For voice and video calls
3. **Photo Library** - For profile pictures
4. **Push Notifications** - For alerts and updates

### Additional Permissions Added
1. **Location Services** - For location-based features
2. **Face ID/Touch ID** - For biometric authentication
3. **Contacts** - For finding other users
4. **Calendar** - For scheduling events
5. **Bluetooth** - For accessory connections
6. **User Tracking** - For analytics (App Tracking Transparency)

### App Transport Security
- Configured for secure HTTPS connections
- Exception for localhost (development only)

## Capabilities (Runner.entitlements)

### Core Capabilities
1. **Push Notifications** - For remote notifications
2. **Background Modes**:
   - Remote notifications
   - Background fetch
   - VoIP
   - Audio playback
   - Background processing

### Additional Capabilities
1. **Associated Domains** - For universal links
2. **Sign in with Apple** - For authentication
3. **App Groups** - For data sharing between app extensions
4. **Keychain Sharing** - For secure credential storage
5. **iCloud** - For document and data sync
6. **Time-Sensitive Notifications** - For urgent alerts

## Code Signing Configuration

### Requirements
Before deploying to TestFlight or the App Store, you need:

1. **Apple Developer Account** ($99/year)
2. **App ID** configured in Apple Developer Portal
3. **Provisioning Profiles**:
   - Development profile for testing
   - Distribution profile for TestFlight/App Store
4. **Signing Certificate**:
   - Apple Development certificate
   - Apple Distribution certificate

### Setting Up Secrets for GitHub Actions

Add these secrets to your GitHub repository:

```yaml
# Certificate and Profile
BUILD_CERTIFICATE_BASE64        # Base64 encoded .p12 certificate
P12_PASSWORD                    # Password for the .p12 file
KEYCHAIN_PASSWORD              # Temporary keychain password
BUILD_PROVISION_PROFILE_BASE64  # Base64 encoded provisioning profile
PROVISIONING_PROFILE_UUID       # UUID from the provisioning profile

# Team and App Info
TEAM_ID                        # Your Apple Developer Team ID
BUNDLE_ID                      # Your app bundle identifier

# App Store Connect API
APPSTORE_API_KEY_ID            # API Key ID
APPSTORE_API_ISSUER_ID         # Issuer ID
APPSTORE_API_KEY               # Base64 encoded .p8 key file

# Export Options
EXPORT_OPTIONS_PLIST           # Base64 encoded ExportOptions.plist
```

### Creating ExportOptions.plist

Create an `ExportOptions.plist` file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>YOUR_BUNDLE_ID</key>
        <string>YOUR_PROVISIONING_PROFILE_NAME</string>
    </dict>
</dict>
</plist>
```

## Workflows

### 1. iOS Build Workflow (`ios-build.yml`)
- Triggered on push to main/develop branches
- Builds the app without code signing
- Uploads build artifacts
- Reports build size

### 2. iOS Deploy Workflow (`ios-deploy.yml`)
- Manual trigger with environment selection
- Handles version bumping (major/minor/patch)
- Code signing with certificates
- Archives and exports IPA
- Uploads to TestFlight
- Creates release tags for production

## Testing on Physical Devices

### Development
1. Connect iPhone/iPad via USB
2. Open `ios/Runner.xcworkspace` in Xcode
3. Select your device
4. Click "Run" or use `flutter run`

### TestFlight
1. Use the deploy workflow to upload
2. Wait for Apple processing (~15-30 minutes)
3. Add internal/external testers in App Store Connect
4. Testers receive invitation email

## Troubleshooting

### Common Issues

1. **Pod Install Failures**
   ```bash
   cd ios
   pod cache clean --all
   rm -rf Pods Podfile.lock
   pod install --repo-update
   ```

2. **Signing Issues**
   - Verify certificates are not expired
   - Check provisioning profile includes all capabilities
   - Ensure bundle ID matches exactly

3. **Build Failures**
   - Clean build folder: `flutter clean`
   - Delete derived data in Xcode
   - Restart Xcode and try again

### Xcode Settings
Ensure these settings in Xcode:
- Deployment Target: iOS 16.0
- Swift Language Version: 5.0
- Build Active Architecture Only: No (for Release)

## Next Steps

1. **Configure Bundle Identifier**: Update placeholder bundle IDs in entitlements
2. **Set Up App Store Connect**: Create app record
3. **Configure Push Notifications**: Set up APNs certificates
4. **Update Domain Links**: Replace placeholder domains in entitlements
5. **Test All Permissions**: Verify each permission works as expected

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Flutter iOS Documentation](https://docs.flutter.dev/platform-integration/ios)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)