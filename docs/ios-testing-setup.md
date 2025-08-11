# iOS Testing Setup Guide (No Mac Required)

This guide will help you set up iOS testing for your Flutter app using GitHub Actions runners and TestFlight.

## Prerequisites

### 1. Apple Developer Account ($99/year)
- **REQUIRED**: Sign up at [developer.apple.com](https://developer.apple.com)
- This gives you access to TestFlight and App Store Connect

### 2. App Store Connect Setup
1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Create a new app:
   - Click "+" and select "New App"
   - Platform: iOS
   - Name: Teacher Dashboard
   - Primary Language: English
   - Bundle ID: Create a new one (e.g., `com.yourname.teacherdashboard`)
   - SKU: Something unique (e.g., `TEACHER-DASHBOARD-001`)

### 3. Required Certificates and Profiles

Since you don't have a Mac, you'll need to use alternative methods to generate these:

#### Option A: Use a Cloud Mac Service (Recommended for initial setup)
- Services like MacinCloud or MacStadium offer hourly Mac rentals
- Cost: ~$1-2 per hour
- You only need this once to generate certificates

#### Option B: Use GitHub Actions to Generate (Advanced)
- I'll provide a workflow to help generate these

## Step-by-Step Setup

### Step 1: Generate Certificates and Profiles

#### Using GitHub Actions (No Mac Required)

1. First, create an Apple App Store Connect API Key:
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Navigate to Users and Access → Keys
   - Click "+" to create a new key
   - Name: "GitHub Actions CI/CD"
   - Access: Admin
   - Download the `.p8` file (you can only download once!)
   - Note the Key ID and Issuer ID

2. Generate a Certificate Signing Request (CSR) using OpenSSL on Windows:

```bash
# Run in Git Bash or WSL
openssl genrsa -out private.key 2048
openssl req -new -key private.key -out CertificateSigningRequest.certSigningRequest -subj "/emailAddress=your-email@example.com/CN=Your Name/C=US"
```

3. Create certificates in Apple Developer Portal:
   - Go to [Certificates](https://developer.apple.com/account/resources/certificates/list)
   - Click "+" to create new certificate
   - Choose "Apple Distribution" (for App Store and Ad Hoc)
   - Upload your CSR file
   - Download the certificate (.cer file)

4. Convert certificate to .p12:

```bash
# Download the Apple Worldwide Developer Relations Certificate
curl -O https://developer.apple.com/certificationauthority/AppleWWDRCA.cer

# Convert .cer to .pem
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM

# Create .p12 file
openssl pkcs12 -export -out Certificates.p12 -inkey private.key -in distribution.pem -certfile AppleWWDRCA.cer
# Set a password when prompted - you'll need this later
```

5. Create Provisioning Profile:
   - Go to [Profiles](https://developer.apple.com/account/resources/profiles/list)
   - Click "+" to create new profile
   - Choose "App Store" for distribution
   - Select your App ID
   - Select your distribution certificate
   - Name it (e.g., "Teacher Dashboard Distribution")
   - Download the `.mobileprovision` file

### Step 2: Configure GitHub Secrets

Go to your repository Settings → Secrets and variables → Actions, and add:

#### Apple Credentials
- `TEAM_ID`: Your Apple Team ID (found in Apple Developer account membership)
- `BUNDLE_ID`: Your app's bundle identifier (e.g., `com.yourname.teacherdashboard`)

#### App Store Connect API
- `APPSTORE_API_KEY_ID`: The Key ID from Step 1.1
- `APPSTORE_API_ISSUER_ID`: The Issuer ID from Step 1.1
- `APPSTORE_API_KEY`: The contents of the .p8 file (base64 encoded)

```bash
# Encode the .p8 file
base64 AuthKey_XXXXXXXXXX.p8 > api_key_base64.txt
# Copy the contents to GitHub secret
```

#### Certificates and Profiles
- `BUILD_CERTIFICATE_BASE64`: Your .p12 certificate (base64 encoded)
- `P12_PASSWORD`: The password you set for the .p12 file
- `BUILD_PROVISION_PROFILE_BASE64`: Your .mobileprovision file (base64 encoded)
- `PROVISIONING_PROFILE_UUID`: The UUID from the provisioning profile
- `KEYCHAIN_PASSWORD`: Any secure password for the temporary keychain

```bash
# Encode certificate
base64 Certificates.p12 > cert_base64.txt

# Encode provisioning profile
base64 YourProfile.mobileprovision > profile_base64.txt

# Get UUID from provisioning profile (on Windows, use a text editor to find the UUID)
# Look for <key>UUID</key><string>XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX</string>
```

#### Firebase Configuration
- `FIREBASE_API_KEY`: Your Firebase API key
- `FIREBASE_PROJECT_ID`: Your Firebase project ID
- `FIREBASE_MESSAGING_SENDER_ID`: Firebase messaging sender ID
- `FIREBASE_STORAGE_BUCKET`: Firebase storage bucket
- `FIREBASE_DATABASE_URL`: Firebase database URL
- `FIREBASE_APP_ID_IOS`: Firebase iOS app ID
- `IOS_BUNDLE_ID`: Same as BUNDLE_ID

#### Export Options Plist
- `EXPORT_OPTIONS_PLIST`: Create and encode this file:

Create `ExportOptions.plist`:
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
    <key>uploadSymbols</key>
    <true/>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.yourname.teacherdashboard</key>
        <string>Teacher Dashboard Distribution</string>
    </dict>
</dict>
</plist>
```

Then encode it:
```bash
base64 ExportOptions.plist > export_options_base64.txt
```

### Step 3: Configure Your Flutter Project

1. Update `ios/Runner.xcodeproj/project.pbxproj`:
   - Set PRODUCT_BUNDLE_IDENTIFIER to your bundle ID
   - Set DEVELOPMENT_TEAM to your Team ID

2. Update `ios/Runner/Info.plist`:
   - Ensure CFBundleIdentifier matches your bundle ID

### Step 4: Deploy to TestFlight

1. Push your code to GitHub
2. Go to Actions tab in your repository
3. Select "iOS Deploy to TestFlight" workflow
4. Click "Run workflow"
5. Select environment (staging/production) and version bump type
6. The workflow will:
   - Build your app
   - Sign it with your certificates
   - Upload to TestFlight
   - Automatically available for testing

### Step 5: Install on Your iOS Device

1. Install TestFlight from the App Store on your iOS device
2. You'll receive an email invitation to test (or find it in App Store Connect)
3. Accept the invitation in TestFlight
4. Download and install your app!

## Troubleshooting

### Common Issues

1. **Provisioning Profile Error**
   - Ensure the profile includes your certificate
   - Check that the bundle ID matches exactly

2. **Signing Error**
   - Verify all secrets are properly base64 encoded
   - Check certificate hasn't expired

3. **Upload to TestFlight Fails**
   - Ensure App Store Connect API key has proper permissions
   - Verify the app exists in App Store Connect

4. **Build Fails**
   - Check Flutter version matches between local and CI
   - Ensure all Firebase configuration is correct

### Testing Workflow Locally (Windows)

While you can't build iOS apps locally on Windows, you can:
1. Test the Flutter app in Chrome: `flutter run -d chrome`
2. Use GitHub Actions for iOS builds
3. Test on physical iOS device via TestFlight

## Quick Deploy Script

Create `.github/workflows/quick-ios-deploy.yml`:
```yaml
name: Quick iOS Deploy

on:
  workflow_dispatch:
    inputs:
      deploy_message:
        description: 'Deployment message'
        required: false
        default: 'Testing new features'

jobs:
  quick-deploy:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to TestFlight
        run: |
          echo "Deploying: ${{ github.event.inputs.deploy_message }}"
          # Trigger the main deploy workflow
          gh workflow run ios-deploy.yml -f environment=staging -f version_bump=patch
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Estimated Timeline

1. Apple Developer Account: 24-48 hours for activation
2. Certificate Generation: 30 minutes
3. First Build & Deploy: 20-30 minutes
4. TestFlight Processing: 10-30 minutes
5. **Total**: ~2-3 hours of actual work (plus waiting time)

## Costs

- Apple Developer Account: $99/year
- GitHub Actions: Free for public repos, 2000 minutes/month for private
- No other costs required!

## Next Steps

After setup:
1. Configure TestFlight test groups
2. Add external testers (up to 10,000)
3. Set up automatic deployments on merge to main
4. Configure build variants (staging/production)

## Support

- [Apple Developer Forums](https://developer.apple.com/forums/)
- [Flutter iOS Deployment Guide](https://docs.flutter.dev/deployment/ios)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)