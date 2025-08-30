#!/bin/bash

# Fermi iOS Development Helper Script
# Quick commands for common iOS development tasks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$PROJECT_ROOT/ios"

# Function to print menu header
print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Fermi iOS Development Helper        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to print menu option
print_option() {
    echo -e "${YELLOW}[$1]${NC} $2"
}

# Function to wait for user
wait_for_user() {
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu
show_menu() {
    print_header
    print_option "1" "Quick Build (Simulator)"
    print_option "2" "Build for Device"
    print_option "3" "Run on iOS Simulator"
    print_option "4" "Run on Connected Device"
    print_option "5" "Clean Build"
    print_option "6" "Update Dependencies"
    print_option "7" "Fix Common Issues"
    print_option "8" "Open in Xcode"
    print_option "9" "Show Device List"
    print_option "10" "Run Tests"
    print_option "11" "Generate App Icon"
    print_option "12" "Check Build Settings"
    print_option "0" "Exit"
    echo ""
    read -p "Select option: " choice
}

# Quick build for simulator
quick_build() {
    echo -e "${GREEN}Building for iOS Simulator...${NC}"
    cd "$PROJECT_ROOT"
    flutter build ios --simulator --debug
    echo -e "${GREEN}✓ Build complete${NC}"
    wait_for_user
}

# Build for device
build_device() {
    echo -e "${GREEN}Building for iOS Device...${NC}"
    cd "$PROJECT_ROOT"
    flutter build ios --debug
    echo -e "${GREEN}✓ Build complete${NC}"
    wait_for_user
}

# Run on simulator
run_simulator() {
    echo -e "${GREEN}Starting iOS Simulator...${NC}"
    cd "$PROJECT_ROOT"
    
    # List available simulators
    echo "Available simulators:"
    flutter devices | grep -i simulator || echo "No simulators found"
    echo ""
    
    read -p "Enter simulator ID (or press Enter for default): " sim_id
    
    if [ -z "$sim_id" ]; then
        flutter run -d ios
    else
        flutter run -d "$sim_id"
    fi
}

# Run on device
run_device() {
    echo -e "${GREEN}Running on connected iOS device...${NC}"
    cd "$PROJECT_ROOT"
    
    # List connected devices
    echo "Connected devices:"
    flutter devices | grep -v simulator || echo "No devices found"
    echo ""
    
    read -p "Enter device ID (or press Enter for first device): " device_id
    
    if [ -z "$device_id" ]; then
        flutter run
    else
        flutter run -d "$device_id"
    fi
}

# Clean build
clean_build() {
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    cd "$PROJECT_ROOT"
    flutter clean
    
    echo -e "${YELLOW}Removing iOS build cache...${NC}"
    rm -rf "$IOS_DIR/Pods"
    rm -rf "$IOS_DIR/Podfile.lock"
    rm -rf "$IOS_DIR/.symlinks"
    rm -rf ~/Library/Developer/Xcode/DerivedData/*
    
    echo -e "${GREEN}✓ Clean complete${NC}"
    
    echo -e "${YELLOW}Reinstalling dependencies...${NC}"
    flutter pub get
    cd "$IOS_DIR"
    pod install
    cd "$PROJECT_ROOT"
    
    echo -e "${GREEN}✓ Dependencies installed${NC}"
    wait_for_user
}

# Update dependencies
update_deps() {
    echo -e "${YELLOW}Updating Flutter dependencies...${NC}"
    cd "$PROJECT_ROOT"
    flutter pub upgrade
    
    echo -e "${YELLOW}Updating CocoaPods...${NC}"
    cd "$IOS_DIR"
    pod update
    
    echo -e "${GREEN}✓ Dependencies updated${NC}"
    wait_for_user
}

# Fix common issues
fix_issues() {
    echo -e "${YELLOW}Fixing common iOS build issues...${NC}"
    
    # Fix Swift compatibility
    echo "Applying Swift compatibility patches..."
    FIREBASE_ENCODER="$IOS_DIR/Pods/FirebaseSharedSwift/FirebaseSharedSwift/Sources/third_party/FirebaseDataEncoder/FirebaseDataEncoder.swift"
    if [ -f "$FIREBASE_ENCODER" ]; then
        sed -i '' 's/extension JSONEncoder: Sendable {}/extension JSONEncoder: @unchecked Sendable {}/' "$FIREBASE_ENCODER" 2>/dev/null || true
        echo "✓ Patched FirebaseDataEncoder.swift"
    fi
    
    UNFAIR_LOCK="$IOS_DIR/Pods/FirebaseFirestoreInternal/FirebaseFirestoreInternal/Swift/Source/UnfairLock.swift"
    if [ -f "$UNFAIR_LOCK" ]; then
        sed -i '' 's/private var _lock/nonisolated(unsafe) private var _lock/' "$UNFAIR_LOCK" 2>/dev/null || true
        echo "✓ Patched UnfairLock.swift"
    fi
    
    # Reset package cache
    echo "Resetting Flutter package cache..."
    cd "$PROJECT_ROOT"
    flutter pub cache clean --force
    flutter pub get
    
    # Reinstall pods
    echo "Reinstalling CocoaPods..."
    cd "$IOS_DIR"
    pod deintegrate
    pod install
    
    echo -e "${GREEN}✓ Common issues fixed${NC}"
    wait_for_user
}

# Open in Xcode
open_xcode() {
    echo -e "${GREEN}Opening project in Xcode...${NC}"
    open "$IOS_DIR/Runner.xcworkspace"
}

# Show device list
show_devices() {
    echo -e "${CYAN}Available devices:${NC}"
    echo ""
    flutter devices
    wait_for_user
}

# Run tests
run_tests() {
    echo -e "${GREEN}Running Flutter tests...${NC}"
    cd "$PROJECT_ROOT"
    
    if [ -d "test" ] && [ "$(ls -A test)" ]; then
        flutter test
    else
        echo -e "${YELLOW}No tests found in test/ directory${NC}"
        echo "Create tests in the test/ directory to run them"
    fi
    
    wait_for_user
}

# Generate app icon
generate_icon() {
    echo -e "${YELLOW}App Icon Generation${NC}"
    echo ""
    echo "Place your 1024x1024 icon as:"
    echo "  $PROJECT_ROOT/assets/icon/app_icon.png"
    echo ""
    echo "Then add flutter_launcher_icons to pubspec.yaml:"
    echo ""
    echo "dev_dependencies:"
    echo "  flutter_launcher_icons: ^0.14.2"
    echo ""
    echo "flutter_launcher_icons:"
    echo "  android: true"
    echo "  ios: true"
    echo "  image_path: \"assets/icon/app_icon.png\""
    echo ""
    echo "Run: flutter pub run flutter_launcher_icons"
    wait_for_user
}

# Check build settings
check_settings() {
    echo -e "${CYAN}iOS Build Settings:${NC}"
    echo ""
    
    # Get bundle ID
    BUNDLE_ID=$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER = ' "$IOS_DIR/Runner.xcodeproj/project.pbxproj" | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER = \(.*\);/\1/' | tr -d ' "')
    echo "Bundle ID: $BUNDLE_ID"
    
    # Get team ID
    TEAM_ID=$(grep -m1 'DEVELOPMENT_TEAM = ' "$IOS_DIR/Runner.xcodeproj/project.pbxproj" | sed 's/.*DEVELOPMENT_TEAM = \(.*\);/\1/' | tr -d ' ')
    echo "Team ID: ${TEAM_ID:-Not set}"
    
    # Get iOS deployment target
    DEPLOYMENT_TARGET=$(grep -m1 'IPHONEOS_DEPLOYMENT_TARGET = ' "$IOS_DIR/Runner.xcodeproj/project.pbxproj" | sed 's/.*IPHONEOS_DEPLOYMENT_TARGET = \(.*\);/\1/' | tr -d ' ')
    echo "iOS Deployment Target: $DEPLOYMENT_TARGET"
    
    # Check Firebase
    if [ -f "$IOS_DIR/Runner/GoogleService-Info.plist" ]; then
        echo "Firebase: ✓ Configured"
    else
        echo "Firebase: ✗ Not configured"
    fi
    
    # Check certificates
    echo ""
    echo "Signing Certificates:"
    security find-identity -v -p codesigning | grep "Apple Development" | head -3 || echo "  No certificates found"
    
    wait_for_user
}

# Main loop
while true; do
    show_menu
    
    case $choice in
        1) quick_build ;;
        2) build_device ;;
        3) run_simulator ;;
        4) run_device ;;
        5) clean_build ;;
        6) update_deps ;;
        7) fix_issues ;;
        8) open_xcode ;;
        9) show_devices ;;
        10) run_tests ;;
        11) generate_icon ;;
        12) check_settings ;;
        0) 
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            wait_for_user
            ;;
    esac
done