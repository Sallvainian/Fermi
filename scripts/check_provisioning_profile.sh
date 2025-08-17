#!/bin/bash
# Script to extract and display provisioning profile information
# Usage: ./check_provisioning_profile.sh path/to/profile.mobileprovision

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-mobileprovision-file>"
    exit 1
fi

PROFILE_PATH="$1"

if [ ! -f "$PROFILE_PATH" ]; then
    echo "Error: File not found: $PROFILE_PATH"
    exit 1
fi

echo "=== Provisioning Profile Information ==="
echo ""

# Decode the profile
DECODED=$(security cms -D -i "$PROFILE_PATH" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Failed to decode provisioning profile"
    exit 1
fi

# Extract key information
echo "UUID:"
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :UUID" /dev/stdin

echo ""
echo "Name:"
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :Name" /dev/stdin

echo ""
echo "Team ID:"
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" /dev/stdin

echo ""
echo "Team Name:"
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :TeamName" /dev/stdin

echo ""
echo "App ID Name:"
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :AppIDName" /dev/stdin

echo ""
echo "Application Identifier:"
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" /dev/stdin

echo ""
echo "Bundle ID (from Entitlements):"
APP_ID=$(echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" /dev/stdin)
echo "${APP_ID#*.}"  # Remove team ID prefix

echo ""
echo "Platform:"
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :Platform:0" /dev/stdin 2>/dev/null || echo "iOS"

echo ""
echo "Expiration Date:"
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :ExpirationDate" /dev/stdin

echo ""
echo "Creation Date:"
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :CreationDate" /dev/stdin

echo ""
echo "Certificates Count:"
CERT_COUNT=$(echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :DeveloperCertificates" /dev/stdin 2>/dev/null | grep -c "Data")
echo "$CERT_COUNT"

echo ""
echo "Is Xcode Managed:"
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :IsXcodeManaged" /dev/stdin 2>/dev/null || echo "false"

echo ""
echo "=== Entitlements ==="
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :Entitlements" /dev/stdin

echo ""
echo "=== Provisioned Devices (if any) ==="
echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :ProvisionedDevices" /dev/stdin 2>/dev/null || echo "No devices (App Store or Enterprise profile)"

echo ""
echo "=== Summary ==="
echo "To use this profile in Xcode/CI:"
echo "  - UUID: $(echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :UUID" /dev/stdin)"
echo "  - Name: $(echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :Name" /dev/stdin)"
echo "  - Team ID: $(echo "$DECODED" | /usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" /dev/stdin)"