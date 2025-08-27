# macOS Code Signing Setup Guide

This guide explains how to properly configure GitHub Secrets for macOS code signing in the CI/CD pipeline.

## Required GitHub Secrets

You need to configure the following secrets in your GitHub repository settings (Settings → Secrets and variables → Actions):

### 1. `MACOS_CERTIFICATE_BASE64`
The base64-encoded content of your `.p12` certificate file.

To create this value:
```bash
base64 < fermi-mac.p12 | tr -d '\n'
```

Copy the entire output (a long string with no newlines) and paste it as the secret value.

### 2. `MACOS_CERTIFICATE_PASSWORD`
The password that was used when exporting the `.p12` certificate file.

This should be the exact password you entered when you created the `.p12` file.

### 3. `MACOS_PROVISION_PROFILE_BASE64`
The base64-encoded content of your `.provisionprofile` file.

To create this value:
```bash
base64 < your-profile.provisionprofile | tr -d '\n'
```

Copy the entire output (a long string with no newlines) and paste it as the secret value.

### 4. `DEVELOPMENT_TEAM_MAC`
Your Apple Developer Team ID: `W778837A9L`

This is the Team ID shown in your provisioning profile and Apple Developer account.

### 5. `MACOS_IDENTITY` (Optional)
The signing identity name. If not provided, the workflow will auto-discover it from the certificate.

Example: "Apple Development: Your Name (XXXXXXXXXX)"

## Important Configuration Details

### Bundle Identifier
The bundle ID in your app must match the provisioning profile:
- Expected: `com.academic-tools.fermi`
- Location: `macos/Runner/Configs/AppInfo.xcconfig`

### Team ID
The Team ID in the Xcode project has been updated to match your provisioning profile:
- Team ID: `W778837A9L`
- Location: `macos/Runner.xcodeproj/project.pbxproj`

### Certificate Requirements
- Must be a **Mac Developer** or **Mac Distribution** certificate
- Must be from Team ID `W778837A9L`
- iOS certificates will NOT work for macOS signing

## Troubleshooting

### If signing fails:
1. Check the workflow logs for "Available signing identities:" - this will show if the certificate was imported correctly
2. Verify the Team ID matches in all locations
3. Ensure the certificate password is correct
4. Confirm the base64 encoding has no newlines or spaces

### Common Issues:
- **"No signing identity found"**: Certificate not imported correctly or wrong type
- **"Provisioning profile doesn't support"**: Bundle ID or Team ID mismatch
- **"security: SecKeychainItemImport: MAC verification failed"**: Wrong certificate password

## Verification

After setting up the secrets, the workflow will:
1. Import the certificate into a temporary keychain
2. Install the provisioning profile
3. Auto-discover or use the provided signing identity
4. Sign the app with the correct Team ID

The workflow now includes diagnostic output to help debug any issues.