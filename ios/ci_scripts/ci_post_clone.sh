#!/bin/sh

# Xcode Cloud post-clone script for Flutter
set -e

echo "Starting Flutter setup for Xcode Cloud"

# Change to workspace directory
cd $CI_WORKSPACE

# Install Flutter
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS
echo "Installing Flutter iOS artifacts..."
flutter precache --ios

# Install Flutter dependencies
echo "Getting Flutter packages..."
flutter pub get

# Install CocoaPods
echo "Installing CocoaPods..."
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

# Install CocoaPods dependencies
echo "Installing Pod dependencies..."
cd ios
pod install

echo "Setup complete!"