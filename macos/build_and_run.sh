#!/bin/bash

# Build and run Fermi on macOS
# This script handles code signing automatically

set -e

echo "🚀 Building Fermi for macOS..."

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Install pods
echo "Installing CocoaPods dependencies..."
cd macos
pod install
cd ..

# Build the app with automatic signing
echo "Building app..."
xcodebuild -workspace macos/Runner.xcworkspace \
    -scheme Runner \
    -configuration Debug \
    -derivedDataPath build/macos \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    -allowProvisioningUpdates

# Check if build succeeded
APP_PATH="build/macos/Build/Products/Debug/teacher_dashboard_flutter.app"
if [ -d "$APP_PATH" ]; then
    echo "✅ Build successful!"
    echo "📦 App location: $APP_PATH"
    
    # Run the app
    echo "🎯 Launching app..."
    open "$APP_PATH"
else
    echo "❌ Build failed!"
    exit 1
fi