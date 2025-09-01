#!/bin/bash

# Fermi iOS Troubleshooting Script
# This script helps diagnose and fix common iOS build issues

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

echo -e "${GREEN}=== Fermi iOS Troubleshooting ===${NC}"
echo ""

# Function to print headers
print_header() {
    echo -e "${YELLOW}━━━ $1 ━━━${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check Flutter environment
print_header "Flutter Environment"
FLUTTER_VERSION=$(flutter --version | head -n 1)
echo "$FLUTTER_VERSION"

if flutter doctor -v | grep -q "No issues found"; then
    print_success "Flutter environment is healthy"
else
    print_warning "Flutter doctor reported issues:"
    flutter doctor
fi
echo ""

# Check Xcode
print_header "Xcode Configuration"
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    echo "$XCODE_VERSION"
    
    # Check Xcode license
    if xcodebuild -license check &> /dev/null; then
        print_success "Xcode license accepted"
    else
        print_error "Xcode license needs to be accepted"
        echo "Run: sudo xcodebuild -license accept"
    fi
    
    # Check command line tools
    if xcode-select -p &> /dev/null; then
        print_success "Xcode command line tools installed"
    else
        print_error "Xcode command line tools not installed"
        echo "Run: xcode-select --install"
    fi
else
    print_error "Xcode not found"
    echo "Install Xcode from the App Store"
fi
echo ""

# Check CocoaPods
print_header "CocoaPods Status"
if command -v pod &> /dev/null; then
    POD_VERSION=$(pod --version)
    echo "CocoaPods version: $POD_VERSION"
    
    # Check if pods are installed
    if [ -d "$IOS_DIR/Pods" ]; then
        POD_COUNT=$(find "$IOS_DIR/Pods" -name "*.podspec" | wc -l | tr -d ' ')
        print_success "$POD_COUNT pods installed"
        
        # Check for outdated pods
        cd "$IOS_DIR"
        if pod outdated 2>/dev/null | grep -q "The following pod updates are available"; then
            print_warning "Some pods have updates available"
        else
            print_success "All pods are up to date"
        fi
        cd - > /dev/null
    else
        print_warning "Pods not installed"
        echo "Run: cd ios && pod install"
    fi
else
    print_error "CocoaPods not installed"
    echo "Run: sudo gem install cocoapods"
fi
echo ""

# Check Firebase configuration
print_header "Firebase Configuration"
FIREBASE_CONFIG="$IOS_DIR/Runner/GoogleService-Info.plist"
if [ -f "$FIREBASE_CONFIG" ]; then
    print_success "GoogleService-Info.plist found"
    
    # Extract bundle ID from Firebase config
    FIREBASE_BUNDLE_ID=$(grep -A1 'BUNDLE_ID' "$FIREBASE_CONFIG" | tail -n1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    echo "Firebase Bundle ID: $FIREBASE_BUNDLE_ID"
    
    # Check if it matches project bundle ID
    PROJECT_BUNDLE_ID=$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER = ' "$IOS_DIR/Runner.xcodeproj/project.pbxproj" | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER = \(.*\);/\1/' | tr -d ' ')
    if [ "$FIREBASE_BUNDLE_ID" = "$PROJECT_BUNDLE_ID" ]; then
        print_success "Bundle IDs match"
    else
        print_warning "Bundle ID mismatch"
        echo "  Firebase: $FIREBASE_BUNDLE_ID"
        echo "  Project:  $PROJECT_BUNDLE_ID"
    fi
else
    print_error "GoogleService-Info.plist not found"
    echo "Download from Firebase Console and add to ios/Runner/"
fi
echo ""

# Check code signing
print_header "Code Signing"
TEAM_ID=$(grep -m1 'DEVELOPMENT_TEAM = ' "$IOS_DIR/Runner.xcodeproj/project.pbxproj" | sed 's/.*DEVELOPMENT_TEAM = \(.*\);/\1/' | tr -d ' ')
if [ ! -z "$TEAM_ID" ] && [ "$TEAM_ID" != "W778837A9L" ]; then
    print_success "Development Team configured: $TEAM_ID"
else
    print_warning "Development Team not configured or using default"
    echo "Configure in Xcode or run: ./scripts/ios_setup_signing.sh"
fi

# Check for certificates
if security find-identity -v -p codesigning | grep -q "Apple Development"; then
    CERT_COUNT=$(security find-identity -v -p codesigning | grep -c "Apple Development")
    print_success "$CERT_COUNT development certificate(s) found"
else
    print_error "No Apple Development certificates found"
    echo "Create in Xcode → Settings → Accounts → Manage Certificates"
fi
echo ""

# Check for common issues in Podfile
print_header "Podfile Analysis"
if [ -f "$IOS_DIR/Podfile" ]; then
    # Check platform version
    PLATFORM_VERSION=$(grep "platform :ios" "$IOS_DIR/Podfile" | sed "s/.*'\(.*\)'.*/\1/")
    echo "iOS deployment target: $PLATFORM_VERSION"
    
    if [[ "${PLATFORM_VERSION%%.*}" -lt 14 ]]; then
        print_warning "iOS deployment target is below 14.0"
        echo "Consider updating to iOS 14.0 or higher for better compatibility"
    else
        print_success "iOS deployment target is appropriate"
    fi
    
    # Check for post_install hooks
    if grep -q "post_install" "$IOS_DIR/Podfile"; then
        print_success "Post-install hooks configured"
    else
        print_warning "No post-install hooks found"
    fi
else
    print_error "Podfile not found"
fi
echo ""

# Check for build errors
print_header "Recent Build Issues"
BUILD_LOG="$PROJECT_ROOT/build_output.log"
if [ -f "$BUILD_LOG" ]; then
    # Check for common errors
    if grep -q "No such module" "$BUILD_LOG"; then
        print_error "Module import errors found"
        echo "Solution: Run 'cd ios && pod install'"
    fi
    
    if grep -q "Code signing is required" "$BUILD_LOG"; then
        print_error "Code signing errors found"
        echo "Solution: Configure signing in Xcode or run ios_setup_signing.sh"
    fi
    
    if grep -q "Swift Compiler Error" "$BUILD_LOG"; then
        print_error "Swift compilation errors found"
        echo "Check for Swift version compatibility issues"
    fi
else
    print_info "No recent build log found"
fi
echo ""

# Provide fixes for common issues
print_header "Quick Fixes"
echo "1. Clean everything and rebuild:"
echo "   flutter clean && cd ios && rm -rf Pods Podfile.lock && pod install && cd .. && flutter build ios"
echo ""
echo "2. Fix code signing:"
echo "   ./scripts/ios_setup_signing.sh"
echo ""
echo "3. Update dependencies:"
echo "   flutter pub upgrade && cd ios && pod update && cd .."
echo ""
echo "4. Reset Xcode derived data:"
echo "   rm -rf ~/Library/Developer/Xcode/DerivedData/*"
echo ""
echo "5. Fix Firebase Swift compatibility:"
echo "   The build script automatically applies patches"
echo ""

# Check disk space
print_header "System Resources"
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    print_error "Low disk space (${DISK_USAGE}% used)"
    echo "Free up space by clearing Xcode derived data and caches"
else
    print_success "Adequate disk space available"
fi

# Memory check
MEMORY_PRESSURE=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
if [ "$MEMORY_PRESSURE" -lt 10000 ]; then
    print_warning "Low available memory"
    echo "Close unnecessary applications before building"
else
    print_success "Adequate memory available"
fi
echo ""

# Final recommendations
print_header "Recommendations"
ISSUES_FOUND=false

if [ -z "$TEAM_ID" ] || [ "$TEAM_ID" = "W778837A9L" ]; then
    print_warning "Configure your Development Team ID"
    ISSUES_FOUND=true
fi

if [ ! -d "$IOS_DIR/Pods" ]; then
    print_warning "Install CocoaPods dependencies"
    ISSUES_FOUND=true
fi

if [ ! -f "$FIREBASE_CONFIG" ]; then
    print_warning "Add GoogleService-Info.plist from Firebase Console"
    ISSUES_FOUND=true
fi

if [ "$ISSUES_FOUND" = false ]; then
    print_success "No critical issues found. Try building with:"
    echo "  ./scripts/ios_build.sh"
else
    echo ""
    echo "Fix the issues above, then run:"
    echo "  ./scripts/ios_build.sh"
fi