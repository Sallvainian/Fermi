# macOS CI/CD Code Signing Solution

## Problem

When building Flutter macOS apps in GitHub Actions, you may encounter the error:
```
No profiles for 'com.academic-tools.fermi' were found: Xcode couldn't find any iOS App Development provisioning profiles matching
```

This occurs because:
1. **Flutter ignores Xcode's automatic signing settings in CI** - Even with `CODE_SIGN_STYLE = Automatic` in your Xcode project
2. **GitHub Actions runners start with a clean state** - No certificates or profiles pre-installed
3. **Flutter requires explicit configuration via environment variables** in CI environments

## Solution Overview

The solution involves two approaches:

### Option 1: Manual Signing with Provisioning Profiles (Recommended for App Store)
- Create and download provisioning profiles from Apple Developer Portal
- Store profiles as base64-encoded GitHub Secrets
- Configure Fastlane to install profiles and use manual signing

### Option 2: Automatic Signing (Simpler, for Developer ID distribution)
- Use Developer ID certificates (no provisioning profiles needed)
- Let Xcode handle signing automatically
- Suitable for direct distribution outside App Store

## Implementation

### 1. Updated Fastfile

The `fastlane/Fastfile` now intelligently handles both scenarios:

```ruby
# In CI environment
if is_ci
  if ENV["MACOS_PROVISIONING_PROFILE_BASE64"]
    # Manual signing with provisioning profile
    # - Decodes and installs the profile
    # - Extracts the profile UUID
    # - Configures Flutter for manual signing
  else
    # Fallback to automatic signing
    # - Uses Developer ID certificates
    # - No provisioning profiles needed
  end
end
```

### 2. GitHub Actions Workflow

The workflow (`04_macos_release.yml`) now supports provisioning profiles:

```yaml
env:
  MACOS_PROVISIONING_PROFILE_BASE64: ${{ secrets.MACOS_PROVISIONING_PROFILE_BASE64 }}
  MACOS_CERTIFICATE_BASE64: ${{ secrets.MACOS_CERTIFICATE_BASE64 }}
  DEVELOPMENT_TEAM: ${{ secrets.DEVELOPMENT_TEAM_MAC }}
```

### 3. Creating Provisioning Profiles

Use the provided script to help create profiles:

```bash
./scripts/create_macos_provisioning_profile.sh
```

This script provides instructions for:
- Creating profiles via Xcode or Apple Developer Portal
- Converting profiles to base64 for GitHub Secrets
- Verifying local profile installation

## Setting Up GitHub Secrets

### Required Secrets

1. **MACOS_PROVISIONING_PROFILE_BASE64** (Optional, for App Store)
   ```bash
   base64 -i ~/Downloads/your_profile.provisionprofile | pbcopy
   ```

2. **MACOS_CERTIFICATE_BASE64** (Required)
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```

3. **MACOS_CERTIFICATE_PASSWORD** (Required)
   - Password for the .p12 certificate file

4. **DEVELOPMENT_TEAM_MAC** (Required)
   - Your Apple Developer Team ID (e.g., W778837A9L)

5. **KEYCHAIN_PASSWORD** (Required)
   - Password for the temporary CI keychain

## How It Works

### During CI Build

1. **Keychain Setup**: Creates temporary keychain for certificates
2. **Certificate Import**: Imports signing certificates from base64
3. **Profile Installation** (if provided):
   - Decodes provisioning profile from base64
   - Extracts UUID from profile
   - Installs to `~/Library/MobileDevice/Provisioning Profiles/`
4. **Flutter Configuration**:
   - Sets `FLUTTER_XCODE_CODE_SIGN_STYLE` to Manual or Automatic
   - Sets `FLUTTER_XCODE_PROVISIONING_PROFILE_SPECIFIER` to profile UUID
   - Sets `FLUTTER_XCODE_DEVELOPMENT_TEAM` to team ID
5. **Build**: Flutter builds with proper signing configuration

## Troubleshooting

### Common Issues

1. **Profile not found**: Ensure the profile matches the bundle ID exactly
2. **Certificate mismatch**: Profile must be created with the same certificate
3. **Team ID mismatch**: DEVELOPMENT_TEAM must match the profile's team
4. **Expired profile**: Regenerate if profile has expired

### Debugging Steps

1. Check GitHub Actions logs for profile UUID extraction
2. Verify certificate installation in keychain
3. Ensure Flutter environment variables are set correctly
4. Try automatic signing first, then add profile if needed

## Key Differences: iOS vs macOS

- **iOS**: Always requires provisioning profiles for device builds
- **macOS**: 
  - Developer ID: No provisioning profiles needed
  - Mac App Store: Provisioning profiles required
  - Development: Can use automatic signing locally

## Flutter-Specific Considerations

Flutter's build system:
- **Ignores Xcode project settings** in CI environments
- **Requires environment variables** for signing configuration
- **Must be explicitly told** whether to use manual or automatic signing
- **Needs the exact profile UUID** for manual signing

## References

- [Flutter iOS/macOS Code Signing](https://docs.flutter.dev/deployment/macos)
- [Fastlane Code Signing Guide](https://docs.fastlane.tools/codesigning/getting-started/)
- [Apple Developer - Provisioning Profiles](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)