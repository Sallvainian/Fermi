#!/bin/bash

# Script to create macOS provisioning profiles for CI/CD
# This script helps generate the necessary provisioning profiles for macOS App Store distribution

set -e

echo "========================================="
echo "macOS Provisioning Profile Creation Tool"
echo "========================================="
echo ""

# Check if xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode is not installed. Please install Xcode first."
    exit 1
fi

# Configuration
BUNDLE_ID="com.academic-tools.fermi"
TEAM_ID="W778837A9L"
PROFILE_NAME="Fermi macOS App Store"

echo "Bundle ID: $BUNDLE_ID"
echo "Team ID: $TEAM_ID"
echo "Profile Name: $PROFILE_NAME"
echo ""

# Function to create provisioning profile
create_provisioning_profile() {
    echo "Creating macOS App Store provisioning profile..."
    
    # Open Xcode and navigate to provisioning profiles
    echo "Please follow these steps in Xcode:"
    echo ""
    echo "1. Open Xcode"
    echo "2. Go to Xcode → Settings → Accounts"
    echo "3. Select your Apple Developer account"
    echo "4. Click 'Manage Certificates...'"
    echo "5. Ensure you have a valid 'Apple Development' certificate"
    echo "6. Close the certificates window"
    echo "7. Click 'Download Manual Profiles' to sync profiles"
    echo ""
    echo "Alternatively, use Apple Developer Portal:"
    echo "1. Visit https://developer.apple.com/account/resources/profiles/list"
    echo "2. Click '+' to create a new profile"
    echo "3. Select 'macOS App Development' or 'Mac App Store' (for production)"
    echo "4. Select your App ID: $BUNDLE_ID"
    echo "5. Select your certificates"
    echo "6. Name it: $PROFILE_NAME"
    echo "7. Download the .provisionprofile file"
    echo ""
}

# Function to export provisioning profile for CI
export_for_ci() {
    echo "To export the provisioning profile for CI/CD:"
    echo ""
    echo "1. Locate the downloaded .provisionprofile file"
    echo "2. Convert to base64 for GitHub Secrets:"
    echo ""
    echo "   base64 -i ~/Downloads/YOUR_PROFILE.provisionprofile | pbcopy"
    echo ""
    echo "3. Add to GitHub Secrets as: MACOS_PROVISIONING_PROFILE_BASE64"
    echo ""
    echo "4. Also ensure you have these secrets set:"
    echo "   - MACOS_CERTIFICATE_BASE64 (your Apple Development certificate)"
    echo "   - MACOS_CERTIFICATE_PASSWORD (certificate password)"
    echo "   - DEVELOPMENT_TEAM (your team ID: $TEAM_ID)"
    echo "   - KEYCHAIN_PASSWORD (for CI keychain)"
    echo ""
}

# Function to verify local provisioning profiles
verify_local_profiles() {
    echo "Checking local provisioning profiles..."
    PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
    
    if [ -d "$PROFILES_DIR" ]; then
        echo "Found provisioning profiles directory"
        echo "Profiles in directory:"
        ls -la "$PROFILES_DIR" 2>/dev/null || echo "  No profiles found"
    else
        echo "Provisioning profiles directory does not exist"
        mkdir -p "$PROFILES_DIR"
        echo "Created directory: $PROFILES_DIR"
    fi
    echo ""
}

# Main execution
echo "What would you like to do?"
echo "1. Create new provisioning profile (instructions)"
echo "2. Export existing profile for CI/CD"
echo "3. Verify local profiles"
echo "4. All of the above"
echo ""
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        create_provisioning_profile
        ;;
    2)
        export_for_ci
        ;;
    3)
        verify_local_profiles
        ;;
    4)
        create_provisioning_profile
        echo "========================================="
        export_for_ci
        echo "========================================="
        verify_local_profiles
        ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "========================================="
echo "Additional Notes for CI/CD:"
echo "========================================="
echo ""
echo "The updated Fastfile now:"
echo "1. Detects CI environment automatically"
echo "2. Installs provisioning profiles from base64 secrets"
echo "3. Configures Flutter to use manual signing with the profile"
echo "4. Falls back to automatic signing if no profile is provided"
echo ""
echo "GitHub Actions workflow environment variables needed:"
echo "- MACOS_PROVISIONING_PROFILE_BASE64: Base64 encoded provisioning profile"
echo "- MACOS_CERTIFICATE_BASE64: Base64 encoded certificate (.p12)"
echo "- MACOS_CERTIFICATE_PASSWORD: Password for the certificate"
echo "- DEVELOPMENT_TEAM: Your Apple Developer Team ID ($TEAM_ID)"
echo "- MACOS_IDENTITY: 'Apple Development' or 'Mac Developer'"
echo ""
echo "Done!"