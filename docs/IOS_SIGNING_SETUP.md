# iOS Code Signing Setup for GitHub Actions

## Overview
This document explains how to set up iOS code signing for automated builds using GitHub Actions with Flutter.

## Prerequisites
1. Apple Developer Account with active membership
2. Valid certificates (Development and Distribution)
3. Valid provisioning profile
4. Team ID from Apple Developer Portal

## Current Configuration
- **Bundle ID**: `com.academic-tools.fermi`
- **Team ID**: `7K5YU45M8A`
- **Signing Method**: Manual
- **Export Method**: App Store

## Files Required

### 1. Certificates
- **Development Certificate**: `DEVELOPMENT.p12`
  - Used for development builds
  - Type: Apple Development
  
- **Distribution Certificate**: `distribution_production.p12`
  - Used for App Store/TestFlight builds
  - Type: Apple Distribution

### 2. Provisioning Profile
- **File**: `Fermi_Distribution.mobileprovision`
- **Type**: App Store Distribution
- **Bundle ID**: Must match `com.academic-tools.fermi`

### 3. Export Options
- **File**: `ios/ExportOptions.plist`
- Configured for manual signing with App Store distribution

## GitHub Secrets Setup

The following secrets must be configured in your GitHub repository:

| Secret Name | Description | How to Generate |
|------------|-------------|-----------------|
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded development certificate | `base64 -i DEVELOPMENT.p12` |
| `BUILD_DISTRIBUTION_CERTIFICATE_BASE64` | Base64-encoded distribution certificate | `base64 -i distribution_production.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64-encoded provisioning profile | `base64 -i Fermi_Distribution.mobileprovision` |
| `P12_PASSWORD` | Password for the P12 certificates | Your certificate password |
| `DEVELOPMENT_TEAM` | Apple Developer Team ID | `7K5YU45M8A` |
| `FIREBASE_API_KEY` | Firebase API key | From Firebase Console |
| `FIREBASE_PROJECT_ID` | Firebase project ID | From Firebase Console |
| `FIREBASE_APP_ID_IOS` | iOS-specific Firebase app ID | From Firebase Console |
| Other Firebase secrets... | | |

## How the Workflow Works

### 1. Certificate Installation
The workflow creates a temporary keychain and imports both development and distribution certificates:
```yaml
- Creates temporary keychain with password
- Imports certificates from base64 secrets
- Sets keychain as default for code signing
- Verifies available signing identities
```

### 2. Provisioning Profile Installation
The workflow extracts the UUID and installs the profile:
```yaml
- Decodes provisioning profile from base64
- Extracts UUID and Name using PlistBuddy
- Installs to ~/Library/MobileDevice/Provisioning Profiles/
- Exports UUID for use in build steps
```

### 3. Build Process
The build is done in three steps:
```yaml
1. Flutter build without code signing (--no-codesign)
2. Xcode archive with manual signing configuration
3. Export IPA from archive using ExportOptions.plist
```

### 4. Manual Signing Configuration
The workflow explicitly sets:
- `CODE_SIGN_STYLE=Manual`
- `DEVELOPMENT_TEAM="7K5YU45M8A"`
- `PROVISIONING_PROFILE_SPECIFIER="<UUID>"`
- `CODE_SIGN_IDENTITY="Apple Distribution"`

## Troubleshooting

### Common Issues

#### 1. "Runner requires a provisioning profile"
**Cause**: The provisioning profile UUID isn't being properly set.
**Solution**: The workflow now extracts and uses the UUID dynamically.

#### 2. "Unable to parse development team from code-signing certificate"
**Cause**: Certificate not properly installed or wrong certificate type.
**Solution**: Ensure both development and distribution certificates are installed.

#### 3. "No profiles for 'com.academic-tools.fermi' were found"
**Cause**: Bundle ID mismatch or profile not installed.
**Solution**: Verify bundle ID matches in all locations:
- Xcode project settings
- Provisioning profile
- ExportOptions.plist

### Verification Scripts

Use the provided scripts to verify your certificates and profiles:

```bash
# Check provisioning profile details
./scripts/check_provisioning_profile.sh path/to/profile.mobileprovision

# Check certificate details
./scripts/check_certificate.sh path/to/certificate.p12 "password"
```

## Local Testing

To test the signing configuration locally:

1. Install certificates in Keychain Access
2. Install provisioning profile:
   ```bash
   cp profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
   ```
3. Build with Flutter:
   ```bash
   flutter build ipa --export-options-plist=ios/ExportOptions.plist
   ```

## Security Notes

1. **Never commit** certificates, provisioning profiles, or passwords to the repository
2. Use GitHub Secrets for all sensitive data
3. Certificates are installed in temporary keychains that are deleted after the build
4. Regularly rotate certificates and update secrets

## Updating Certificates/Profiles

When certificates or profiles expire:

1. Generate new certificates in Apple Developer Portal
2. Export as .p12 files with password
3. Download new provisioning profile
4. Encode in base64:
   ```bash
   base64 -i certificate.p12 > certificate_base64.txt
   base64 -i profile.mobileprovision > profile_base64.txt
   ```
5. Update GitHub Secrets with new values
6. Update `ExportOptions.plist` if profile name changes

## References

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [GitHub Actions - Installing Apple Certificates](https://docs.github.com/en/actions/deployment/deploying-xcode-applications/installing-an-apple-certificate-on-macos-runners-for-xcode-development)
- [Apple Developer - Code Signing](https://developer.apple.com/support/code-signing/)