#!/bin/bash

# Standard build script for non-China regions with full CallKit support
# This is the default build for most App Store territories

echo "Building Fermi with full CallKit support..."
echo "For China builds, use build_china.sh instead"

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

# Build with standard configuration
if [ "$PLATFORM" == "ios" ]; then
    echo -e "${GREEN}Building iOS app with full features...${NC}"
    
    # Build iOS with standard configuration
    flutter build ios \
        --$BUILD_TYPE \
        --build-name=$(grep 'version:' pubspec.yaml | sed 's/version: //g' | cut -d'+' -f1) \
        --build-number=$(grep 'version:' pubspec.yaml | sed 's/version: //g' | cut -d'+' -f2)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ iOS build completed successfully${NC}"
        echo -e "${YELLOW}Archive location: build/ios/archive/${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Open Xcode and archive the app"
        echo "2. Upload to App Store Connect"
        echo "3. Select territories (exclude China if using this build)"
        echo "4. Submit for review"
    else
        echo -e "${RED}✗ iOS build failed${NC}"
        exit 1
    fi
    
elif [ "$PLATFORM" == "android" ]; then
    echo -e "${GREEN}Building Android app with full features...${NC}"
    
    # Build Android with standard configuration
    flutter build apk \
        --$BUILD_TYPE \
        --build-name=$(grep 'version:' pubspec.yaml | sed 's/version: //g' | cut -d'+' -f1) \
        --build-number=$(grep 'version:' pubspec.yaml | sed 's/version: //g' | cut -d'+' -f2)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Android build completed successfully${NC}"
        echo -e "${YELLOW}APK location: build/app/outputs/flutter-apk/app-$BUILD_TYPE.apk${NC}"
    else
        echo -e "${RED}✗ Android build failed${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Standard build completed with all features enabled${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Features enabled in this build:"
echo "  ✓ CallKit native call UI"
echo "  ✓ VoIP push notifications"
echo "  ✓ PushKit registration"
echo "  ✓ High-quality call experience"
echo ""
echo -e "${YELLOW}Note: This build includes CallKit and should NOT be${NC}"
echo -e "${YELLOW}distributed to China App Store. Use build_china.sh for China.${NC}"