#!/bin/bash

# Fermi macOS DMG Creation Script
# Creates a professional distributable DMG file for the Fermi macOS application

set -e

# Configuration
APP_NAME="Fermi"
REAL_APP_NAME="teacher_dashboard_flutter"
VERSION=$(grep 'version:' ../pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
BUILD_NUMBER=$(grep 'version:' ../pubspec.yaml | sed 's/.*+//')
DMG_FILE="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME}"

# Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_PATH="${PROJECT_ROOT}/build/macos/Build/Products/Release/${REAL_APP_NAME}.app"
DMG_OUTPUT="${PROJECT_ROOT}/build/macos/${DMG_FILE}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           ${GREEN}Fermi macOS DMG Creation Script v1.0${BLUE}                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📱 App: ${APP_NAME}${NC}"
echo -e "${GREEN}📦 Version: ${VERSION} (Build ${BUILD_NUMBER})${NC}"
echo -e "${GREEN}💾 Output: ${DMG_FILE}${NC}"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Parse command line arguments
BUILD_APP=false
SIGN_APP=false
NOTARIZE_APP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_APP=true
            shift
            ;;
        --sign)
            SIGN_APP=true
            shift
            ;;
        --notarize)
            NOTARIZE_APP=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --build      Build the Flutter app before creating DMG"
            echo "  --sign       Sign the app and DMG (requires MACOS_IDENTITY env var)"
            echo "  --notarize   Notarize the DMG (requires APPLE_ID, APPLE_ID_PASSWORD, APPLE_TEAM_ID env vars)"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Build app if requested
if [ "$BUILD_APP" = true ]; then
    echo -e "${YELLOW}🔨 Building Flutter app for macOS...${NC}"
    cd "$PROJECT_ROOT"
    flutter clean
    flutter pub get
    cd macos
    pod install
    cd ..
    flutter build macos --release --build-name="${VERSION}" --build-number="${BUILD_NUMBER}"
    cd "$SCRIPT_DIR"
fi

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: App not found at ${APP_PATH}${NC}"
    echo -e "${YELLOW}💡 Run with --build flag or run 'flutter build macos --release' first${NC}"
    exit 1
fi

# Install create-dmg if not available
if ! command_exists create-dmg; then
    echo -e "${YELLOW}📦 Installing create-dmg via Homebrew...${NC}"
    if ! command_exists brew; then
        echo -e "${RED}❌ Homebrew not found. Please install Homebrew first.${NC}"
        echo -e "${YELLOW}Visit: https://brew.sh${NC}"
        exit 1
    fi
    brew install create-dmg
fi

# Clean up any existing DMG
if [ -f "$DMG_OUTPUT" ]; then
    echo -e "${YELLOW}🧹 Removing existing DMG file...${NC}"
    rm "$DMG_OUTPUT"
fi

# Sign the app if requested
if [ "$SIGN_APP" = true ]; then
    if [ -z "$MACOS_IDENTITY" ]; then
        echo -e "${RED}❌ MACOS_IDENTITY environment variable not set${NC}"
        echo -e "${YELLOW}Export your signing identity: export MACOS_IDENTITY='Developer ID Application: Your Name'${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}🔐 Signing app with identity: ${MACOS_IDENTITY}${NC}"
    codesign --force --deep --options runtime --sign "$MACOS_IDENTITY" \
        --entitlements "${SCRIPT_DIR}/Runner/Release.entitlements" \
        "$APP_PATH"
    
    # Verify signature
    echo -e "${YELLOW}✔️  Verifying signature...${NC}"
    codesign --verify --verbose "$APP_PATH"
fi

# Create DMG
echo -e "${YELLOW}💿 Creating DMG package...${NC}"

# Check if we have a custom background image
BACKGROUND_IMG="${SCRIPT_DIR}/dmg_assets/background.png"
if [ -f "$BACKGROUND_IMG" ]; then
    echo -e "${GREEN}🎨 Using custom background image${NC}"
    BACKGROUND_ARG="--background $BACKGROUND_IMG"
else
    BACKGROUND_ARG=""
fi

# Check if we have a volume icon
VOLUME_ICON="${SCRIPT_DIR}/Runner/Assets.xcassets/AppIcon.appiconset/1024.png"
if [ -f "$VOLUME_ICON" ]; then
    VOLICON_ARG="--volicon $VOLUME_ICON"
else
    VOLICON_ARG=""
fi

# Create the DMG with create-dmg
create-dmg \
    --volname "$VOLUME_NAME" \
    $VOLICON_ARG \
    --window-pos 200 120 \
    --window-size 800 450 \
    --icon-size 100 \
    --icon "${REAL_APP_NAME}.app" 200 190 \
    --hide-extension "${REAL_APP_NAME}.app" \
    --app-drop-link 600 190 \
    --no-internet-enable \
    --hdiutil-quiet \
    $BACKGROUND_ARG \
    "$DMG_OUTPUT" \
    "$APP_PATH"

# Check if DMG was created successfully
if [ ! -f "$DMG_OUTPUT" ]; then
    echo -e "${RED}❌ Failed to create DMG${NC}"
    exit 1
fi

# Sign the DMG if requested
if [ "$SIGN_APP" = true ]; then
    echo -e "${YELLOW}🔐 Signing DMG...${NC}"
    codesign --force --sign "$MACOS_IDENTITY" "$DMG_OUTPUT"
fi

# Notarize if requested
if [ "$NOTARIZE_APP" = true ]; then
    if [ -z "$APPLE_ID" ] || [ -z "$APPLE_ID_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
        echo -e "${RED}❌ Missing notarization credentials${NC}"
        echo -e "${YELLOW}Required environment variables:${NC}"
        echo -e "  APPLE_ID, APPLE_ID_PASSWORD, APPLE_TEAM_ID"
        exit 1
    fi
    
    echo -e "${YELLOW}📤 Submitting DMG for notarization...${NC}"
    xcrun notarytool submit "$DMG_OUTPUT" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        --wait
    
    echo -e "${YELLOW}📌 Stapling notarization ticket...${NC}"
    xcrun stapler staple "$DMG_OUTPUT"
fi

# Generate checksums
echo -e "${YELLOW}🔒 Generating checksums...${NC}"
CHECKSUM=$(shasum -a 256 "$DMG_OUTPUT" | awk '{print $1}')
echo "$CHECKSUM  $DMG_FILE" > "${DMG_OUTPUT}.sha256"

# Display summary
SIZE=$(du -h "$DMG_OUTPUT" | cut -f1)
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     ${GREEN}✅ DMG Creation Complete!${BLUE}                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📦 DMG File: ${DMG_OUTPUT}${NC}"
echo -e "${GREEN}📏 Size: ${SIZE}${NC}"
echo -e "${GREEN}🔒 SHA256: ${CHECKSUM}${NC}"
echo ""

# Next steps
if [ "$SIGN_APP" = false ] || [ "$NOTARIZE_APP" = false ]; then
    echo -e "${YELLOW}📋 Next steps:${NC}"
    
    if [ "$SIGN_APP" = false ]; then
        echo -e "  • Sign the DMG for distribution:"
        echo -e "    ${BLUE}codesign --sign 'Developer ID Application: Your Name' '${DMG_OUTPUT}'${NC}"
    fi
    
    if [ "$NOTARIZE_APP" = false ]; then
        echo -e "  • Notarize the DMG:"
        echo -e "    ${BLUE}xcrun notarytool submit '${DMG_OUTPUT}' --apple-id YOUR_APPLE_ID --password YOUR_APP_PASSWORD --team-id YOUR_TEAM_ID${NC}"
        echo -e "  • Staple the notarization:"
        echo -e "    ${BLUE}xcrun stapler staple '${DMG_OUTPUT}'${NC}"
    fi
fi

echo -e "${GREEN}🎉 Your DMG is ready for distribution!${NC}"