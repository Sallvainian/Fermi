#!/bin/bash

# Test Fastlane setup locally
# This script will use your local certificates and provisioning profile

echo "Testing Fastlane setup for macOS build..."

# Check if Fastlane is installed
if ! command -v fastlane &> /dev/null; then
    echo "Fastlane is not installed. Installing..."
    gem install fastlane
fi

# Check if certificate exists
CERT_PATH="/Users/sallvain/Certificates:Keys/fermi-mac-distribution.p12"
PROFILE_PATH="/Users/sallvain/Certificates:Keys/Fermi_MacOS.provisionprofile"

if [ ! -f "$CERT_PATH" ]; then
    echo "Error: Certificate not found at $CERT_PATH"
    exit 1
fi

if [ ! -f "$PROFILE_PATH" ]; then
    echo "Error: Provisioning profile not found at $PROFILE_PATH"
    exit 1
fi

echo "✅ Certificate found: $CERT_PATH"
echo "✅ Provisioning profile found: $PROFILE_PATH"

# Navigate to project directory
cd "$(dirname "$0")/.." || exit

# Run Fastlane local build
echo ""
echo "Running Fastlane local build..."
echo "This will:"
echo "  1. Import your certificate"
echo "  2. Install your provisioning profile"
echo "  3. Build the Flutter app"
echo "  4. Sign the app"
echo "  5. Create a DMG installer"
echo ""

# Run the local build lane
fastlane mac local_build

echo ""
echo "Build complete! Check for Fermi-0.9.3.dmg in the current directory."