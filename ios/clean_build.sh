#!/bin/bash

echo "Cleaning iOS build environment..."

# Clean Flutter build
echo "1. Cleaning Flutter build..."
cd .. && flutter clean

# Clean iOS specific files
echo "2. Removing iOS build artifacts..."
cd ios
rm -rf Pods
rm -rf .symlinks
rm -rf Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf build

# Clean CocoaPods cache
echo "3. Cleaning CocoaPods cache..."
pod cache clean --all

# Deintegrate pods
echo "4. Deintegrating CocoaPods..."
pod deintegrate || true

# Get Flutter dependencies
echo "5. Getting Flutter dependencies..."
cd .. && flutter pub get

# Install pods with repo update
echo "6. Installing CocoaPods..."
cd ios
pod repo update
pod install --repo-update

echo "iOS build environment cleaned and dependencies reinstalled!"
echo "You can now try building again with: flutter build ios"