#!/bin/bash

# Fermi iOS Build Script
# This script provides a reliable way to build the iOS version of the Fermi Flutter app

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$PROJECT_ROOT/ios"

echo -e "${GREEN}=== Fermi iOS Build Script ===${NC}"
echo "Project Root: $PROJECT_ROOT"
echo "iOS Directory: $IOS_DIR"
echo ""

# Function to print step headers
print_step() {
    echo -e "${YELLOW}➤ $1${NC}"
}

# Function to handle errors
handle_error() {
    echo -e "${RED}✗ Error: $1${NC}"
    exit 1
}

# Check prerequisites
print_step "Checking prerequisites..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    handle_error "Flutter is not installed or not in PATH"
fi

# Check if CocoaPods is installed
if ! command -v pod &> /dev/null; then
    handle_error "CocoaPods is not installed. Install with: sudo gem install cocoapods"
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    handle_error "Xcode is not installed"
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Parse command line arguments
BUILD_TYPE="debug"
TARGET="simulator"
CLEAN_BUILD=false
UPDATE_PODS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --device)
            TARGET="device"
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --update-pods)
            UPDATE_PODS=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --release       Build in release mode (default: debug)"
            echo "  --device        Build for physical device (default: simulator)"
            echo "  --clean         Clean build before compiling"
            echo "  --update-pods   Update CocoaPods repositories before installing"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Navigate to project root
cd "$PROJECT_ROOT"

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_step "Cleaning previous build..."
    flutter clean
    rm -rf "$IOS_DIR/Pods"
    rm -rf "$IOS_DIR/Podfile.lock"
    rm -rf "$IOS_DIR/.symlinks"
    rm -rf "$PROJECT_ROOT/build"
    echo -e "${GREEN}✓ Clean completed${NC}"
    echo ""
fi

# Get Flutter dependencies
print_step "Getting Flutter dependencies..."
flutter pub get || handle_error "Failed to get Flutter dependencies"
echo -e "${GREEN}✓ Dependencies fetched${NC}"
echo ""

# Install/Update CocoaPods
print_step "Installing CocoaPods dependencies..."
cd "$IOS_DIR"

# Update repo if requested
if [ "$UPDATE_PODS" = true ]; then
    echo "Updating CocoaPods repositories..."
    pod repo update || handle_error "Failed to update CocoaPods repositories"
fi

# Install pods
pod install || handle_error "Failed to install CocoaPods dependencies"
echo -e "${GREEN}✓ CocoaPods installed${NC}"
echo ""

# Apply necessary patches
print_step "Applying iOS compatibility patches..."

# Patch for Firebase Swift 6 compatibility
FIREBASE_ENCODER="$IOS_DIR/Pods/FirebaseSharedSwift/FirebaseSharedSwift/Sources/third_party/FirebaseDataEncoder/FirebaseDataEncoder.swift"
if [ -f "$FIREBASE_ENCODER" ]; then
    if grep -q "@unchecked Sendable" "$FIREBASE_ENCODER"; then
        echo "FirebaseDataEncoder.swift already patched"
    else
        sed -i '' 's/extension JSONEncoder: Sendable {}/extension JSONEncoder: @unchecked Sendable {}/' "$FIREBASE_ENCODER"
        echo "✓ Patched FirebaseDataEncoder.swift"
    fi
fi

# Patch for UnfairLock Swift 6 compatibility
UNFAIR_LOCK="$IOS_DIR/Pods/FirebaseFirestoreInternal/FirebaseFirestoreInternal/Swift/Source/UnfairLock.swift"
if [ -f "$UNFAIR_LOCK" ]; then
    if grep -q "nonisolated(unsafe)" "$UNFAIR_LOCK"; then
        echo "UnfairLock.swift already patched"
    else
        sed -i '' 's/private var _lock/nonisolated(unsafe) private var _lock/' "$UNFAIR_LOCK"
        echo "✓ Patched UnfairLock.swift"
    fi
fi

echo -e "${GREEN}✓ Patches applied${NC}"
echo ""

# Return to project root for Flutter build
cd "$PROJECT_ROOT"

# Build the app
print_step "Building iOS app..."
echo "Build type: $BUILD_TYPE"
echo "Target: $TARGET"
echo ""

if [ "$TARGET" = "simulator" ]; then
    if [ "$BUILD_TYPE" = "release" ]; then
        flutter build ios --simulator --release || handle_error "Build failed"
    else
        flutter build ios --simulator --debug || handle_error "Build failed"
    fi
else
    if [ "$BUILD_TYPE" = "release" ]; then
        flutter build ios --release || handle_error "Build failed"
    else
        flutter build ios --debug || handle_error "Build failed"
    fi
fi

echo ""
echo -e "${GREEN}=== Build Successful! ===${NC}"
echo ""

# Provide next steps
if [ "$TARGET" = "simulator" ]; then
    echo "To run the app on iOS Simulator:"
    echo "  flutter run -d ios"
    echo ""
    echo "Or open in Xcode:"
    echo "  open $IOS_DIR/Runner.xcworkspace"
else
    echo "To install on a connected device:"
    echo "  flutter install"
    echo ""
    echo "Make sure your device is:"
    echo "  1. Connected via USB"
    echo "  2. Trusted on this computer"
    echo "  3. Developer mode enabled (iOS 16+)"
fi

# Build location info
echo ""
echo "Build artifacts location:"
if [ "$TARGET" = "simulator" ]; then
    echo "  $PROJECT_ROOT/build/ios/iphonesimulator/"
else
    echo "  $PROJECT_ROOT/build/ios/iphoneos/"
fi