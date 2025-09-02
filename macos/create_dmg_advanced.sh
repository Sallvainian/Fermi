#!/bin/bash

# Advanced Fermi macOS DMG Creation Script
# Creates a professional DMG with custom background and layout

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Building Fermi for macOS (Advanced DMG)...${NC}"

# Configuration
APP_NAME="Fermi"
VERSION=$(grep "version:" ../pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
DMG_NAME="Fermi-${VERSION}"
APP_PATH="build/macos/Build/Products/Release/teacher_dashboard_flutter.app"
DMG_PATH="build/macos/${DMG_NAME}.dmg"
VOLUME_NAME="Fermi ${VERSION}"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf build/macos/Build/Products/Release/*.app
rm -rf build/macos/*.dmg

# Build the Flutter app for macOS in release mode
echo -e "${YELLOW}Building Flutter app (this may take a few minutes)...${NC}"
flutter build macos --release

# Check if build was successful
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Build failed! App bundle not found.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"

# Sign the app (if certificates are available)
echo -e "${YELLOW}Checking code signing...${NC}"
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo -e "${BLUE}Code signing certificate found. Signing app...${NC}"
    IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}')
    codesign --force --deep --sign "$IDENTITY" "$APP_PATH"
    echo -e "${GREEN}✅ App signed successfully${NC}"
else
    echo -e "${YELLOW}⚠️  No Developer ID certificate found. App will not be signed.${NC}"
    echo -e "${YELLOW}   Users may see security warnings when opening the app.${NC}"
fi

# Create DMG with create-dmg if available, otherwise use hdiutil
if command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}Creating DMG with create-dmg...${NC}"
    
    # Create a custom DMG with window settings
    create-dmg \
        --volname "$VOLUME_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 150 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 450 150 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_PATH"
else
    echo -e "${YELLOW}create-dmg not found. Using basic DMG creation...${NC}"
    echo -e "${BLUE}Tip: Install create-dmg for a better installer:${NC}"
    echo -e "${BLUE}  brew install create-dmg${NC}"
    
    # Basic DMG creation
    TEMP_DIR=$(mktemp -d)
    cp -R "$APP_PATH" "$TEMP_DIR/$APP_NAME.app"
    ln -s /Applications "$TEMP_DIR/Applications"
    
    hdiutil create -volname "$VOLUME_NAME" \
        -srcfolder "$TEMP_DIR" \
        -ov \
        -format UDZO \
        "$DMG_PATH"
    
    rm -rf "$TEMP_DIR"
fi

# Verify DMG was created
if [ -f "$DMG_PATH" ]; then
    # Get file info
    SIZE=$(du -h "$DMG_PATH" | cut -f1)
    
    echo -e "${GREEN}✅ DMG created successfully!${NC}"
    echo ""
    echo -e "${GREEN}📦 Package Information:${NC}"
    echo -e "   Name: ${DMG_NAME}.dmg"
    echo -e "   Version: ${VERSION}"
    echo -e "   Size: ${SIZE}"
    echo -e "   Location: ${DMG_PATH}"
    echo ""
    
    # Verify the DMG
    echo -e "${YELLOW}Verifying DMG...${NC}"
    hdiutil verify "$DMG_PATH" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ DMG verification passed${NC}"
    else
        echo -e "${YELLOW}⚠️  DMG verification failed (non-critical)${NC}"
    fi
    
    # Open the folder containing the DMG
    echo -e "${BLUE}Opening output folder...${NC}"
    open "build/macos/"
    
    echo ""
    echo -e "${GREEN}🎉 Success! Your DMG installer is ready for distribution.${NC}"
    echo ""
    echo -e "${BLUE}Distribution Tips:${NC}"
    echo -e "  1. Test the installer on a clean Mac before distribution"
    echo -e "  2. Consider notarizing the app for Gatekeeper approval"
    echo -e "  3. Upload to a CDN or GitHub Releases for distribution"
else
    echo -e "${RED}❌ Failed to create DMG${NC}"
    exit 1
fi