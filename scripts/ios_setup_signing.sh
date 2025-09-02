#!/bin/bash

# Fermi iOS Code Signing Setup Script
# This script helps configure code signing for the iOS app

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$PROJECT_ROOT/ios"
PBXPROJ="$IOS_DIR/Runner.xcodeproj/project.pbxproj"

echo -e "${GREEN}=== Fermi iOS Code Signing Setup ===${NC}"
echo ""

# Function to print step headers
print_step() {
    echo -e "${YELLOW}➤ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check current signing configuration
print_step "Checking current signing configuration..."

# Extract current settings from project
CURRENT_TEAM=$(grep -m1 'DEVELOPMENT_TEAM = ' "$PBXPROJ" | sed 's/.*DEVELOPMENT_TEAM = \(.*\);/\1/' | tr -d ' ')
CURRENT_BUNDLE_ID=$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER = ' "$PBXPROJ" | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER = \(.*\);/\1/' | tr -d ' ')

echo "Current Development Team: ${CURRENT_TEAM:-Not set}"
echo "Current Bundle ID: ${CURRENT_BUNDLE_ID:-Not set}"
echo ""

# Get available signing identities
print_step "Available signing identities:"
security find-identity -v -p codesigning | grep -E "Apple Development|iPhone Developer|Apple Distribution|iPhone Distribution" || echo "No signing identities found"
echo ""

# Interactive setup
read -p "Do you want to configure code signing? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Get team ID
    echo ""
    print_step "Enter your Development Team ID"
    print_info "You can find this in:"
    print_info "  1. Xcode → Preferences → Accounts → Team"
    print_info "  2. Apple Developer Portal → Membership"
    print_info "  3. Leave blank to use automatic signing"
    read -p "Team ID (current: $CURRENT_TEAM): " TEAM_ID
    
    if [ -z "$TEAM_ID" ]; then
        TEAM_ID=$CURRENT_TEAM
    fi
    
    # Get bundle identifier
    echo ""
    print_step "Enter your Bundle Identifier"
    print_info "Format: com.yourcompany.appname"
    print_info "This must match your App ID in Apple Developer Portal"
    read -p "Bundle ID (current: $CURRENT_BUNDLE_ID): " BUNDLE_ID
    
    if [ -z "$BUNDLE_ID" ]; then
        BUNDLE_ID=$CURRENT_BUNDLE_ID
    fi
    
    # Signing method
    echo ""
    print_step "Select signing method:"
    echo "1) Automatic signing (recommended for development)"
    echo "2) Manual signing (for production/CI)"
    read -p "Choice (1 or 2): " SIGNING_METHOD
    
    # Create backup
    print_step "Creating backup of project file..."
    cp "$PBXPROJ" "$PBXPROJ.backup"
    echo -e "${GREEN}✓ Backup created at $PBXPROJ.backup${NC}"
    
    # Update project settings
    print_step "Updating project settings..."
    
    if [ "$SIGNING_METHOD" = "1" ]; then
        # Automatic signing
        sed -i '' "s/CODE_SIGN_STYLE = .*/CODE_SIGN_STYLE = Automatic;/g" "$PBXPROJ"
        echo "✓ Set to automatic signing"
    else
        # Manual signing
        sed -i '' "s/CODE_SIGN_STYLE = .*/CODE_SIGN_STYLE = Manual;/g" "$PBXPROJ"
        echo "✓ Set to manual signing"
        
        # Ask for provisioning profile
        echo ""
        print_step "Provisioning Profile Configuration"
        print_info "Leave blank to let Xcode manage automatically"
        read -p "Provisioning Profile Name or UUID: " PROFILE
        
        if [ ! -z "$PROFILE" ]; then
            sed -i '' "s/PROVISIONING_PROFILE_SPECIFIER = .*/PROVISIONING_PROFILE_SPECIFIER = \"$PROFILE\";/g" "$PBXPROJ"
            echo "✓ Set provisioning profile"
        fi
    fi
    
    # Update team ID
    if [ ! -z "$TEAM_ID" ]; then
        sed -i '' "s/DEVELOPMENT_TEAM = .*/DEVELOPMENT_TEAM = $TEAM_ID;/g" "$PBXPROJ"
        echo "✓ Updated Development Team ID"
    fi
    
    # Update bundle ID
    if [ ! -z "$BUNDLE_ID" ]; then
        sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" "$PBXPROJ"
        echo "✓ Updated Bundle Identifier"
    fi
    
    echo ""
    echo -e "${GREEN}=== Configuration Updated ===${NC}"
    echo ""
    echo "Summary:"
    echo "  Team ID: $TEAM_ID"
    echo "  Bundle ID: $BUNDLE_ID"
    echo "  Signing: $([ "$SIGNING_METHOD" = "1" ] && echo "Automatic" || echo "Manual")"
    
    # Verify configuration
    echo ""
    print_step "Verifying configuration..."
    cd "$IOS_DIR"
    
    if xcodebuild -workspace Runner.xcworkspace -scheme Runner -showBuildSettings | grep -q "CODE_SIGN_IDENTITY"; then
        echo -e "${GREEN}✓ Code signing configuration valid${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Could not verify code signing${NC}"
    fi
    
else
    echo "Skipping configuration"
fi

# Additional tips
echo ""
echo -e "${BLUE}=== Tips for Successful iOS Development ===${NC}"
echo ""
echo "1. Ensure your Apple Developer account is configured in Xcode:"
echo "   Xcode → Settings → Accounts → Add Apple ID"
echo ""
echo "2. For physical device testing:"
echo "   - Enable Developer Mode (iOS 16+): Settings → Privacy & Security → Developer Mode"
echo "   - Trust your computer when prompted"
echo ""
echo "3. Common issues and solutions:"
echo "   - 'No signing certificate': Create one in Xcode → Settings → Accounts → Manage Certificates"
echo "   - 'No provisioning profile': Let Xcode create one automatically or create in Developer Portal"
echo "   - 'Bundle ID mismatch': Ensure Bundle ID matches your App ID in Developer Portal"
echo ""
echo "4. To reset signing configuration:"
echo "   - Restore from backup: cp $PBXPROJ.backup $PBXPROJ"
echo "   - Or use Xcode: Open project → Select Runner → Signing & Capabilities"
echo ""

# Check for common issues
print_step "Checking for common issues..."

# Check if development team is set
if [ -z "$CURRENT_TEAM" ] || [ "$CURRENT_TEAM" = "W778837A9L" ]; then
    echo -e "${YELLOW}⚠ Development Team needs to be configured${NC}"
    echo "  Run this script again and enter your team ID"
fi

# Check certificates
if ! security find-identity -v -p codesigning | grep -q "Apple Development"; then
    echo -e "${YELLOW}⚠ No Apple Development certificate found${NC}"
    echo "  Create one in Xcode → Settings → Accounts → Manage Certificates"
fi

echo ""
echo "Run './scripts/ios_build.sh' to build the app"