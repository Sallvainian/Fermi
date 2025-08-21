#!/bin/bash

# Build script for China App Store version with CallKit disabled
# This ensures compliance with China MIIT regulations

echo "Building Fermi for China App Store..."
echo "CallKit and VoIP features will be disabled"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}Error: pubspec.yaml not found. Please run this script from the project root.${NC}"
    exit 1
fi

# Parse command line arguments
BUILD_TYPE="release"
PLATFORM="ios"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) BUILD_TYPE="debug" ;;
        --profile) BUILD_TYPE="profile" ;;
        --ios) PLATFORM="ios" ;;
        --android) PLATFORM="android" ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo -e "${YELLOW}Building for platform: $PLATFORM in $BUILD_TYPE mode${NC}"

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Build with China-specific configuration
if [ "$PLATFORM" == "ios" ]; then
    echo -e "${GREEN}Building iOS app for China region...${NC}"
    
    # Build iOS with China mode enabled
    flutter build ios \
        --$BUILD_TYPE \
        --dart-define=FORCE_CHINA_MODE=true \
        --dart-define=VERBOSE_REGION_LOGGING=true \
        --build-name=$(grep 'version:' pubspec.yaml | sed 's/version: //g' | cut -d'+' -f1) \
        --build-number=$(grep 'version:' pubspec.yaml | sed 's/version: //g' | cut -d'+' -f2)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ iOS build for China completed successfully${NC}"
        echo -e "${YELLOW}Archive location: build/ios/archive/${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Open Xcode and archive the app"
        echo "2. Upload to App Store Connect"
        echo "3. Select China as available territory"
        echo "4. Submit for review"
    else
        echo -e "${RED}✗ iOS build failed${NC}"
        exit 1
    fi
    
elif [ "$PLATFORM" == "android" ]; then
    echo -e "${GREEN}Building Android app for China region...${NC}"
    
    # Build Android with China mode enabled
    flutter build apk \
        --$BUILD_TYPE \
        --dart-define=FORCE_CHINA_MODE=true \
        --dart-define=VERBOSE_REGION_LOGGING=true \
        --build-name=$(grep 'version:' pubspec.yaml | sed 's/version: //g' | cut -d'+' -f1) \
        --build-number=$(grep 'version:' pubspec.yaml | sed 's/version: //g' | cut -d'+' -f2)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Android build for China completed successfully${NC}"
        echo -e "${YELLOW}APK location: build/app/outputs/flutter-apk/app-$BUILD_TYPE.apk${NC}"
    else
        echo -e "${RED}✗ Android build failed${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Build completed for China region with CallKit disabled${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Features disabled in this build:"
echo "  • CallKit native call UI"
echo "  • VoIP push notifications"
echo "  • PushKit registration"
echo ""
echo "Fallback features enabled:"
echo "  • Standard push notifications for calls"
echo "  • Local notification call alerts"
echo "  • In-app call handling"