# China Region Build Configuration

This document explains how to build the app for China App Store distribution with CallKit restrictions compliance.

## Background

Apple's App Store Connect requires apps distributed in China to comply with local regulations regarding VoIP and CallKit functionality. This includes removing CallKit and VoIP background mode capabilities.

## Files

- `Info.plist` - Standard configuration with full CallKit support
- `Info-China.plist` - China-specific configuration without CallKit capabilities

## Building for China

### Option 1: Manual File Replacement (Recommended for CI/CD)

1. Before building, backup the original Info.plist:
   ```bash
   cp ios/Runner/Info.plist ios/Runner/Info-Original.plist
   ```

2. Replace with China configuration:
   ```bash
   cp ios/Runner/Info-China.plist ios/Runner/Info.plist
   ```

3. Build the app:
   ```bash
   flutter build ios --release
   ```

4. Restore original configuration:
   ```bash
   cp ios/Runner/Info-Original.plist ios/Runner/Info.plist
   rm ios/Runner/Info-Original.plist
   ```

### Option 2: Xcode Build Scheme

Create a separate build scheme in Xcode for China builds:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Go to Product → Scheme → Manage Schemes
3. Duplicate the existing scheme and name it "Runner-China"
4. Edit the new scheme's Build Settings
5. Add a user-defined setting to switch Info.plist files

### Option 3: Build Script

Create a build script that handles the file switching automatically:

```bash
#!/bin/bash
# build-china.sh

# Backup original
cp ios/Runner/Info.plist ios/Runner/Info-Original.plist

# Use China config
cp ios/Runner/Info-China.plist ios/Runner/Info.plist

# Build
flutter build ios --release

# Restore original
cp ios/Runner/Info-Original.plist ios/Runner/Info.plist
rm ios/Runner/Info-Original.plist

echo "China build completed"
```

## Key Differences in China Configuration

1. **Removed UIBackgroundModes**: 
   - `voip` mode removed
   - CallKit background processing removed

2. **Removed CallKit Capabilities**:
   - No CallKit framework integration
   - VoIP push notifications disabled

3. **Added Documentation**:
   - Comments explaining China-specific modifications
   - Clear indicators for compliance requirements

## Testing

1. **Functionality Testing**: Ensure app works without CallKit features
2. **App Store Review**: Use China configuration for China App Store submissions
3. **Regional Testing**: Test with Chinese App Store guidelines

## CI/CD Integration

For automated builds, add environment variables:

```yaml
# GitHub Actions example
- name: Configure for China
  if: ${{ env.BUILD_REGION == 'china' }}
  run: |
    cp ios/Runner/Info-China.plist ios/Runner/Info.plist
    
- name: Build iOS
  run: flutter build ios --release
  
- name: Restore original config
  if: always()
  run: |
    git checkout ios/Runner/Info.plist
```

## Important Notes

1. **App Store Review**: Always use the appropriate configuration for the target region
2. **Feature Parity**: Ensure app functionality is maintained without CallKit
3. **User Experience**: Consider alternative notification methods for China users
4. **Compliance**: This configuration helps meet China App Store requirements but consult legal advice for complete compliance

## Related Files

- `pubspec.yaml` - Contains `flutter_callkit_incoming` dependency
- `lib/features/auth/` - Authentication system with Apple Sign In
- Apple Sign In is still available and compliant in China region